---
title: DeepSeek + RAG： 让大模型更智能、更精准
date: 2025-03-14 16:10:51
tags:
---


在大模型应用中，**如何保证答案的准确性和实时性** 一直是一个难题。尽管 LLM（Large Language Models）具有强大的生成能力，但它们的知识存在 **时间局限性**，并且容易产生“幻觉”（hallucination）。为了解决这些问题，**RAG（检索增强生成）** 方案应运而生，在 RAG（检索增强生成）中，检索机制负责获取相关信息，而 LLM 负责生成最终答案。**DeepSeek** 作为国内领先的大模型之一，可以在 RAG 体系中作为生成部分，为检索增强的上下文提供自然、准确的回答。本文将带你了解 DeepSeek 与 RAG 的结合，并提供代码示例。

---

## ** 什么是 RAG（检索增强生成）？**

**RAG（Retrieval-Augmented Generation）** 是一种将 **信息检索（Retrieval）** 与 **大模型生成（Generation）** 结合的技术，主要分为 **两步：**

1. **检索（Retrieve）**: 在外部知识库（如文档数据库、向量数据库）中找到与用户问题相关的信息。
2. **生成（Generate）**: 将检索到的内容作为上下文输入给大模型，提高回答的准确性。

**优点：**
- 让 LLM 能够利用**最新的**外部知识，不再局限于训练数据。
- 降低 LLM **胡编乱造（幻觉）** 的概率。
- 提供**可验证的答案来源**，提高可靠性。

![hallucination](./images/deepseek-rag/hallucination.png)

---

## ** 为什么选择 DeepSeek 作为 RAG 模型？**

[DeepSeek](https://deepseek.com/) 是一个强大的国产 LLM，具备以下特点：
- **支持中文优化**，相比 GPT-4/Claude，在中文场景下表现更佳。
- **更开放的 API**，可以免费试用，并且提供了本地部署版本。
- **模型能力强**，支持 **代码、数学推理、知识问答等任务**，适合 RAG 场景。

此外，DeepSeek 提供 **DeepSeek-VL（视觉+文本）** 以及 **DeepSeek-Coder（代码生成）** 版本，使其在 **技术文档问答、代码辅助、金融分析等领域** 表现优异。当然最重要的一点是，DeepSeek 是 **开源** 的，这意味着你可以在本地部署它，并且可以根据自己的需求进行定制。谁能拒绝白嫖呢？![DeepSeek](./images/deepseek-rag/baipiao.jpg)

---

## ** 如何实现 DeepSeek + RAG？**

我们可以结合 **DeepSeek + Qdrant 向量数据库** 来实现一个简单的 RAG 系统：

前置条件：
- 本地部署ollama。
- ollama运行DeepSeek。
- 一个 Qdrant 实例。

> 对于部署以上环境部署有疑问的老铁可以参考老夫之前的介绍
>
> [《DeepSeek 本地部署+web端访问 指南》](https://mp.weixin.qq.com/s/EmNzMrH1L52IWcEdROWehQ)
> 
> [《Qdrant：开启高效相似性搜索的先锋》](https://mp.weixin.qq.com/s/vrwbpo3cUrSKN1OX9LjgOw)

### **架构**

1. **数据预处理**：
   - 将文档（如 PDF、网页）分割成小段，并向量化存储。
2. **用户输入查询**：
   - 计算输入问题的向量，并检索相似的文档片段。
3. **DeepSeek 生成回答**：
   - 将检索到的文档片段和用户问题一起输入 DeepSeek，生成最终答案。

![架构](./images/deepseek-rag/RAG-system-architecture.png)

### **代码实现**

这里我们使用 `Qdrant` 作为向量数据库，并结合 `DeepSeek` 进行 RAG 任务。

#### **安装依赖**

```bash
pip install qdrant-client openai tiktoken
```

#### **1️⃣ 数据预处理（文本向量化 + 存入 Qdrant）**

```python
import Qdrant
import numpy as np
from openai import OpenAI

# 配置参数
COLLECTION_NAME = "deepseek_rag"
QDRANT_URL = "http://localhost:6333"

# 连接 Qdrant
client = QdrantClient(QDRANT_URL)
ollamaClient = ollama.Client(host="http://127.0.0.1:11434")

# 假设我们有一些文本需要存入 Qdrant
docs = [
        "DeepSeek 是一个强大的大模型，支持代码生成和中文优化。",
        "RAG 是结合检索与生成的技术，能够提升大模型回答的准确性。",
        "Qdrant 是一个高效的向量数据库，适用于大规模检索。",
        "ITProHub是一个致力于信息技术领域，为专业人士、学习者和技术爱好者提供丰富的资源、技能培训的社区交流平台。",
]

# 向量化
doc_vectors = []
for doc in docs:
     """ 使用本地 Ollama 计算文本嵌入向量 """
    response = ollamaClient.embeddings(model="mxbai-embed-large", prompt=text)
    vector = response.embeddingresponse.data[0].embedding
    doc_vectors.append(vector)

# 存入 Qdrant
points = [
    PointStruct(id=i, vector=vectors[i], payload={"text": docs[i]})
    for i in range(len(docs))
]
client.upsert(collection_name=COLLECTION_NAME, points=points)
print(f"📥 已存入 {len(docs)} 篇文档")
```

#### **2️⃣ 用户查询 + 向量检索**

```python
def retrieve_similar_docs(query, top_k=2):
    """ 从 Qdrant 中检索与查询最相似的文档 """
    query_vector = get_embedding(query)
    search_result = client.search(
        collection_name=COLLECTION_NAME, query_vector=query_vector, limit=top_k
    )
    return [hit.payload["text"] for hit in search_result]

# 示例查询
query = "你知道ITProHub么？"
retrieved_docs = retrieve_similar_docs(query)
print("检索到的相关文档：", retrieved_docs)
```

#### **3️⃣ DeepSeek 生成答案**

```python
def generate_answer(query, retrieved_docs):
    """ 使用 DeepSeek 结合检索内容生成答案 """
    context = "\n".join(retrieved_docs)
    prompt = f"根据以下信息回答用户问题：\n{context}\n\n用户问题：{query}"

    response = ollamaClient.chat(
        model="deepseek-r1:1.5b",
        messages=[{"role": "user", "content": prompt}],
    )
    return response["message"]["content"]

# 生成答案
final_answer = generate_answer(query, retrieved_docs)
print("DeepSeek 生成的答案：", final_answer)
```

#### ** 4️⃣ 看看效果**

1. 原始搜索结果
提出问题："你知道ITProHub?" 显然在原始模型的数据里面是没有关于本公众号的任何信息的，所以你可以看到deepseek针对这个问题开始胡言乱语了
![效果](./images/deepseek-rag/raw-result.png)
可以看到针对 `ITProHub` 这个问题，原始的模型并不知道是啥。
2. 接入RAG之后的效果
接入RAG之后，模型可以根据检索到的内容，生成更准确的答案。
![效果](./images/deepseek-rag/rag-result.png)
---

## **4. 典型应用场景**

1. **企业知识库问答**（客户支持、内部文档搜索）
2. **AIOps**（通过 RAG，结合实时运维数据，快速定位和分析故障原因）
3. **代码辅助**（自动补全、代码文档解析）
4. **学术研究**（查询特定文献，生成摘要）

---

## **5. 总结**

RAG 作为一种 **结合外部知识和大模型的增强技术**，极大提高了回答的**准确性和可解释性**。DeepSeek 作为国产 LLM，在 **中文优化、API 兼容性、代码生成能力** 方面有独特优势，适合作为 RAG 系统的核心组件。

**未来，我们可以探索更多优化方案，比如：**
- **结合 LlamaIndex / LangChain** 进行更复杂的检索。
- **使用 Milvus / Weaviate** 等更强大的向量数据库。
- **本地化部署 DeepSeek**，提升数据安全性。

如果你对 RAG 和 DeepSeek 感兴趣，可以尝试在自己的项目中落地应用，让 AI 变得更智能、更可靠！🚀
完整示例代码可访问老夫的[GitHub](https://github.com/ItProHub/rag)

