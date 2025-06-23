---
title: Promise 深度解析：从原理到实战
date: 2025-06-20 09:43:24
tags:
---

拙荆是一位测试工程师，说她是我的最佳对手也不为过，常常与我这个开发针尖对麦芒、唇枪舌剑。前几天她突然问我：“Promise 到底是啥？是不是非用不可？”我简单地解释了一番，她却似懂非懂，眼神中流露出明显的不满。于是我决定动笔写下这篇文章，一来是给她一个全面的交代，二来也整理一下自己对 Promise 的理解。
![fight](./images/promise/fight.png)

在 JavaScript 异步编程的世界里，Promise 是几乎无处不在的基础构件。即使你已经习惯使用 `async/await`，理解 Promise 的底层运行机制，仍然是深入掌握异步编程的关键。

本篇文章将从 Promise 的基本用法讲起，逐步深入到微任务队列、链式调用原理、错误处理，再到一些常见的“看不懂输出顺序”的典型案例，并配以可调试的代码示例。

---

# 什么是 Promise?

简单来说，Promise 是 JavaScript 提供的一种异步编程解决方案，用于表示一个**未来才会完成**的操作结果。它有三种状态：

* `pending`：初始状态，既不是成功，也不是失败。
* `fulfilled`：操作成功完成。
* `rejected`：操作失败。

Promise 的基本用法如下：

```js
const promise = new Promise((resolve, reject) => {
  setTimeout(() => {
    resolve('Hello, Promise!');
  }, 1000);
});

promise.then(result => {
  console.log(result); // 输出: Hello, Promise!
});
```

更详细的介绍可以参考阮一峰的文章[Promise 对象](https://es6.ruanyifeng.com/#docs/promise)

---

# 📌 什么时候用 Promise
下面是一些常见、实际开发中会用到 Promise 的典型场景：

---

## 1. **异步请求（最常见）**

```js
fetch('/api/data')
  .then(res => res.json())
  .then(data => console.log(data))
  .catch(err => console.error(err));
```

> HTTP 请求需要时间，结果不是立即返回，必须用异步；而 Promise 能优雅地组织这些操作和错误处理。

---


## 2. **异步文件操作（在 Node.js 中）**

```js
const fs = require('fs/promises');

fs.readFile('file.txt', 'utf8')
  .then(data => console.log(data))
  .catch(err => console.error(err));
```

---

## 3. **串行异步流程控制**

有时候你需要一个任务完成后再执行下一个，不能全并发跑。

```js
getUser()
  .then(user => getPostsByUser(user.id))
  .then(posts => display(posts));
```

---

## 4. **并发任务的批量处理**

比如一次加载多个资源，等全部完成后再进行处理：

```js
Promise.all([
  fetch('/user'),
  fetch('/posts'),
  fetch('/comments')
]).then(([user, posts, comments]) => {
  // 全部都加载完了，统一处理
});
```

---

## 5. **定时器、延迟执行**

```js
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

delay(1000).then(() => {
  console.log('1秒后执行');
});
```

---


# 链式调用与返回值穿透

```js
Promise.resolve(1)
  .then((res) => {
    console.log(res); // 输出 1
    return res + 1;
  })
  .then((res) => {
    console.log(res); // 输出 2
    return Promise.resolve(res + 1);
  })
  .then((res) => {
    console.log(res); // 输出 3
  });
```

* 每个 `.then()` 返回的都是一个新的 Promise。
* 如果 `.then()` 中返回的是普通值，它会被 `Promise.resolve()` 包装。
* 如果返回的是一个 Promise，则等待它的状态改变。

---

# 🔄 什么是 Event Loop（事件循环）？

JavaScript 是单线程语言，只能一个任务一个任务地执行。那它是如何做到异步执行 `Promise`、`setTimeout` 等非阻塞任务的呢？这就离不开核心机制 —— **事件循环（Event Loop）**。

事件循环的执行过程可以简化为：

1. 执行主线程上的同步任务；
2. 取出微任务队列（Microtask Queue）并依次执行完毕；
3. 如果微任务队列为空，则执行一个宏任务（Macrotask）；
4. 重复以上过程。

![event_loop](./images/promise/event_loop.gif)

---

## 🧠 更直观地理解：

每次 JavaScript 执行一个宏任务（如 `setTimeout` 回调、主线程代码等）后，会**立即清空当轮产生的所有微任务（如 Promise.then）**，然后再进入下一个宏任务。

---

## 📌 举个例子：

```js
console.log('start');

setTimeout(() => {
  console.log('macro');
}, 0);

Promise.resolve().then(() => {
  console.log('micro');
});

console.log('end');
```

**输出顺序为：**

```
start
end
micro
macro
```

* `start` 和 `end` 属于同步任务；
* `micro` 属于微任务，执行优先级高于宏任务；
* `macro` 是下一个宏任务，最后执行。

---

# 常见执行顺序陷阱：请你猜猜输出
## 多个微任务队列

```js
Promise.resolve().then(() => {
    console.log(1);
}).then(() => {
    console.log(2);
}).then(() => {
    console.log(3);
}).then(() => {
    console.log(4);
});


Promise.resolve().then(() => {
    console.log('A');
}).then(() => {
    console.log('B');
}).then(() => {
    console.log('C');
}).then(() => {
    console.log('D');
});
```

**输出为：**

```
1
A
2
B
3
C
4
D
```
### 🧠**原因分析：**

虽然看起来你是写了两条链，但它们会**交错执行**，这与 JavaScript 中的**微任务队列**行为密切相关。

---

### 🔍 执行过程详解：

JavaScript 执行模型是这样的：

1. 执行同步代码（全局同步代码优先）；
2. 执行微任务队列（microtasks）：包括 Promise 的 `.then()`、`MutationObserver`、`queueMicrotask()`；
3. 执行宏任务队列（macrotasks）：如 `setTimeout`、`setInterval`、I/O 等。


![multi-queue](./images/promise/multi-queue.png)
---

#### ✅ 第一步：同步阶段

* 没有任何同步 `console.log()`，所以直接进入**微任务阶段**。

---

#### ✅ 第二步：第一轮微任务队列

全局有两个 Promise 链：

```js
// 链1
Promise.resolve().then(() => console.log(1)) // 微任务A
  .then(() => console.log(2))               // 微任务C
  .then(() => console.log(3))               // 微任务E
  .then(() => console.log(4));              // 微任务G

// 链2
Promise.resolve().then(() => console.log('A')) // 微任务B
  .then(() => console.log('B'))                // 微任务D
  .then(() => console.log('C'))                // 微任务F
  .then(() => console.log('D'));               // 微任务H
```

但**重要的是**：

* `Promise.resolve().then(...)` 是**立即进入微任务队列**的；
* 后续 `.then(...)` 是在 **前一个 then 执行完后、产生的新微任务**！

---

### 👇 微任务轮次如下（每轮会清空当前所有微任务队列）：

---

#### 🌀 第一轮微任务队列：

* 执行 `console.log(1)`（A）
* 执行 `console.log('A')`（B）

这两个是**最早入队**的两个 `.then()`，并且没有前置依赖。

**输出：**

```
1
A
```

---

#### 🌀 第二轮微任务队列：

* 上一轮执行完 `console.log(1)`，它的 `.then(() => console.log(2))`（C）被加入；
* 执行完 `console.log('A')`，它的 `.then(() => console.log('B'))`（D）被加入。

现在队列中是：

* `console.log(2)`（C）
* `console.log('B')`（D）

**输出：**

```
2
B
```
后面依次类推完成所有的输出，这里就不再赘述了。

每一个 `.then()` 的回调都是**当前 Promise 链前一个 then 完成后，才加入下一轮微任务队列**，而两个链是**并发推进**的。

---

## 嵌套 Promise + 链式 Promise 组合类型

```js
Promise.resolve().then(() => {
    console.log(1);
    return Promise.resolve(5);
}).then((res) => {
    console.log(res);
});

Promise.resolve().then(() => {
    console.log(2);
}).then(() => {
    console.log(3);
}).then(() => {
    console.log(4);
}).then(() => {
    console.log(6);
});
```

### 💡**输出结果：**

```
1
2
3
4
5
6
```
怎么样？惊不惊喜？意不意外？

### 🧠**原因分析：**

**为什么不是 "1 2 5 3 4 6"？**

所有的 `.then()` 都是微任务，会按**创建顺序入队并逐步推进**。而且**两个链虽然几乎同时创建，但第二条链会先执行得更快**，这是重点。

---

#### ✅ 还原执行过程（按微任务轮次）：

##### 🌐 同步阶段：

* 两个 `Promise.resolve().then()` 被创建，注册了 `.then()` 回调，但没有同步输出。

---

##### 🌀 第 1 轮微任务队列（按创建顺序执行）：

1. **第一个 `.then()` 回调**（来自第一条链）：

```js
() => {
  console.log(1);
  return Promise.resolve(5);
}
```

输出：`1`
返回值是一个新的 Promise，因此下一个 `.then(res => console.log(res))` 会**等待该 Promise 的结果**，**不会立即进入当前微任务队列**，而是延迟一轮。

2. **第二条链的第一个 `.then()` 回调：**

```js
() => console.log(2)
```

输出：`2`

---

##### 🌀 第 2 轮微任务队列：

接着入队的是这两个：

1. 第二条链的 `.then(() => console.log(3))` → 输出：`3`
2. 第一条链返回的 `Promise.resolve(5)` 被 resolve 后，产生一个新微任务 → `.then(res => console.log(res))` 被延迟到下一轮！

---

##### 🌀 第 3 轮微任务队列：

1. 第二条链的 `.then(() => console.log(4))` → 输出：`4`

---

##### 🌀 第 4 轮微任务队列：

1. 第一条链 `.then(res => console.log(res))` → 输出：`5`
2. 第二条链 `.then(() => console.log(6))` → 输出：`6`

---


# 错误处理：catch 与链路中断

```js
Promise.resolve()
  .then(() => {
    throw new Error('Oops!');
  })
  .catch((err) => {
    console.log('Caught:', err.message);
  });
```

注意点：

* 一旦在 `.then()` 中抛出错误，后续的 `.then()` 会被跳过，直到 `.catch()`。
* `catch` 本质上也是 `then(undefined, onRejected)` 的语法糖。

---

# finally：无论成功失败都执行

```js
Promise.reject('error')
  .catch(err => {
    console.log('catch:', err);
  })
  .finally(() => {
    console.log('finally: clean up');
  });
```

* `finally` 不会接收任何参数。
* 它在 promise 结束（无论成功或失败）后执行。
* 它不会影响链式传值。

---

# 与 async/await 的融合

`async/await` 其实是 Promise 的语法糖，让异步代码更像同步流程：

```js
async function main() {
  try {
    const result = await Promise.resolve(123);
    console.log(result); // 123
  } catch (err) {
    console.error('Error:', err);
  }
}
main();
```

等价于：

```js
Promise.resolve(123)
  .then(res => console.log(res))
  .catch(err => console.error('Error:', err));
```

---

# 调试技巧与最佳实践

* **避免嵌套地狱**：通过链式调用或 async/await 展平逻辑结构。
* **统一错误处理**：链式调用最后用 `.catch()`，或者 try/catch 包裹 async 函数。
* **使用 `Promise.all` 处理并发**：

```js
const results = await Promise.all([fetchUser(), fetchPosts(), fetchComments()]);
```

* **合理使用 `Promise.race`** 做超时控制：

```js
const timeout = new Promise((_, reject) => setTimeout(() => reject('timeout'), 3000));
const result = await Promise.race([fetchData(), timeout]);
```

---

# 结语

虽然现在大家更倾向于使用 `async/await`，但 Promise 是 async 的根基。真正理解 Promise 的行为顺序和状态变化，对于构建稳定、可维护的异步程序至关重要。掌握 Promise，不只是写出能跑的代码，而是写出**能预期、能控制的异步逻辑**。

