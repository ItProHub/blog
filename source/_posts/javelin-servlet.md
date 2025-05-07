---
title: 构建自己的微型 Spring 框架（三）：接入内嵌 Tomcat 与 Servlet
date: 2025-05-06 15:07:53
tags:
---

在前两篇中，我们已经实现了一个具备依赖注入、路由注册、参数绑定、中间件、JSON 返回、异常处理的微型 Web 框架 —— Javelin，它基于 JDK 自带的 `HttpServer` 实现了最小运行闭环。

曾几何时，我一度以为HttpServer就是我的最终目标，直到我被告知它存在一定的局限性，不适合生产使用。显然我们的目标不仅仅是一个简单的最小闭环，而是一个完整的、可扩展的、强壮的 Web 框架。本篇将带你将 Javelin **接入内嵌 Tomcat，并运行在标准 Servlet 容器之上**，向真正的工程化迈进一步。

---

# 为什么 HttpServer 不适合生产环境？
| 项目          | 说明                                                                   |
| ----------- | -------------------------------------------------------------------- |
| ❌ 性能较低      | 它使用阻塞 IO（虽然支持线程池），但并不擅长高并发处理。                                        |
| ❌ 功能简陋      | 不支持 HTTPS 配置灵活性、不支持 HTTP/2、缺少对请求体/响应流的高级控制。                          |
| ❌ 安全性弱      | 缺少成熟的安全机制（如防 XSS/CORS/session 注入等），也没有专门的安全更新机制。                     |
| ❌ 缺乏标准支持    | 不支持 Servlet、Filter、Multipart 等常用 Web 标准，无法使用 Spring MVC、Shiro 等主流组件。 |
| ❌ 没有压缩/缓存机制 | 不支持 GZIP 压缩、缓存控制等特性，效率低下。                                            |
| ❌ 维护成本高     | 基础功能要自己手写，中间件、安全、监控都要自己造轮子。                                          |

# 什么是 Servlet 容器/Web 容器？
Web 容器（也称为 Servlet 容器）是驻留在 Web 服务器内部与 Java Servlet 交互的组件。Web 容器负责管理 Servlet 的生命周期、将 URL 映射到特定的 Servlet、从 Servlet 获取响应以及将响应发送给请求者。

Web 容器创建 servlet 实例、加载和卸载 servlet、创建和管理请求和响应对象，以及执行其他 servlet 管理任务。

Servlet 容器由三个组件组成：过滤器 (Filter)、Servlet 和监听器 (Listener)。当请求到达 Tomcat（即 Servlet 容器）时，它会被发送到 Servlet 过滤器 (Filter)。Servlet 处理请求并生成响应。
![Servlet 容器与 Web 服务器的关系](./images/javelin-servlet/servlet-container.png)

从上图可以看出，Servlet 容器位于 Web 服务器内部。静态内容由 Web 服务器提供，而任何动态请求则由 Servlet 容器组件处理，该组件负责启动 Servlet 并管理其生命周期。

# 为什么使用内嵌 Tomcat

JDK 的 `HttpServer` 非常轻量，但它的问题是：

* 不支持 Servlet 规范，无法与主流框架生态兼容
* 缺少压缩、过滤器、Session 等高级特性
* 不适合高并发或复杂业务场景

而 Tomcat 作为最主流的 Servlet 容器，性能成熟、生态完善。通过嵌入式启动方式，我们既可以保留 Javelin 的轻量特性，又可以获得生产级的服务能力。

---

# Servlet 架构说明与类图
![Servlet 架构说明](./images/javelin-servlet/servlet.png)


为了实现标准 Servlet 支持，Javelin 框架在原有基础上新增了如下组件：

- JavelinEmbeddedTomcatServer：内嵌 Tomcat 启动器，负责创建 Servlet 容器、注册 DispatcherServlet。

- JavelinDispatcherServlet：自定义 HttpServlet，用作框架的统一入口，初始化 Router 并转发请求。

- Router：负责路由匹配与控制器分发，调用中间件与控制器方法。

- ActionExecutor：处理参数绑定、生命周期方法、中间件链执行。

- NHttpContext：请求上下文，在不同协议（如 HttpServer、Servlet）中作为桥梁。

![Servlet 架构说明与类图](./images/javelin-servlet/architecture.png)

---

# 启动内嵌 Tomcat

在 `javelin-core` 中添加如下 Gradle 依赖：

```groovy
dependencies {
    implementation 'org.apache.tomcat.embed:tomcat-embed-core:10.1.20'
    implementation 'jakarta.servlet:jakarta.servlet-api:6.0.0'
}
```

> 注意：Tomcat 10 之后已经迁移到 `jakarta.servlet` 命名空间。

我们在 `javelin-core.http.tomcat` 包下新增了一个启动器类：

```java
public class JavelinEmbeddedTomcatServer {
    public JavelinEmbeddedTomcatServer(int port, String basePackage) { ... }

    public void start() throws Exception {
        tomcat.setPort(port);
        tomcat.setBaseDir(...);
        Context context = tomcat.addContext("", new File(".").getAbsolutePath());

        // 注册 DispatcherServlet
        JavelinDispatcherServlet servlet = new JavelinDispatcherServlet(basePackage);
        Tomcat.addServlet(context, "Javelin", servlet);
        context.addServletMappingDecoded("/*", "Javelin");

        tomcat.getConnector(); // 强制初始化协议监听器
        tomcat.start();
        tomcat.getServer().await();
    }
}
```

通过该类，我们可以像 Spring Boot 一样，直接启动一个内嵌的 Web 服务。

---

# 自定义 HttpServlet

## Servlet 生命周期
Servlet 的生命周期包括以下几个阶段：
![Servlet 生命周期](./images/javelin-servlet/servlet-lifecycle.png)

1. 加载和实例化：当容器接收到 Servlet 的请求时，ClassLoader 会加载该 Servlet 类。
    - 加载：加载 Servlet 类。
    - 实例化：创建 Servlet 的一个实例。为了创建 Servlet 的新实例，容器使用无参数构造函数。
2. 初始化 Servlet：Servlet 成功实例化后，Servlet 容器将初始化 Servlet 对象。容器将调用 Servlet 的 init() 方法。

3. 处理请求：初始化后，Servlet 实例将处理客户端请求。容器将为 Servlet 创建HttpServletResponse和HttpServletRequest对象，以处理 HTTP 请求。然后，容器将调用 Servlet 的 Service() 方法来处理请求。

4. 销毁 Servlet：Servlet 处理完请求并提供响应后，容器将通过调用 Servlet 的 destroy() 方法将其销毁。此时，Servlet 将清理所有不再需要的内存、线程等。

## DispatcherServlet 类
为了与现有框架的路由机制对接，我们实现了一个简化的 `HttpServlet`：

```java
public class JavelinDispatcherServlet extends HttpServlet {

    private final Router router;

    public JavelinDispatcherServlet() { 
        this.router = new Router(); // 初始化router变量
    }

    @Override
    public void init() throws ServletException {
        router.registerRoutes();
    }

    @Override
    protected void service(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        try {
            ServletHttpContext context = new ServletHttpContext(req, resp); // 创建ServeletHttpContext实例
            router.handle(context); // 调用router的handle方法，传入ServeletHttpContext实例
        } catch (Exception e) { 
            // 捕获异常
            resp.setStatus(500);
            resp.getWriter().write("Internal Server Error");
        }
    }
    
}
```

此 Servlet 会在初始化时扫描注解控制器，并注册到 Javelin 的路由表中。

后续我们将引入 `ServletHttpContext` 封装 HttpServletRequest，以继续复用中间件链、参数绑定、异常处理等机制。

---

# 运行效果

启动入口如下：

```java
public class JavelinStarter {

    public void run(Class<?> appClass, String[] args, AppStartupOption option) throws Exception
    {
        BASE_PACKAGE = appClass.getPackage().getName(); // 自动获取包名
        
        JavelinEmbeddedTomcatServer server = new JavelinEmbeddedTomcatServer(BASE_PACKAGE); 

        System.out.println(" Javelin initialized!");

        server.start();
    }
}
```

控制台输出：

```
5月 06, 2025 2:52:31 下午 org.apache.coyote.AbstractProtocol init
信息: Initializing ProtocolHandler ["http-nio-8080"]
5月 06, 2025 2:52:31 下午 org.apache.catalina.core.StandardService startInternal
信息: Starting service [Tomcat]
5月 06, 2025 2:52:31 下午 org.apache.catalina.core.StandardEngine startInternal
信息: Starting Servlet engine: [Apache Tomcat/10.1.20]
5月 06, 2025 2:52:31 下午 org.apache.coyote.AbstractProtocol start
信息: Starting ProtocolHandler ["http-nio-8080"]
```

浏览器访问 `http://localhost:8080/`，可看到返回：

![浏览器访问效果](./images/javelin-servlet/result.png)

---

# 下一步计划

目前我们已完成：

* ✅ 替换 HttpServer 为 Servlet 容器
* ✅ 手动注册 DispatcherServlet
* ✅ 支持包名动态传入，实现灵活控制器扫描

下一篇我们将实现：

* 🔄 封装 `ServletHttpContext`
* 🔁 抽象 `IHttpContext` 接口，兼容多种后端
* 🌐 支持静态资源、session、filter 等 Servlet 功能

欢迎关注继续升级版的 Javelin 框架设计！
