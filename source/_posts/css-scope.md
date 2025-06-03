---
title: 从 scoped 到 @scope：CSS 样式隔离的进化
date: 2025-06-03 09:56:38
tags:
---

在前端开发中，“样式污染”一直是一个反复出现的问题。尤其在构建大型项目或维护多个组件库时，全局 CSS 的不确定性会带来许多调试难题。为了实现组件级样式隔离，我们使用过许多手段：BEM 命名规范、CSS Modules、Vue 的 scoped 样式、甚至 Shadow DOM。但今天，我们迎来了一个更加原生、简洁的解决方案：`@scope`。

本文将带你了解 CSS 的这项新特性，以及它在组件样式管理中的应用实践，并结合 Vue 的 scoped 实战与对比，探讨 `@scope` 的优势与适用场景，看看它是否真的值得期待。

# 为什么我们需要作用域 CSS？

我们先从一个经典的例子开始说起：

```html
<style>
  h1 {
    color: red;
  }
</style>

<div class="my-comp">
  <h1>我是红色的</h1>
</div>
<h1>我也变红了</h1>
```
![test](./images/css-scope/test1.png)

这段样式会作用于页面中所有的 `h1` 标签。这种全局样式一旦覆盖了不该覆盖的部分，可能会导致页面样式出现不可预期的混乱。在多人协作、跨团队开发时，这种“样式污染”现象尤为常见。

为了解决这个问题，我们过去主要依赖以下几种方式：

* 添加命名空间前缀，例如 `.my-comp h1 { color: red }`；
* 使用构建工具支持的 CSS Modules；
* 在 Vue 或 React 中使用 scoped 样式特性；
* 使用 Shadow DOM 实现样式封装。

这些方案都各有优缺点，但本质上都是“曲线救国”。

---

# Vue的scoped style

提到scoped， 前端开发者们肯定会想到Vue的scoped style。它用于实现组件级别的样式隔离，可以让组件的样式只在当前组件内生效，不会影响全局。
Vue 是最早支持 scoped 样式的主流框架之一。

## 实战示例：Vue scoped CSS 的使用方式

```vue
<template>
  <div class="card">
    <h2>我是标题</h2>
    <p>这是一段内容</p>
  </div>
</template>

<script>
export default {
  name: 'ScopedCard'
}
</script>

<style scoped>
.card {
  border: 1px solid #ccc;
  padding: 1rem;
  border-radius: 8px;
}

.card h2 {
  color: steelblue;
}

.card p:hover {
  background-color: #f0f0f0;
}
</style>
```

Vue 中的 `<style scoped>` 是通过编译时处理实现的。

## 实现原理

1. 编译模板时，会给组件的根元素自动添加一个唯一的属性（如 `data-v-123456`）。
2. 所有选择器都会被转化为带这个属性的选择器，例如：

```css
h1[data-v-123456] { color: red; }
```

这使得样式局部生效，但依赖构建工具。所以当我们通过开发者工具查看vue开发的项目时，会发现，样式的选择器都带有data-v-xxx的属性。
![test](./images/css-scope/vue-scoped-style.png)

## 存在的问题

* ❌ 无法自动作用于子组件，除非使用 `::v-deep`；
* ❌ 缺乏原生支持，不能脱离构建工具；
* ❌ 编译后的选择器冗长，调试体验差；
* ❌ 无法完全避免全局样式干扰。

因此，Vue 的 scoped 是构建时 hack，而非 CSS 原生功能。

---

# 什么是 @scope？
`@scope` 是 CSS 官方提出的作用域语法，它允许我们为样式规则限定作用范围，实现真正原生的样式隔离。

## 基本语法

```css
<style>
@scope (.my-comp) {
  h1 {
    color: red;
  }
}
</style>
<div class="my-comp">
  <h1>我是红色的</h1>
</div>
<h1>我没有变红</h1>
```

只有 `.my-comp` 元素内的 `h1` 才会生效。
![result](./images/css-scope/result.png)

## 特性优势

* ✅ 原生支持，无需依赖构建工具；
* ✅ 支持所有标准选择器和伪类；
* ✅ 可以嵌套和组合使用；
* ✅ 不依赖类名、属性名等技术手段；
* ✅ 可与 `<style>` 标签结合，适用于组件化开发。

---

## 内联使用 @scope：更自然的组件化体验

`@scope` 也可以与内联 `<style>` 标签结合使用：

```html
<div class="card">
  <style>
    @scope (.card) {
      h2 {
        color: steelblue;
      }
      p:hover {
        background: #f0f0f0;
      }
    }
  </style>
  <h2>标题</h2>
  <p>内容段落</p>
</div>
```
![inline](./images/css-scope/inline.png)
相比传统的 scoped CSS，这种方式不依赖任何构建步骤，语义清晰，维护简单。

---

## 动态添加 @scope 样式

在 JavaScript 中动态插入样式：

```js
const style = document.createElement('style');
style.textContent = `
  @scope (.dynamic-box) {
    span {
      font-weight: bold;
      color: orange;
    }
  }
`;
document.head.appendChild(style);
```

![dynamic](./images/css-scope/dynamic.png)
适用于微前端、动态组件等运行时场景。

---

# 对比：@scope 与其他样式隔离方案

| 方案             | 样式隔离 | 支持选择器 | 依赖工具链  | 浏览器支持    |
| -------------- | ---- | ----- | ------ | -------- |
| BEM 命名规范       | ❌    | ✅     | ❌      | ✅        |
| CSS Modules    | ✅    | ✅     | ✅（构建时） | ✅        |
| Shadow DOM     | ✅    | ✅     | ❌（原生）  | ✅        |
| Vue scoped CSS | ✅    | 部分支持  | ✅（编译时） | ✅        |
| **@scope**     | ✅    | ✅     | ❌      | ✅（逐步完善中） |

---

# 浏览器支持情况

截至 2025 年中：

* ✅ Chrome（111+）
* ✅ Safari（16.4+）
* ✅ Edge
* ⚠️ Firefox：需手动开启 `layout.css.scope.enabled`

👉 [Can I Use: @scope](https://caniuse.com/?search=%40scope)

---

# 使用建议

* ✅ 推荐用于组件化样式隔离；
* ✅ SSR 场景优选，兼容性好；
* ✅ 可用于构建无依赖的 UI 组件；
* ⚠️ 老旧浏览器（如 IE11）不支持；
* ⚠️ 当前阶段可与 scoped CSS 搭配使用；

---

# 总结

`@scope` 的出现为 CSS 带来了“模块化思维”。它弥补了长期以来 CSS 缺乏作用域机制的缺陷，为组件开发带来了新的可能。

相比构建时方案（如 Vue scoped、CSS Modules）或高成本方案（如 Shadow DOM），`@scope` 提供了一种更自然、更贴近语义的写法。

未来，我们或许可以更少依赖工具链，而更多依赖浏览器原生能力来实现高质量的组件样式隔离。

```css
@scope (.card) {
  h1 {
    color: blue;
  }
}
```

简单、直观、强大。

---

# 延伸阅读

* [MDN：@scope](https://developer.mozilla.org/en-US/docs/Web/CSS/@scope)
* [Chrome Platform Status](https://chromestatus.com/feature/5798754575984640)
* [Scoped Styles Draft Spec](https://drafts.csswg.org/css-cascade-6/#scope)

---

如果你觉得这篇文章有帮助，欢迎点赞 / 收藏 / 留言交流 🙌

如需更多框架实战例子（如 React / Web Components 中的应用），也欢迎留言告诉我。