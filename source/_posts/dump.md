---
title: Dump分析入门指南
date: 2024-04-28 14:18:14
tags: dump 性能 异常
---

想象一下，突然有一天部署在服务器上的应用突然挂了！没有一点点防备，也没有一丝顾虑，你就这样出现。。。
挂就挂了吧，服务还没有输出任务的错误信息。这个时候有没有什么途径可以让我找到崩溃的原因呢？

![crash](./images/dump/crash.jpeg)

在软件开发和运维过程中，Dump 文件是一种非常重要的工具，可以帮助我们定位和解决各种问题，包括应用程序崩溃、性能问题、内存泄漏等。本文将介绍 Dump 文件的基本概念、常见类型以及如何进行分析和利用，帮助读者更好地理解和利用 Dump 文件进行故障排查和性能优化。


# Dump 文件是什么？
Dump 文件是在应用程序发生崩溃或异常情况时生成的一种内存转储文件，记录了应用程序在崩溃时的内存状态、线程堆栈、变量值等信息。Dump 文件通常以 .dmp 或 .core 等扩展名保存，可以被用于后续的故障排查和分析。

## 常见的 Dump 文件类型
+ 完全内存转储（Full Memory Dump）： 完全内存转储记录了整个进程的内存状态，包括代码、数据、堆栈、寄存器等信息。这种类型的 Dump 文件通常用于分析应用程序崩溃的根本原因。
+ 迷你内存转储（Mini Dump）： 迷你内存转储只记录了应用程序崩溃时的关键信息，如线程堆栈、异常信息等，体积相对较小。这种类型的 Dump 文件通常用于快速定位问题，但可能丢失一些详细信息。
+ 核心转储（Core Dump）： 核心转储是在 Unix/Linux 系统下产生的一种内存转储文件，记录了应用程序崩溃时的内存状态。核心转储文件通常用于分析应用程序崩溃的原因和内存使用情况。

# Dump 文件分析的基本步骤
1. 收集 Dump 文件： 首先需要收集到应用程序崩溃时生成的 Dump 文件，可以通过操作系统、监控工具或者应用程序自身设置来获取。
2. 选择合适的工具： 根据 Dump 文件的类型和问题的性质，选择合适的工具进行分析。常用的工具包括 WinDbg、GDB、Visual Studio 等。
3. 分析dump文件
    + 查看线程堆栈： 分析线程堆栈信息，定位到异常发生时的代码位置，了解程序的执行流程和调用关系。
    + 检查内存使用情况： 分析内存使用情况，查找可能存在的内存泄漏或者过度使用内存的情况，优化内存管理和资源释放。
    + 分析异常信息： 查看异常信息，了解异常的类型、位置和原因，为故障排查提供重要线索。
    + 诊断性能问题： 分析性能指标和性能瓶颈，找出影响服务性能的原因，进行性能优化和调整。
4. 诊断和解决问题： 根据分析结果，诊断出问题的根本原因，并采取相应的措施进行修复或优化。

# Dump 文件分析的实战演练
上面说了那么多理论，下面我们来实际操作一下。

首先简单介绍一下作为示例的项目背景，
1. 程序性质：基于 .NET 的 Web 应用程序；
2. 运行环境：运行在docker 容器中；
3. 收集工具：createdump是随着 .NET Core runtime 一起发布的一个创建 dump 的一个工具；
3. 问题表现：内存泄漏；

## 收集dump文件
### 进入容器
```
docker exec -it wpp bash
```
### 进入.net运行时目录
```
root@4aa6a7d51e1e:/# 
root@4aa6a7d51e1e:/# find / -name createdump
/usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.0/createdump
root@4aa6a7d51e1e:/# cd /usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.0           
root@4aa6a7d51e1e:/usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.0# 

```
### 运行createdump抓包
```
createdump [options] pid
-f, --name - dump path and file name. The default is '/tmp/coredump.%p'. These specifiers are substituted with following values:
   %p  PID of dumped process.
   %e  The process executable filename.
   %h  Hostname return by gethostname().
   %t  Time of dump, expressed as seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC).
-n, --normal - create minidump.
-h, --withheap - create minidump with heap (default).
-t, --triage - create triage minidump.
-u, --full - create full core dump.
-d, --diag - enable diagnostic messages.
```
top一下查看进程id
```
 PID  PPID USER     STAT   VSZ %VSZ %CPU COMMAND
    1     0 root     S     261g7842%   0% dotnet SubscriptionAccount.dll
11480     0 root     S     4188   0%   0% bash
11845 11480 root     R     3268   0%   0% top

```
执行命令
```
./createdump -f /tmp/wpp_dump -u 1
```
> 如果提示没有权限，需要在docker运行时增加一个参数 --privileged=true ，以便容器以特权方式运行。

### 将dump文件拷贝出来
```
sudo docker cp wpp:/tmp/wpp_dump /tmp/wpp_dump
```
## WinDbg 分析dump文件
项目背景里面我们也讲到了，这次我们分析的是内存泄漏的问题。所以我们分析的第一步是找到哪些内存占用比较大的变量

首先，我们找到内存占用最大类型，这里我们内存占用较大的System.Byte[]
然后穿透找到类型对应的变量的内存占用情况
![内存占用](/images/dump/windbg_1.png)
![变量内存](/images/dump/windbg_2.png)
通过上面的命令，我们找到内存占用最高的几个变量，然后穿透到具体这个大变量里面装的是啥
![变量内容](/images/dump/windbg_3.png)
通过变量的内容，找到具体代码的位置了就不是什么难事了。
![bug位置](/images/dump/windbg_4.png)
我们可以看到上面的代码在拼接sql，最后生成了一个很大的字符串，导致内存占用很大。
对于大于 85,000 字节的对象，.NET 会将它们分配到一个称为“大对象堆（Large Object Heap，LOH）”的特殊堆中。大对象堆上的垃圾回收策略与普通堆上的策略略有不同，而且触发条件也可能不同。因此，大对象可能会存活更长的时间。


# 结语
通过本文的介绍，相信读者对 Dump 文件的基本概念和分析方法有了更深入的了解。Dump 文件是故障排查和性能优化的重要工具，掌握好 Dump 文件的分析技巧能够帮助我们更快地定位和解决各种问题，提高系统的稳定性和性能。