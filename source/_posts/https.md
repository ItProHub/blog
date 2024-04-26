---
title: HTTPS的工作原理以及安装
date: 2024-04-11 15:36:46
tags: https http ssl tls
---

# 什么是 HTTPS？
HTTP 是一种用于在服务器和客户端（Web 浏览器）之间交换数据的互联网协议。 HTTPS 只不过是在HTTP的基础上添加了安全层。
HTTP 不是一个安全协议：它是为了纯粹的功能目标而设计的，没有考虑任何安全约束。

所以我们给HTTP添加了一个安全层。更准确地说，将 HTTP 封装到安全连接中。

![安全连接](/images/https/security.png)

HTTPS 使我们能够实现三个目标：

+ 身份验证：HTTPS 使用数字证书来验证服务器和客户端的身份，防止中间人攻击。服务器需要提供有效的数字证书，而客户端可以验证证书的有效性，确保与正确的服务器建立连接。
+ 隐私：网络上的任何人都无法读取数据，因为它是加密的
+ 完整性：HTTPS 使用消息摘要算法（如 SHA-256）来计算数据的摘要，并将摘要与数据一起传输。接收方可以验证数据的完整性，确保数据在传输过程中未被篡改。


# 证书颁发机构
证书颁发机构是提供 SSL 证书的公司。这些组织为网络浏览器所熟知，并接受这些机构提供的证书。
任何人都可以生成证书，但如果不是由已知机构提供的，浏览器会显示安全警报。

证书颁发机构示例：DigiCert、GeoTrust、GlobalSign、CFCA、TrustAsia

![ca](/images/https/ca2.png)

# SSL 握手
SSL 握手是 Web 服务器和浏览器讨论并商定要使用的协议（特定版本中的 SSL 或 TLS）、要使用的密码套件以及最后要使用的会话密钥的过程。握手完成后进行通信。

![握手过程](/images/https/handshake.png)图片来源：https://code-maze.com/wp-content/uploads/2017/07/TLS-handshake.png

不深究细节，握手会经过以下步骤：

1. 浏览器和服务器就所使用的协议达成一致（SSL X、TLS X）
2. 浏览器验证服务器的真实性（证书颁发机构）
3. 浏览器创建会话密钥并使用服务器的公钥对其进行加密
4. 服务器用其私钥解密先前的消息
5. 浏览器和服务器使用他们刚刚商定的会话密钥进行通信。握手完毕。




感兴趣的同学也可以抓包看一下https访问的详细过程，下面是用wireshark抓包的结果
![握手](/images/https/client-hello.png)
握手完成后数据传输的都是加密的数据
![数据加密](/images/https/encrypted.png)




# 密码套件
HTTPS 内存在不同级别的加密。
如前所述，HTTPS 是将 HTTP 封装到安全协议 SSL 或 TLS 中。
这两种安全协议存在不同的版本，其中一些被认为是较弱的。自“POODLE”漏洞以来，SSL V2 已过时，SSL V3 也已过时。（感兴趣的同学可以自行百度）
使用：TLS v1.0、v1.1、v1.2

此外，SSL和TLS使用不同的加密算法。这些算法在通信过程中使用，使用哪种算法取决于服务器和浏览器接受的算法。
随着时间的推移，其中一些算法会变得很弱，必须停用：
例如，我们可以提到密钥大小低于 128 位的所有密码和 RC4 算法。

因此，有必要使系统保持最新，特别是 Web 服务器的 HTTPS 配置。

## client hello
下面是我们通过wireshar抓包查看客户端支持的密码套件
![客户端支持的密码套件](/images/https/cipher-suites.png)

## server hello
客户端与服务端协商密码套件, 主要是从客户端支持的加密方式中选择一个合适的告诉客户端。
![协商密码套件](/images/https/negotiated-cipher-suite.png)

## 该密码串的含义
ECDHE：密钥交换算法
ECDSA：身份验证
AES_128_CBC：用于消息加密的批量密码
SHA：MAC 算法


# 在 Web 服务器上安装 HTTPS
对于不同类型的服务器，在 Web 服务器上配置 HTTPS 相对简单，并且有详细的文档记录。

设置的主要步骤是：

+ 向证书颁发机构订购 SSL 证书
+ 在 Web 服务器中安装证书（要复制到服务器的文件）
+ 配置网络服务器

服务器的配置可能包括：

+ 证书绑定的IP地址-端口/域名
+ 激活协议的配置（TLS/SSL）
+ 算法和密码密钥大小的配置（密码套件）

```nginx
server {
    listen 443 ssl;
    server_name xxx;

    ssl_certificate /cert/xxx.crt;
    ssl_certificate_key /cert/xxx.key;

    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

可以在下面找到详细说明如何在三个主要 Web 服务器上安装 SSL 的文档链接：
Apache：  https://wiki.apache.org/httpd/SSL
IIS： http://www.iis.net/learn/manage/configuring-security/how-to-set-up-ssl-on-iis
Nginx： http://nginx.org/en/docs/http/configuring_https_servers.html

Mozilla 发布了一个站点，你可以在其中生成安全的 HTTPS 配置：

[Mozilla SSL 配置生成器](https://mozilla.github.io/server-side-tls/ssl-config-generator/)


# 保持 HTTPS 更新为最新
HTTPS 配置不是一次性事件。安装后，必须保持其配置最新。
很多bug都会影响一些较低版本的openSSL库(例如[Heartbleed](https://baike.baidu.com/item/Heartbleed/13580882)), 系统更新可以帮助避免一些与 HTTPS 使用直接相关的漏洞。

此外，有必要随时了解不同协议和密码套件的安全性。这里的目标是在某些时候被认为较弱的情况下停用其中一些。

最后一点也是很重要的，也是很明显但经常被遗忘的：证书过期。一旦证书过期，网络浏览器将显示非常具有劝阻性的安全警报，鼓励用户离开网站。

相信大家在浏览网站的时候遇到过这样的情况
![过期](/images/https/expire.png)


# HTTPS 不做什么
人们很容易认为 HTTPS 是一个神奇的互联网安全解决方案，但它还有很多不能做的事情。

## HTTPS 不会：
1. 隐藏你正在访问的网站的名称

这是因为网站的名称（又名“域”）是使用 DNS（域名服务）发送的，而 DNS 不在 HTTPS 隧道内。它在建立安全连接之前发送。中间的窃听者可以看到你要访问的网站的名称（例如 TipTopSecurity.com），他们只是无法读取来回传输的任何实际内容。直到DNSSEC完全实施后，这种情况才会改变。

2. 保护你免受访问邪恶网站的侵害

HTTPS 不能确保网站本身的安全。仅仅因为你安全连接并不意味着你没有连接到由坏人运行的网站。我们尝试通过受信任的证书颁发机构来解决此问题，但该系统并不完美（请继续关注有关此方面的更多信息）。

3. 提供匿名

HTTPS 不会隐藏你的物理位置或个人身份。你的个人 IP 地址（你在互联网上的地址）必须附加到加密数据的外部，因为如果你的 IP 地址也被加密，互联网将不知道将其发送到哪里。而且它也不会在你正在访问的网站上隐藏你的身份。你访问的网站仍然了解你的一切，就像在非安全连接上一样。

4. 防止你感染病毒

HTTPS 不是过滤器。有可能通过 HTTPS 连接接收病毒和其他恶意软件。如果 Web 服务器被感染或者你所在的恶意网站正在分发恶意软件，则该恶意软件将像其他所有内容一样在 HTTPS 流中发送。然而， HTTPS确实可以防止中间的任何人将恶意软件注入到你的移动流量中。

5. 保护你的计算机免遭黑客攻击

HTTPS 仅保护在你的计算机和 Web 服务器之间移动的数据。它不会为你的实际计算机或服务器本身提供任何保护。这也意味着，如果有恶意软件正在监视连接一端的流量，它就可以读取 HTTPS 流中加密之前和之后的流量。


更多一手讯息，可关注公众号：[ITProHub](https://myom-dev.oss-cn-hangzhou.aliyuncs.com/WechatPublicPlatformQrCode.jpg)

![ITProHub](https://myom-dev.oss-cn-hangzhou.aliyuncs.com/WechatPublicPlatformQrCode.jpg)