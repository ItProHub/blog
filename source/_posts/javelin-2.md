---
title: 手写一个微型 Spring 框架（二）:从路由到生命周期管理
date: 2025-04-27 15:42:39
tags:
---

书接上回，在上一篇文章中，我们展示了如何构建一个简单的微型 Spring 框架，涵盖了端口监听、路由动态注册和依赖注入（IoC）。本篇将进一步扩展我们的框架，涵盖 参数绑定、中间件机制、全局异常处理、JSON 返回支持 以及 生命周期管理。

这些功能将使我们的微型框架更加完整，能够处理更多的应用场景。让我们开始深入探讨这些新增功能。

# 参数绑定
在上一篇文章里面虽然我们已经能够通过访问接口来获取返回值。但是请求的参数是如何绑定到方法的参数上的呢？这就是参数绑定的作用。
在 Web 开发中，参数绑定是一个非常重要的特性，通常用于从请求中提取参数并绑定到方法的参数上。在 Spring 框架中，我们通过注解如 @RequestParam 和 @RequestBody 来实现这一功能， 这里我们也直接参照实现。

## 目标：
1. 使用 @FromQuery 注解实现 URL 查询参数的绑定。
2. 使用 @FromBody 注解将请求体中的 JSON 数据绑定为 Java 对象。
3. 使用 @FromRoute 注解将路径变量绑定到方法参数。

## 实现方法：

### 动态路由
在之前的路由注册过程中，我们已经将路径和对应的处理方法进行了映射。为了实现路径参数（/user/{id}）绑定，我们需要实现动态路由，即根据请求的 URL 路径来动态确定要调用的处理方法。只有这样我们才能过滤出请求的参数。
```java
// 之前的路由注册
//  server.createContext(path, exchange -> {
//      // 这里我们需要根据请求的 URL 路径来确定要调用的处理方法
//  });

// 现在我们需要实现动态路由（在程序启动的时候扫描所有controller、action，然后缓存起来）
private final List<RouteDefinition> dynamicRoutes = new ArrayList<>();
 for (Class<?> clazz : classes) {
    for (Method method : clazz.getDeclaredMethods()) {
        dynamicRoutes.add(new RouteDefinition(httpMethod, path, pathPattern, pathVaribleNames, controllerInstance, method));
    }
 }

server.createContext("/", exchange -> {
    String requestPath = exchange.getRequestURI().getPath();

    // 根据请求路径找到对应的处理方法
    RouteDefinition matchedRoute = findMatchRoute(requestPath);

    // 执行具体的处理方法
});
```
### 解析参数
这里注解的实现就不多说了，我们主要看看参数绑定的实现。
我们在框架中通过反射机制来解析方法参数，根据注解从请求中提取相应的参数。以下是参数绑定的代码示例：

```java
public Object[] resolveMethodParameters(HttpExchange exchange, RouteDefinition route, Map<String, String> pathVariables) throws Exception {
    Parameter[] parameters = route.handlerMethod.getParameters();
    Object[] args = new Object[parameters.length];

    for (int i = 0; i < parameters.length; i++) {
        Parameter parameter = parameters[i];

        if (parameter.isAnnotationPresent(FromQuery.class)) {
            // 从 URL 查询参数中提取
            Map<String, String> queryParams = UrlExtensions.parseQueryParams(exchange.getRequestURI().getRawQuery());
            args[i] = StringExtensions.convertTo(queryParams.get(parameter.getName()), parameter.getType());
        } else if (parameter.isAnnotationPresent(FromBody.class)) {
            // 从请求体中提取 JSON 数据并绑定
            String bodyString = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            args[i] = new Gson().fromJson(bodyString, parameter.getType());
        } else if (parameter.isAnnotationPresent(FromRoute.class)) {
            // 从路径变量中提取
            args[i] = StringExtensions.convertTo(pathVariables.get(parameter.getName()), parameter.getType());
        }
    }

    return args;
}
```
此方法确保可以将查询参数、请求体和路径变量自动绑定到控制器方法的参数上。

我们来一起看看效果
1. get参数
![post](./images/javelin-2/query-params.png)
2. post参数
![post](./images/javelin-2/post-params.png)
3. 路径参数
![post](./images/javelin-2/route-params.png)


# JSON 返回支持
在此之前我们返回接口返回的都是String类型，现在我们来实现JSON返回支持。同时我们希望可以根据返回值的类型自动判断是否需要转换为 JSON 格式。

## 目标：

支持返回 String 类型或自定义对象类型。

如果返回的是对象，则自动将其转换为 JSON 格式。

## 实现方式：

```java
// 获取返回值的类型
Class<?> returnType = route.action.getReturnType();

String responseBody;
if(returnType == String.class || returnType == void.class || returnType == int.class) {
    responseBody = (String) result;
    exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=UTF-8");
} else {
    responseBody = gson.toJson(result);
    exchange.getResponseHeaders().set("Content-Type", "application/json; charset=UTF-8");
}
```
此逻辑将根据返回类型自动决定响应类型。对于 Java 对象，将使用 Gson 转换为 JSON 格式返回。
## 实现效果
![json](./images/javelin-2/json.png)

# 中间件机制
中间件（Middleware）是框架中一个非常强大的特性，它允许你在请求处理流程的各个阶段插入额外的处理逻辑。比如，我们可以在请求到达控制器之前，进行权限验证、日志记录等操作。 这里有一个需要关注的地方，我并没有使用现在比较流行的委托链式的中间件，而是参考类似asp.net 的HTTP 管道的方式实现的。

之所以有这样的选择是因为委托链式的中间件在处理过程中会有一些问题，比如：
1. 中间件的执行顺序难以控制，可能会导致请求处理流程出现问题。
2. 一旦出现异常，中间件的异常处理逻辑可能会变得复杂， 异常链非常的深。

所以我选择了类似asp.net 的HTTP 管道的方式实现的中间件，这样可以更加清晰的控制中间件的执行顺序，并且异常处理也更加方便。
![管道](./images/javelin-2/pipeline.png)

## 实现目标：

1. 在请求处理流程中添加拦截器，允许在方法调用之前或之后执行特定操作。
2. 可以添加多个中间件。
3. 支持定义中间件的执行顺序。

## 实现方式：

```java
// 框架初始化的时候注册中间件
private static void loadModules() {
    NHttpModuleFactory.registerModule(OprLogModule.class);

    NHttpModuleFactory.registerModule(AuthenticateModule.class);
    NHttpModuleFactory.registerModule(AuthorizeModule.class);
}
```
在路由处理程序中，我们执行中间件链：

```java
public void execute(NHttpContext context) throws Exception {
    NHttpApplication app = NHttpApplication.INSTANCE;

    preHandle(context);
    try{
        app.beginRequest(context);
        app.authenticateRequest(context);
        app.postAuthenticateRequest(context);
        app.resolveRequestCache(context);

        handlerRequest(context);
    } catch ( AbortRequestException e) {
        // 提前结束请求，啥也不干了
    } catch (Exception e) {
        context.pipelineContext.setException(e);
        app.onError(context);
    } finally {
        app.endRequest(context);
    }

}
```
通过这种方式，我们能够在请求处理过程中插入不同的功能，增加灵活性和可扩展性。

## 实现效果
这里我们新增了一个权限验证的中间件，在请求到达控制器之前进行验证。
![权限](./images/javelin-2/authorize.png)

# 全局日志处理
在我们的框架中，我们可以通过中间件机制来实现全局日志处理。这样，我们就可以在请求处理的各个阶段记录日志，方便调试和监控。

## 目标：
1. 在请求到达控制器之前记录请求信息。
2. 在请求处理完成后记录响应信息。
3. 捕获所有未处理的异常。
4. 返回适当的错误响应。

## 实现方式：
我们可以创建一个日志中间件，在请求到达控制器之前和处理完成后记录日志：
```java
public class OprLogModule extends NHttpModule {
    @Override
    public void beginRequest(NHttpContext httpContext) {
        // 请求到达之前记录请求信息
    }

    @Override
    public void endRequest(NHttpContext httpContext) {
        // 请求处理完成后记录响应信息
    }

    @Override
    public void onError(NHttpContext httpContext) {
        // 请求发生异常的时候记录异常信息
    }
}
```
通过统一的异常处理，可以确保系统稳定性和一致的错误响应。

## 实现效果
为了测试，我们直接在控制器中抛出一个异常：
```java
 @GetMapping("/error")
@AllowAnonymous
public void error() throws Exception {
    throw new Exception("测试异常");
}
```
![日志](./images/javelin-2/error.png)
最后我们来看看日志的记录结果，这是初版的日志，直接记录在文件里面。
这里记录一个TODO，后期需要优化日志记录。（日志异步上报， ELK等等）
![日志](./images/javelin-2/log.png)



# 生命周期管理
生命周期管理是一个框架的重要组成部分。在 Spring 中，我们有 @PostConstruct 和 @PreDestroy 等注解来管理对象的生命周期。在我们的微型框架中，我们可以模拟类似的生命周期管理。

## 目标：

1. 在创建控制器实例时进行初始化。
2. 在销毁时执行清理操作。

## 实现方式：

```java
public class JavelinContext {
    private final Map<Class<?>, Object> singletonMap = new HashMap<>();

    public <T> T getBean(Class<T> clazz) {
        if (!singletonMap.containsKey(clazz)) {
            try {
                T instance = createBean(clazz);
                singletonMap.put(clazz, instance);
                return instance;
            } catch (Exception e) {
                throw new RuntimeException("Failed to create bean: " + clazz.getName(), e);
            }
        }
        return (T) singletonMap.get(clazz);
    }

    private <T> T createBean(Class<T> clazz) throws Exception {
        // 创建实例并调用初始化方法
        T instance = (T) injectConstructor.newInstance(args.toArray());
        callPostConstruct(instance);
        return instance;
    }

    private void callPostConstruct(Object instance) throws Exception {
        // 调用初始化方法
    }

    public void callPreDestroy(Object instance) {
        // 调用销毁方法
    }
}
```
通过这种方式，框架在创建实例时调用 @PostConstruct 注解的方法, 请求处理完成之后调用 @PreDestroy 注解的方法。帮助我们在对象生命周期中插入初始化逻辑。
## 实现效果
![生命周期](./images/javelin-2/life-cycle.png)


# 总结与下步计划
在本篇文章中，我们深入探讨了如何将更多实用的功能添加到我们自定义的微型 Spring 框架中，包括参数绑定、中间件机制、全局异常处理、JSON 返回支持以及生命周期管理。这些功能的实现使得框架的功能更加完善，能够更好地应对复杂的 Web 应用需求。

- 参数绑定：我们通过 @FromQuery, @FromBody, 和 @FromRoute 注解来实现请求参数与方法参数的自动绑定。这一机制可以让控制器方法直接接收 URL 查询参数、请求体数据和路径变量，提高了开发效率。

- 中间件机制：我们参考了 ASP.NET 的 HTTP 管道模式，实现了一个可扩展的中间件机制。通过中间件，可以在请求处理过程中插入额外的逻辑，如权限验证、日志记录等，极大提升了框架的灵活性和可维护性。

- 全局异常处理：通过中间件，框架能够统一处理请求过程中可能出现的异常，确保系统的稳定性，并能够返回一致的错误响应，便于调试和监控。

- JSON 返回支持：我们实现了自动判断返回值的类型并根据类型转换为 JSON 格式。这使得框架能够支持更加复杂的数据返回类型，便于处理 JSON 响应。

- 生命周期管理：模拟了 Spring 的 @PostConstruct 和 @PreDestroy 注解功能，确保在对象生命周期中能够执行初始化和销毁操作，为框架的管理提供了更多控制。

通过实现这些功能，我们不仅提升了框架的可用性，也使其更加完善，能够更好地适应复杂的业务场景。在接下来的文章中，我们将继续扩展更多功能，进一步增强框架的灵活性和实用性。

后续我们将继续拓展：
- 权限与角色管理
- 支持定时任务与后台任务
- 支持数据库操作

如果你对框架有更多的扩展需求，或者希望了解其他细节，请继续关注我们的后续文章！

由于篇幅原因，示例中的代码仅展示了部分关键实现细节，完整代码请参考[GitHub](https://github.com/ItProHub/Javelin)仓库。