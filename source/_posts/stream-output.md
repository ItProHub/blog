---
title: 解读大型语言模型（LLM）API：了解流式输出的工作原理
date: 2024-11-08 10:09:20
tags:
---

最近几年GPT在全球大火，相信大家在日常生活、工作中都在使用。细心的老铁们可能已经注意到，市面上的GPT在回复我们的问题的时候基本上都是采用类似对话的方式。数据在生成后立即被发送给用户，而不是等待所有数据都生成完毕后再一次性发送。

![gpt](./images/stream-output/gpt-1.gif)

在本文中，我们将探讨主流的大型语言模型（LLM）提供商如何实现其流式输出的 HTTP API。我们将深入研究流式输出的工作原理，探讨其优势，并提供示例代码以帮助您理解如何在实际应用中使用流式输出。

----

# 什么是流式输出？
流式输出（Streaming Output）是一种使后端将数据分块、逐步发送到前端的技术。通过这种方法，前端应用能够即时接收和渲染数据，不必等到整个响应体生成完毕后再处理。

传统的API 通常会一次性返回所有数据，然后客户端一次性接收。
![normal](./images/stream-output/regular-http-communication.png)

流式输出则允许服务器在生成数据的同时将其发送给客户端，从而实现实时更新。
![stream](./images/stream-output/sse-communication.png)

流式输出通常用于以下几种场景：

- 实时数据更新，例如股票行情、社交媒体的实时消息流。
- 大数据处理，例如长时间查询或计算的结果逐步传输。
- 节省带宽，在网络环境不佳的情况下减少一次性传输大量数据的压力。

## 流式 API 的优势
流式 API 提供了即时响应的体验，允许用户在内容生成过程中即时查看部分结果。相比等待整个响应完成，流式输出极大提高了用户体验。适用于多种场景，例如：

+ 实时内容生成：用户在等待生成大段文本时，可以即时查看部分内容。
+ 渐进式加载：减少等待时间，提升交互性。
+ 流式处理：流式 API 让开发者能够边生成边处理数据，尤其适用于实时应用。

# 流式输出的实现方式
在具体实现流式输出时，常用的技术包括：

+ HTTP 分块传输（Chunked Transfer Encoding）：HTTP 协议支持将数据以分块的方式传输，每个数据块都会携带长度信息。后端可以在响应完成之前，逐步地发送多个数据块给前端。

+ Server-Sent Events (SSE)：SSE 是一种在服务器向客户端推送事件的技术，适合实时性要求高但传输频率不高的场景。

+ WebSocket：WebSocket 是一个全双工协议，允许服务器和客户端相互通信，适合高频率的实时数据传输。

<font color="#dd0000">本文主要讲解SSE的实现。</font>

# SSE数据格式
Server-Sent Events（SSE）返回的数据格式是由一系列文本流组成，每行包含一个键值对，表示一个数据事件。每条事件消息由事件名称、数据内容等字段组成，并且这些字段具有特定的格式和规则。

![sse](./images/stream-output/sse.gif)

1. SSE 格式的基本结构
SSE 使用 Content-Type: text/event-stream，将数据以纯文本的方式分块传输到客户端，每次传输一个事件，数据传输结束时不需要关闭连接。每个事件消息有几个常用字段：

- data：表示事件的主要数据内容，数据可以是单行或多行。
- id：事件的唯一标识符（可选）。客户端会自动记录最近一次接收到的 id，以便在重新连接时从该事件之后恢复。
- event：事件的类型，默认为 message。客户端可以通过 addEventListener 监听不同类型的事件。
- retry：重试时间（以毫秒为单位），用于在连接中断时自动重连。
2. SSE 数据格式示例
在每条事件中，字段通过换行分隔，格式如下：

```plaintext
event: custom-event
id: 1
retry: 5000
data: {"message": "Hello, World!"}
```

- event：自定义事件名为 custom-event。
- id：该事件的唯一标识符为 1。
- retry：指示客户端在连接断开后每隔 5000 毫秒（5 秒）重新尝试连接。
- data：该事件的主要数据部分为 JSON 字符串 {"message": "Hello, World!"}。
每条事件结束后，必须包含两个换行符。若需要传输多条事件，可按此格式依次添加。

3. 多行数据
data 字段支持多行。对于多行内容，在每行前都需要加 data: 前缀, 并且以两个换行符(\n\n)结尾，SSE 会自动将其拼接为单个字符串传递到客户端。例如：

```plaintext
data: {"message": "Part 1 of the message"}

data: {"message": "Part 2 of the message"}

data: {"message": "Part 3 of the message"}
```

在客户端收到时，这两行会被拼接成一条数据。

# 示例：使用SSE实现流式输出

 1. 后端实现
后端需要实现一个 HTTP 接口，该接口返回一个流式响应。在 C# 中，可以使用 ASP.NET Core 来实现。以下是一个简单的示例：
```C#
[HttpPost, HttpGet]
[ActionTitle(Name = "聊天")]
[Route("chat")]
public async Task Completions([FromBody] ChatDto chatDto)
{
    Response.ContentType = "text/event-stream";

    await foreach( var message in GetStreamingResponseAsync(chatDto.Input) ) {
        var data = $"data: {message}\n\n";
        Console.Write(data);
        var bytes = Encoding.UTF8.GetBytes(data);
        await Response.Body.WriteAsync(bytes);
        await Response.Body.FlushAsync();
        await Task.Delay(100);
    }
}

public static async IAsyncEnumerable<string> GetStreamingResponseAsync(string userInput)
{
    // 随机获取一个配置
    GptConfig gptConfig = new GptConfig() { 
        ApiKey = "your-api-key",
        Version = "2023-03-15-preview"
    };

    HttpRequestMessage request = new HttpRequestMessage(HttpMethod.Post, $"URL_ADDRESS");
    request.Headers.Add("api-key", gptConfig.ApiKey);

    var requestBody = new {
        messages = new[]
        {
            new { role = "user", content = userInput }
        },       
        stream = true
    };

    var jsonRequestBody = JsonSerializer.Serialize(requestBody);
    request.Content = new StringContent(jsonRequestBody, Encoding.UTF8, "application/json");

    using HttpClient httpClient = new HttpClient();

    using( var response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead) ) {
        response.EnsureSuccessStatusCode();
        var responseStream = await response.Content.ReadAsStreamAsync();

        using( var reader = new StreamReader(responseStream) ) {
            while( !reader.EndOfStream ) {
                var line = await reader.ReadLineAsync();
                if( !string.IsNullOrWhiteSpace(line) && line.StartsWith("data:") ) {
                    var jsonData = line.Substring(5).Trim();
                    if( jsonData == "[DONE]" )
                        break;

                    var data = JsonSerializer.Deserialize<JsonElement>(jsonData);

                    // 检查是否包含 content 字段，避免报错
                    if( data.TryGetProperty("choices", out var choices) &&
                        choices[0].TryGetProperty("delta", out var delta) &&
                        delta.TryGetProperty("content", out var content) ) {
                        yield return content.GetString();
                    }
                }
            }
        }
    }

}
```

 2. 前端实现
在前端，我们可以使用 vue3来实现。以下是一个简单的示例：
```javascript
chat() {
    fetch(`/v20/openai/chat`, {
      method: 'POST',
      body: JSON.stringify({ input: this.input }),
      headers: {
        'Content-Type': 'application/json'
      }
    }).then((res) => {
      const reader = res.body.getReader();

      this.handleReadStream(reader)
    }).finally(() => {
      this.input = ''
    })

},
// 流式对话
handleReadStream(stream) {
  stream.read().then(({ done, value }) => {
    if (done) {
      return
    }
    const data = new TextDecoder().decode(value)
    if (!data) {
      return
    }

    this.message += data.replaceAll('data: ', '')
    // 强制 Vue 渲染更新
    this.$nextTick(() => {
      console.log("Stream updated");
    });
    // 递归处理流
    this.handleReadStream(stream)
  })
},
```
 3. 实现效果
![chat](./images/stream-output/result.gif)

需要注意的是，vue3项目在本地开发代理api接口的时候似乎默认启用了gzip压缩，导致前端无法正常解析SSE的数据格式。可以在vue.config.js中配置关闭gzip压缩。
![gzip](./images/stream-output/gzip.png)
```
devServer: {
    port: 9588,
    compress: false,
    allowedHosts: "all",
    proxy: {
      'v20': { target: 'http://localhost:2222', changeOrigin: true },
    }
  }
```

# 结论
流式输出是一种强大的工具，能够显著改善数据传输体验，特别适用于实时和大数据场景。合理选择适合的流式输出技术并处理好前后端的数据解析和错误恢复，可以显著提升应用的交互性和性能。