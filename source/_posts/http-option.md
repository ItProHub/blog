---
title: 用 HTTP OPTIONS 发现 API 的隐藏能力
date: 2025-09-25 09:31:53
tags:
---

# 引子：一个常见的问题

假设你正在开发一个前端应用，遇到这样一个接口：

```
POST /api/orders
```

你心里冒出几个问题：

* 这个接口除了 `POST`，还能不能用 `GET` 来获取订单？
* 如果能更新订单，是 `PUT` 还是 `PATCH`？
* 服务器期望的数据格式是 JSON、XML，还是 `form-data`？
* 这个接口有没有写权限，或者我只能读？

通常我们需要查文档（比如 OpenAPI、Swagger），但如果文档缺失、过时或者不完整呢？
其实 HTTP 协议早就提供了一种“问 API 自己”的方式，那就是 **OPTIONS 方法**。

很多人第一次接触 OPTIONS 是在跨域请求（CORS）里：浏览器会先发一个预检请求 `OPTIONS`，确认目标服务器是否允许真正的请求。但 **OPTIONS 的价值远不止于此**。它的设计初衷是让客户端能够被动地发现“在这里我能做什么”。

接下来，我们就深入聊聊 OPTIONS 的用途，并配合实际案例演示。

---

# 基本用法：Allow 头部

最经典的 OPTIONS 用法是通过 `Allow` 头部告诉客户端，某个资源支持哪些方法。

比如我们对 `/api/orders/123` 发起请求：

```bash
curl -X OPTIONS http://localhost:8080/api/orders/123
```

可能会得到：

```
HTTP/1.1 204 No Content
Date: Tue, 24 Sep 2025 12:00:00 GMT
Server: DemoServer/1.2
Allow: GET, PUT, DELETE, OPTIONS
```

从 `Allow` 头就能看出：

* 这个订单可以 `GET`（查看）
* 可以 `PUT`（更新）
* 可以 `DELETE`（删除）
* 当然，OPTIONS 也被允许

这就像 API 自己在告诉你“菜单上有哪些菜”。

---

## 动态 Allow：权限控制

更有意思的是，`Allow` 可以根据**用户角色**动态返回。

## 普通用户：

```
Allow: GET, OPTIONS
```

只能查看订单，不能修改。

## 管理员用户：

```
Allow: GET, PUT, DELETE, OPTIONS
```

可以修改和删除订单。

这意味着，前端应用完全可以在渲染按钮之前，先发一个 OPTIONS 请求，根据 `Allow` 动态决定界面上是否显示“删除订单”按钮。

这种做法的好处是 **前后端解耦**：前端不需要硬编码权限逻辑，直接让 API 自己说话。

```C#
public class OrderController : ControllerBase
{
    [HttpOptions]
    public IActionResult Options(string role)
    {
        if (role == "admin") {
            Response.Headers["Allow"] = "GET, POST, PUT, DELETE, OPTIONS";
        }
        else {
            Response.Headers["Allow"] = "GET, OPTIONS";
        }

        return Ok();
    }


    [HttpGet]
    public IActionResult Get() => Ok("GET OK");

    [HttpPost]
    [Authorize]
    public IActionResult Post() => Ok("POST OK");

    [HttpPut]
    [Authorize(Roles = "Admin")]
    public IActionResult Put() => Ok("PUT OK");

    [HttpDelete]
    [Authorize(Roles = "Admin")]
    public IActionResult Delete() => Ok("DELETE OK");
}
```
普通用户
![普通用户 OPTIONS 响应](./images/http-option/visitor.png)

管理员
![管理员 OPTIONS 响应](./images/http-option/admin.png)

---

# 进一步探索：Accept 和 Accept-\* 系列头

OPTIONS 不只是告诉你支持哪些方法，它还能说明**支持哪些数据格式**。

## Accept 响应头

比如：

```
HTTP/1.1 204 No Content
Date: Tue, 24 Sep 2025 12:10:00 GMT
Server: DemoServer/1.2
Allow: GET, POST, OPTIONS
Accept: application/json, application/xml
```

这里的 `Accept` 表示该接口支持返回 **JSON** 和 **XML**。
这对客户端来说很有用：

* 如果你是浏览器，可以直接选择 JSON
* 如果是一个老系统，需要 XML 也没问题

---

## Accept-Post

对于 `POST` 请求，还能通过 `Accept-Post` 指定可接受的请求体类型：

```
HTTP/1.1 204 No Content
Allow: POST, OPTIONS
Accept-Post: multipart/form-data, application/json
```

这告诉我们：

* 你可以用 `multipart/form-data` 来上传文件
* 也可以用 JSON 来创建数据

举个例子，前端上传头像时用：

```js
const form = new FormData();
form.append("avatar", file);
await fetch("/api/profile/avatar", {
  method: "POST",
  body: form
});
```

而创建用户时则用：

```js
await fetch("/api/users", {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({name: "Alice", email: "a@example.com"})
});
```

---

## Accept-Patch

PATCH 方法常见于部分更新资源，比如只更新订单状态。

```
HTTP/1.1 204 No Content
Allow: PATCH, OPTIONS
Accept-Patch: application/merge-patch+json, application/json-patch+json
```

这意味着服务器支持两种 PATCH 格式：

* **JSON Merge Patch**：整体覆盖部分字段
* **JSON Patch**：通过操作指令更新特定字段

示例请求（JSON Patch）：

```json
[
  { "op": "replace", "path": "/status", "value": "shipped" }
]
```

---

## Accept-Query

这是一个不常见但很有潜力的头部，表示接口支持某种查询语言。

```
HTTP/1.1 204 No Content
Allow: QUERY, OPTIONS
Accept-Query: application/graphql
```

说明你可以通过 `QUERY` 方法发 GraphQL 查询。虽然大多数框架不常用 QUERY 方法，但它在协议层面完全合法。

---

# OPTIONS 响应中的文档链接

OPTIONS 还可以充当“接口说明书入口”。

例如：

```
HTTP/1.1 200 OK
Allow: GET, POST, OPTIONS
Link: <https://api.example.com/docs/orders>; rel="help"
Link: <https://api.example.com/openapi.yaml>; rel="service-desc" type="application/openapi+yaml"
Content-Type: text/plain

你可以在 https://api.example.com/docs/orders 找到详细文档。
```

这里有几点：

* `Link` 头指向了 API 文档和 OpenAPI 描述
* 响应体里返回了友好的提示

这样即便文档站点挂了，至少还能找到线索。

---

# OPTIONS \* ：探测整个服务

平时我们都是对某个路径发 OPTIONS，比如 `/api/orders`。
但协议里还规定了一个特殊格式：

```
OPTIONS * HTTP/1.1
```

注意 `*` 不是路径，而是“整个服务器”。

用 `curl` 可以这样试：

```bash
curl -vX OPTIONS --request-target '*' http://localhost:8080
```

可能返回：

```
HTTP/1.1 204 No Content
Allow: GET, POST, PUT, DELETE, PATCH, OPTIONS
```

这表示服务器全局支持的方法。
虽然现代 fetch() 不支持 `OPTIONS *`，但老牌服务器（如 Apache、Nginx）大多兼容。

---

# 特殊用法：WebDAV 与扩展

OPTIONS 也常用于 WebDAV、CalDAV、CardDAV 这类扩展协议。

例如：

```
HTTP/1.1 204 No Content
Allow: GET, PROPFIND, MKCOL, LOCK, UNLOCK
DAV: 1, 2, calendar-access, addressbook
```

这就超出了传统 REST 的范围，进入了文件共享、日历、联系人等场景。

这类协议通常依赖 OPTIONS 来声明自己支持的扩展能力。

---

# 实战：用 Node.js 实现一个 OPTIONS

为了直观，我们用 Node.js/Express 搭个例子：

```js
import express from "express";
const app = express();

app.use(express.json());

app.options("/api/orders", (req, res) => {
  res.set("Allow", "GET, POST, OPTIONS");
  res.set("Accept", "application/json, application/xml");
  res.set("Accept-Post", "application/json, multipart/form-data");
  res.status(204).send();
});

app.listen(8080, () => console.log("Server started"));
```

测试：

```bash
curl -i -X OPTIONS http://localhost:8080/api/orders
```

结果：

```
HTTP/1.1 204 No Content
Allow: GET, POST, OPTIONS
Accept: application/json, application/xml
Accept-Post: application/json, multipart/form-data
```

这样前端开发者无需文档就能获知接口支持情况。

---

# 总结

OPTIONS 是 HTTP 协议里被低估的一个方法。

* 它不仅仅是 CORS 的配角，更是 API 的“自描述能力”。
* 通过 OPTIONS + Allow，客户端能知道支持的方法。
* 通过 Accept 和 Accept-\*，客户端能知道支持的数据格式。
* OPTIONS 响应还能附带文档链接，帮助开发者快速找到资料。
* 特殊场景下，OPTIONS \* 和 WebDAV 扩展让它更加强大。

所以，当你设计 API 时，不妨善用 OPTIONS，让接口自己“说话”，这能让使用者的体验提升一个档次。

---

👉 未来我准备写一篇《用 OPTIONS 打造自解释 API》的实战文章，展示如何在实际项目中动态返回不同角色的 Allow 结果，并结合前端渲染逻辑，做一个“接口驱动 UI”的 demo，敬请期待！
