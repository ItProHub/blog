---
title: RabbitMQ之三种队列之间的区别及如何选型
date: 2024-07-11 10:36:12
tags:
---

RabbitMQ 是一个强大的消息队列系统，它提供了多种队列类型以满足不同的使用需求。本文将探讨三种主要队列类型：经典队列、仲裁队列和流式队列，并讨论它们的区别和选型建议。

# 经典队列（Classic Queues）
## 简介：
经典队列是 RabbitMQ 中最早期也是最常用的一种队列类型。它们具有良好的性能和稳定性，适合大多数常规的消息传递场景。

## 特点：

+ 存储机制：消息存储在磁盘或内存中，支持持久化。
+ 消息传递：一旦消息被消费者确认，消息会从队列中删除。
+ 性能：性能相对较高，但在高并发和大消息量场景下，可能会遇到瓶颈。
+ 高可用性：支持镜像队列，实现高可用性。镜像队列中的消息会复制到多个节点，以防单节点故障。
## 适用场景：

适合大多数常规消息传递场景，如任务调度、事件通知等。
当需要消息的持久化存储和高可靠性时，经典队列是一个很好的选择。

# 仲裁队列（Quorum Queues）
## 简介：
仲裁队列是一种基于 Raft 协议实现的新型队列，专为提高数据一致性和可靠性而设计。

## 特点：

- 存储机制：消息存储在多个节点上，采用 Raft 协议确保数据一致性。
- 高可用性：天然支持高可用性，通过多节点复制实现数据冗余。
- 数据一致性：仲裁队列确保每条消息在多个副本之间的一致性，避免单点故障导致的数据丢失。
- 性能：由于需要确保数据一致性，性能可能比经典队列略低，适合对数据一致性要求较高的场景。

## 适用场景：

- 适用于对数据一致性和高可用性要求较高的场景，如金融交易、订单处理等关键业务系统。
- 在需要确保消息不丢失且需要高可用性的情况下，仲裁队列是一个理想选择。

## 注意事项
1. 仲裁队列只能声明为持久的
仲裁队列只能被声明为持久的，否则会引发以下错误消息：
：server_initiated_close，406，“PRECONDITION_FAILED - 队列‘my-quorum-queue’的属性‘non-durable’无效

Quorum 队列具有一些特殊功能和限制。它们不能是非持久的，因为 Raft 日志始终写入磁盘，因此它们永远不能被声明为瞬态的。从 3.8.2 开始，它们也不支持消息 TTL 和消息优先级 2。

2. 仲裁队列的消息默认就是持久化的
对mq熟悉的老铁应该知道，队列的持久化和消息的持久化是分开的。一般情况下如果不对消息声明为持久化的，服务重启之后消息就会丢失。但是仲裁队列默认消息就是持久化的。

下面我手撸了一个简单的demo，同时给经典队列和仲裁队列各发送一条消息。
![重启前](/images/rabbitmq-quarum/quarum1.png)
然后我们重启服务，发现经典队列的消息已经丢失了，但是仲裁队列的消息还在队列中。
![重启后](/images/rabbitmq-quarum/quarum2.png)

## 仲裁队列 VS 经典队列

### 数据一致性
仲裁队列使用 Raft 共识算法来确保数据的一致性。即使在单节点情况下，仲裁队列也会严格遵循日志记录和确认机制，确保消息的顺序和一致性。而经典队列在单节点情况下可能会因节点故障导致数据丢失或不一致。

### 数据可靠性
仲裁队列会将每条消息记录到持久存储中，确保即使在系统崩溃后，消息也不会丢失。经典队列虽然也支持消息持久化，但其可靠性依赖于消息写入磁盘的速度和节点的稳定性。

# 流式队列（Stream Queues）
流式队列是一种新型队列，专为处理大规模数据流和高吞吐量场景设计。

## 特点：
+ 存储机制：消息以流的形式存储，可以实现消息的回放和重复消费。
+ 高吞吐量：设计上优化了高吞吐量和低延迟，适合处理大规模实时数据流。
+ 数据持久性：消息可以持久化存储，支持长时间的消息保留和回溯。
+ 订阅机制：支持多种订阅模式，允许多个消费者按需订阅消息流。

## 什么是消息回放和重复消费？
消息回放：允许消费者在任何时间点重新读取过去的消息。这对于需要重现历史事件或进行审计的应用程序特别有用。

重复消费：消费者可以多次消费同一条消息，这在调试和处理异常时尤为重要。

```CSharp
public void InitStreamMQ()
{
    var factory = new ConnectionFactory() { HostName = "localhost", UserName = "user", Password = "myrabbit" };

    var connection = factory.CreateConnection();
    var channel = connection.CreateModel();
    // 声明流式队列
    var args = new Dictionary<string, object> { { "x-queue-type", "stream" } };
    channel.QueueDeclare(queue: "stream_queue", durable: true, exclusive: false, autoDelete: false, arguments: args);
    channel.QueueBind(queue: "stream_queue", exchange: "amq.direct", routingKey: "stream_queue");
}


[ActionTitle(Name = "订阅队列")]
[Route("subscribe")]
public void SubscribeQuorumMessage()
{
    var factory = new ConnectionFactory() { HostName = "localhost", VirtualHost = "/", UserName = "user", Password = "myrabbit" };

    var connection = factory.CreateConnection();
    var channel = connection.CreateModel();

    channel.BasicQos(prefetchSize: 0, prefetchCount: 1, global: false);
    // 设置消费者，从指定的偏移量消费消息
    var consumer = new EventingBasicConsumer(channel);
    consumer.Received += (model, ea) => {
        var body = ea.Body.ToArray();
        var message = Encoding.UTF8.GetString(body);
        Console.WriteLine(" [x] Received {0}", message);
    };

    /**
     * x-stream-offset的可选值有以下几种：
        first: 从日志队列中第一个可消费的消息开始消费
        last: 消费消息日志中最后一个消息
        next: 相当于不指定offset，消费不到消息。
        Offset: 一个数字型的偏移量
        Timestamp:一个代表时间的Data类型变量，表示从这个时间点开始消费。例如 一个小时前 Date timestamp = new Date(System.currentTimeMillis() - 60 * 60 * 1_000)
     */
    var args = new Dictionary<string, object> { { "x-stream-offset", 2 } };
    channel.BasicConsume(queue: "stream_queue", autoAck: false, arguments: args, consumer: consumer);
}

```
这里我们往流式队列里面发送了10条消息但是每次消费的时候都从第3条消息(offset为2)开始消费.
![offset](/images/rabbitmq-quarum/stream-offset.png)

## 流式队列的工作原理
流式队列的工作方式类似于日志系统（如 Apache Kafka）。消息按照顺序追加到队列的末尾，并保存在磁盘上。每个消息都有一个唯一的偏移量（offset），消费者可以通过指定偏移量来读取特定的消息或重新消费消息。

## 适用场景：

+ 适用于实时数据分析、日志处理、实时监控等场景。
+ 在需要处理大规模数据流和高吞吐量的场景下，流式队列是一个合适的选择。

## PS
1. Auto-Ack 必须为 false
在流式队列中，为了确保消息的可靠性和能够实现消息回放，自动确认（autoAck）必须设置为 false。自动确认会导致消息一旦被消费即刻从队列中移除，失去消息的持久性和回放功能。
![aoto ack](/images/rabbitmq-quarum/stream-error2.png)

2. 必须设置prefetchCount
流式队列（Stream Queue）在 RabbitMQ 中主要设计用于高吞吐量和低延迟的消息传输。设置 prefetchCount（每次发送给消费者的消息数量）是为了优化流式队列的性能和资源使用
![prefetchCount](/images/rabbitmq-quarum/stream-error1.png)

3. durable必须设置为true
与Quorum队列类似， Stream队列的durable参数必须声明为true，exclusive参数必须声明为false。这其中，x-max-length-bytes 表示日志文件的最大字节数。x-stream-max-segment-size-bytes 每一个日志文件的最大大小。这两个是可选参数，通常为了防止stream日志无限制累计，都会配合stream队列一起声明。


# 选型建议
在选择 RabbitMQ 队列类型时，需要根据具体的业务需求和场景来决定。以下是一些选型建议：

1. 经典队列：
   - 适合大多数常规的消息传递需求。
   - 需要较高的性能和可靠性，但不需要特别高的数据一致性要求。
2. 仲裁队列：
   - 适用于对数据一致性和高可用性要求较高的场景。
   - 需要确保消息不丢失且能够在多节点间保持数据一致性。
3. 流式队列：
   - 适合处理大规模实时数据流和高吞吐量的场景。
   - 需要消息的回放和重复消费功能，适用于实时数据分析和日志处理等场景。

# 总结
通过了解经典队列、仲裁队列和流式队列的特点和应用场景，能够更好地选择适合自己业务需求的队列类型。在实际应用中，可以根据具体的业务需求和性能要求，灵活地选择和配置 RabbitMQ 队列，以实现最佳的消息传递效果。

参考文档
[Quorum Queues](https://www.rabbitmq.com/docs/quorum-queues)