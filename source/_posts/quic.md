---
title: QUIC:被寄予厚望的下一代互联网传输协议
date: 2024-08-16 16:45:11
tags:
---
HTTP协议是一种应用协议，它通常运行在TCP之上。但是TCP协议存在一些限制，导致Web应用程序响应速度较慢。

为了克服 TCP 的缺点，Google开发了一种改变游戏规则的传输协议 QUIC。QUIC（Quick UDP Internet Connections）是一种传输层网络协议，最早由Google在2012年提出，旨在改善HTTP/2的性能，特别是在高延迟和不稳定网络条件下。QUIC的主要目标是通过基于UDP的传输来减少连接建立时间、提高传输效率，并改善整体网络性能。随着QUIC的逐渐成熟，IETF（互联网工程任务组）标准化了QUIC，并且它现在成为HTTP/3的底层协议。

本文我们将开始了解 QUIC 将如何取代 TCP。我们将首先介绍 TCP 和 UDP 的一些基本网络概念。然后我们将了解 QUIC 是什么以及它是如何工作的。我们将探讨为什么 QUIC 比 TCP 具有更高的性能


# 为什么选择QUIC？

传统的HTTP/2虽然引入了多路复用，但它仍然依赖于TCP（传输控制协议）。TCP在设计时主要考虑可靠性，而不是速度。这导致了几个问题，特别是在移动设备或高延迟网络中：

1. 连接建立慢：TCP的握手过程需要三次往返，特别是在TLS（传输层安全）上使用时，可能还需要额外的握手。
![三次握手](/images/http/TCP-connection-1.png)<center>(图片来源网络)</center>

2. 队头阻塞（Head-of-Line Blocking）：虽然HTTP/2在应用层引入了多路复用，但底层TCP流仍然是串行的，任何丢包都会导致所有流的传输被阻塞。

    >HTTP管道化要求服务端必须按照请求发送的顺序返回响应，那如果一个响应返回延迟了，那么其后续的响应都会被延迟，直到队头的响应送达。

![队头阻塞](/images/quic/head_of_line_blocking.png)<center>(图片来源网络)</center>

QUIC通过以下方式解决了这些问题：

1. 更快的连接建立：QUIC将握手时间减少到一次往返（0-RTT），在某些情况下甚至可以做到无往返（0-RTT Resumption）。
2. 内置加密：QUIC协议本身内置了TLS 1.3加密，减少了TLS握手带来的延迟。
3. 多路复用无队头阻塞：QUIC使用独立的传输流，丢包只会影响特定的流，不会阻塞其他流的数据传输。
4. 更好的移动性支持：QUIC支持连接迁移，这意味着在切换网络（如从Wi-Fi切换到4G）时，连接可以保持不变，无需重新建立。

# QUIC协议的核心特性

1. UDP传输：QUIC基于UDP协议，而不是传统的TCP。这使得它能够实现更快的握手过程，并在高延迟网络环境下表现更好。
 
    > 你可能想知道“由于 QUIC 在 UDP 上工作，数据包会丢失吗？”。答案是不会。QUIC 在 UDP 堆栈之上增加了可靠性。它实现了数据包重传，以防它没有收到必要的数据包。例如：- 如果服务器没有从客户端收到数据包 5，协议将检测到它，服务器将要求客户端重新发送相同的数据包。

2. 多路复用：QUIC允许多个数据流在一个连接中传输，这意味着即使某个数据流出现丢包，其他流也不会受到影响，减少了队头阻塞问题。

3. 连接迁移：QUIC协议允许连接在不同的IP地址和端口之间迁移。这对于移动设备非常有用，例如在Wi-Fi和4G网络之间切换时，连接不会中断。

4. 内置加密：QUIC协议默认集成了TLS 1.3，确保数据传输的安全性，同时减少了加密握手所需的时间。

5. 拥塞控制：QUIC引入了先进的拥塞控制机制，通过实时调整传输速率来优化网络性能，特别是在网络状况不佳的情况下。

# 与TCP的对比
|特性|	TCP |	QUIC |
|--|--|--|
|传输层|	基于TCP|	基于UDP|
|多路复用|	受限于TCP的队头阻塞|	无队头阻塞的多路复用|
|加密|	可选（如TLS）|	内置TLS 1.3|
|握手时间|	至少需要一个RTT|	最低0-RTT|
|连接迁移|	不支持 |	支持|
|实时性|	表现较差，适合可靠传输|	表现优秀，适合低延迟传输|

# QUIC建立连接
在QUIC协议的握手过程中，特别是使用TLS 1.3时，客户端和服务器之间需要多次交换消息来完成连接的建立和加密密钥的协商。
![handshake](/images/quic/handshake.png)

## 简单流程图总结：

1. ClientHello -> 客户端发起握手请求，包含支持的加密算法和其他参数。
2. ServerHello -> 服务器回应，选择加密算法，并发送证书。
3. Certificate -> 服务器发送证书并验证身份。
4. Finished -> 双方确认加密密钥和握手完成。
5. 开始加密通信 -> 使用QUIC加密数据流开始实际数据传输。

## 为什么需要多次消息交换：

+ 身份验证：客户端需要验证服务器身份，防止中间人攻击。
+ 密钥协商：客户端和服务器需要共同生成会话密钥，用于加密后续的通信。
+ 加密通道建立：完成握手后，双方通信将完全通过加密通道进行，确保数据安全。

QUIC利用TLS 1.3的握手过程来保证安全性，并结合了QUIC的低延迟特性，使得连接建立和数据传输更加快速。如果看到多个握手消息，这是因为握手的各个阶段涉及到多个消息的交换和验证。

# 测试连接迁移
上面说到QUIC支持连接迁移，这里我们撸一个简单的例子看看效果。

为了方便看到具体的效果，这里我们撸了一个站点先后分别使用TCP和UDP。nginx配置如下所示（TCP的配置注释QUIC相关配置即可）：
```
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    listen 443 quic reuseport;
    listen [::]:443 quic reuseport;

    http2 on;
    server_name itprohub.site www.itprohub.site;

    ssl_certificate /etc/ssh/itprohub.site_bundle.crt;
    ssl_certificate_key /etc/ssh/itprohub.site.key;

    # 配置 QUIC 相关的 HTTP/3 选项
    #add_header Alt-Svc 'h3=":443"; ma=86400';  # HTTP/3 ALPN

    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256";  # 适用于 TLS 1.3 的推荐套件
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

```
然后用手机访问该站点，过程中我们切换手机网络，并在服务端进行抓包。
```
sudo tcpdump -i eth0 udp port 443 -w quic_capture.pcap
```
最后我们用wireshark 分析抓包文件

TCP如下：
![TCP](/images/quic/tcp.png)

QUIC如下：
![QUIC](/images/quic/quic.png)

对比两次的结果，我们会发现TCP切换网络之后ip立即发生的变化，并且重新进行握手。而QUIC没有立即变化ip，同时没有重新握手的过程。

QUIC 协议设计的一个关键点就是支持连接迁移，即使客户端的 IP 地址发生变化，QUIC 也会尽量保持同一个连接不中断。因此，当你切换网络时，QUIC 可能会继续使用旧的连接来发送数据包，而不会立即使用新的 IP 地址，这就是为什么 Wireshark 可能不会立即显示 IP 变化。

具体来说，QUIC 会尝试通过网络路径发现（Path Validation）来验证新的网络路径是否可用，这个过程可能需要一些时间。在切换网络后的短时间内，QUIC 可能仍会通过旧的路径发送数据，直到确认新路径可用。这就解释了为什么你在 Wireshark 中看到 QUIC 的 IP 地址没有变化，而 TCP 切换网络后立即更新了 IP 地址。

# QUIC协议的应用场景

1. 视频流媒体：在视频流媒体应用中，低延迟和稳定性是至关重要的。QUIC的多路复用和更快的连接建立时间使得它成为理想的选择，尤其是在不稳定的网络环境下。

2. 实时通讯：在VoIP或视频会议等实时通讯应用中，QUIC的低延迟和快速恢复能力显著改善了用户体验。

3. 移动应用：对于频繁切换网络环境的移动应用（如Wi-Fi到4G切换），QUIC的连接迁移能力确保了连接的连续性，减少了重新连接的开销。

4. Web浏览：HTTP/3已经逐步取代HTTP/2成为新的Web传输标准。QUIC作为HTTP/3的底层协议，改善了页面加载速度，特别是在复杂网页内容的加载过程中。

# QUIC的挑战

尽管QUIC有许多优势，但它也面临一些挑战：

1. UDP阻塞：由于QUIC基于UDP，一些网络设备（如防火墙和NAT）可能会阻止或限制UDP流量，影响QUIC的性能。

2. 兼容性问题：尽管QUIC越来越受欢迎，但并不是所有设备和应用程序都支持它。因此，过渡到QUIC需要兼顾兼容性问题。

3. 复杂性增加：由于QUIC集成了加密和多路复用等功能，相比TCP，它的实现更为复杂，可能导致维护成本的增加。


# 总结

随着互联网对实时性和效率的需求不断增长，QUIC将扮演越来越重要的角色。HTTP/3的普及将推动QUIC的广泛应用，尤其是在Web浏览和实时应用中。此外，随着5G网络的发展，QUIC的低延迟和高效率将进一步展示其优势。

QUIC作为一种新型的传输协议，通过改进连接建立、减少延迟、支持多路复用和连接迁移，解决了TCP的许多固有问题。虽然QUIC仍然面临一些挑战，但随着标准化和应用的推进，它将成为未来互联网的重要组成部分。开发者可以开始探索并应用QUIC协议，以提升应用程序的网络性能和用户体验。

----

这篇博客旨在帮助你理解和应用QUIC协议。如果你有任何关于QUIC的疑问或经验分享，欢迎在评论区讨论！