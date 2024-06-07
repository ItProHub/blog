---
title: C# 学习笔记： TaskCompletionSource
date: 2024-05-30 08:52:16
published: true
tags:
---

在异步编程中，C# 提供了许多强大的工具来简化异步任务的管理。其中，TaskCompletionSource 是一个非常有用的类，它允许开发者创建和控制任务的完成状态。在这篇博客中，我们将了解 TaskCompletionSource 的功能和使用方法，并结合实际代码示例来帮助更好地理解和应用它。

TaskCompletionSource<T>是 .NET 库中用于处理任务的极其有用的工具，尤其是在处理手动控制任务完成的时间和方式时。TaskCompletionSource <T>类表示未绑定到委托的Task<TResult>的生产者端，通过 Task 属性提供对消费者端的访问。


# 什么是TaskCompletionSource？
简单来说，TaskCompletionSource<T>是一种允许我们创建未绑定Task<T>的类型，这意味着它不与委托绑定。这让您可以手动控制任务完成的时间和方式。您可以手动设置任务的结果，或者发出信号表示任务由于取消或错误而完成。
```C#
using System;
using System.Threading.Tasks;

public class Program
{
    public static void Main(string[] args)
    {
        var tcs = new TaskCompletionSource<bool>();
        tcs.SetResult(true);
    }
}
```
在这个示例中，我们创建了一个 TaskCompletionSource<bool> 对象，并通过 SetResult 方法手动完成任务。

# TaskCompletionSource实现回调
在异步编程中，回调函数常用于在操作完成时执行某些逻辑。使用 TaskCompletionSource，我们可以将回调函数转换为任务，并等待其完成。
```C#
using System;
using System.Threading.Tasks;

public class CallbackExample
{
    public static void Main(string[] args)
    {
        Task task = DoSomethingAsync();

        task.ContinueWith(t =>
        {
            if (t.IsCompletedSuccessfully)
            {
                Console.WriteLine("操作完成!");
            }
        }).Wait();
    }

    public static Task DoSomethingAsync()
    {
        var tcs = new TaskCompletionSource<bool>();

        // 模拟异步操作和回调
        Task.Run(() =>
        {
            Task.Delay(2000).Wait(); // 模拟异步操作
            tcs.SetResult(true); // 操作完成，设置结果
        });

        return tcs.Task;
    }
}
```

# TaskCompletionSource实现暂停
TaskCompletionSource 还可以用于实现任务的暂停和恢复。通过手动控制任务的完成状态，我们可以在特定条件下暂停任务，并在条件满足时恢复任务。
我们使用 TaskCompletionSource 来实现任务的暂停和恢复。当用户按下任意键时，任务将从暂停状态恢复并继续执行。
```C#
using System;
using System.Threading.Tasks;

public class PauseExample
{
    private static TaskCompletionSource<bool> _pauseTcs;

    public static async Task Main(string[] args)
    {
        _pauseTcs = new TaskCompletionSource<bool>();

        Task longRunningTask = LongRunningOperationAsync();

        Console.WriteLine("按任意键继续...");
        Console.ReadKey();
        _pauseTcs.SetResult(true); // 恢复任务

        await longRunningTask;
        Console.WriteLine("任务完成!");
    }

    public static async Task LongRunningOperationAsync()
    {
        Console.WriteLine("任务开始...");

        await _pauseTcs.Task; // 等待任务恢复

        Console.WriteLine("任务恢复，继续执行...");
        // 模拟更多工作
        await Task.Delay(2000);

        Console.WriteLine("任务结束。");
    }
}
```
运行我们可以看到如下结果
![暂停1](/images/task-completion-source/pause-1.png)
按任意键，任务继续运行
![暂停2](/images/task-completion-source/pause-2.png)

# TaskCompletionSource的其他用途

除了上述用途，TaskCompletionSource 还可以用于以下场景：

1. 事件处理：将事件驱动的模型转换为任务模型，使异步编程更加简洁。
2. 并发操作：管理和协调多个异步操作的完成状态。
3. 任务组合：与其他任务组合方法（如 Task.WhenAll 和 Task.WhenAny）结合使用，实现复杂的异步逻辑。

# TaskCompletionSource的建议

使用 TaskCompletionSource 时，以下是一些建议：

1. 明确任务完成条件：确保在适当的时间点调用 SetResult、SetException 或 SetCanceled 方法来完成任务。
2. 避免死锁：如果在 UI 线程中使用 TaskCompletionSource，注意避免死锁情况。
3. 线程安全：如果在多个线程中使用 TaskCompletionSource，确保操作是线程安全的。

# 结论
TaskCompletionSource 是一个强大且灵活的工具，适用于各种异步编程场景。通过本文的介绍，希望你能更好地理解和应用 TaskCompletionSource，从而编写出更加高效和可维护的异步代码。

如果你有任何问题或建议，欢迎在评论区留言讨论。