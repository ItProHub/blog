---
title: Agent Harness：模型只是引擎，“马具”才是那辆车
date: 2026-09-24 09:53:00
tags:
abstract: 同一个模型，两个团队做出来的 Agent 为什么会天差地别？差距几乎全在 Harness 上。它的本义是马具——不提供力气，但没了它马拉不了车。本文拆解这台软件骨架的六大部件，并解释为什么模型没换，成本却差了 3 倍。
description: Harness 本义是马具，在 AI 时代它指的是模型之外那层让它能真正干活的软件骨架。本文拆解 agentic loop 与生产级 harness 的六大部件，并解释为什么同一个模型，成本能差出 3 倍。
photos:
  - /blog/images/agent-harness/cover.png
---

> 前段时间重读 Anthropic 的《How Claude Code works》，注意到一个此前被我忽略的词：**agentic harness**。
> 文档里说，Claude Code 本质上就是一个 harness —— 提供工具、上下文管理和执行环境，把语言模型变成一个能干活的编程 Agent。
>
> 这个词越琢磨越有意思，值得单独写一篇。

---

# 🐎 一、Harness 是什么：从“马具”说起

Harness 的本意是**马具、挽具**。它本身不提供力气，但没了它，马拉不了车。

同样一个 LLM，你发一句 prompt，它回你一段文字 —— 它是个**极聪明的一次性猜词机**。它不能搜网页、不能跑代码、不能读文件，也无法验证自己刚说的话是不是真的。

但当你把它“套”进一层软件骨架里：

* 给它工具去**行动**；
* 给它反馈去**观察**；
* 给它记忆去**追踪进度**；
* 给它规则去**保证安全**。

同一个模型，就能完成一个十几步的真实任务了。这层骨架，就是 **Agent Harness（智能体挽具）**。

LangChain 的 Vivek Trivedy 有一句话我很喜欢：

> **“如果你不是模型，你就是 harness。”**

Beren Millidge 在 2023 年给过一个更工程化的类比：裸的 LLM 就像一颗没有内存、没有硬盘、没有 I/O 的 **CPU**，而 harness 就是让它变得可用的**操作系统**。

这个词其实是从测试领域借来的 —— test harness（测试脚手架）指的是在受控条件下驱动被测代码的那层设施。Agent 时代的 harness 承担的是同一个角色：**模型负责决策，harness 负责其他一切**。

---

# 🔥 二、为什么 2026 年这个词突然火了

因为行业终于达成了一个共识：**模型是 Agent 系统里最小的那个部分。**

几个标志性事件：

* Anthropic 在 Claude Code 的官方文档里直接自称 agent harness；
* OpenAI 的 Codex 团队把 agent 和 harness 当作同义概念；
* 微软 Agent Framework 甚至提供了一个开箱即用的 `HarnessAgent`；
* 2025 ~ 2026 年间，**harness engineering（挽具工程）** 作为一个独立的工程方向出现了。

实践中的证据更直观：**两个团队用同一个模型，做出来的 Agent 体验可能天差地别** —— 差距几乎全在 harness 上：上下文怎么裁剪、工具怎么定义、错误怎么恢复。

我在写 [Microsoft Agent Framework](https://itprohub.github.io/blog/2025/10/11/agent-framework/) 那篇时还没意识到，文章里讲的那些“构建块”（Agent Host / Runtime / Skills / Memory），拼起来其实就是一台 harness。

---

# 🔁 三、核心中的核心：Agentic Loop

Harness 的心脏是一个循环，也就是经典的 **ReAct（Reason + Act）** 模式。剥离到最简，它短得惊人：

```python
messages = [{"role": "user", "content": task}]

while True:
    response = llm.chat(messages, tools=tools)

    if not response.tool_calls:      # 没有工具调用 → 任务完成
        break

    for call in response.tool_calls:
        result = execute(call)       # 真正执行动作的是 harness，不是模型
        messages.append(tool_result(call, result))  # 结果喂回上下文
```

一个 `while` 循环，构成了 Agent 的脊柱。模型每转一圈：

```
┌──────────────────────────────────────────────┐
│                                              │
│   ┌────────┐   ┌────────┐   ┌──────────┐     │
│   │  思考   │ → │  行动   │ → │  观察     │ ──┐ │
│   │ Think  │   │  Act   │   │ Observe  │   │ │
│   └────────┘   └────────┘   └──────────┘   │ │
│        ▲                                   │ │
│        └───────────────────────────────────┘ │
│                                              │
└──────────────────────────────────────────────┘
   直到：没有工具调用 / 达到轮次上限 / 触发护栏
```

Magic 全在“**观察**”这一步。

一次性问答的模型是在**盲飞** —— 它必须在看到第一步是否成功之前，就押注整个计划。而循环中的模型，每一步之间都有反馈信号：命令失败了可以换条路，结果意外了可以调整方向。

**是“看到中间结果再修正”这一个差别，把推理变成了做事。**

听起来简单得不像话，但整台 harness 的其他部件 —— 工具、记忆、护栏 —— 全都是为了让这个循环的每一圈转得更聪明、更安全。

---

# 🧩 四、拆解一台生产级 Harness

一个 `while` 循环只是起点。真正把模型变成可靠 Agent 的，是循环周围这些工程部件：

## 🛠️ 1. 工具系统（Tools）

模型并不亲自执行工具，它只是发出一个结构化的 `tool_calls` 请求，由 harness 校验参数、检查权限、在沙箱里执行、再把结果格式化后喂回去。

这个“间接层”正是安全的起点：**模型提议，harness 决定**。只读操作可以并行，写操作必须串行 —— 这也是 harness 的调度决策。

## 📦 2. 上下文管理（Context）

上下文窗口是最稀缺的资源。生产级 harness 要决定每一轮**让模型看见什么**：历史消息压缩、无关观察打码、关键信息按需检索。

斯坦福的 *Lost in the Middle* 研究表明，关键信息落在窗口中段时，模型表现会掉 **30% 以上** —— 所以重要上下文要放在窗口的首尾。

## 🧠 3. 记忆与状态（Memory & State）

* **短期记忆**：会话历史；
* **长期记忆**：跨会话的持久存储（Claude Code 的 `CLAUDE.md` 就是这个思路）。

LangGraph 把状态建模成在图节点间流动的类型化字典，检查点（checkpoint）机制还支持中断恢复和“时间旅行调试”。

## 🚨 4. 错误处理与护栏（Guardrails）

错误要分类处理：

| 错误类型 | 处理策略 |
| ------- | ------- |
| 瞬时错误 | 自动重试（生产系统一般上限 2 次） |
| 模型可自纠 | 把错误作为 observation 喂回去让它改 |
| 用户可修复 | 升级给人，等待输入 |
| 未知错误 | 熔断终止，避免继续在坏状态上前进 |

Anthropic 的一个关键设计是**把权限检查从模型推理中剥离出来** —— 永远别指望模型“自己判断”自己是否有权执行高危操作，要用代码强制。

## ✅ 5. 验证循环（Verification Loop）

让模型自查：规则校验、跑测试、截图比对，或者用一个 LLM-as-judge 子 Agent 做评审。Claude Code 作者 Boris Cherny 提到，加入自我验证后质量提升了 **2 ~ 3 倍**。

## 🧬 6. 子 Agent 编排（Subagents）

主 Agent 可以把独立任务 fork 给子 Agent —— 子 Agent 有自己的上下文窗口，干完活只汇报结论。

这既是并行手段，也是上下文管理的终极形态。

---

# 💰 五、一个反直觉的结论：Harness 决定账单

大部分团队优化 Agent 成本的第一反应是**换模型**。但 True Foundry 做过一个控制变量实验，结果值得每个做 Agent 的人记住：

> 同样用 Claude Opus 跑同一批企业任务，Claude 官方的托管 Agent 平均烧掉约 **1000 万 token**；
> 换成第三方 harness 跑**完全相同的模型**，只用了 **380 万 token** —— 精度不变。

**模型没换，账单差了 3 倍。**

差距全部来自 harness 的上下文管理。低效的 harness 会犯三个典型错误（社区称之为 **tool bloat**）：

* 把用不上的工具定义一直留在上下文里；
* 每次工具调用的完整输出都原样保留，而不是逐步展开；
* 缺乏结构引导，导致 Agent 反复走冗余往返。

模型负责回答问题，**harness 决定它要问多少个问题、每个问题周围堆多少脚手架**。

---

# ⚖️ 六、Harness ≠ Framework

最后澄清一对最容易混淆的概念：

| 维度 | Framework | Harness |
| --- | --- | --- |
| 是什么 | 造 harness 的**工具箱** | 你实际跑在生产上的**整机** |
| 例子 | LangGraph、CrewAI、Agent SDK | Claude Code、你线上那套 Agent 运行时 |
| 提供什么 | 循环、工具、状态等原语 | 具体的上下文策略、权限策略、恢复策略 |

你可以不用任何框架徒手造一台 harness，也可以用框架 —— 但框架免不掉你的设计工作。

上下文怎么裁、工具的人机工程学怎么做、故障怎么恢复，这些难题无论用不用框架，都得你自己答。

---

# 🧭 七、写在最后

从 [MCP](https://itprohub.github.io/blog/2025/03/18/MCP/)（工具层的标准化）、[函数调用](https://itprohub.github.io/blog/2025/02/21/function-calling/)、[Agent Framework](https://itprohub.github.io/blog/2025/10/11/agent-framework/)，到今天的 Harness，这条线其实一直在讲同一件事：

> **大模型的能力上限是模型决定的，但你实际拿到的能力下限，是 harness 决定的。**

2024 年我们讨论“用哪个模型”，2025 年讨论“怎么写 prompt”，2026 年的问题变成了：

**你的 harness 修得怎么样了？**

---

# 📚 参考资料

* [Anthropic — How Claude Code Works](https://code.claude.com/docs/en/how-claude-code-works)
* [Microsoft Learn — Agent Framework: Agent Harness](https://learn.microsoft.com/en-us/agent-framework/concepts/harness)
* [Agent Harness 术语条目（ai-solutions.wiki）](https://ai-solutions.wiki/glossary/agent-harness)
* [Why Your AI Agent's Harness Matters More Than the Model for Cost（MindStudio）](https://www.mindstudio.ai/blog/agent-harness-cost-savings-benchmark)
* [Deep Dive into Agent Harness: Dissecting the Architecture Behind AI Agents](https://www.besthub.dev/articles/deep-dive-into-agent-harness-dissecting-the-architecture-behind-ai-agents-5053b8e7878d)

---
