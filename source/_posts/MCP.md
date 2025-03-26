---
title: MCP：AI 时代的“USB-C”，解锁模型上下文新范式
date: 2025-03-18 17:03:04
tags:
---

## MCP 出现的背景

MCP（Model Context Protocol，模型上下文协议）是一个开放协议，它标准化了应用程序向大语言模型（LLM）提供上下文的方式。可以将 MCP 类比为 AI 应用的 USB-C 端口。就像 USB-C 提供了一种标准化的方式来连接不同设备和配件一样，MCP 也为 AI 模型提供了一种标准化的方式，使其能够与不同的数据源和工具进行交互。这样，开发者可以更轻松地将 MCP 集成到各类 AI 解决方案中，提高模型的上下文获取能力，并增强其对外部数据的适配性。

本文将深入探讨 MCP 的核心概念、适用场景、架构设计以及如何在实际应用中使用 MCP，并提供具体的代码示例，帮助开发者更好地理解和应用 MCP。



## 什么是 MCP？

MCP（Model Context Protocol，模型上下文协议）是一种协议，旨在促进分布式或模块化系统中模型之间的高效和结构化交互。它定义了一种标准化的方式来交换模型上下文信息，确保一致的数据流和跨不同模型组件的互操作性。

MCP 在人工智能、微服务和去中心化计算环境中特别有用，这些环境中需要多个模型进行通信并保持上下文一致性。

---

## 为什么选择 MCP？

MCP 的出现是 Prompt Engineering 发展的产物。更结构化的上下文信息能够显著提升模型的性能。在构造 Prompt 时，我们希望提供更具体的信息（如本地文件、数据库、实时网络数据等）给模型，以便它能够更准确地理解真实场景中的问题。

### 传统方法的局限性

在 MCP 之前，我们通常会手动从数据库中筛选或使用工具检索相关信息，并将其粘贴到 Prompt 中。然而，随着问题的复杂性增加，手动管理这些信息变得越来越困难。

为了解决这一问题，许多 LLM 平台（如 OpenAI、Google）引入了 **Function Call** 机制，使得模型可以在需要时调用预定义的函数来获取数据或执行操作，从而提升自动化水平。

### Function Call 的局限性

尽管 Function Call 机制带来了便利，但它存在一些关键问题：

- **平台依赖性**：不同 LLM 平台的 Function Call API 实现方式各不相同，例如 OpenAI 和 Google 的调用方式不兼容，开发者在切换模型时需要重写代码，增加了适配成本。
- **安全性**：Function Call 需要开放额外的接口，可能带来安全隐患。
- **交互性**：在部分场景下，Function Call 的交互流程可能较为复杂，影响整体使用体验。
![没有MCP](./images/mcp/without-mcp.png)

#### MCP 如何改进？

- **标准化上下文管理**：MCP 通过提供统一的协议，使应用能够高效地存取和管理上下文，而无需手动管理 Prompt 结构。
- **跨平台兼容性**：MCP 作为开放协议，减少了不同 LLM 平台之间的适配成本，开发者可以更轻松地切换底层模型。
- **提升自动化水平**：MCP 允许应用程序自动从不同数据源（数据库、API、文件等）动态填充上下文，提高模型的理解能力。

![有MCP](./images/mcp/with-mcp.png)
因此，MCP 的引入为 AI 应用带来了更高效、灵活的上下文管理方式，突破了 Function Call 的局限，使得开发者能够更专注于模型能力的发挥，而非手动适配数据。

---

## MCP 架构解析

这里我就直接引入官方给出的架构图吧

![架构图](./images/mcp/architecture.png)

MCP 的架构设计清晰地划分为几个核心组件，每个组件都有明确的职责，共同实现上下文信息的标准化交互：

- MCP Hosts（宿主程序）：
如 Claude Desktop、各类 IDE 或 AI 工具，这些应用程序希望通过 MCP 获取上下文信息或数据，以增强模型的能力。

- MCP Clients（客户端）：
协议中的客户端，负责与 MCP Servers 建立并维护一对一的连接，实现标准化的数据请求与交互。

- MCP Servers（服务端）：
轻量级的服务程序，每个服务端都通过 MCP 协议暴露出特定的能力或数据访问接口，从而满足客户端的不同需求。

- Local Data Sources（本地数据源）：
包括用户计算机上的本地文件、数据库、服务等。这些数据源可通过 MCP Servers 被安全地访问，以提供丰富的上下文信息。

- Remote Services（远程服务）：
指可通过网络访问的外部系统或第三方服务（如 API），MCP Servers 可安全连接到这些服务，以进一步扩展模型所能获取的上下文范围。

通过以上的分层结构，MCP 架构确保了数据访问的安全性、扩展性与灵活性，使得应用程序能轻松、安全地利用多种数据来源提升模型表现。

---

## 4. 如何使用 MCP（结合代码示例）

### 示例：在 Python 中使用 MCP 进行 AI 模型交互

![架构图](./images/mcp/architecture2.png)

#### 前置工作
1. ollama
2. 环境配置[（参考官网的推荐配置）](https://modelcontextprotocol.io/quickstart/server)
3. 安装 MCP SDK


#### ** 实现MCP Server **
这里我只实现了两个简单的工具

```python
# 创建 MCP 服务器实例
mcp = FastMCP("DataService")

# 定义工具：从本地 MySQL 数据库获取数据
@mcp.tool()
def get_local_data(name: str) -> str:
    """执行查询并返回本地 MySQL 数据库中的数据"""
    load_dotenv()
    # 连接到本地数据库
    connection = mysql.connector.connect(
        host=os.getenv('db_host'),
        user=os.getenv('db_user'),
        password=os.getenv('db_password'),
        database=os.getenv('db_name')
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("select salary from employees where name like %s limit 1", (f"%{name}%",))
            row = cursor.fetchone()
            while row is not None:
                return row[0]
        return ''
    finally:
        connection.close()

# 定义工具：从网络上搜索数据
@mcp.tool()
def get_web_data(query: str) -> str:
    """Search the web for current information on a topic"""
    
    # 使用 Google 搜索 API

# 运行 MCP 服务器
if __name__ == "__main__":
    mcp.run()

```
定义完工具之后，我们可以运行 MCP 服务器，让它监听来自客户端的请求。

#### ** 测试MCP Server **
使用 MCP Inspector 我们可以查看服务器的状态和工具列表，同时对工具进行调试。
```bash
mcp dev server.py
```
看到如下输出，说明服务器已经启动成功
![运行中](./images/mcp/running.png)
然后我们就可以通过访问Inspector的地址来查看服务器的状态和工具列表。
![Inspector](./images/mcp/inspector.png)


#### **实现客户端**

```python
class MCPClient:
    def __init__(self):
        self.servers = []
        self.tools = []
        self.exit_stack = AsyncExitStack()
        self.ollama = AsyncClient('127.0.0.1')

    async def initialize(self):
        server_config = None
        with open("servers_config.json", "r") as f:
            server_config = json.load(f)
        # 列出服务器提供的工具
        print("可用的工具:", self.tools)

    async def chat_loop(self):
        """Run an interactive chat loop"""
        print("\nMCP Client Started!")
        print("Type your queries or 'quit' to exit.")
        
        while True:
            try:
                response = await self.process_query(query)
                print("\n" + response)
                    
            except Exception as e:
                print(f"\nError: {str(e)}")


    async def process_query(self, query: str) -> str:
        """Process a query using Claude and available tools"""

        tools_description = "\n".join([tool.format_for_llm() for tool in self.tools])

        system_message = (
                "You are a helpful assistant with access to these tools:\n\n"
                f"{tools_description}\n"
                ...
            )

        messages = [{"role": "system", "content": system_message}]
        messages.append({"role": "user", "content": query})

        llm_response = await self.ollama.chat(
            'qwen2.5:0.5b',        
            messages=messages
        )
        
        result = await self.process_llm_response(llm_response)

        if result != llm_response:
            messages.append({"role": "assistant", "content": llm_response})
            messages.append({"role": "system", "content": result})

            final_response = await self.ollama.chat(
                'qwen2.5:0.5b',        
                messages=messages
            )
            final_response = final_response.message['content']
            logging.info("\nFinal response: %s", final_response)
            messages.append(
                {"role": "assistant", "content": final_response}
            )
        else:
            messages.append({"role": "assistant", "content": llm_response})


        return final_response


async def main():
    client = MCPClient()
    try:
        await client.initialize()
        await client.chat_loop()
    finally:
        await client.cleanup()

if __name__ == "__main__":
    asyncio.run(main())

```

#### **运行效果**
通过上述代码，我们可以实现一个简单的 AI 对话系统，它可以使用 MCP 服务器提供的工具来获取上下文信息，并与用户进行交互。
![运行效果](./images/mcp/result1.png)

![运行效果](./images/mcp/result3.png)

---

##  关于 MCP 与 Function Call 机制的关系（补充说明）
### MCP Client 如何决定调用哪个工具？
在实际应用中，MCP 客户端判断调用哪个工具主要有两种实现方式：

1. 利用 LLM 平台原生的 Function Call 功能

这种方式依赖 LLM 平台自带的函数调用能力，例如 OpenAI 的 Function Call API。具体流程为：

- 模型识别用户意图，返回指定的函数调用请求。

- 客户端接收到函数调用指令后，通过 MCP 协议访问具体数据或服务。

优点是模型能够直接识别调用意图，调用精准度较高。
缺点是不同模型平台之间存在 API 差异，切换模型可能需要额外适配。

2. 通过特定的 Prompt 结构（Prompt Engineering）来实现调用判断

通过向模型提供明确、结构化的 system prompt（如下面示例），指导模型在需要调用外部工具时输出指定格式的 JSON 指令：

```
"You are a helpful assistant with access to these tools:\n\n"
f"{tools_description}\n"
"Choose the appropriate tool based on the user's question. "
"If no tool is needed, reply directly.\n\n"
"IMPORTANT: When you need to use a tool, you must ONLY respond with "
"the exact JSON object format below, nothing else:\n"
"{\n"
'    "tool": "tool-name",\n'
'    "arguments": {\n'
'        "argument-name": "value"\n'
"    }\n"
"}\n\n"
"After receiving a tool's response:\n"
"1. Transform the raw data into a natural, conversational response\n"
"2. Keep responses concise but informative\n"
"3. Focus on the most relevant information\n"
"4. Use appropriate context from the user's question\n"
"5. Avoid simply repeating the raw data\n\n"
"Please use only the tools that are explicitly defined above."
```
在这种方法中：

- 模型无需特定的函数调用能力，而是通过 prompt engineering 来判断何时调用工具。

- 客户端解析 JSON 格式指令后调用 MCP 接口访问工具。

优点是对模型平台的 function call API 无依赖，适配性强。
缺点是依赖 Prompt 结构，模型输出的稳定性可能较差，偶尔需要额外的校验和容错处理。


## 总结

MCP（模型上下文协议）提供了一种结构化、高效的方式，使得模型在分布式环境中能够交换上下文信息。它的主要优势包括：

- **标准化的上下文共享**，确保多模型系统的稳定性。
- **高效可扩展**，适用于不同规模的模型交互需求。
- **无缝集成**，可通过简单的 API 调用轻松适配现有框架。

通过实现 MCP，开发者可以增强模型之间的协作，减少冗余，并确保模型驱动应用程序中的一致性。如果你正在从事 AI、微服务或分布式计算，MCP 是一个值得考虑的协议！

