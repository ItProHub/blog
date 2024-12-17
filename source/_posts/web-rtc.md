---
title: WebRTC入门：让浏览器之间的实时通信变得简单
date: 2024-12-16 17:23:31
tags:
---

# 什么是WebRTC？
WebRTC（Web Real-Time Communication）是一项支持网页和移动应用程序进行实时语音、视频和数据共享的技术，允许用户直接在浏览器中进行通信，无需安装额外的插件或应用。WebRTC是一项开放标准，由W3C和IETF共同推动，广泛应用于视频会议、即时通讯、文件共享等场景。

WebRTC的核心优势在于其低延迟、高效率和跨平台支持，使得不同设备和浏览器之间的实时通信变得简单和快速。

# WebRTC的三大核心技术
WebRTC的功能依赖于三个主要的API：

1. getUserMedia API：这个API允许浏览器访问用户的媒体设备，如摄像头和麦克风，捕获音视频流。

2. RTCPeerConnection API：这个API负责处理浏览器之间的点对点连接，确保音视频数据能够在浏览器间高效、稳定地传输。

3. RTCDataChannel API：这个API允许浏览器之间传输任意类型的数据，如文本、文件或其他媒体文件。

# WebRTC如何工作？
WebRTC的工作原理可以概括为以下几个步骤：

![结构](./images/webrtc/architecture.png)

1. 媒体设备访问：使用getUserMedia API获取音视频流。

2. 建立连接：使用RTCPeerConnection API建立点对点连接。此时，浏览器之间需要交换一些“信令”信息（如SDP，Session Description Protocol）以建立连接。

3. ICE协议：WebRTC使用ICE（Interactive Connectivity Establishment）协议在浏览器间选择最佳的传输路径，以确保点对点连接的质量和稳定性。

4. 数据传输：通过RTCDataChannel API，浏览器之间可以直接传输任意数据。

# SDP是什么？
SDP（Session Description Protocol） 是一个描述多媒体会话的协议，它用于提供多媒体通信的会话参数，包括音频、视频、数据等流的格式、编解码器信息、网络地址等。在 WebRTC 中，SDP 协议扮演着一个非常重要的角色，它被用来在建立点对点连接时描述会话的各项参数，如音视频的编解码方式、网络传输信息等。

在 WebRTC 中，SDP 主要用于两个目的：

+ 描述媒体会话：通过 SDP 来描述媒体会话的格式、编解码器、网络传输信息等。
+ 建立连接：通过交换 SDP offer 和 answer，WebRTC 的两端可以协商连接的参数并建立 P2P 连接。

##  WebRTC 中的 SDP 交换流程
WebRTC 使用 SDP 来交换会话的描述，通常通过信令通道（如 WebSocket、Socket.io 等）在两个端点之间交换 offer 和 answer：

### 创建 Offer 和 Answer
- Offer：由发起方（通常是客户端 A）创建，表示该方希望建立连接。offer 会包含可支持的媒体格式、编解码器、传输协议等信息。
- Answer：由接收方（通常是客户端 B）创建，表示同意建立连接，并返回支持的媒体格式、编解码器等信息。接收方根据 offer 的内容来选择合适的媒体参数，并生成 answer。

## SDP 交换过程
1. 发起方创建 SDP offer：
- 发起方通过 RTCPeerConnection.createOffer() 创建一个包含媒体信息的 offer。
- 发起方将 offer 通过信令通道发送给接收方。

2. 接收方收到 offer 后创建 SDP answer：
- 接收方收到 offer 后，通过 RTCPeerConnection.createAnswer() 创建 answer。
- 接收方根据自身的能力（如支持的编解码器、分辨率等）生成适合的 answer，并通过信令通道发送给发起方。

3. 双方交换 ICE 候选：
- 在 offer 和 answer 交换后，双方会通过 ICE 候选交换（通过 onicecandidate 事件），确保点对点连接的稳定性。


# 使用WebRTC实现文件传输
下面是一个简单的WebRTC文件传输的示例。我们将用.net实现一个简单的信令服务器，然后通过RTCPeerConnection进行连接，最终实现点对点的文件传输。
![流程](./images/webrtc/webrtc-overview.svg)

1. 连接信令服务器
WebRTC 作为 P2P（点对点）通信协议，首先需要通过一个信令通道（通常是通过 WebSocket、HTTP 或其他通信机制）来交换信息，建立两端之间的连接。这个信令过程是 WebRTC 的必备部分，它不属于 WebRTC 标准的一部分，因此需要开发者自行实现。这里我们在前端使用SignalR来实现信令的发送和接收。

```javascript
this.connection = new HubConnectionBuilder()
    .withUrl('http://localhost:5217/signalr')  // .NET SignalR 服务的 URL
    .build();

// 开始连接
try {
await this.connection.start();
this.isConnected = true;
this.connectionId = this.connection.connectionId;
ElMessage.success('SignalR 连接成功！');
// 获取所有连接的 ID
this.connection.invoke('GetAllConnections');
// 初始化 WebRTC
this.setupWebRTC();
} catch (err) {
ElMessage.error('SignalR 连接失败！');
}
```
这里我希望能够选择目标客户端进行连接，所以在后端维护了一个连接的字典，前端获取连接列表，通过选择不同的连接来建立连接。
![连接](./images/webrtc/connections.png)

2. 初始化 WebRTC
创建一个RTCPeerConnection实例

```javascript
async setupWebRTC() {
    this.rtcPeerConnection = new RTCPeerConnection();

    // 收集 ICE 候选并发送给目标连接
    this.rtcPeerConnection.onicecandidate = event => {
    if (event.candidate) {
        console.log('收集到 ICE 候选:', event.candidate);
        this.sendIceCandidate(event.candidate);
    }
    };

    // 监听连接状态变化
    this.rtcPeerConnection.oniceconnectionstatechange = () => {
    console.log('ICE 连接状态:', this.rtcPeerConnection.iceConnectionState);
    if (this.rtcPeerConnection.iceConnectionState === 'failed') {
        console.error('ICE 连接失败！');
    }
    };

    this.rtcPeerConnection.onconnectionstatechange = () => {
    console.log('WebRTC 连接状态:', this.rtcPeerConnection.connectionState);
    if (this.rtcPeerConnection.connectionState === 'failed') {
        console.error('WebRTC 连接失败！');
    }
    };

    this.setupDataChannel()
}
```

3. 发送信令并建立连接
在信令通道上交换信息以完成连接设置。信令本身不是WebRTC的一部分，因此我们可以使用WebSocket、WebRTC DataChannel等方式来交换这些信令。在界面上手动选择要连接的客户端。然后发送信令给目标客户端，建立连接。

```javascript
// 发送 Offer 给目标客户端
async sendOffer() {
    if (this.targetConnectionId) {
    const offer = await this.rtcPeerConnection.createOffer();
    await this.rtcPeerConnection.setLocalDescription(offer);
    try {
        console.log('发送 Offer:', offer);
        await this.connection.invoke('SendOffer', offer, this.targetConnectionId);
    } catch (err) {
        console.error('发送 Offer 失败：', err);
    }
    }
},

// 目标客户端接收到的 Offer，创建 Answer
async receiveOffer(offer) {
    console.log('收到 Offer:', offer);
    await this.rtcPeerConnection.setRemoteDescription(new RTCSessionDescription(offer));
    const answer = await this.rtcPeerConnection.createAnswer();
    console.log("创建 Answer 成功");
    await this.rtcPeerConnection.setLocalDescription(answer);
    console.log("Local Description 设置成功");
    this.connection.invoke('SendAnswer', answer, this.targetConnectionId);
},
```
4. 传输文件
在WebRTC连接建立后，我们可以使用RTCDataChannel来传输任意类型的数据，包括文件。这里我们使用RTCDataChannel来传输文件，并且在接收方直接把图片展示出来。

```javascript
// 选择文件
handleFileSelection(event) {
    const file = event.target.files[0];
    if (file) {
    this.file = file;
    console.log('已选择文件:', file.name);
    }
},

// 发送文件
sendFile() {
    if (this.dataChannel && this.file) {
    const chunkSize = 16384;  // 设置块大小为 16KB
    const fileReader = new FileReader();

    let offset = 0;

    // 发送文件基本信息（如文件名和文件大小）
    const fileInfo = {
        name: this.file.name,
        size: this.file.size,
    };

    this.dataChannel.send(JSON.stringify(fileInfo));  // 发送文件基本信息

    const sendNextChunk = () => {
        const fileSlice = this.file.slice(offset, offset + chunkSize);
        fileReader.onload = () => {
        this.dataChannel.send(fileReader.result);  // 发送文件块
        offset += chunkSize;
        if (offset < this.file.size) {
            sendNextChunk();  // 继续发送下一个块
        } else {
            console.log('文件发送完毕');
        }
        };
        fileReader.readAsArrayBuffer(fileSlice);  // 读取文件块为 ArrayBuffer
    };

    sendNextChunk();  // 开始发送文件块
    } else {
    console.error('数据通道不可用或未选择文件');
    }
},
```

打完收工，最后我们来看看实现的效果：
![效果](./images/webrtc/result.gif)

# WebRTC的实际应用
WebRTC已被广泛应用于各种实时通信场景，包括：

1. 视频会议：如Zoom、Google Meet等平台都使用了WebRTC。
2. 在线教育：利用WebRTC实现师生之间的实时互动和交流。
3. 文件传输：通过RTCDataChannel实现浏览器间的文件传输。
4. 在线客服：实现企业与客户之间的实时视频或语音通信。

# WebRTC的优势与挑战
## 优势
- 无需插件：WebRTC支持浏览器原生实现，不需要安装额外插件。
- 低延迟：WebRTC专为实时通信设计，支持高效的数据传输。
- 跨平台：支持各种操作系统和设备，具有良好的兼容性。
## 挑战
- NAT穿透：由于大多数用户在NAT（网络地址转换）后面，WebRTC需要使用STUN/TURN服务器来处理NAT穿透，这增加了开发和部署的复杂性。
- 信令：WebRTC本身不定义信令协议，因此开发者需要自己选择一种信令方式。
- 浏览器兼容性：尽管大部分现代浏览器支持WebRTC，但仍存在一些兼容性问题，尤其是在移动设备上。

# 小结
WebRTC为浏览器之间提供了高效、低延迟的实时通信解决方案，应用场景广泛，能够帮助开发者构建出更丰富的实时交互体验。虽然在开发过程中可能会遇到一些挑战，如信令协议、NAT穿透等问题，但随着技术的不断发展，WebRTC的应用前景仍然非常广阔。

----

本文只是对WebRTC的简单介绍和概念引入，更多细节和实际应用可以参考官方文档和相关资源。
