---
title: 手写一个微型 Spring 框架：从端口监听到依赖注入
date: 2025-04-14 10:17:55
tags:
---
书接上回，作为一个从.NET转Java的开发人员，Spring框架肯定是无法绕过的。在学习 Spring 框架的过程中，我们往往只是停留在“使用”层面，而对其底层实现机制知之甚少。但我始终觉得，学习框架的过程中，理解其设计思想和实现原理是非常重要的。因此，我决定手写一个微型的Spring框架，来深入理解Spring的核心设计思想。为了加深我对 Spring 的理解，并锻炼 Java 框架设计能力，我决定手写一个微型的 Spring 框架 —— Javelin。

这篇文章我们将实现：

- 一个简单的 IoC 容器 `JavelinContext`，用于管理 Bean 实例的生命周期。
- 支持 `@RestController`、`@GetMapping`、`@PostMapping` 等注解的自动扫描与注册。
- 基于 `HttpServer` 的端口监听与请求路由分发。

> 本文适合有 Java 或 .NET 框架开发经验的读者，特别是希望深入理解 Spring、探索其核心设计思想的人群。

---

## 为什么要手写一个 Spring 框架？

首先Spring 是 Java 生态中最具代表性的框架之一，而作为一个搬砖多年的开发人员，CURD显然不再是我们的追求。但，学习框架的设计思想和实现原理还是非常有价值的。Sping框架核心理念在于控制反转（IoC）、面向切面编程（AOP）和基于注解的声明式编程。手写框架可以帮助我们：

1. **理解 IoC 容器原理**：Bean 是如何被发现、实例化、依赖注入的？
2. **掌握路由注册机制**：Spring MVC 如何基于注解将请求分发给具体的方法？
3. **探索类扫描与反射机制**：如何实现自动发现注解的类与方法？
4. **对比 .NET**：Spring 与 ASP.NET Core 的设计思路在某些地方是相通的，比如 `@RestController` 和 `[ApiController]`，但实现方式有差异。

通过实战构建 Javelin，我们能够站在框架设计者的角度重新思考“约定优于配置”的设计哲学。

---

## 项目结构
我们手写的框架名叫 `Javelin`，目前已经实现了三个核心模块：

| 模块 | 功能 |
|------|------|
| `JavelinContext` | 提供简化版 IoC 容器，实现基于注解的构造函数注入 |
| `Router` | 自动扫描 `@RestController`，绑定 GET/POST 请求路径 |
| `AppStartup` | 应用启动入口，配置端口监听、类扫描路径等 |


![结构](./images/spring-1/architecture.png)

项目结构如下：
```
javelin-core/
├── annotations/        // 自定义注解（@RestController, @Inject 等）
├── context/            // IoC 容器
├── rest/               // 路由注册
├── core/               // 类扫描器
└── startup/            // 启动类
```


## 构建核心 IoC 容器 `JavelinContext`

我们首先需要一个容器类来负责扫描、实例化 Bean，并支持构造函数注入。代码结构如下：

```java
public class JavelinContext {

    private final Map<Class<?>, Object> singletonMap = new HashMap<>();

    public <T> T getBean(Class<T> clazz) {
        if (singletonMap.containsKey(clazz)) {
            return (T) singletonMap.get(clazz);
        }

        T instance = (T) createBean(clazz);
        singletonMap.put(clazz, instance);
        return instance;
        
    }

    public <T> T createBean(Class<T> clazz) {
        try {
            Constructor<?>[] constructors = clazz.getDeclaredConstructors();
            
            injectConstructor = clazz.getDeclaredConstructor();
            // ...

            return (T) injectConstructor.newInstance(args.toArray());
        }  catch (Exception e) {
            throw new RuntimeException("Failed to instantiate: " + clazz.getName(), e); 
        }
    }
}

```

这段代码的核心思路与 .NET Core 的构造函数注入类似（例如通过 `IServiceCollection.AddTransient()` 注册服务并注入）。


---

## 自动路由注册 Router

我们手动实现了基于注解的请求路由注册机制。Javelin 支持如下注解：

控制器注解
```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface RestController {}
```

请求映射注解
```java
@Target(ElementType.ANNOTATION_TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface HttpMethodMapping {
    String method();
}

@HttpMethodMapping(method = "POST")
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface PostMapping {
    String value();
}

// ...
```

而 `Router` 类的核心逻辑如下：

```java
public class Router {
    public void registerRoutes(HttpServer server, Set<Class<?>> classes, JavelinContext context) {
        for (Class<?> clazz : classes) {
            if (!clazz.isAnnotationPresent(RestController.class)) continue;

            Object controller = context.getBean(clazz);

            for (Method method : clazz.getDeclaredMethods()) {
                HttpMethodMapping mapping = annotation.annotationType().getAnnotation(HttpMethodMapping.class);
                if (mapping != null) {
                       String httpMethod = mapping.method();                       
                       try{
                           String path = (String) annotation.annotationType().getMethod("value").invoke(annotation);
                           registerHandler(server, path, httpMethod, controllerInstance, method);
                       } catch (Exception e) {
                           e.printStackTrace(); 
                       }

                    }
            }
        }
    }

    private void registerHandler(HttpServer server, String path, String expectedMethod, Object controllerInstance, Method method) {
        server.createContext(path, exchange -> {
            // 判断请求的合法性

            try {
                // 反射调用方法
            } catch (Exception e) {
                exchange.sendResponseHeaders(500, 0);
                e.printStackTrace();
            }
        });

        System.out.println("➡️  [" + httpMethod + "] " + path + " → " + controller.getClass().getSimpleName() + "." + method.getName());
    }
}
```


.NET 中这部分功能相当于 ASP.NET Core 中的 `MapControllers()` + `[HttpGet("/api/foo")]` 等特性。

---

## 3. 启动类 AppStartup

```java
public class AppStartup {
    public static void run(Class<?> appClass, String[] args)
    {
        String basePackage = appClass.getPackage().getName(); // 自动获取包名
        Set<Class<?>> controllers = ClassScanner.scan(basePackage);

        int port = resolvePort(); // ✅ 获取端口号
        HttpServer server;
        try {
            server = HttpServer.create(new InetSocketAddress(port), 0); // 默认端口8080     
        } catch (IOException e) {
            throw new RuntimeException("Failed to start HTTP server", e);
        }           

        JavelinContext context = new JavelinContext();
        new Router().registerRoutes(server, controllers, context);

        server.start();
        System.out.println("🚀 Server started at http://localhost:" + port);
    }
}
```

## Service 注入
```java

@RestController
public class HelloController {
    private UserService userService;

    @Inject
    public HelloController(UserService userService) {
        this.userService = userService; // ✅ 注入UserService实例 
    }

    @GetMapping("/hello")
    public String hello() {
        return "Hello World from " + userService.getUserById(1) ;
    }
}
```
接下面让我们看看我们的Hello World
![运行效果](./images/spring-1/result.png)


## 💡和 .NET 框架的对比分析
在开发 Javelin 的过程中，我时常联想到 .NET 的实现，尤其是 ASP.NET Core，它与 Spring 在设计理念上高度一致，但细节又有一些差异，下面进行系统性对比：

### 控制器与路由
|特性 |	Javelin (Java) |	ASP.NET Core (.NET) |
|------|------|------|
| 控制器注解/特性 |	@RestController | [ApiController] |
|路由声明方式 |	@GetMapping("/path") |	[HttpGet("path")] |
|路由注册机制 |	手动反射扫描注册 |	中间件动态注册至 EndpointRouting |
|请求处理 |	HttpExchangeHandler |	ControllerInvoker 中间件链 |

### 依赖注入与服务容器
|特性 |	Javelin (Java) |	ASP.NET Core (.NET) |
|------|------|------|
|服务注册方式 |	自动递归构造，无需注册 |	显式调用 services.AddXyz() |
|注入方式 |	构造函数 + @Inject |	构造函数 + 内建 IoC 容器 |
|生命周期管理 |	默认单例 |	支持 Transient / Scoped / Singleton |
|循环依赖检测 |	暂不支持 |	默认会在启动时检测并抛出异常 |

### 底层运行机制
|特性 |	Javelin |	ASP.NET Core |
|------|------|------|
|HTTP 服务器 |	com.sun.net.httpserver.HttpServer |	Kestrel 内置服务器 |
|请求派发模型 |	映射到类方法，反射调用 |	中间件链 + 路由匹配 + ControllerInvoker |

可以看出，Javelin 更加简洁直观，适合做教学或理解框架底层流程，而 ASP.NET Core 更加强大和工程化，适用于复杂企业级应用。


## 总结与下步计划

通过上面的内容，我们已经实现了 Spring 框架的三个关键能力：

- 简易 IoC 容器支持构造函数注入
- 使用 `@RestController`/`@GetMapping`/`@PostMapping` 注解注册请求处理器
- 类似 Spring Boot 的端口监听启动类

后续我们将继续拓展：

- 参数绑定（如 `@RequestParam`, `@RequestBody`）
- 中间件机制（如拦截器）
- 全局异常处理
- JSON 返回支持
- 生命周期管理

敬请期待下一篇：**实现请求参数自动注入与 JSON 响应支持**！