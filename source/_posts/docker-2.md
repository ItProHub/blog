---
title: 优化Docker镜像：减少Dockerfile层数的技巧
date: 2024-07-08 09:20:55
tags:
---

引言
在构建Docker镜像时，Dockerfile的层数对镜像的性能和大小有显著影响。本文将深入探讨Dockerfile中的层定义、层数多带来的问题，以及如何通过优化Dockerfile来减少层数，提高构建效率和运行性能。

# Dockerfile中的层定义
在Dockerfile中，每一个指令（如RUN、COPY、ADD等）都会创建一个新的层。Docker采用联合文件系统（UnionFS），每一层都是只读的，只有最顶层是可写的。

```dockerfile
# 每一条指令都会创建一个新层
FROM python:3.8-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```
上面的Dockerfile创建了四个层：FROM、WORKDIR、COPY和RUN。


在Docker中，每个RUN指令都会创建一个新的层，这个层主要包含的是该指令执行过程中对文件系统所做的更改。具体来说，一个RUN指令会生成一个文件系统层，其中包含以下内容：

1. 新增的文件和目录：RUN指令中执行的命令可能会创建新的文件和目录。例如，使用RUN apt-get install命令安装软件包时，会在文件系统中创建新的文件和目录来存放这些软件包。

2. 修改的文件和目录：如果RUN指令修改了已有的文件或目录，这些修改也会被记录在这一层中。例如，修改配置文件或更新现有的软件包。

3. 删除的文件和目录：如果RUN指令删除了某些文件或目录，这些删除操作也会记录在这一层中。

4. 文件权限的更改：RUN指令可能会改变文件或目录的权限，这些权限更改也会包含在这一层中。

为了更具体地说明，下面是一个示例Dockerfile及其解释：

```dockerfile
FROM ubuntu:20.04

# 第一层
RUN apt-get update && apt-get install -y curl

# 第二层
RUN echo "Hello, World!" > /hello.txt

# 第三层
RUN chmod 644 /hello.txt
```
在这个示例中，每个RUN指令都会创建一个新的层：

1. 第一层：RUN apt-get update && apt-get install -y curl：
- 这一层包含了更新包索引文件和安装curl工具所做的所有更改。
- 新增了curl工具的相关文件和目录。
- 修改了包管理器的状态文件。
2. 第二层：RUN echo "Hello, World!" > /hello.txt：
- 这一层包含了创建/hello.txt文件并向其中写入"Hello, World!"的操作。
- 新增了文件/hello.txt。

3. 第三层：RUN chmod 644 /hello.txt：
- 这一层包含了对文件/hello.txt的权限更改。
- 修改了文件/hello.txt的权限信息。

每一层都会记录该层创建时的文件系统快照。Docker通过这种层级方式，使得每一层都可以被缓存和重用，从而提高构建速度和效率。

# 层带来的好处
Docker 镜像由多个只读层组成，这些层通过 Union File System（联合文件系统）组合在一起，形成一个统一的文件系统视图。每一层对应 Dockerfile 中的一条指令，并且每一层都是前一层的增量变化。这些层被称为镜像层。

## 层的重用机制
层的重用主要是通过以下几个步骤实现的：

1. 层的哈希值：当 Docker 执行一条指令时，会计算这条指令生成的文件系统变化的哈希值。这个哈希值用于唯一标识这层内容。如果相同的指令生成了相同的文件系统变化，那么它们的哈希值也会相同。

2. 层缓存：Docker 会在本地存储层缓存，这些缓存是基于层的哈希值存储的。当构建新的镜像时，Docker 会检查本地是否已经存在相同哈希值的层。如果存在，Docker 就会重用这个层，而不是重新创建。

3. 层的共享：由于每个层是只读的，因此多个镜像可以共享相同的层。这样不仅节省了存储空间，还加快了镜像的构建速度。

## 层的重用示例
假设我们有一个简单的 Dockerfile：

```dockerfile
FROM python:3.8-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```
为了验证，这里我们构建了两个镜像。第一个requirements.txt是空的，而第二个镜像构建之前，我们在requirements.txt里面输入如下内容
```
# requirements.txt 示例
flask
requests
```
根据我们上面说所的，如果我们修改了 requirements.txt 文件，那么对应的 COPY requirements.txt . 和 RUN pip install -r requirements.txt 这两条指令会生成新的层。然而，其余的层（比如 FROM python:3.8-slim、WORKDIR /app、COPY . . 和 CMD ["python", "app.py"]）由于没有变化，可以直接从缓存中重用。

构建完镜像以后，让我们inspect一下镜像
![inspect1](/images/docker-2/inspect1.png)![inspect2](/images/docker-2/inspect2.png)

我们对比一下这些层hash，可以清晰的看到没有变化的层的hash也是一样的。由此可见，这些层确实重用了。
![inspect3](/images/docker-2/inspect3.png)


# 层数多带来的问题
层数多会导致以下几个问题：

1. 镜像大小增加：每一层都会增加镜像的总体大小，特别是在有大量中间层的情况下。
2. 构建时间增加：每一层都需要单独构建和缓存，层数越多，构建时间越长。
3. 性能开销：在运行容器时，Docker需要处理每一层的文件系统，这会增加I/O操作的开销。

# 减少Dockerfile层数的方法
合并指令
将多个指令合并到一个RUN指令中，可以显著减少层数。例如：

```dockerfile
# 将多个RUN指令合并到一个
RUN apt-get update && \
    apt-get install -y package1 package2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

减少临时文件
在构建过程中，避免创建不必要的临时文件，可以减少层的大小。例如：

```dockerfile
# 使用多行命令避免临时文件
RUN wget -qO- https://example.com/file.tar.gz | tar xz -C /path/to/destination
```
使用.dockerignore
类似于.gitignore，.dockerignore文件可以指定在构建镜像时忽略哪些文件和目录，从而减少不必要的层。

```dockerignore
# .dockerignore 文件示例
node_modules
.git
.tmp
```

# 实际案例：优化一个Dockerfile
原始Dockerfile：

```dockerfile
FROM python:3.8-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean
CMD ["python", "app.py"]
```
优化后的Dockerfile：

```dockerfile
# 优化后的Dockerfile，减少层数
FROM python:3.8-slim

WORKDIR /app

# 合并COPY和RUN指令
COPY requirements.txt ./
RUN apt-get update && \
    apt-get install -y curl && \
    pip install -r requirements.txt && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 使用.dockerignore忽略不必要的文件
COPY . .

CMD ["python", "app.py"]
```
我们来看看优化前后镜像的大小。从下图可以看到，仅仅是很小的改动，镜像就小了20M。
![优化dockerfile](/images/docker-2/after.png)


# 其他优化技巧
## 使用多阶段构建
多阶段构建允许你在一个Dockerfile中使用多个FROM指令，从而在构建过程中只保留最终阶段的镜像，减少不必要的层。下面这个例子中，我们将.net项目的编译和运行分开构建。
通过这样的方式，我们在最后运行的镜像里面不需要包含.net sdk，而只有运行时，从而缩小镜像的大小。

```dockerfile
# 多阶段构建示例
FROM net8-sdk AS build
WORKDIR /app
# 拷贝项目文件并还原依赖项
COPY . .
# 构建发布版本
RUN dotnet publish "src/Uranus.DatacenterMH/Uranus.DatacenterMH.csproj" -c Release -o /app/publish

# 设置运行时镜像
FROM net8-runtime
WORKDIR /app
# 从构建镜像阶段复制发布的文件到运行时镜像
COPY --from=build /app/publish .

EXPOSE 80
ENTRYPOINT ["dotnet", "Uranus.DatacenterMH.dll"]
```


## 定期清理镜像和容器
定期清理未使用的镜像和容器，可以保持Docker环境的干净，避免不必要的存储开销。

```bash
# 清理未使用的镜像
docker image prune -a

# 清理未使用的容器
docker container prune
```

结语
通过理解Dockerfile中的层定义和层数对性能的影响，可以更好地优化镜像构建过程。合并指令、减少临时文件、使用.dockerignore以及多阶段构建都是有效的减少层数的方法。希望本文能帮助你在实际项目中更高效地使用Docker，构建更轻量级、更快速的容器镜像。


希望这篇文章能帮助你理解学习Docker。如果你有任何问题或建议，欢迎留言讨论！