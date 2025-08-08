---
title: 别再乱用箭头函数了！JavaScript 三种函数写法的终极指南
date: 2025-08-06 15:36:41
tags:
---


在 JavaScript 中，我们有多种方式来定义函数。最常见的两种就是普通函数（使用 `function` 关键字）和箭头函数（`=>`）。虽然它们看起来有些相似，但实际上它们之间有不少微妙的区别，尤其是在 `this`、`new`、`yield` 等语义上的差异。如果你也常常纠结“我该用哪种写法更合适？”，那本文或许能帮你厘清思路。

---

# 三种创建函数的方式

## 1. 函数声明（Function Declaration）

最传统的方式是使用 `function` 关键字直接声明函数：

```js
function helloWorld() {
  console.log('Hello, world!');
}
```

这种方式是**函数声明语句**，在作用域中具有名称绑定，并且最重要的一点是，它会被**提升（hoisting）**到当前作用域的顶部。

```js
<script type="text/javascript">
sayHello(); // ✅ 可以提前调用，输出：Hello, world!

function sayHello() {
  console.log('Hello, world!');
}
</script>
```

### 🔍 为什么这样不会报错？
这是因为 函数声明 会在代码运行前被 JavaScript 引擎“提升”到当前作用域的顶部。也就是说，在你执行 sayHello() 的时候，这个函数其实已经“存在”了。

---

## 2. 函数表达式（Function Expression）

你也可以将匿名函数赋值给变量：

```js
var sayHi = function() {
  console.log('Hi!');
}

sayHi(); // ✅ 可以调用，输出：Hi!
```

这种写法称为函数表达式，它不像声明那样会被提升，必须在使用前先定义。

### 1️⃣ 函数声明会被完整提升，而函数表达式不会

```js
sayHi(); // ❌ TypeError: sayHi is not a function

var sayHi = function() {
  console.log('Hi!');
}
```

虽然变量 sayHi 被提升了，但它的值（即函数体）并没有被赋值。在 sayHi() 执行时，变量的值是 undefined，调用它会报错。


### 2️⃣ 匿名函数表达式在调试堆栈中可能丢失函数名

很多时候我们写函数表达式时是匿名的，比如：

```js
const handler = function(a, b) {
  throw new Error('Oops!');
};
```

虽然你赋值给了变量 `handler`，但 JavaScript 引擎不一定能在调试堆栈中正确还原这个名称，特别是在打包压缩或 V8 优化场景中。


有趣的是，我们还可以给函数表达式命名：

```js
const throwError = function error(predicate, arr) {
  throw new Error('Oops');
}
```

虽然我们无法直接通过 `error()` 调用它，但如果出错，错误堆栈中会显示这个名称，有利于调试。

![堆栈](./images/js-arrow-function/stack.png)


**注意：** 使用 `let` 或 `const` 声明函数表达式时，甚至连变量提升都不会发生，会抛出 `ReferenceError`：

```js
sayHello(); // ❌ ReferenceError: Cannot access 'sayHello' before initialization

const sayHello = function() {
  console.log('Hello');
};
```

---

## 3. 箭头函数（Arrow Function）

箭头函数是 ES6 引入的语法，语法更短，也更现代：

```js
double(2); // ❌ TypeError: greet is not a function

const double = (x) => {
  return x * 2;
};
```

如果函数体只有一行返回语句，还可以进一步简化：

```js
const double = (x) => x * 2;
```

如果参数只有一个，连小括号都可以省略：

```js
const double = x => x * 2;
```

但别被这些简洁迷惑了，箭头函数背后隐藏着一些重要差异。

---

# 箭头函数 ≠ 普通函数

## 1. 箭头函数没有自己的 this

```js
function getName() {
  return this.userName;
}

const getNameArrow = () => this.userName;

const User = {
  userName: 'Tim Cook',
  getName,
  getNameArrow
};

console.log(User.getName()); // ✅ 正常输出 Tim Cook
console.log(User.getNameArrow()); // ❌ undefined
```

箭头函数会捕获**定义时**的 `this` 值，而不是调用时的。这也是为什么它不适合用作对象的方法或类的原型方法。

---

## 2. 箭头函数不能用作构造函数

```js
const User = (userName, age) => {
  this.userName = userName;
  this.age = age;
};

const myUser = new User('Tim Cook', 55); // ❌ TypeError: User is not a constructor
```

你不能用 `new` 调用箭头函数，它们没有 `prototype`，也没有 `new.target`。

---

## 3. 箭头函数不能使用 yield

```js
// ❌ 不合法，不能在箭头函数里使用 yield
function* numberGen() {
  const show = () => {
    yield 1; // SyntaxError
  };
}
```

箭头函数无法作为生成器使用，不能使用 `yield`，也无法被声明为 `function*`。

---

# 应该何时使用箭头函数？

简单总结：

| 使用场景             | 推荐写法              |
| ---------------- | ----------------- |
| 不使用 this / yield | ✅ 箭头函数更简洁         |
| 需要 this 正确指向     | ✅ 使用普通函数          |
| 函数需要提前调用（如顶层函数）  | ✅ 函数声明更合适         |
| 用作构造函数           | ✅ 使用普通函数或 class   |
| 编写 generator 函数  | ✅ 必须使用 function\* |

比如我们可以这样使用箭头函数作为回调：

```js
['a', 'b', 'c'].map(x => x.toUpperCase());
```

或者创建一个通用的日志方法：

```js
const log = (obj) => console.log(obj.toLogString());
```

只要不涉及 `this`，箭头函数通常都是更简洁的选择。

---

# 函数声明带来的 hoisting 优势

有时你可能希望把实现细节放在文件底部，而逻辑入口放在顶部，这时候函数声明的提升就很有用了：

```js
const result = processOrder('pending');
console.log(result); // 输出：请尽快支付订单！

// --- 下面是逻辑实现部分 ---
function processOrder(status) {
  if (isCancelled(status)) {
    return '订单已取消';
  }

  if (isPaid(status)) {
    return '感谢您的购买！';
  }

  if (isPending(status)) {
    return '请尽快支付订单！';
  }

  return '未知状态';
}

function isCancelled(status) {
  return status === 'cancelled';
}

function isPaid(status) {
  return status === 'paid';
}

function isPending(status) {
  return status === 'pending';
}

```

这种结构让代码阅读起来更清晰：先看到“大意”，再了解“细节”。

---

# 总结：一张选择函数写法的流程图

我们可以根据以下几个问题，快速判断使用哪种函数写法更合适：

![流程](./images/js-arrow-function/choose.png)

1. **是否需要使用 `yield`？** → 用 `function*`
2. **是否使用 `this`？** → 用普通函数（method or function expression）
3. **是否希望提前调用该函数？** → 用函数声明（`function name() {}`）
4. **其余情况？** → 用箭头函数，代码更简洁

当然，规范不应束缚创作，你完全可以根据团队风格、可读性或调试需要选择你喜欢的写法。但理解这些差异，可以让你写出更稳健、更清晰的 JavaScript 代码。

---

# 结语

箭头函数不是 function 的替代品，而是一个补充。当你理解它们之间的本质差异后，就能更合理地在项目中权衡使用了。

如果你有自己的选择标准，欢迎留言分享你的实践经验！

