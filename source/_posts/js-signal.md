---
title: JavaScript 信号：如何将响应式功能带到普通 Web 开发中
date: 2024-10-30 16:06:01
tags:
---
在现代前端框架中，信号（Signals）正变得越来越流行。从 Angular 到 Solid、Preact，几乎所有主流框架都在使用信号，甚至有提案将其作为语言的核心功能。如果这个提案通过，那么框架中内置信号将是时间问题，而对于普通的 Web 开发者来说，信号也不再是遥不可及的技术。

# 信号是什么？
信号本质上是一个可以包装值并在值发生变化时发出事件的机制。在更现代的框架中，信号通过捕捉数据的变化并以响应的方式进行操作，避免了像传统 DOM 更新那样的重绘操作，从而提高了性能和开发效率。它的最大特点是能够简洁、高效地处理响应式状态，而不需要像 React 那样频繁地重新渲染整个组件。

## 举个例子
如果你对前端不是很熟悉，或者与世隔绝很久了，我们先通过下面的例子来简单了解一下信号的作用
```javascript
import { h } from 'preact';
import { signal, computed } from '@preact/signals';
import style from './style.css';

const username = signal('');
const password = signal('');
const message = computed(() => `用户名：${username.value} / 密码：${password.value}`);
const Test = ({ user }) => {
	const submitForm = () => {

	};

	return (
		<div>
			<h2>用户注册</h2>
			<input
				type="text"
				placeholder="用户名"
				onInput={(e) => username.value = e.target.value}
			/><br/>
			<input
				type="password"
				placeholder="密码"
				onInput={(e) => password.value = e.target.value}
			/><br/>
			<button onClick={submitForm}>提交</button>
			<p>{message}</p>
		</div>
	);
};

export default Test;
```
运行上面preact的例子，我们可以看到如下效果
![效果](./images/js-signal/responsive.gif)

# 从零开始实现信号
虽然信号在大多数现代框架中已经成为标准，但对于普通的 Web 开发者来说，我们可以通过一些简单的技巧在普通的 JavaScript 环境中实现类似的功能。我们通过 EventTarget 基类来封装信号，简单的包装便能实现信号机制。

```javascript
class Signal extends EventTarget {
    #value;

    constructor(value) {
        super();
        this.#value = value;
    }

    get value() {
        return this.#value;
    }

    set value(newValue) {
        if (this.#value !== newValue) {
            this.#value = newValue;
            this.dispatchEvent(new CustomEvent('change', { detail: newValue }));
        }
    }
}


const signal = new Signal('Initial Value');
console.log(signal.value);
signal.addEventListener('change', (event) => {
    console.log(`信号的新值是：${event.detail}`);
});

signal.value = 'Updated Value'; // 输出：信号的新值是：Updated Value
signal.value = 'Another Value'; // 输出：信号的新值是：Another Value
```
这段代码使用了 EventTarget 来监听和分发变化事件。通过 value 属性，我们可以轻松地读取和更新信号值，而当信号值改变时，会触发一个 change 事件。我们可以通过 addEventListener 来订阅信号变化：

![效果](./images/js-signal/EventTarget.png)
这只是信号的基本实现，接下来，我们可以通过添加一些语法糖来简化其使用体验。

# 增强功能：更简洁的 API
我们可以为 Signal 添加一些额外的方法，简化订阅和取消订阅的操作。例如，effect 方法可以直接订阅信号的变化并执行相应的回调。

```javascript
class Signal extends EventTarget {
    #value;

    constructor(value) {
        super();
        this.#value = value;
    }

    get value() {
        return this.#value;
    }

    set value(newValue) {
        if (this.#value !== newValue) {
            this.#value = newValue;
            this.dispatchEvent(new CustomEvent('change', { detail: newValue }));
        }
    }

    effect(fn) {
        fn();
        this.addEventListener('change', fn);
        return () => this.removeEventListener('change', fn);
    }

    valueOf () { return this.#value; }
    toString () { return String(this.#value); }
}
```
现在，我们可以通过 effect 来简化代码：

```javascript
const signal = new Signal('Initial Value');
signal.effect(() => console.log(`信号的新值是：${signal.value}`)); 
signal.value = 'Updated Value'; 
```
在这个例子中，effect 方法会立即执行一次回调，并订阅 change 事件。返回的取消函数可以让我们在不需要时取消对信号的订阅。
![效果](./images/js-signal/EventTarget2.png)

# 计算信号：依赖多个信号的计算
有时我们需要基于多个信号来计算一个新值，这时候我们就需要计算信号。计算信号会基于其他信号的变化，自动重新计算自己的值。

```javascript
class Signal extends EventTarget {
    #value;

    constructor(value) {
        super();
        this.#value = value;
    }

    get value() {
        return this.#value;
    }

    set value(newValue) {
        if (this.#value !== newValue) {
            this.#value = newValue;
            this.dispatchEvent(new CustomEvent('change', { detail: newValue }));
        }
    }

    valueOf () { return this.#value; }
    toString () { return String(this.#value); }
}


class ComputedSignal extends Signal {
    constructor(calculateFn, deps) {
        super(calculateFn(...deps));
        this.deps = deps;

        deps.forEach(dep => {
            dep.addEventListener('change', () => {
                this.value = calculateFn(...deps);
            });
        });
    }
}

const name = new Signal('Thor');
const surname = new Signal('Odinson');

const fullName = new ComputedSignal((first, last) => `${first} ${last}`, [name, surname]);

fullName.addEventListener('change', () => {
    console.log(`计算后的全名是：${fullName.value}`);
});

name.value = 'Bruce'; // 输出：计算后的全名是：Bruce Odinson
surname.value = 'Banner'; // 输出：计算后的全名是：Bruce Banner
```
在这个示例中，fullName 会根据 name 和 surname 信号的变化自动更新。当 name 改变时，fullName 也会重新计算。
![效果](./images/js-signal/EventTarget3.png)

# 将信号与 Web 组件结合使用
信号的一个非常有趣的应用是在 Web 组件中。我们可以通过信号将状态和 UI 更新绑定在一起，从而避免直接操作 DOM。

```javascript
class Signal extends EventTarget {
    #value;
    constructor(value) {
        super();
        this.#value = value;
    }
    get value() {
        return this.#value;
    }

    set value(newValue) {
        if (this.#value !== newValue) {
            this.#value = newValue;
            this.dispatchEvent(new CustomEvent('change', { detail: newValue }));
        }
    }

    effect(fn) {
        fn();
        this.addEventListener('change', fn);
        return () => this.removeEventListener('change', fn);
    }
}

customElements.define('theme-switcher', class extends HTMLElement {
    constructor() {
        super();
        this.darkThemeSignal = new Signal(false); // 默认为亮色主题
    }

    connectedCallback() {
        // 创建主题切换按钮
        this.innerHTML = `
            <button id="light">亮色主题</button>
            <button id="dark">暗色主题</button>
            <p>当前主题：${this.darkThemeSignal.value ? '暗色' : '亮色'}</p>
        `;

        // 获取按钮元素
        const lightButton = this.querySelector('#light');
        const darkButton = this.querySelector('#dark');
        const statusText = this.querySelector('p');

        // 监听按钮点击事件，切换主题
        lightButton.addEventListener('click', () => {
            this.darkThemeSignal.value = false; // 切换到亮色主题
        });

        darkButton.addEventListener('click', () => {
            this.darkThemeSignal.value = true; // 切换到暗色主题
        });

        // 监听信号变化，更新主题
        this.darkThemeSignal.effect(() => {
            document.body.style.backgroundColor = this.darkThemeSignal.value ? 'black' : 'white';
            document.body.style.color = this.darkThemeSignal.value ? 'white' : 'black';
            statusText.textContent = `当前主题：${this.darkThemeSignal.value ? '暗色' : '亮色'}`;
        });
    }
});
```
这个例子中，实现一个简单的主题切换器，允许用户在“暗色”和“亮色”主题之间切换。信号将用于存储当前主题，Web 组件将用于渲染和切换主题。
![切换主题](./images/js-signal/switch-theme.gif)

# vue？
通过上面实现的效果很容易让我们联想到双向绑定的vue。但是需要注意的是，vue3的响应式系统是基于Proxy实现的（vue2是Object.defineProperty），而我们实现的信号是基于EventTarget实现的。因此，虽然它们都能实现响应式，但它们的实现原理和使用方式是不同的。虽然 Vue 使用了类似于事件的机制来通知视图更新（当数据发生变化时，通知组件重新渲染），但 Vue 的核心机制并不是基于 EventTarget。Vue 更侧重于数据响应和依赖跟踪。EventTarget 通常用于事件处理（如 DOM 事件），而 Vue 更专注于数据绑定和自动更新，并通过依赖收集和更新机制来触发视图的变化。

# 结语
信号提供了一种简洁且高效的方式来响应数据变化，在现代 Web 开发中大有可为。通过简单的 JavaScript，我们可以将信号机制引入到应用中，不再依赖大型框架即可享受响应式的编程体验。如果你还没尝试过信号，赶快开始吧！