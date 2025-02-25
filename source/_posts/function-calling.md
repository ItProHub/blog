---
title: 让AI模型不再只是“说话”——探索AI模型的函数调用
date: 2025-02-21 14:02:30
tags:
---
# 引入
在当今数字化时代，人工智能（AI）技术已经成为我们生活中不可或缺的一部分。从语音助手到智能客服，AI模型已经成为我们日常生活中不可或缺的一部分。然而，随着AI技术的不断发展，我们面临了一个新的挑战：如何让AI模型真正“做事”？

![AI](./images/function-calling/labour.jpg)

在过去，AI模型主要被训练为生成文字，回答问题，或者提供信息。然而，随着AI模型的不断发展，我们开始看到它能够执行更复杂的任务，如自动化任务、数据处理、决策支持等。这一趋势的一个关键驱动力是**函数调用**的引入。

如果现在的你还只会使用AI模型来生成文字，那么作为一个开发人员，你已经OUT了！
![AI](./images/function-calling/out.jpg)

生成式人工智能的一个显著优点是它能够使用自然语言与用户进行互动。然而，对于那些希望将人工智能的响应与其他应用程序进行集成的开发者来说，这可能成为一项挑战。通常，开发者不得不依赖正则表达式（Regex）或精心设计的提示工程，将输出转换为所需格式，才能顺利地将数据传递给其他系统。

为了解决这一问题，OpenAI 引入了一个创新的概念——函数调用（function calling）。本文，我将结合具体的例子，详细阐释这一概念。

# 什么是函数调用？
随着人工智能技术的快速发展，AI模型已经不再仅仅是生成文字的工具。通过引入**函数调用**，大型语言模型（LLM）不仅能理解用户的输入，还能够执行实际操作，调用外部工具和API，获取实时数据，从而解决实际问题。在这篇博客中，我们将深入探讨函数调用的概念及其实际应用，展示如何通过AI模型的函数调用，让AI真正成为一个动态的助手，协助用户完成复杂任务。


例如，传统的AI模型可能仅仅会生成“今天的天气如何”这类问题的文本回答，但有了函数调用，AI可以直接从天气API获取实时数据，并返回具体的天气情况。这样，AI不仅仅是回答问题，而是通过执行外部操作提供精确、实时的服务。

# 函数调用的工作流程
函数调用通常包括以下几个步骤：

1. 用户请求：用户发出查询或要求一个操作，如“明天的天气如何？”或者“检查库存是否充足？”
2. AI处理：AI模型分析用户的请求，并判断是否需要外部数据或执行外部任务。如果是，它将决定执行函数调用。
3. 函数调用决策：
    - API调用：通过外部API获取数据。例如，调用天气API获取实时天气数据。
    - 自定义函数：访问内部工具或数据库。例如，查询库存数据库检查产品的库存。
4. 数据获取与集成：AI模型从外部工具或API获取数据后，整合结果并生成适合的响应。

![AI](./images/function-calling/process.png)

通过这种方式，AI模型不仅限于生成答案，还能自动执行操作，极大增强了其功能和实用性。

# 函数调用的示例：创建一个实时查询工具
为了更直观地展示函数调用如何发挥作用，我们将创建一个简单的AI工具，它可以根据用户的输入实时查询网络信息或者查询本地数据库。我们将使用一个Python库，以及AI模型来实现这一功能。

1. 查询API和LLM模型
   首先，我们需要一个网络查询API，并将其与AI模型连接。在本示例中，我们使用Google Search API来获取网络数据。

   本地用Ollama启动模型qwen2.5:0.5b，当然也可以使用其他模型。不过在选择模型的时候记得选择支持函数调用的模型。
   ![函数调用模型](./images/function-calling/search.png)

2. 定义函数调用
AI模型通过判断用户请求是否涉及网络搜索或者查询本地数据库 来决定是否使用tool 或者说 使用哪个tool。下面是我们定义的函数调用逻辑：

```python
search_web_tool = {
        'type': 'function',
        'function': {
            'name': 'search_web',
            'description': 'Search the web for current information on a topic',
            'parameters': {
                'type': 'object',
                'required': ['query'],
                'properties': {
                    'query': {
                        'type': 'string',
                        'description': 'The search query to look up'
                    }
                }
            }
        }
    }

# MySQL查询工具
search_db_tool = {
    'type': 'function',
    'function': {
        'name': 'search_db',
        'description': 'Query inventory quantity of a product from a local MySQL database.',
        'parameters': {
            'type': 'object',
            'required': ['product_name'],
            'properties': {
                'query': {
                    'type': 'string',
                    'description': 'The product name to query .'
                }
            }
        }
    }
}

```

3. 函数的具体实现
我们定义了两个函数，分别用于网络搜索和查询本地数据库。这些函数会被AI模型调用，获取所需的数据。
```python
def search_web(query):
    # 调用网络查询API获取数据
    ...
def search_db(query):
    # 调用本地数据库查询API获取数据
    ...
```

4. 连接AI模型和函数调用
当用户输入查询语句时，AI模型分析请求，决定是否调用函数获取数据，并将返回的信息结合自然语言生成响应：

```python
client = AsyncClient('127.0.0.1')

# First, let Ollama decide if it needs to search
response = await client.chat(
    'qwen2.5:0.5b',        
    messages=[{
        'role': 'user',
        'content': f'Answer this question: {query}'
    }],
    tools=[search_web_tool, search_db_tool]
)

if response.message.tool_calls:
    print("Searching by tools...")

    for tool in response.message.tool_calls:
        if function_to_call := available_functions.get(tool.function.name):
            # Call the search function
            search_results = function_to_call(**tool.function.arguments)

            ...

            # Get final response from Ollama with the search results
            final_response = await client.chat(
                'qwen2.5:0.5b',
                messages=messages
            )
            return final_response.message.content  
   
```

4. 获取实时数据并返回给用户
通过这种方式，AI模型不仅仅是生成“天气好坏”的模糊回答，而是调用API获取实时数据，并返回具体的天气信息，让用户得到更加准确的答案。

5. 运行示例
现在，我们可以运行这个示例，看看AI模型是如何根据用户的输入实时查询网络信息或者查询本地数据库的。
![运行示例](./images/function-calling/result.gif)

上面的代码示例因为篇幅原因，仅给出了大致结构。如果需要完整代码，可以在我的[github](https://github.com/ItProHub/function-calling)上下载。
# 结论
函数调用的引入使得AI模型不仅仅局限于生成文本，而是能够真正“做事”。通过与外部工具和API的交互，AI可以获取实时数据、自动化任务、集成多种服务，从而更好地满足用户需求，提升应用的实用性和效率。无论是在个人助理、智能客服，还是在更复杂的企业系统中，函数调用都能极大增强AI的功能，改变我们与AI的互动方式。

你是否已经开始在你的AI应用中使用函数调用了呢？如果有任何问题，欢迎在评论区与我们讨论！

希望这篇博客能够帮助你更好地理解函数调用的概念及其应用，助力你在开发AI驱动的应用时做出更高效、智能的解决方案！