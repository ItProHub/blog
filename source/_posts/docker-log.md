---
title: 减少 Docker 日志大小：实用的日志管理指南
date: 2025-02-05 15:40:48
tags:
---
之所以选择这个主题，是因为最近，我发现我的一台服务器的可用磁盘空间不足，几乎就要满了。经过调查，我发现一个 Docker 容器在短短半年内就积累了 2.7G 的日志文件。

在现代开发和运维中，Docker 已成为开发者的常用工具，但在高负载和高并发的环境下，Docker 容器生成的日志文件可能会迅速膨胀，占用大量磁盘空间，甚至导致系统性能问题。本文将探讨如何有效地管理和减少 Docker 日志的大小，确保日志的高效存储和易于管理。

# Docker 日志机制概述
Docker 默认使用 json-file 日志驱动来记录容器的标准输出和标准错误输出。这些日志通常会存储在 /var/lib/docker/containers/[container-id]/ 路径下，文件名为 container-id-json.log。随着容器的运行，日志文件会不断增长，甚至变得庞大无比。

Docker 提供了多种日志驱动方式，例如：

- json-file（默认）
- syslog
- journald
- fluentd
- gelf
- awslogs
- none（不记录日志）

通过选择合适的日志驱动并配置日志管理策略，能够帮助我们避免日志文件的无限膨胀。

# 为什么 Docker 日志会膨胀？
让我们回到上面我自己的案例。在过去的半年里，服务器已经重启多次，这意味着 Docker 容器也曾被停止和启动过。然而，它们的日志文件一直存在并且持续增长。

发生这种情况的原因在于我的容器是重新启动，而不是重新创建容器。当服务器重新启动时，Docker 守护进程会正常关闭正在运行的容器，并在启动后自动启动它们。

同样，使用“systemctl restart docker”命令手动重启 Docker 服务时，行为也是一样的。重要的是要了解，只有在删除并重新创建 Docker 容器时，Docker 日志才会重置。简单地停止并启动容器不会重置日志。


# 减少 Docker 日志大小的有效策略
## 使用合适的日志驱动
选择正确的日志驱动是管理日志文件大小的第一步。如果你不需要将日志保留在本地磁盘，可以选择将日志直接转发到远程服务器或日志聚合系统。常见的日志驱动如 syslog 和 fluentd 可以将日志发送到外部日志管理平台，如 Elasticsearch、Logstash 或 Kibana（ELK），或者云端服务。

示例：将 Docker 容器日志发送到 syslog
```bash
docker run --log-driver=syslog --name my-container my-image
```
## 限制日志文件大小和日志文件数量
Docker 允许你在启动容器时设置日志的最大文件大小和最大日志文件数。这有助于防止日志文件无限增长，从而节省磁盘空间。

使用 --log-opt 参数可以设置以下选项：

- max-size：设置日志文件的最大大小，超过该大小时会自动轮换日志文件。
- max-file：设置最多保存多少个轮换的日志文件。

示例：限制日志文件大小和数量
```bash
docker run --log-driver=json-file --log-opt max-size=10m --log-opt max-file=3 --name my-container my-image
```
在这个例子中，每个日志文件的最大大小为 10MB，当文件达到该大小时会进行轮换，最多保存 3 个轮换文件。

也可以通过配置文件（如 /etc/docker/daemon.json）来全局设置日志驱动和日志选项。
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

要应用更改，还需重启 Docker 服务：
```bash
sudo systemctl restart docker
```
<font color="#dd0000">需要注意的是，这些更改只会影响新创建的 Docker 容器，而不会影响已经运行的容器</font>

要将更改应用于现有容器，必须先删除它们，然后重新创建它们
```bash
docker rm -f <container_id_or_name>
```

再次查看容器详情，你会看到日志选项已经被设置。
![日志文件](./images/docker-log/log5.png)

## 禁用日志
如果容器的日志完全不需要存储，或者你决定将日志流转到其他地方，可以选择禁用 Docker 容器的日志记录。这种做法适合那些对于日志并不重要的应用。

示例：禁用日志记录
```bash
docker run --log-driver=none --name my-container my-image
```

## 定期清理旧日志文件
虽然 Docker 提供了日志轮换功能，但一些过期的日志文件可能会积累在磁盘上。定期清理旧日志文件可以确保磁盘空间得到合理利用。


### 检查容器日志大小

Docker 日志通常保存在主机上的以下目录中（除非你更改了默认路径）：

```bash
/var/lib/docker/containers/<container-id>/<container-id>-json.log
```
每个 Docker 容器都有自己的目录，且在该目录下，你会找到一个以 -json.log 结尾的文件。这个文件包含该容器的标准输出（stdout）和标准错误（stderr）流。

要快速检查所有 Docker 容器日志的大小，可以使用以下命令：

```bash
find /var/lib/docker/containers/ -name "*json.log" | xargs du -h | sort -rh
```
这个命令将显示所有 Docker 容器日志的大小，并按从大到小的顺序排序，帮助你找出哪个容器占用了最多的磁盘空间。

![日志文件](./images/docker-log/log1.png)

### 根据日志文件 ID 查找容器名称
现在我们知道了日志文件的大小，接下来是将容器 ID 与实际容器名称匹配。例如，假设你发现了一个非常大的日志文件，容器 ID 是 3908b66962bca22ddb818a8df1a61c9003a23283a932d44d1c91631d9de7e3e4。

要查找该容器的名称，可以运行以下命令：

```bash
docker inspect --format='{{.Name}}' <container_id>
```
对于我们的例子：

```bash
docker inspect --format='{{.Name}}' 3908b66962bca22ddb818a8df1a61c9003a23283a932d44d1c91631d9de7e3e4
```
这将返回容器的名称，如下图。
![日志文件](./images/docker-log/log2.png)

要再次检查这是否是生成日志文件的正确容器，您可以使用命令docker inspect <container_name>获取有关它的更多详细信息并确认它是日志文件的来源。
```bash
docker inspect registry_registry_1
```

![日志文件](./images/docker-log/log3.png)

或者直接使用如下命令查看容器日志路径信息
```bash
docker inspect --format='{{.LogPath}}' registry_registry_1
```
![日志文件](./images/docker-log/log4.png)

### 清理 Docker 容器日志
一旦你确认了哪个容器导致了日志文件膨胀，接下来就可以清理这些日志文件以释放磁盘空间。

要清理特定容器的日志文件，可以使用 truncate 命令。例如：

```bash
truncate -s 0 /var/lib/docker/containers/3908b66962bca22ddb818a8df1a61c9003a23283a932d44d1c91631d9de7e3e4/3908b66962bca22ddb818a8df1a61c9003a23283a932d44d1c91631d9de7e3e4-json.log
```
如果你想一次性清理所有 Docker 容器的日志，可以运行以下命令：

```bash
truncate -s 0 /var/lib/docker/containers/*/*-json.log
```
这个命令会清理所有容器的日志文件。使用之前请确保理解其影响，因为这将删除所有日志。

## 配置容器的标准输出和标准错误输出
Docker 容器的标准输出和标准错误输出可能包含大量日志。你可以在容器内部或应用程序中通过配置日志框架来限制日志的级别（例如，设置日志级别为 ERROR，避免 DEBUG 和 INFO 级别的日志输出）。

## 使用日志聚合和集中化
使用集中化日志系统可以将日志存储和管理集中化，避免了每个 Docker 容器在本地存储大量日志。常见的日志聚合系统有：

- Elasticsearch + Logstash + Kibana（ELK）
- Fluentd
- Graylog
- Splunk

这些系统不仅可以帮助你管理日志文件大小，还能为你提供强大的日志搜索、过滤和分析功能。

## 使用外部日志存储
将 Docker 日志输出到外部存储系统，可以有效减少本地磁盘的使用。例如，AWS 提供了 awslogs 日志驱动，可以将日志直接发送到 CloudWatch 中：

```bash
docker run --log-driver=awslogs --log-opt awslogs-group=my-log-group --log-opt awslogs-stream=my-log-stream --name my-container my-image
```

# 监控 Docker 日志大小
为了及时发现日志文件异常增长，建议对 Docker 容器的日志大小进行监控。可以使用一些开源工具（如 logrotate）来自动清理过期日志，也可以结合 Prometheus 等监控工具来实时监控日志文件的大小。

# 小结

Docker 日志管理是一项关键的运维任务，尤其是在生产环境中，日志文件的大小和数量会直接影响系统的稳定性和可维护性。通过选择合适的日志驱动、配置日志轮换、定期清理旧日志以及利用集中化日志系统，可以有效地管理和减少 Docker 日志的大小。希望本文的技巧和策略能帮助你更好地管理 Docker 容器日志，保持系统的高效运行。

----

这篇博客概述了减少 Docker 日志大小的几种实用方法，包括选择合适的日志驱动、设置日志轮换策略、禁用日志记录、定期清理过期日志等。你可以根据实际需求，调整策略来优化你的 Docker 环境。