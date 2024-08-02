---
title: daemonset
date: 2024-08-01 08:54:53
tags:
---

当谈论 Kubernetes 中的 DaemonSet（守护进程集）时，我们通常在分布式系统中需要确保某些特定的 Pod 在集群的每个Node上运行。DaemonSet 就是为了满足这种需求而设计的 Kubernetes 控制器。本文将探讨 DaemonSet 的定义、工作原理、常见用途以及如何在实际场景中使用 DaemonSet。

# 什么是 DaemonSet？
![daemonset](/images/daemonset/DaemonSets.png)

DaemonSet 是 Kubernetes 的一个控制器类型，用于确保集群中的每个节点上都运行一个 Pod 的副本。每个节点上只会有一个该类型的 Pod 实例，如果有新的节点加入集群，它会自动在新节点上创建一个新的 Pod 实例；如果节点从集群中移除，它会相应地删除该节点上的 Pod 实例。

DaemonSet 主要用于在每个节点上运行一些系统级别的服务或者需要全局唯一性的 Pod，如日志收集器（Fluentd、Filebeat）、监控代理（Prometheus Node Exporter）、网络代理（kube-proxy）等。

# DaemonSet 的工作原理

DaemonSets 自动执行此过程，确保每个节点在加入集群后无需任何人工干预即可纳入监控范围。

此外，DaemonSet管理每个节点上这些工具的生命周期。当从集群中删除节点时，DaemonSet 会确保相关监控工具也被彻底删除，从而使集群保持整洁高效。

DaemonSet 的工作原理非常简单直观：

+ Pod 创建与删除： 当 DaemonSet 被创建或更新时，Kubernetes 会为每个现有节点创建一个 Pod。新加入的节点也会自动创建对应的 Pod。当节点从集群中删除时，Kubernetes 会删除该节点上的 Pod 实例。

+ Pod 调度规则： DaemonSet 可以通过节点选择器（Node Selector）或者节点亲和性（Node Affinity）来控制 Pod 的调度。可以使用这些选项来限制 Pod 只在特定的节点上运行。

+ 更新策略： 当 DaemonSet 的 Pod 模板更新时，Kubernetes 会自动处理更新策略。可以选择逐个节点更新（默认）或者批量更新，确保在更新过程中集群的稳定性。

# 常见用途

DaemonSet 在 Kubernetes 中有许多实际应用场景，包括但不限于：

1. 日志收集与监控： 如 Fluentd、Filebeat、Prometheus Node Exporter 等，这些组件需要在每个节点上收集和发送数据。

> 由于k8s里面pod都是短暂的，所以我们把日志存储在容器内部是毫无意义的，容器重启后日志就丢失了。这就是为什么有必要从每个节点收集日志并将其发送到 Kubernetes 集群之外的某个中心位置进行持久化和后续分析。

2. 网络代理： 如 kube-proxy，负责管理节点上的网络规则和流量转发。

> 说到网络代理，部署过k8s的老铁们应该会注意到。我们用到的CNI插件通常就是用DaemonSet的方式部署的。
    ![daemonset-1](/images/daemonset/daemonset-1.png)

3. 存储和数据处理： 某些情况下需要在每个节点上运行特定的数据处理任务或者存储服务。

# 实战探索

随着我们团队将部署基础架构迁移到容器中，监控和日志记录方法发生了很大变化。将日志存储在容器或虚拟机中毫无意义——它们都是暂时性的。这就是 Kubernetes DaemonSet 等解决方案的用武之地。

前面说到Kubernetes 中的 DaemonSet 是一种特定类型的工作负载控制器，可确保 Pod 的副本在集群内的所有或某些指定节点上运行。它会自动将 Pod 添加到新节点，并从已移除的节点中移除 Pod。这使得 DaemonSet 非常适合在每个节点上监控、记录或运行网络代理等任务。 

### 背景和挑战

容器化和微服务架构中，对集群节点的实时监控是确保系统稳定性和性能优化的关键。典型的挑战包括：

+ 分布式环境： 集群中的节点数量和位置随时可能发生变化，需要实时监控每个节点的状态和资源使用情况。
+ 高可用性需求： 监控代理需要高可用地运行在每个节点上，即使部分节点故障也要保持数据的连续性。
+ 数据安全和隔离： 监控数据的收集和传输需要安全可靠，避免泄露和未经授权访问。

模拟环境总共3个node，一个master和两个工作节点。

![节点](/images/daemonset/nodes.png)

我们希望能够把我们的监控程序部署在每个工作节点中。

### 架构设计
我们将使用自研的客户端程序实现节点监控，通过 DaemonSet 在每个 Kubernetes 节点上部署 Node Exporter，将节点的指标数据推送到云端数据存储和查询系统。

1. 监控数据生成和收集

    自研监控工具： 开发和部署自研的监控工具，用于收集 Kubernetes 集群中的各项指标数据，如节点资源使用情况、Pod 健康状态、应用程序性能指标等。

    数据聚合和处理： 在每个节点上运行监控代理，负责实时收集和聚合监控数据。数据聚合过程中确保数据的时序性和准确性。

2. 数据传输和安全性保障

    安全传输协议： 使用安全的传输协议，如 HTTPS 或者其他加密传输协议，确保监控数据在传输过程中的机密性和完整性。

3. 云端存储和管理

    数据存储和管理： 将监控数据存储在云端的时序数据库中，使用数据库的特性进行数据分区、索引和备份，以支持高效的数据存储和检索。

4. 数据分析和可视化

    数据分析和报表： 基于存储在时序数据库中的监控数据，开发数据分析和报表功能，以便实时监控和历史数据分析，支持决策和优化操作。

    可视化和警报： 使用数据可视化工具创建仪表盘和报表，实时展示监控指标的趋势和变化，设置警报规则以便及时响应

### Kubernetes部署
1、DaemonSet 配置文件
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
        image: acr/txclientx:5.24.10729.10
        ports:
        - containerPort: 80  # 如果你的应用有服务端口，请替换为实际端口
        env:
        - name: KhGuid
          value: "xxx"
        - name: TxCloudSite_Url
          value: "https://domain.com"
        - name: HttpJsonWriter_Target_Url
          value: "http://domain.com/v20/api/loggate/save/{datatype}"
        - name: NebulaFides_Url
          value: "http://domain.com"
        resources:
          requests:
            cpu: "100m"
            memory: "200Mi"
          limits:
            cpu: "200m"
            memory: "400Mi"

```
2、部署到Kubernetes集群
```bash
kubectl apply -f agent-daemonset.yaml
```

3、部署结果
我们可以看到k8s已经自动为我们的两个工作节点部署了监控程序
![监控pod](/images/daemonset/daemonset-pods.png)


# 结语

通过本文，我们介绍了 Kubernetes 中 DaemonSet 的定义、工作原理、常见用途以及如何在实际场景中使用 DaemonSet。DaemonSet 是 Kubernetes 中非常实用且强大的一个控制器类型，适用于需要在每个节点上运行特定 Pod 的场景，如日志收集、监控、网络代理等。通过灵活使用 DaemonSet，可以有效地管理和部署分布式系统中的服务。