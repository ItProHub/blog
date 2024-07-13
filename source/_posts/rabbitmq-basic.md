---
title: 深入理解 RabbitMQ 中的基础概念
date: 2024-07-09 16:28:36
tags:
---

RabbitMQ 是一个广泛使用的消息代理，它使得不同系统和服务之间可以进行可靠的消息传递。理解 RabbitMQ 的核心概念是高效使用它的关键。本文将深入探讨 RabbitMQ 的 Channel、Exchange、Queue、Vhost、Route 等概念，并通过实际开发示例展示如何在项目中应用这些概念。

# 标准 RabbitMQ 消息流
1. 生产者向交易所发布一条消息。
2. 交换机收到消息并且负责消息的路由。
3. 必须在队列和交换机之间建立绑定。在本例中，我们绑定了来自交换机的两个不同队列。交换机将消息路由到队列中。
4. 消息一直留在队列中，直到被消费者处理。
5. 消费者处理该消息。
![mq-flow](/images/rabbitmq-basic/exchanges-bidings-routing-keys.svg)

# 1. 核心概念
## 1.1 broker
简单来说 Broker 就是消息队列服务器实体。

我们把部署 RabbitMQ 的机器称为节点，也就是 Broker。Broker 有 2 种类型节点：

+ 磁盘节点：磁盘节点的 Broker 把元数据存储在磁盘中，磁盘节点的 Broker 在重启后元数据可以通过读取磁盘进行重建，保证了元数据不丢失
+ 内存节点：内存节点的 Broker 把元数据存储在内存中，内存节点的 Broker 可以获得更高的性能，但在重启后元数据就都丢了。
## 1.2 Channel
Channel 是 RabbitMQ 中的一个虚拟连接，是建立在实际的 TCP 连接之上的。通过 Channel，可以减少 TCP 连接的创建和销毁带来的开销，提升消息传输的效率。每个 Channel 可以有自己的设置和属性，与其他 Channel 相互独立。

Channel 信道是生产者/消费者与 RabbitMQ 通信的渠道，生产者 publish 或者消费者消费一个队列都是需要通过信道来通信的。也就是 RabbitMQ 在一个 TCP 上面建立成百上千的信道来达到多个线程处理。

在客户端的每个连接里，可建立多个 Channel，每个 Channel 代表一个会话任务

### 为什么使用 Channel 而不是直接使用 TCP 连接？
1. 性能：
   - 创建和销毁 TCP 连接是昂贵的操作，而创建和销毁 Channel 是相对轻量级的。
   - TCP 连接的建立涉及三次握手，而销毁涉及四次挥手，这些操作在高频率连接情况下会带来显著的开销。
   - Channel 的创建和销毁不需要这种复杂的握手过程，因此可以快速地进行资源管理。

2. 独立性：
   - 每个 Channel 都是独立的，可以有自己的设置和属性。比如，每个 Channel 可以绑定到不同的队列和交换机，有不同的 QoS（Quality of Service）设置等。
   - 这种独立性允许在一个 TCP 连接上同时进行多种不同的消息处理任务，而不相互干扰。

3. 资源复用：
   - 通过复用 TCP 连接，可以减少系统的资源消耗，特别是在高并发的场景下。
   - 使用 Channel 复用 TCP 连接还可以提高传输效率，减少网络带宽的占用。

下面我们通过一个简单的例子看一下。这里我们创建了两个队列，每个队列一个消费者。默认情况下，我们会看到2个Channel和2个Connection。然后我们稍微改一下代码，让两个消费者绑定在一个Connection上。
![一个channel对应一个connection](/images/rabbitmq-basic/channel1.png)
```CSharp
var factory = new ConnectionFactory() {
    HostName = "127.0.0.1"
};
string clientProvidedName = $"{EnvUtils.GetAppName()}({EnvUtils.GetHostName()})-Subscriber";

// 创建一个 TCP 连接
var connection = factory.CreateConnection(clientProvidedName);
string consumerTag = $"{EnvUtils.GetAppName()}({EnvUtils.GetHostName()})";

// 在同一个连接上创建第一个 Channel
var channel1 = connection.CreateModel();
var queueName1 = "TestMQ.Rabbit.WeChat";

var consumer1 = new EventingBasicConsumer(channel1);
consumer1.Received += (model, ea) => {
    var body = ea.Body.ToArray();
    var message = Encoding.UTF8.GetString(body);
};
channel1.BasicConsume(queue: queueName1, autoAck: true, consumerTag, consumer: consumer1);

// 在同一个连接上创建第二个 Channel
var channel2 = connection.CreateModel();
var queueName2 = "TestMQ.Rabbit.Email";

var consumer2 = new EventingBasicConsumer(channel2);
consumer2.Received += (model, ea) => {
    var body = ea.Body.ToArray();
    var message = Encoding.UTF8.GetString(body);
};
channel2.BasicConsume(queue: queueName2, autoAck: true, consumerTag, consumer: consumer2);
```
![一个channel对应一个connection](/images/rabbitmq-basic/channel2.png)

## 1.3 Exchange
Exchange 是 RabbitMQ 中接收消息并根据绑定规则将其路由到一个或多个 Queue 的组件。默认的 Exchange 类型有：

+ Direct Exchange：根据消息的路由键（routing key）精确匹配绑定键将消息发送到对应的 Queue。
+ Topic Exchange：根据消息的路由键模式（如 logs.*）匹配绑定键，将消息发送到对应的 Queue。
+ Fanout Exchange：将接收到的消息广播到所有绑定的 Queue，不考虑路由键。
+ Headers Exchange：根据消息头属性来路由消息，而不是路由键。
## 1.4 Queue
Queue 是 RabbitMQ 中存储消息的地方，消费者从 Queue 中接收消息。Queue 可以绑定到一个或多个 Exchange，并根据绑定规则接收消息。Queue 具有 FIFO（First In, First Out）特性，确保消息按顺序处理。

## 1.5 Vhost（Virtual Host）
vhost(虚拟主机)是一种逻辑隔离机制，用于将消息队列和相关资源隔离开来。虚拟主机允许您在单个RabbitMQ服务器上创建多个独立的消息队列环境，每个环境都有自己的队列、交换机、绑定和权限设置。


### 作用和好处
1. 资源隔离：
   - 独立的命名空间：每个 vhost 都有自己独立的命名空间，这意味着在一个 vhost 中创建的队列、交换机和绑定不会与其他 vhost 中的资源冲突。
   - 安全性和权限管理：通过 vhost，可以为不同的用户分配不同的权限，从而确保不同应用程序或服务之间的数据安全。例如，应用 A 和应用 B 可以使用相同的资源名称（如队列名）而不会产生冲突，因为它们在不同的 vhost 中。
2.多租户支持：
   - 隔离不同应用或服务：在多租户环境中，可以为每个租户（tenant）创建一个 vhost，从而将不同租户的消息和资源完全隔离开来。这对于 SaaS 应用程序尤为重要，可以确保不同客户之间的数据不互相干扰。
3. 环境隔离：
   - 开发、测试和生产环境：可以使用不同的 vhost 来隔离开发、测试和生产环境。这样可以确保在开发和测试过程中不会对生产环境中的消息和队列产生影响。
4. 简化管理：
   - 组织和管理资源：通过 vhost，可以更好地组织和管理 RabbitMQ 资源。在管理界面中，可以清晰地看到每个 vhost 中的资源使用情况，从而简化了运维和管理工作。


上面我们说到默认的4中Exchange类型。当我们手动创建vhost的时候就会发现，mq也自动帮我们给vhost创建了对应的4种类型总共7个Exchange
![默认交换机](/images/rabbitmq-basic/default-exchange.png)

## 1.6 Routing Key
Routing Key 是生产者发送消息时指定的路由信息，Exchange 根据 Routing Key 将消息路由到相应的 Queue。不同类型的 Exchange 使用 Routing Key 的方式不同。

### Exchange 类型与 RoutingKey、BindingKey 的关系
不同类型的交换机处理 RoutingKey 和 BindingKey 的方式不同：

1. Direct Exchange：
   - 交换机将消息路由到 RoutingKey 精确匹配的队列。
   - 例如，RoutingKey 为 "orange" 的消息只会路由到绑定了 BindingKey 为 "orange" 的队列。
    ![direct exchange](/images/rabbitmq-basic/direct-exchange.svg)
2. Topic Exchange：
   - 交换机根据 RoutingKey 和 BindingKey 的模式匹配规则路由消息。
   - RoutingKey 是由点分隔的字符串，BindingKey 可以包含特殊字符 *（匹配一个单词）和 #（匹配零个或多个单词）。
   - 例如，RoutingKey 为 "user.update.info" 的消息可以匹配 BindingKey 为 "user.*.info" 或 "user.#"。
![direct exchange](/images/rabbitmq-basic/topic-exchange.svg)
3. Fanout Exchange：
   - 交换机将消息广播到所有绑定的队列，忽略 RoutingKey。
   - 在这种情况下，BindingKey 不被使用。
![direct exchange](/images/rabbitmq-basic/fanout-exchange.svg)
下面我写了一个简单的fanout交换机的demo​，我们可以看到，往交换机发送一条消息，4个队列都收到了消息。
   ![fanout](/images/rabbitmq-basic/vro2s-b2mub.gif)
4. Headers Exchange：
   - 交换机根据消息头属性（Headers）而不是 RoutingKey 进行路由。
   - BindingKey 在这种交换机类型中不被使用。
![direct exchange](/images/rabbitmq-basic/rabbitmq-headers-exchange.svg)

由 Exchange、Queue、RoutingKey 三个才能决定一个从 Exchange 到 Queue的 唯一的线路。


# 3. 使用场景
虽然这篇文章将的是mq里面的概念，但是我们还是简单带过一下mq的使用场景吧

## 3.1 负载均衡
在微服务架构中，可以使用 RabbitMQ 进行负载均衡，将任务分发给多个消费者，提升系统的处理能力。

## 3.2 异步处理
将需要异步处理的任务放入 RabbitMQ 队列，可以使系统更具响应性，减少请求处理时间。

## 3.3 日志系统
使用 Fanout Exchange，将日志消息广播到多个日志处理服务，实现分布式日志收集和分析。

# 4. 结论
RabbitMQ 通过 Channel、Exchange、Queue、Vhost、Routing Key 等机制，实现了高效、可靠的消息传递。在实际开发中，合理使用这些概念和机制，可以显著提升系统的性能和可靠性。希望本文的介绍和示例代码能帮助你更好地理解和使用 RabbitMQ。


参考文档
[RabbitMq经典队列](https://www.rabbitmq.com/docs/classic-queues)


希望这篇文章能帮助你理解学习Docker。如果你有任何问题或建议，欢迎留言讨论！