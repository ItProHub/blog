---
title: DeepSeek 本地部署+web端访问 指南
date: 2025-02-07 09:33:25
tags:
---
去年了解到DeepSeek的时候，它在大模型排行榜上已经是第7名了，而且它还是前10名里面唯一一个开源的。想不到经过一个春节，DeepSeek更是火出了天际。‌DeepSeek在美国苹果应用商店和中国苹果应用商店的免费应用排行榜上均排名第一‌。DeepSeek在1月27日赶超OpenAI的ChatGPT，在美国苹果应用商店免费应用排行榜上排名第一。在中国苹果应用商店，DeepSeek同样排名第一‌。

这不，老夫也算是起了个大早，赶了个晚集。
这两天才有时间把前段时间部署DeepSeek的文档整理出来，做一个简单的分享。
![迟到](./images/deepseek-1/late.jpg)

在本篇博客中，我将分享如何在本地部署和使用DeepSeek模型，并结合Chatbox网页端进行交互，以提升使用体验。以下是部署的详细步骤。

# 本地部署DeepSeek
## 下载并安装Ollama
首先，我们需要安装Ollama，这是一个支持多种AI模型的本地化部署工具。Ollama支持Windows、macOS和Linux系统，选择适合你操作系统的版本。

Windows/macOS用户：可以直接访问Ollama官网，下载适合操作系统的安装包并进行安装。

![下载](./images/deepseek-1/download.png)

Linux用户：需要通过命令行执行以下命令来安装：
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

以下是我的电脑的配置，后面所有的安装都是基于以下配置完成的

![下载](./images/deepseek-1/environment.png)

<font color="#dd0000">建议看到这里的小伙子们，先去下载Ollama, 然后回来继续看下去。因为Ollama下载真的慢。</font>

## 选择DeepSeek模型
安装完成后，打开Ollama应用程序，点击界面上的“Models”选项。你会看到“deepseek-r1”模型列表，可以选择不同版本的模型，具体选择哪个版本，取决于你硬件设备的配置。

![模型](./images/deepseek-1/models.png)

7B版本：命令为 ollama run deepseek-r1:7b
1.5B版本：命令为 ollama run deepseek-r1:1.5b

![deepseek模型](./images/deepseek-1/deepseek-models.png)

这里，我选择了1.5B版本，因为其配置适合普通的电脑。需要注意的是，参数量越大的模型通常更强大，但也需要更多计算资源。如果你的硬件设备较为强大，可以选择更大的版本。

## 运行命令
选择完合适的模型后，输入相应的命令来启动DeepSeek模型。系统会显示“success”表示安装成功。

## 效果测试
一旦安装成功，你可以开始与DeepSeek进行交互。例如，输入“Hello World!”模型将返回相应的答案。如果一切正常，说明安装成功。

![安装完成](./images/deepseek-1/success.png)

# 使用Chatbox进行网页端访问
命令行界面虽然可以使用，但相对不够直观, 很多格式都没办法正常展示出来。如果你希望更方便地与DeepSeek进行交互，可以使用Chatbox来通过网页端访问模型。

![安装完成](./images/deepseek-1/cmd-effect.png)
通过上图可以看到，浮力公式和很多markdown格式都没有正常渲染出来。

## 环境变量配置
默认情况下，Ollama服务仅在本地运行，不对外提供服务。为了让Ollama能够对外提供服务，需要设置以下环境变量：

- OLLAMA_HOST：设置为 0.0.0.0
- OLLAMA_ORIGINS：设置为 *

在Windows系统上，你需要先退出Ollama应用程序，然后配置环境变量。

![deepseek模型](./images/deepseek-1/env_var.png)

保存设置后，从Windows开始菜单启动Ollama。

## 配置Chatbox
完成环境变量配置后，接下来配置Chatbox以访问本地的Ollama模型。

打开[Chatbox](https://web.chatboxai.app/)官网，并选择启动网页版。
![ChatBox](./images/deepseek-1/chatboxai.png)
选择“本地模型”，如果没有找到本地模型，点击左侧的设置按钮。
在设置中选择Ollama API。

选择你已经安装并运行的模型，Chatbox会自动识别到本地运行的模型，直接选择即可。
点击“DISPLAY”选项，选择简体中文，并点击保存按钮。

![deepseek模型](./images/deepseek-1/chatbox-setting3.png)

完成配置后，可以在聊天窗口输入问题进行测试，体验与DeepSeek的交互。

这个时候，我们可以看到之前在命令行无法正常显示的格式都可以正常显示了。
![deepseek模型](./images/deepseek-1/chatbox-answer.png)

# 总结
通过上述步骤，你可以成功在本地部署DeepSeek，并使用Chatbox网页端进行交互。无论是命令行还是网页端，Ollama和DeepSeek都能提供强大的AI模型支持，帮助你完成各种任务。使用Chatbox作为前端应用，可以使与模型的交互更加直观和友好。

希望这篇部署分享对你有所帮助，祝你在使用DeepSeek时能够获得愉快的体验！