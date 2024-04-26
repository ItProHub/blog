---
title: 深入理解 HTTP Connection 头
date: 2024-03-19 16:11:52
tags: http http协议 Connection
---
HTTP Connection 头是 HTTP 协议中的一个重要头部字段，它用于控制客户端和服务器之间的连接行为。在本文中，我们将深入探讨 HTTP Connection 头部的作用、用法，并结合实际开发案例展示其在应用程序开发中的应用。

在开始本文的阅读之前，默认屏幕前的老铁已经对HTTP有了基础的认识。如果不是，请移步学习[超文本传输协议](https://zh.wikipedia.org/wiki/%E8%B6%85%E6%96%87%E6%9C%AC%E4%BC%A0%E8%BE%93%E5%8D%8F%E8%AE%AE#)


## 作用与语法
HTTP Connection头是通用类型标头，允许发送方或客户端指定该特定连接所需的选项。Connection 帮助使用单个 TCP 连接发送或接收多个 HTTP 请求/响应，而不是为每个请求/响应打开一个新连接。它还控制当前事务完成后网络是否保持打开或关闭状态。

### 语法
```http request
Connection: keep-alive
Connection: close
```

HTTP Connection头接受上面提到的两个指令，并如下所述：

+ keep-alive该指令表明客户端在发送响应消息后希望保持连接打开或活动。在 HTTP 1.1 版本中，默认情况下使用持久连接，该连接在事务后不会自动关闭。但HTTP 1.0不会将连接视为持久连接，因此如果要保持连接处于活动状态，则需要包含一个保持活动连接标头。
+ close这个关闭连接指令表明客户端在发送响应消息后想要关闭连接。在 HTTP 1.0 中，默认情况下连接会关闭。但在 HTTP 1.1 中，如果您希望关闭连接，则需要将其包含在标头中。

Http1.1 以后，Keep-Alive已经默认支持并开启。客户端（包括但不限于浏览器）发送请求时会在 Header 中增加一个请求头Connection: Keep-Alive，当服务器收到附带有Connection: Keep-Alive的请求时，也会在响应头中添加 Keep-Alive。这样一来，客户端和服务器之间的 HTTP 连接就会被保持，不会断开（断开方式下面介绍），当客户端发送另外一个请求时，就可以复用已建立的连接。

_保持连接和不保持连接区别可以参考下面的图_
![handshake](/images/http/perisitent-connection.png)


## Keep-Alive的优缺点
keep-alive 这么完美么？
### 优点：

1. 减少连接建立和断开的开销： 使用长连接可以避免在每次请求时都重新建立连接，从而减少了连接建立和断开的时间和开销。
2. 减少网络延迟： 由于连接已经建立，可以直接进行数据传输，不需要等待连接的建立过程，从而减少了网络延迟，提高了数据传输效率。
3. 提高性能： 长连接可以实现连接的复用，多个请求可以共享同一个连接，从而减少了服务器的负担，提高了系统的整体性能。

### 缺点：
1. 资源占用： 长连接会占用服务器和客户端的资源，尤其是在连接空闲时，会持续占用资源，可能导致资源浪费。
2. 可能造成资源不足： 如果长时间保持大量的长连接，可能会耗尽服务器和客户端的资源，导致性能下降甚至崩溃。

## 怎么断开连接
### 通过 Keep-Alive Timeout 标识
keep-alive不会永久保持连接，它有一个保持时间，可以在不同的服务器软件（如Apache）中设定这个时间。实现长连接需要客户端和服务端都支持长连接。
Keep-Alive：如果浏览器请求保持连接，则该头部表明希望 WEB 服务器保持连接多长时间（秒）。例如：
```http request
Keep-Alive:timeout=5
```
<font color="#dd0000">注意：Mozilla 和 Konquor 浏览器能识别 “Keep-Alive：Timeout=Time” 报头字段，而 MSIE 在大约 60 秒内自行关闭保活连接。</font>

### 通过 Connection close 标识
通在 Response Header 中增加Connection close标识，来主动告诉发送端，连接已经断开了，不能再复用了；客户端接收到此标示后，会销毁连接，再次请求时会重新建立连接。

注意：配置 close 配置后，并不是说每次都新建连接，而是约定此连接可以用几次，达到这个最大次数时，接收端就会返回 close 标识


## 动手试一试
为了更好的理解keep-alive是怎么玩的，我写了一个简单的例子

+ 主动断开连接
```
[HttpGet]
[ActionTitle(Name = "关闭连接")]
[Route("close.svc")]
public void Close()
{
    Response.Headers.Connection = "close";
    return;
}
```
![主动断开连接](/images/http/handshake-2.png)
首先，我们第一次调用start接口打开连接，可以看到开始的三次握手。后续我们再次发送请求的时候，由于连接还没有断开，所以就不再有三次握手的过程。

然后，我们又主动调用了close这个接口，这个接口返回的头部信息中携带了“connection: close”，告诉浏览器要关闭连接。因此在此之后我们立马就看到了4次挥手。

+ 超时断开连接(Mozilla)
```C#
[HttpGet]
[ActionTitle(Name = "开启连接")]
[Route("start.svc")]
public void Start()
{
    Response.Headers.KeepAlive = "timeout=10, max=3";
    return;
}
```
  ![主动断开连接](/images/http/timeout-auto-disconnect.png)
在服务端设置10s超时。第一次主动打开连接，之后我们不再进行请求，10s之后连接自动断开。


+ 被动断开连接
![主动断开连接](/images/http/auto-disconnect.png)
上图可以看到，我们第一次主动打开连接。之后我们不再进行请求，一段时间之后连接自动断开。

**分析上图流程**
+ 首先：10.21.21.6（本机ip）率先向服务端 发起了 Keep-Alive 报文
+ 服务端会进行 Keep-Alive ACK
+ 规律是 客户端一直在发送 Keep-Alive ，服务端呢，一直在 Keep-Alive ACK，且 Seq 和 Ack 一直没有变
+ 大概过了 5min 服务端率先发起 FIN ACK 进入 进入挥手 断开连接阶段

**猜想**
+ 客户端 TCP 在没有数据流通时有自己的探活机制，由客户端上报 Keep-Alive 报文，服务端 ACK ，双方确认彼此活着。
+ 探活有时间限制，超过限定时间，如果一直没有数据交换，即使探活心跳正常，也会进行挥手断连，释放资源。

## TCP  Keep-Alive 机制
> + TCP Keep-Alive 并不是 TCP 标准的一部分，而是由协议栈实现者进行拓展实现，主流操作系统 Linux、Windows、MacOS 都进行了对应的实现。 
> + TCP Keep-Alive 报文是由操作系统或网络库实现的，而不是由特定的应用程序（如浏览器或HTTP客户端库）直接发送的。它是一种网络层的功能，用于维持两个网络设备之间的连接状态。这个机制在TCP协议中定义，允许一方在一定时间内没有收到数据时发送探测包，以确认连接的另一端是否仍然可达。 
> + 在Windows操作系统中，这通常通过发送TCP Keep-Alive探测包来实现，这些探测包是由操作系统的网络堆栈自动发送的。

以下是一些可能发送TCP Keep-Alive报文的实体：
1. 操作系统网络堆栈：大多数现代操作系统都会实现TCP Keep-Alive功能。例如，在Windows中，可以通过注册表设置或使用netsh命令来配置TCP Keep-Alive参数。
2. 网络库：某些编程语言的网络库可能实现了自己的Keep-Alive逻辑。例如，Java的HttpURLConnection或C#的HttpClient可能会在底层TCP连接上启用Keep-Alive。
3. 浏览器：虽然浏览器可能不会在没有HTTP请求的情况下发送Keep-Alive报文，但它们可能会定期发送HTTP/1.1协议中的Keep-Alive头部，这是一种应用层的机制，用于维持HTTP连接的活跃状态。
4. 其他网络应用程序：任何使用TCP连接的应用程序都可能实现自己的Keep-Alive逻辑，以确保连接的持续性。

## 结语
HTTP Connection 头是 HTTP 协议中非常重要的头部字段之一，它控制着客户端和服务器之间的连接行为，直接影响着通信的效率和性能。在实际开发中，合理使用 HTTP Connection 头可以有效地管理网络资源，提高通信的效率。希望本文能够帮助读者更深入地理解 HTTP Connection 头的作用和用法，并在实际开发中加以应用。


更多一手讯息，可关注公众号：[ITProHub](https://myom-dev.oss-cn-hangzhou.aliyuncs.com/WechatPublicPlatformQrCode.jpg)

![ITProHub](https://myom-dev.oss-cn-hangzhou.aliyuncs.com/WechatPublicPlatformQrCode.jpg)