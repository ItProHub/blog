---
title: 深入了解 HTTP 状态码和消息头
date: 2024-03-19 16:11:52
tags: http 协议 http协议
---
HTTP（Hypertext Transfer Protocol）是现代网络通信的基础，它通过消息头来传递关键信息，从而实现客户端和服务器之间的通信。在本文中，我们将探讨 HTTP 消息头的作用、结构以及常见的使用方式，并通过详细的代码例子来说明。

在开始本文的阅读之前，默认屏幕前的老铁已经对HTTP有了基础的认识。如果不是，请移步学习[超文本传输协议](https://zh.wikipedia.org/wiki/%E8%B6%85%E6%96%87%E6%9C%AC%E4%BC%A0%E8%BE%93%E5%8D%8F%E8%AE%AE#)


## 什么是HTTP消息头：协议中的精华
HTTP 消息头是 HTTP 报文中的一部分，它包含了一系列键值对，用于描述报文的属性和特征。每个键值对被称为一个消息头字段，其中键是字段名，值是字段值，它们由一个冒号（:）分隔。消息头字段通常用于控制缓存、身份验证、内容协商、内容类型、内容编码等方面的行为。

## HTTP 消息头的类型
HTTP 消息头由若干个字段组成，每个字段占据一行，以 CRLF（Carriage Return Line Feed）作为分隔符。通常，消息头分为请求头和响应头两种类型。请求头出现在客户端发送的 HTTP 请求中，而响应头出现在服务器返回的 HTTP 响应中。

```http request
Host: www.itprohub.site
Connection: keep-alive
Content-Length: 1823
sec-ch-ua: "Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"
sec-ch-ua-platform: "Windows"
sec-ch-ua-mobile: ?0
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36
Content-Type: application/json
Accept: */*
Origin: https://www.itprohub.site
Sec-Fetch-Site: cross-site
Sec-Fetch-Mode: cors
Sec-Fetch-Dest: empty
Referer: https://www.itprohub.site
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: zh-CN,zh;q=0.9
```

1. 通用头部（General Headers）：适用于请求和响应的通用头部，如：Cache-Control、Connection、Date、Pragma、Trailer。
2. 请求头部（Request Headers）：出现在 HTTP 请求中，描述客户端的信息和请求的属性，如：Host，User-Agent，Accept，Authorization。
3. 响应头部（Response Headers）：出现在 HTTP 响应中，描述服务器的信息和响应的属性，如：Content-Type,Content-Length，Location,Server。
   > 关于响应头里面的类型也可以参考老夫另外一篇分享[了解 MIME 类型：Web 开发中的重要概念](https://juejin.cn/post/7340286503505592330)
4. 实体头部（Entity Headers）：描述请求或响应的主体内容，如：Content-Encoding,Content-Language，Content-Disposition。

## HTTP消息头的常见字段
+ Cache-Control：控制缓存行为。
+ Content-Type：指定消息主体的媒体类型。
+ Content-Length：指定消息主体的长度。
+ Host：指定服务器的主机名和端口号。
+ User-Agent：客户端标识，描述客户端的软件和操作系统信息。
+ Server：服务器标识，描述服务器的软件和操作系统信息。

其他字段的含义就不在这里赘述了，感兴趣的老铁可以移步[HTTP头字段](https://zh.wikipedia.org/wiki/HTTP%E5%A4%B4%E5%AD%97%E6%AE%B5#cite_note-29)

## HTTP消息头的使用场景
### 控制缓存行为：Cache-Control
假设你正在开发一个新闻网站，用户可以浏览最新的新闻文章。为了提高网站的性能和用户体验，你想要利用缓存来减少服务器的负载并加快页面加载速度。

在这种情况下，你可以使用 Cache-Control 和 Last-Modified（或 ETag）头部来控制新闻文章页面的缓存行为。当用户首次访问新闻文章时，服务器会发送文章内容以及相关的缓存控制头部。如果用户再次访问相同的文章，客户端可以根据这些头部来决定是否使用缓存。
具体地，你可以采取以下步骤：
1. 当用户首次访问新闻文章时，服务器会发送文章内容以及相关的缓存控制头部：
```http request
HTTP/1.1 200 OK
Content-Type: text/html
Cache-Control: max-age=3600
Last-Modified: Mon, 25 Jan 2024 12:00:00 GMT

<!DOCTYPE html>
<html>
<head>
    <title>News Article</title>
</head>
<body>
    <h1>Breaking News!</h1>
    <p>This is the latest news article.</p>
</body>
</html>
```
2. 当用户再次访问相同的文章时，客户端可以向服务器发送条件请求，检查文章是否发生了变化：
```http request
GET /news/article?id=123 HTTP/1.1
Host: example.com
If-Modified-Since: Mon, 25 Jan 2024 12:00:00 GMT
```
3. 如果文章未发生变化，服务器可以返回一个 304 Not Modified 响应，表示文章仍然有效，客户端可以使用缓存：
```http request
HTTP/1.1 304 Not Modified
```

### 控制消息的传输和连接行为
考虑一个在线文件传输服务的实际场景。在这个服务中，用户可以上传文件到服务器，并且可以从服务器下载已经上传的文件。为了实现更好的用户体验和系统性能，我们需要控制消息的传输和连接行为。
1. 上传文件请求
   当用户上传文件时，客户端会向服务器发送上传请求，并将文件数据通过 POST 请求发送给服务器。为了控制消息的传输，我们可以使用流式传输（Streaming）来逐块地上传文件，而不是一次性发送整个文件。
```http request
POST /upload HTTP/1.1
Host: example.com
Content-Type: application/octet-stream
Content-Length: <length_of_file_data>

<file_data_chunk>
```

2. 处理上传请求
   服务器收到上传文件的请求后，会逐块地接收文件数据，并将其写入到文件系统中的临时文件中。在处理上传请求时，我们需要控制连接的持续性，以便及时释放服务器资源并提高系统的并发性能。
3. 上传完成响应
   当文件上传完成时，服务器会向客户端发送上传成功的响应，并包含上传文件的元数据信息，如文件名、大小等。在响应中，我们可以设置连接头部为 Connection: close，表示该请求处理完毕后，关闭连接。
```http request
HTTP/1.1 200 OK
Content-Type: application/json
Connection: close

{"status": "success", "filename": "example.txt", "size": 1024}
```

## 可扩展性
HTTP 消息头很好的体现了HTTP协议的可扩展性，这使得它可以适应各种不同的应用场景和需求。以下是 HTTP 消息头可扩展性的几个方面：

### 自定义消息头
HTTP 协议允许开发者自定义消息头，以满足特定应用程序的需求。这意味着开发者可以定义自己的消息头字段，并在请求和响应中使用它们来传递特定的元数据信息。

```http request
POST /vab-mock-server/api/summary/site-summary/8/tenant-grid HTTP/1.1
...
accessToken: admin-accessToken
x-bpm-saasops-token: grwekVGIWIjAIFqRHILI1A==
```
上面的例子我们看到，请求头的最后两个属性[accessToken]和[x-bpm-saasops-token]就都是根据业务自定义的两个属性
### 标准扩展头
HTTP 协议规范定期更新，并不断添加新的标准消息头字段，以满足日益增长的网络通信需求。例如，HTTP/2 引入了一些新的标准头部，如 :authority 和 :method 等，用于支持新的协议功能。

当谈到扩展标准消息头时，一个很好的例子是 Accept 消息头。Accept 消息头用于指示客户端所能接受的响应内容类型。通常情况下，它包含一个或多个媒体类型（MIME 类型）和相应的优先级。

例如，一个客户端可以发送如下的 Accept 消息头：
```
Accept: text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8
```
在这个例子中，客户端指示它可以接受 text/html、application/xhtml+xml 和 application/xml 类型的响应内容，并为它们设置了不同的优先级。这种设置允许客户端灵活地控制服务器返回的响应类型，根据客户端的需求和偏好进行适当的选择。

### 消息头参数化
部分消息头支持参数化，允许在消息头中传递额外的参数信息。例如：

假设服务器要向客户端传送一个名为 "document.pdf" 的 PDF 文件，并且希望客户端将该文件保存到本地而不是直接在浏览器中打开。服务器可以通过设置 Content-Disposition 消息头来指示客户端的行为。下面是服务器可能返回的响应头部分：
```http request
Content-Disposition: attachment; filename="document.pdf"
```
在这个例子中，Content-Disposition 消息头的值是 "attachment"，表示该响应中包含的是一个附件文件。另外，通过 filename 参数指定了文件名为 "document.pdf"，这样客户端就知道该附件应该以什么名字保存。
当客户端收到这个响应时，会根据 Content-Disposition 消息头的指示，将响应中的内容保存为一个名为 "document.pdf" 的文件，而不是尝试在浏览器中打开它。这样，服务器可以控制客户端对响应的处理方式，实现了更灵活的消息传递和处理。

### 条件请求头
条件请求头允许客户端在发送请求时附加条件，以控制服务器的行为。
这一点可以参考上面[控制缓存行为：Cache-Control](#控制缓存行为：Cache-Control)



## 结语
其实关于HTTP消息头还有很多知识点本文没有讲到。本文的介绍，姑且算是入门指引吧。从基础知识到应用场景，希望能够帮助读者更好地理解和应用 HTTP 协议。在实际开发中，合理利用 HTTP 协议能够提升 Web 应用的性能和安全性。