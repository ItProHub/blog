---
title: Redis成长记 - Redis的陷阱（一）
date: 2024-04-18 15:09:28
tags: redis 面试 求职
---
相信很多老铁在求职过程中都看到过类似下面这样的任职要求

<img src="/images/redis-interview/recruitment.png" width="50%">

你申请的岗位上面写着”熟悉Redis”，那么你已经准备好回答面试官可能会问到的问题了么？
后面我将开启一个针对Redis的系列分享，希望能帮助刚刚开始学习Redis的朋友们。

在开始阅读本篇文章之前，默认你已经具备基础的Redis知识，如果你没有，可以先阅读文末[相关文章推荐](#References)


当使用 Redis 作为缓存或数据存储时，虽然它提供了高性能和灵活性，但也存在一些陷阱需要注意。之前看博客的时候看到过这样一句话”Experts aren’t the only people who know what to do. They’re the people who know what not to do.“ 专家并不是唯一知道如何做的人，他们只是知道如何避免一些陷阱。

下面讲诉的是一些常见的 Redis 陷阱，或者说容易忽略的问题。内容较多，可能会分多篇文章，尽情期待。
同时由于要讲的内容实在是太多，所以本文更多的只是起到”抛砖“的作用，更多的详细的内容还需要老铁们自己再深层次的去学习。

# 缓存穿透
缓存穿透指的是恶意请求或者大量不存在的 key 导致缓存无法命中，从而绕过缓存直接访问数据库，导致数据库压力过大，甚至宕机的情况。

![缓存穿透](/images/redis-interview/cache-penetration.png)

## 缓存穿透的原因
缓存穿透通常发生在以下情况下：

1. 恶意请求：攻击者发送大量不存在于缓存中的 key，导致缓存无法命中，直接访问数据库。
2. 大量并发查询：当并发查询量很大时，可能会出现大量不存在于缓存中的 key，从而导致缓存穿透。

## 缓存穿透的影响
+ 数据库压力过大：大量无效请求直接访问数据库，导致数据库压力过大，甚至导致数据库宕机。
+ 系统性能下降：数据库压力增大，可能导致系统响应变慢，影响用户体验。

## 缓存穿透的解决方法
1. 空对象缓存：当查询结果为空时，也将该空结果缓存起来，但设置一个较短的过期时间，防止攻击者利用缓存穿透问题。
2. 布隆过滤器：在缓存层之前增加布隆过滤器，用于快速过滤掉不存在于缓存中的 key，从而避免缓存穿透。
3. 热点数据预热：将热点数据提前加载到缓存中，提高命中率，减少缓存穿透的发生。
4. 限流控制：对于频繁查询的接口，可以进行限流控制，防止攻击者发起大量无效请求。
5. 使用缓存锁：在查询数据库时，使用缓存锁进行串行化处理，防止大量并发查询导致缓存穿透。

下面是一个使用 C# 空对象缓存的示例代码：

```C#
public class UserBll
{
    public static readonly int CACHE_NULL_TTL = 10;
    public static readonly int CACHE_TTL = 20;
    /** 
     * 缓存穿透* 
     * @param id 
     * @ return 
     */
    public WebUserInfo QueryUser(string key)
    {
        var redis = Redis.GetDatabase(0);
        // 1.从redis中查询store缓存
        String value = redis.StringGet(key);
        WebUserInfo user = null;
        // 2.判断是否存在
        if( value.HasValue() ) {
            user = value.FromJson<WebUserInfo>();
            // 3.存在，直接返回
            return user;
        }
        // 判断命中是否为空值
        if ( value == null) {
            // 返回错误信息
            return null;
        }
        // 4.不存在，根据id查询数据库
        user = DatabaseQuery(key);
        // 5. 不存在，返回错误
        if( user == null ) {
            // 向redis写入空值（缓存穿透）
            redis.StringSet(key, "", new TimeSpan(0, CACHE_NULL_TTL, 0));
            return null;
        }
        // 6.存在，写入redis
        redis.StringSet(key, user.ToJson(), new TimeSpan(0, CACHE_TTL, 0));
        // 7. 返回
        return user;
}


    public WebUserInfo DatabaseQuery(string key)
    {
        // 模拟从数据库中查询数据
        // 实际情况下，这里可以是访问数据库、调用外部 API 等操作
        // 这里简化为返回 null
        return null;
    }


}

class Program
{
    static void Main(string[] args)
    {
        UserBll cache = new UserBll();

        // 第一次查询，缓存中不存在，但是查询结果为空
        string result1 = cache.QueryUser("key1");
        Console.WriteLine("Result 1: " + result1); // Output: Result 1: (null)

        // 第二次查询，缓存中已存在空对象缓存，直接返回空值
        string result2 = cache.QueryUser("key1");
        Console.WriteLine("Result 2: " + result2); // Output: Result 2: (null)

        // 第三次查询，模拟数据库中存在对应值的情况
        string result3 = cache.QueryUser("key2");
        Console.WriteLine("Result 3: " + result3); // Output: Result 3: <value from database>
    }
}


```
上述代码中，当用户请求一个key时，redis和数据库都不存在。我们直接将key对应的null值缓存到redis中，这样下次用户重复请求这个key的时候，redis就可以命中（hit null），只是不会询问数据库
- 优点：实现简单，易于维护
- 缺点：额外的内存消耗（可以通过添加TTL来解决）

同时可能会造成短暂的不一致（控制TTL时间可以在一定程度上缓解）。当null被缓存时，我们只是在数据库中设置值，而用户query为空，但数据库中实际存在，会造成不一致（可以通过插入数据时自动覆盖之前的空数据来解决）

# 缓存雪崩
缓存雪崩指的是在缓存失效的瞬间，大量的请求同时涌入数据库或其他数据源，导致数据库负载剧增，甚至造成数据库宕机的情况。

![Cache Avalanche](/images/redis-interview/cache-avalanche.png)

## 缓存雪崩的原因
缓存雪崩通常是由于缓存中的大量数据同时失效而引起的。当多个缓存键具有相同的失效时间，并且这些缓存键又在同一时间失效时，就会导致大量请求直接击穿缓存，同时涌入数据源，造成缓存雪崩

## 缓存雪崩的解决方案
### 1. 设置随机过期时间
通过给缓存键设置随机的过期时间，可以有效地分散缓存失效的时间点，降低大量缓存同时失效的可能性，从而减轻了缓存雪崩的风险。

### 2. 使用多级缓存策略
采用多级缓存架构，包括本地缓存、分布式缓存和持久化存储，当主缓存失效时，可以从备用缓存中获取数据，降低对数据库的直接访问。

### 3. 限流和降级
在缓存失效期间，可以对请求进行限流，降低请求的并发数量，从而减轻了数据库的压力。同时，可以对部分非关键请求进行降级处理，暂时屏蔽一些非必要的服务，保证核心服务的稳定性。

### 4. 预热缓存
在系统启动或低峰期，预先加载缓存数据，提前将常用数据缓存起来，避免在高峰期间大量请求直接击穿缓存。

# 缓存击穿
缓存击穿是指某个热点key突然失效或者未命中，导致大量请求直接访问数据库，造成数据库压力剧增的现象。这种情况通常发生在具有高并发访问量的系统中，特别是在缓存系统中使用了较短的过期时间或者热点数据的访问频率突然增加时。

![缓存击穿](/images/redis-interview/cache-breakdown.png)

1. 设置热点数据永不过期： 对于一些热点数据，可以设置永不过期，或者设置较长的过期时间，保证其不会在短时间内失效，从而避免了缓存击穿的发生。
2. 加锁机制： 在缓存失效时，可以通过加锁机制确保只有一个线程能够进入数据库查询数据，并将查询结果更新到缓存中，避免了多个线程同时查询数据库的情况。
3. 使用互斥锁和分布式锁： 使用互斥锁或者分布式锁来保证在查询数据库的过程中，只有一个线程能够执行查询操作，其他线程需要等待锁释放后再进行查询，避免了并发访问数据库的情况。
4. 使用缓存预热： 在系统启动或者低峰期，可以预先将热点数据加载到缓存中，提前减少了缓存失效时的并发请求量，从而避免了缓存击穿的发生。

下面是一个用C#实现的示例代码，演示了如何使用互斥锁来解决缓存击穿问题：
```C#
using System;
using System.Collections.Generic;
using System.Threading;

public class Cache
{
    private Dictionary<string, string> cache = new Dictionary<string, string>();
    private Mutex mutex = new Mutex();

    public string Get(string key)
    {
        // 先尝试从缓存中获取数据
        string value;
        if (cache.TryGetValue(key, out value))
        {
            return value;
        }

        // 如果缓存中不存在，加锁查询数据库
        mutex.WaitOne();
        try
        {
            // 再次检查缓存，防止多个线程同时查询数据库
            if (cache.TryGetValue(key, out value))
            {
                return value;
            }

            // 模拟从数据库中查询数据
            value = QueryFromDatabase(key);

            // 将查询结果更新到缓存中
            cache[key] = value;
        }
        finally
        {
            mutex.ReleaseMutex();
        }

        return value;
    }

    private string QueryFromDatabase(string key)
    {
        // 模拟从数据库中查询数据的过程
        Thread.Sleep(100); // 模拟耗时查询操作
        return "value for " + key;
    }
}

class Program
{
    static void Main(string[] args)
    {
        Cache cache = new Cache();

        // 并发查询
        List<Thread> threads = new List<Thread>();
        for (int i = 0; i < 10; i++)
        {
            Thread thread = new Thread(() =>
            {
                string value = cache.Get("key");
                Console.WriteLine(Thread.CurrentThread.Name + ": " + value);
            });
            thread.Name = "Thread " + i;
            threads.Add(thread);
        }

        foreach (Thread thread in threads)
        {
            thread.Start();
        }

        foreach (Thread thread in threads)
        {
            thread.Join();
        }
    }
}

```

# 相关文章推荐
<div id="References"></div>

+ [Redis官方文档](http://redis.io/documentation)
+ [Redis教程](https://www.runoob.com/redis/redis-tutorial.html)


今天就不总结了，未完待续😪...


更多一手讯息，可关注公众号：[ITProHub](https://myom-dev.oss-cn-hangzhou.aliyuncs.com/WechatPublicPlatformQrCode.jpg)

![ITProHub](https://myom-dev.oss-cn-hangzhou.aliyuncs.com/WechatPublicPlatformQrCode.jpg)