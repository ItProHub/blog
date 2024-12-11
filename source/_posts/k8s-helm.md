---
title: Kubernetes 分享：如何使用 Helm 优化 Kubernetes 应用部署
date: 2024-12-11 14:22:16
tags:
---

在 Kubernetes 的生态中，Helm 是一个非常重要的工具，它作为 Kubernetes 的包管理器，简化了复杂应用的部署和管理过程。而 Helm Chart 是 Helm 中的核心概念，它将应用的部署定义成一种可复用的模板，能帮助我们快速地在 Kubernetes 上安装、升级和管理应用。

今天，我们将深入探讨 Helm Chart 的概念、使用方式以及一些实用的实践技巧，帮助你更高效地管理 Kubernetes 应用。

# 什么是 Helm 和 Helm Chart？
![architecture](./images/helm/helm3-arch.png)
1. Helm：Helm 是 Kubernetes 的包管理工具，类似于 Linux 上的 APT 或 YUM。它允许你定义、安装和管理 Kubernetes 应用程序的各种资源。Helm 通过 Chart 来实现这一功能。

2. Helm Chart：Helm Chart 是一种标准化的应用定义格式，包含了 Kubernetes 对象的所有资源定义，如 Deployment、Service、ConfigMap 等。Chart 本质上是一个压缩包，里面存放着 Kubernetes 应用的 YAML 配置文件和模板，使用 Helm 进行管理。

# 为什么要使用 Helm Chart？
在没有 Helm 之前，Kubernetes 部署通常涉及手动编写和管理多个 YAML 文件，而这些文件常常会有大量的重复和冗余。使用 Helm Chart 有以下几个优势：

- 简化应用部署：通过 Helm Chart，用户只需要一个简单的命令就能将应用快速部署到 Kubernetes 集群中。
- 模板化配置：Chart 使用模板引擎，允许你在不同环境中配置不同的值（如数据库的用户名、密码等），避免手动修改多个配置文件。
- 版本管理：Helm 支持对应用的版本控制，可以轻松回滚到之前的版本。
- 共享与重用：通过 Helm 仓库，开发者可以共享自己创建的 Helm Chart，其他人可以直接使用。

# Helm Chart 结构
一个典型的 Helm Chart 包含以下几个关键部分：
![helm](./images/helm/new-helm.png)

1. Chart.yaml：这个文件包含了 Chart 的基本信息，例如名称、版本、描述等。
2. values.yaml：这是 Helm Chart 中用于存放默认值的文件，用户可以在部署时覆盖其中的配置项。
3. templates/目录：存放模板文件，在这些文件中，我们可以使用 Go 模板语法进行变量替换和条件判断，最终生成 Kubernetes 的资源文件。
4. charts/目录：存放依赖的子 Chart，Helm 支持多 Chart 之间的依赖关系。
5. README.md：存放 Chart 的使用文档，提供如何使用 Chart 的指南。

# 创建一个简单的 Helm Chart
假设我们要创建一个监控程序部署 Helm Chart，并且采用[DaemonSet](/2024/08/01/daemonset/)方式部署，步骤如下：

1. 创建 Chart： 使用 Helm 的命令行工具创建一个新的 Chart：

```bash
helm create txclient
```
这将生成一个包含上述结构的基本 Chart。

2. 修改 values.yaml： 在 values.yaml 中，可以配置容器的镜像、端口等：

```yaml
replicaCount: 1

image:
  repository: xxx/txclientx
  tag: 5.24.11203.10
  pullPolicy: IfNotPresent

service:
  enabled: false

daemonset:
  enabled: true
  containers:
    - name: txclient
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      ports:
        - containerPort: 80  # 你程序暴露的端口，可以根据实际情况调整

resources: {}
```
3. 修改模板文件： 在 templates/daemonset.yaml 中，替换其中的变量为模板形式：

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: txclientx
  namespace: monitor
spec:
  selector:
    matchLabels:
      name: txclientx
  template:
    metadata:
      labels:
        name: txclientx
    spec:
      containers:
      - name: txclientx
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"    
        env:
        - name: KhGuid
          value: "xxxxxxx"
        - name: TxClient_DatabusUrl
          value: "https://xxx.com"

```
4. 安装 Chart： 在创建好 Helm Chart 后，可以通过 Helm 安装应用：

```bash
helm install txclient /helm/txclient
```
这会根据模板创建一个 txclient 部署。

# 实用技巧与最佳实践
1. 使用 values.yaml 管理配置： 对于复杂的应用，values.yaml 可以帮助你管理不同环境的配置。可以在安装时传递自定义配置文件，支持不同环境下的灵活部署。

   - 传入外部配置文件：

    ```bash
    helm install my-release ./my-chart -f custom-values.yaml
    ```
    - 使用 --set 传递单个值：
    ```bash
    helm install my-release ./my-chart --set image.tag=v1.2.3
    ```
   这种方式对于修改特定的单个配置项非常有用。
2. Chart 版本管理： Helm 允许你为 Chart 打标签并管理版本，确保每次发布的应用都有明确的版本标记，方便回滚。

3. 多环境部署： 在 Helm Chart 中使用不同的命名空间和环境变量，可以轻松实现多个环境（如开发、测试、生产）的部署。

   如果你有多个环境（比如开发、生产等），可以为每个环境创建不同的 values.yaml 文件。然后使用 -f 来指定不同环境的配置。

    ```bash
    helm install my-release ./my-chart -f values-prod.yaml
    helm install my-release ./my-chart -f values-dev.yaml
    ```

4. 自定义 Helm Chart： 你可以将常见的 Kubernetes 应用封装成 Helm Chart，方便团队内部共享和管理。

5. 调试和测试
   - 调试 Chart：在安装或升级 Helm Chart 前，使用 helm template 可以渲染出最终的 Kubernetes 资源清单。这对于调试和验证 Helm Chart 是否按预期工作非常有帮助。

    ```bash
    helm template my-release ./my-chart -f values.yaml
    ```
    这样可以查看 Helm 渲染后的所有资源清单，而不会真正部署到 Kubernetes 集群中。

   - 测试 Chart：Helm 也提供了 Chart 的单元测试功能，使用 helm test 来运行测试。如果你在 Chart 中定义了测试（如 Pod，Job 等），可以通过这个命令来运行这些测试。

    ```bash
    helm test my-release
    ```

# 结语
Helm 和 Helm Chart 作为 Kubernetes 中的强大工具，极大地简化了应用的部署、管理和维护过程。掌握 Helm 的使用，能有效提高开发效率，减少重复工作，并确保部署的一致性。无论是个人开发者还是团队协作，Helm 都是 Kubernetes 环境下不可或缺的利器。