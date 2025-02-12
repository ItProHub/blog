---
title: Cursor平替：把 DeepSeek 接入 VS Code
date: 2025-02-12 09:50:46
tags:
---
提到春节最火热的两件事，一定是”哪吒“和”DeepSeek“了。
![哪吒](./images/deepseek-2/hot.png)

趁着这波热潮，作为开发人员的我们怎么利用上这波红利呢？

提到AI代码编辑器就不得不提到Cursor，它不仅仅是一个开发环境（IDE），融合了最先进 AI 技术的智能助手。无论你是经验丰富的程序员，还是对编程一窍不通的普通用户，Cursor 都能为你带来前所未有的效率提升和创新可能。但是价格。。。

![价格](./images/deepseek-2/price.png)

而VS Code作为当下最流行的编辑器之一，提供了丰富的插件生态，可以让开发者轻松集成各种外部工具。今天，我们将介绍如何通过Roo Code插件将DeepSeek接入VS Code，助力开发者更高效地进行开发工作。

# 什么是 Roo Code
Roo Code (prev. Roo Cline) 是一个 VS Code 插件，旨在帮助开发人员更高效地进行代码导航、重构和代码操作。它的主要功能是增强代码编辑体验，特别是在类和方法的跳转、重命名以及快速定位方面提供帮助。

以下是 Roo Code 插件的一些主要特点和功能：

1. 智能代码导航：
   - 支持快速跳转到类、方法或变量的定义。
   - 提供返回和前进导航功能，让开发者可以在多个位置之间轻松跳转。

2. 重构工具：
   - 支持重命名类、方法、变量等代码元素，可以自动调整所有引用的位置，确保代码一致性。

3. 代码片段：
   - 提供代码片段功能，帮助开发者在常用代码模式中快速生成代码模板。

4. 增强的代码补全：
   - 提供智能提示，能够根据上下文提供更加精确的代码补全建议，提升编程效率。

总的来说，Roo Code 是一个强大的辅助工具，特别适合那些需要频繁进行代码导航、重构和优化的开发人员。如果你正在使用 VS Code 进行日常开发工作，安装并配置这个插件能大大提高开发效率。

# 安装 Roo Code 插件

打开 VS Code。
进入扩展市场（左侧栏的 Extensions 图标）。
在搜索框中输入 "Roo Code"。
![价格](./images/deepseek-2/search.png)
点击 Install 按钮，安装插件。
安装完成后，你将在 VS Code 的活动栏上看到一个 DeepSeek 图标，表示插件已成功安装。
![价格](./images/deepseek-2/installed.png)
可以看到插件迭代的非常快。

# 配置 Roo Code
## 申请 DeepSeek API 密钥
在使用 DeepSeek 之前，你需要先在 DeepSeek 官网注册并获取 API 密钥。

将复制的 API 密钥保存好，你将在后续的配置中使用它。
![价格](./images/deepseek-2/apikeys.png)

## 配置 Roo Code 插件
打开 VS Code 设置（点击右下角齿轮图标，然后选择 "Settings"）。

这里需要使用上面的 API 密钥。
![价格](./images/deepseek-2/settings.png)

# 使用 Roo Code 插件
这里我新建了一个空项目，然后让DeepSeek帮我用python写一个简单的命令行的”2048小游戏“项目。
![游戏](./images/deepseek-2/generating.gif)
可以看到DeepSeek已经帮我写好了，并且还把这次对话产生的费用也返回给了我。
![游戏](./images/deepseek-2/game1.png)

下面我直接运行DeepSeek生成的代码，不做任何修改。不出意外的话，意外就要发生了。
![错误](./images/deepseek-2/error.png)

然后我直接把错误信息再次发给DeepSeek，让它帮我修改。
![修改](./images/deepseek-2/feedback.png)
可以看到DeepSeek已经帮我修改好了，并且还把这次对话产生的费用也返回给了我。

再次运行修改后的代码，发现可以正常运行了。
![运行](./images/deepseek-2/running.gif)
整个过程可以说是非常的流畅。爽！

# 总结
将 DeepSeek 集成到 VS Code 中，不仅能让开发者更加方便地进行代码搜索和分析，还能有效提高开发效率。通过 VS Code 扩展与 DeepSeek 的结合，我们能够在熟悉的开发环境中直接使用强大的代码分析工具，从而提升开发体验。

希望这篇文章能帮助你顺利将 DeepSeek 接入 VS Code，享受更高效的开发流程。如果你有任何问题或建议，欢迎留言讨论！