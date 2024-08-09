---
title: 了解容器镜像层
date: 2024-08-08 14:58:18
tags:
---

之前我写了一篇博客《Docker镜像构建优化》，里面讲到了Docker里面的层，但是始终觉得差了点什么。今天这篇就算是补充一下吧！

容器非常神奇。它们允许简单的进程像虚拟机一样运行。在这种优雅的背后是一套模式和实践，最终使一切正常运转。设计的根源是层。层是存储和分发容器化文件系统内容的基本方式。这种设计既出奇的简单，又非常强大。在今天的文章中，我将解释什么是层以及它们在概念上是如何工作的。

# 构建分层图像
创建镜像时，通常使用 来Dockerfile定义容器的内容。它包含一系列命令，例如：
```
FROM alpine
RUN echo "hello" > /usr/file1.txt
COPY requirements.txt /usr/file2.txt
RUN rm -rf /usr/file1.txt
```
在幕后，容器引擎将按顺序执行这些命令，为每个命令创建一个“层”。但实际情况是什么？最简单的方法是将每个层视为一个包含所有修改文件的目录。

让我们逐步了解一种可能的实施方法的示例。

1. FROM alpine表示此容器从无内容开始。这是第一层，可以用空目录来表示/img/layer1。

2. 创建第二个目录/img/layer2。从/img/layer1中拷贝所有内容。然后，从 Dockerfile 执行下一个命令，将“hello”写入/img/layer2/usr/file1.txt。这是第二层。

3. 创建第三个目录/img/layer3。从img/layer2中拷贝所有内容。从主机复制requirement.txt到该目录。这是第三层。

4. 最后，创建第四个目录/img/layer4。从img/layer3中拷贝所有内容。下一个命令删除消息文件img/layer4/usr/file1.txt。这是第四层。

要共享这些层，最简单的方法是为每个目录创建一个压缩文件.tar.gz。为了减少总文件大小，任何未修改的来自前一层的数据副本的文件都将被删除。为了清楚地说明文件何时被删除，可以使用“空白文件”作为占位符。该文件只需.wh.作为原始文件名的前缀。例如，第四层将用名为 .wh.file1.txt 的占位符替换已删除的文件。当解压一个层时，可以删除任何以 .wh. 开头的文件。

继续我们的例子，压缩文件将包含：

|文件|内容|
|  ----  | ----  |
|layer1.tar.gz|	精简的linux基础环境|
|layer2.tar.gz|	包含/usr/file1.txt|
|layer3.tar.gz|	包含/usr/file2.txt（因为file1.txt未被修改）|
|layer4.tar.gz|	包含/usr/.wh.file1.txt（因为file1.txt已被删除）。该文件file2.txt未被修改，因此不包含在内。|

以这种方式构建大量镜像将产生大量“layer1”目录。为了确保名称唯一，压缩文件基于内容摘要命名。这类似于 Git 的工作方式。它的好处是可以在下载时识别文件损坏的同时识别相同的内容。如果内容摘要与文件名不匹配，则文件已损坏。

为了使结果可重现，还需要一件事---一个解释如何对图层进行排序的文件（清单）。清单将标识要下载哪些文件以及解压它们的顺序。这可以重新创建目录结构。它还提供了一个重要的好处：图层可以在图像之间重复使用和共享。这最大限度地减少了本地存储控件。

引擎还可以查看构建中使用的文件，以确定是否需要重新创建层。这是层缓存的基础，可最大限度地减少构建或重新创建层的需要。作为额外的优化，不依赖于前一层的层可以使用COPY --link来指示该层不需要删除或修改前一层的任何文件。这允许与其他步骤并行创建压缩层文件。

# 快照
在容器运行之前，它需要挂载一个文件系统。本质上，它需要一个包含所有可用文件的目录。压缩层文件包含文件系统的组件，但不能直接挂载和使用。相反，它们需要解压并组织成一个文件系统。这个解压后的目录称为快照。

创建快照的过程与镜像构建相反。它首先下载清单并构建要下载的层列表。对于每个层，都会创建一个目录，其中包含该层父级的内容。此目录称为活动快照。接下来，差异识别程序负责解压压缩的层文件并将更改应用于活动快照。生成的目录称为已提交快照。最终提交的快照是作为容器文件系统挂载的快照。

使用我们之前的例子：

1. 初始层，FROM alpine基础的linux环境；

2. 创建一个目录layer2。这个空目录现在是一个活动快照。文件layer2.tar.gz被下载、验证（通过将摘要与文件名进行比较）并解压到目录中。结果是一个包含/work/file1.txt 的目录。这是第一个提交的快照。

3. 创建一个目录layer3，并将layer2的内容复制到其中。这是一个新的活动快照。文件layer3.tar.gz下载、验证和解压。结果是一个包含/work/file1.txt和/work/file2.txt的目录。这是第二个已提交的快照。

4. 创建的目录layer4，并将layer3 的内容复制到其中。layer4.tar.gz下载、验证和解压文件。diff applier识别 whiteout 文件 /work/.wh.file1.txt，并删除/work/file1.txt。这样就只剩下/work/file2.txt。这是第三个已提交的快照。

5. 由于layer4是最后一层，因此它是容器的基础。为了使其支持读写操作，将创建一个新的快照目录并将的内容layer4复制到其中。此目录将挂载为容器的文件系统。正在运行的容器所做的任何更改都将在此目录中发生。

如果这些目录中的任何一个已经存在，则表明另一个映像具有相同的依赖关系。因此，引擎可以跳过下载和 差异识别。它可以按原样使用该层。实际上，这些目录和文件中的每一个都根据内容摘要命名，以便于识别。例如，一组快照可能如下所示：

```
 "RootFS": {
    "Type": "layers",
    "Layers": [
        "sha256:78561cef0761903dd2f7d09856150a6d4fb48967a8f113f3e33d79effbf59a07",
        "sha256:48dcbf93fac08ef430c39a4924c0622c13f17548cec0ca5588a665a773f5d091",
        "sha256:53e113db23922a5cc6d6c916a2a796f87e8db900d5a8ece3237cbcc4db9e5b7e",
        "sha256:df7fa7c302ca914532aaa453ec101e5f21b1c3bb81b2f5046321aa40f2de1399"
    ]
},
```   

实际的快照系统支持插件，可以改善其中一些行为。例如，它可以允许快照预先组合和解包，从而加快该过程。这允许快照远程存储。它还允许进行特殊优化，例如即时下载所需的文件和层。

# 叠加层
虽然挂载起来很容易，但我们刚刚描述的快照方法会产生大量文件变动和大量重复文件。这会减慢首次启动容器的速度并浪费空间。幸运的是，这是文件系统可以处理的容器化过程的众多方面之一。Linux 本身支持将目录挂载为覆盖层，为我们实现了大部分过程。

在 Linux 中（或以--privileged/--cap-add=SYS_ADMIN 运行的linux容器中）：

1. 创建tmpfs挂载（基于内存的文件系统，将用于探索覆盖过程）
```
mkdir /tmp/overlay
mount -t tmpfs tmpfs /tmp/overlay
```

2. 为我们的进程创建目录。我们将使用lower下层（父层）、upper上层（子层）、work文件系统的工作目录以及merged包含合并的文件系统。
```
mkdir /tmp/overlay/{lower,upper,work,merged}
```

3. 为实验创建一些文件。您upper也可以选择添加文件。
```
cd /tmp/overlay
echo hello > lower/hello.txt
echo "I'm only here for a moment" > lower/delete-me.txt
echo message > upper/upper-message.txt
```
4. 将这些目录挂载为overlay类型文件系统。这将在目录中创建一个新的文件系统，其中包含和目录merged的组合内容。该目录将用于跟踪文件系统的更改。lowerupperwork
```
mount -t overlay overlay -o lowerdir=lower,upperdir=upper,workdir=work merged
```
5. 探索文件系统。您会注意到包含和merged的组合内容。然后进行一些更改：upperlower
```
rm -rf merged/delete-me.txt
echo "I'm new" > merged/new.txt
echo world >> merged/hello.txt
```
6. 正如预期的那样，delete-me.txt被删除，并且在同一目录中创建了merged一个新文件。如果你查看目录，你会看到一些有趣的东西：new.txttree
```
   |-- lower
   |   |-- delete-me.txt
   |   `-- hello.txt
   |-- merged
   |   |-- hello.txt
   |   |-- new.txt
   |   `-- upper-message.txt
   |-- upper
   |   |-- delete-me.txt
   |   |-- hello.txt
   |   |-- new.txt
   |   `-- upper-message.txt
```
还有ls -l upper演出
```
total 12
c--------- 2 root root 0, 0 Jan 20 00:17 delete-me.txt
-rw-r--r-- 1 root root   12 Jan 20 00:20 hello.txt
-rw-r--r-- 1 root root    8 Jan 20 00:17 new.txt
-rw-r--r-- 1 root root    8 Jan 20 00:17 upper-message.txt
```
虽然merged显示了我们更改的效果，upper但（作为父层）存储的更改类似于我们手动过程中的示例。它包含新文件new.txt和修改的hello.txt文件。它还创建了一个 whiteout 文件。对于覆盖文件系统，这涉及用字符设备（和 0、0 设备号）替换文件。简而言之，它拥有我们打包目录所需的一切！

您可以看到这种方法也可以用于实现快照系统。该mount命令可以本机接受以冒号 ( :) 分隔的lowerdir路径列表，所有这些路径都合并到单个文件系统中。这是现代容器的本质 - 容器是使用本机操作系统功能组成的。

这就是创建一个基本系统的全部内容。事实上，containerdKubernetes（以及最近发布的 Docker Desktop 4.27.0）使用的运行时使用类似的方法来构建和管理其镜像（ 内容流中涵盖了更详细的细节）。希望这有助于揭开容器镜像工作方式的神秘面纱！

