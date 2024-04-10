---
title: Garnet，缓存的新选择！
date: 2024-04-07 15:24:24
tags: Garnet 缓存 微软
---

号外号外！
1. redis不再“开源”；
2. 微软开源了Garnet

#  什么是Garnet？
Garnet是微软推出的一款远程缓存存储系统，旨在为开发者提供高性能、可靠性和可伸缩性的缓存解决方案。它采用了现代化的架构和技术，具有高度可定制性和灵活性，适用于各种规模和类型的应用场景。

# 特性和优势
1. 高性能

   &nbsp; Garnet采用了高效的缓存算法和数据结构，以实现快速的数据访问和响应。它支持并发访问和高吞吐量，能够处理大规模的请求流量。
  Garnet通过智能缓存策略，将热点数据（经常访问的数据）存储在用户附近的节点上，从而减少了数据传输的时间和距离，实现了低延迟访问。

2. 可靠性

   &nbsp; Garnet具有强大的数据保护和容错机制，能够确保数据的持久性和一致性。它支持数据备份、复制和故障转移，有效地降低了数据丢失和系统故障的风险。

3. 可扩展性

   &nbsp; Garnet的架构设计具有良好的水平扩展性，可以轻松地扩展到数百甚至数千台服务器。它支持动态添加和移除节点，能够根据需求灵活调整集群规模。

4. 多种数据类型支持：

   &nbsp; 除了常规的键值对存储之外，Garnet还支持多种数据类型，包括列表、集合、哈希表等，满足了不同应用场景的需求。

5. 丰富的功能

   &nbsp; Garnet提供了丰富的功能和工具，包括监控、调优、故障排除等，帮助开发者更好地管理和运维缓存系统。

# 高性能
对于一个中间件来说，大家最关心的应该就是性能到底怎么样？基准测试的结果，总体还是表现不错的。

具体性能测试详情可以查看链接： [Evaluating Garnet's Performance Benefits](https://microsoft.github.io/garnet/docs/benchmarking/results-resp-bench)

实际应用的过程中效果到底咋样当然还需要我们在通过代码来验证一下。

下面我写了一个简单的例子，直接循环往garnet和redis里面写入和读取数据。通过计算时间来对比一下两者的差距到底有多大
```C#
[HttpGet]
[ActionTitle(Name = "测试Garnet")]
[Route("test.svc")]
public void Start()
{
    // Redis connection
    var redis = ConnectionMultiplexer.Connect("localhost");
    var redisDb = redis.GetDatabase();

    // Garnet connection
    var garnet = new GarnetClient("localhost", 3278);

    // Test data
    string key = "test_key";
    string value = "test_value";

    // Test with Redis
   var redisStartTime = DateTime.Now;
   for( int i = 0; i < 1000; i++ ) {
       redisDb.StringSet(key + i, value + i);
   }
   var redisEndTime = DateTime.Now;
   Console.WriteLine($"StringSet Time taken by Redis: {(redisEndTime - redisStartTime).TotalMilliseconds} ms");
   
   // Test with Garnet
   var garnetStartTime = DateTime.Now;
   for( int i = 0; i < 1000; i++ ) {
       garnet.StringSet(key + i, value + i, null);
   }
   var garnetEndTime = DateTime.Now;
   Console.WriteLine($"StringSet Time taken by Garnet: {(garnetEndTime - garnetStartTime).TotalMilliseconds} ms");
   
   // Test with Redis
   redisStartTime = DateTime.Now;
   for( int i = 0; i < 1000; i++ ) {
       string a = redisDb.StringGet(key + i).ToString();
   }
   redisEndTime = DateTime.Now;
   Console.WriteLine($"StringGet Time taken by Redis: {(redisEndTime - redisStartTime).TotalMilliseconds} ms");
   
   // Test with Garnet
   garnetStartTime = DateTime.Now;
   for( int i = 0; i < 1000; i++ ) {
       garnet.StringGet(key + i, null);
   }
   garnetEndTime = DateTime.Now;
   Console.WriteLine($"StringGet Time taken by Garnet: {(garnetEndTime - garnetStartTime).TotalMilliseconds} ms");
}
```
最后运行的结果还是挺振奋人心的!

![运行结果1](/images/garnet/compare1.png)

# 兼容性
当然在进行中间件选择的时候，切换的成本也是重点要纳入考虑的。“白嫖一时爽，重构火葬场！”这种事情显然是我们不愿意看到的。

这个时候我们在官网看到这样一句话
> Garnet 并不是要成为 Redis 100% 完美的替代品，而是应该将其视为一个足够接近的起点，以确保对您重要的功能的兼容性。 Garnet 确实可以在未经修改的情况下与许多 Redis 客户端一起使用（我们特别对 Garnet 进行了StackExchange.Redis很好的测试），因此入门非常容易。

于是，我们再整个demo
```C#
[HttpGet]
[ActionTitle(Name = "测试Garnet连接")]
[Route("connect.svc")]
public void Connect()
{
    // Redis connection
    var redis = ConnectionMultiplexer.Connect("localhost");
    var redisDb = redis.GetDatabase();

    // Garnet connection
    var garnet = ConnectionMultiplexer.Connect("localhost:3278");
    var garnetDb = garnet.GetDatabase();

    // Test data
    string key = "test_key";

    // Test with Redis
    string a = redisDb.StringGet(key + 1).ToString();
    Console.WriteLine($"StringGet by Redis : {a}");

    // Test with Garnet
    string b = garnetDb.StringGet(key + 1).ToString();
    Console.WriteLine($"StringGet by Garnet : {b}");
}
```
微软 诚不我欺！

在不动客户端代码的情况下，我们能够非常平滑的切换到Garnet
![connect](/images/garnet/connect.png)

redis桌面客户端也能直接连接Garnet
![client](/images/garnet/client.png)


# 日志和诊断
Garnet 提供了丰富的日志和诊断特性，以帮助开发人员监视和调试其应用程序的性能和行为。以下是 Garnet 日志和诊断特性的主要内容：

1. 详细日志记录：Garnet 具有灵活的日志记录功能，可以记录各种级别的日志消息，包括信息、警告和错误。这些日志消息可以帮助开发人员了解系统的运行情况，识别潜在的问题并进行故障排除。

2. 性能指标：Garnet 还提供了丰富的性能指标，可以帮助开发人员监视系统的性能状况。这些指标可以包括各种关键性能指标，如请求响应时间、吞吐量、延迟等。

3. 异常跟踪：Garnet 具有异常跟踪功能，可以捕获和记录应用程序中的异常情况。这些异常跟踪信息可以帮助开发人员快速定位和修复问题。

4. 诊断工具：Garnet 还提供了一系列诊断工具，用于分析和调试系统的行为。这些工具可以帮助开发人员深入了解系统的内部工作原理，并识别潜在的性能瓶颈和问题。

```C#
static void Main(string[] args)
{
    try
    {

        var loggerFactory = LoggerFactory.Create(x =>
        {
            x.ClearProviders();
            x.SetMinimumLevel(LogLevel.Trace);
            x.AddZLoggerConsole(options =>
            {
                options.UsePlainTextFormatter(formatter =>
                {
                    formatter.SetPrefixFormatter($"[{0}]", (in MessageTemplate template, in LogInfo info) => template.Format(info.Category));
                });
            });
        });


        using var server = new GarnetServer(args, loggerFactory);

        // Optional: register custom extensions
        RegisterExtensions(server);

        // Start the server
        server.Start();

        Thread.Sleep(Timeout.Infinite);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Unable to initialize server due to exception: {ex.Message}");
    }
}
```
![日志](/images/garnet/log.png)



# 自定义命令
想要在 Redis 上执行一些复杂的执行是很常见的，在 Redis 的情况下，我们过去常常使用 Lua 脚本来处理它，但使用 Garnet，我们可以在 C# 中实现和合并自定义命令。 如果你不知道 LUA 是否在性能方面，或者如果你想做一些 LUA 做不到的相当复杂的事情，你可以使用它而不会有任何性能劣势。 更好的是，服务器端提供的扩展命令遵循 RESP，因此客户端可以从 PHP 或 Go 调用它们，而不仅仅是针对 C#。

因此，让我们立即创建一个名为“TEST”的自定义命令。命令很简单，直接返回一个“Hello Garnet!”

注册自定义命令本身非常简单，只需添加一个实现的类，或者与命令名称一起添加即可。

```Garnet Server
// 测试自定义命令
server.Register.NewTransactionProc("TEST", 0, () => new TestCustomCommand());


sealed class TestCustomCommand : CustomTransactionProcedure
{
    /// <summary>
    /// No transactional phase, skip Prepare
    /// </summary>
    public override bool Prepare<TGarnetReadApi>(TGarnetReadApi api, ArgSlice input)
        => false;

    /// <summary>
    /// Main will not be called because Prepare returns false
    /// </summary>
    public override void Main<TGarnetApi>(TGarnetApi api, ArgSlice input, ref MemoryResult<byte> output)
        => throw new InvalidOperationException();

    /// <summary>
    /// Finalize reads two keys (non-transactionally) and return their values as an array of bulk strings
    /// </summary>
    public override void Finalize<TGarnetApi>(TGarnetApi api, ArgSlice input, ref MemoryResult<byte> output)
    {
        // Return the two keys as an array of bulk strings
        WriteSimpleString(ref output, "Hello Garnet!");
    }
}

```

同时还是因为Garnet遵循 RESP，因此客户端不是专用于 C#，也不是 Garnet 客户端独有的。 所以我们可以直接在redis客户端调用Garnet的自定义命令
```Garnet client
 [HttpGet]
 [ActionTitle(Name = "测试Garnet 自定义命令")]
 [Route("custom-command.svc")]
 public async void Test()
 {       
     // Garnet connection
     var garnet = new GarnetClient("localhost", 3278);
     garnet.Connect();
     // Test data
     string result = await garnet.ExecuteForStringResultAsync("TEST");

     Console.WriteLine($"Garnet Custom Command Result: {result}");

     // 采用redis客户端连接
     var client = ConnectionMultiplexer.Connect("localhost:3278");
     var db = client.GetDatabase();

     RedisResult redisResult = db.Execute("TEST");

     Console.WriteLine($"Redis Client Custom Command Result: {((string?)redisResult)}");
 }
```

![custom command result](/images/garnet/custom-command.png)

# 结语
Garnet作为微软最新推出的远程缓存存储系统，为开发者提供了一种全新的选择。它具有高性能、可靠性和可伸缩性的特性，适用于各种规模和类型的应用场景。通过使用Garnet，开发者可以更好地提升应用的性能和用户体验，实现业务的快速发展和持续创新。

# 参考文档
+ [Garnet 开发入门](https://microsoft.github.io/garnet/docs)