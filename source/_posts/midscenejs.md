---
title: AI驱动的自动化测试：探索MidScene.js的强大功能
date: 2025-02-27 14:10:28
tags:
---
随着AI快速发展，AI技术可以说已经渗透到了我们的生活和工作中。在开发领域，代码生成工具可以说是百花齐放，无处不在。而测试工具就寥寥无几了。

在现代Web开发中，自动化测试已经成为提高开发效率和保证代码质量的重要手段。随着前端应用变得越来越复杂，传统的UI自动化测试方法面临着一些挑战，例如页面结构变化、动态内容加载等问题。为了解决这些问题，字节跳动推出了 MidScene.js ——一款AI驱动的UI自动化测试工具，旨在通过智能识别UI组件，帮助开发者更高效地进行自动化测试。它的目标是通过AI技术，自动识别和操作UI元素，从而进行自动化测试。与传统的基于选择器（如ID、class等）定位元素的自动化测试工具不同，MidScene.js通过机器视觉、图像识别和文本分析来识别和操作页面元素。

在本文中，我们将深入探讨 MidScene.js 的工作原理、使用场景以及如何在项目中利用它进行UI自动化测试。
![midscenejs](./images/midscenejs/bg.png)

# MidScene.js的工作原理
MidScene.js 的核心原理是通过AI来分析页面内容，识别UI组件，并模拟用户操作。它的工作流程可以分为以下几个步骤：

![工作原理](./images/midscenejs/principle.png)

1. 页面截图与UI元素分析
- MidScene.js首先对页面进行截图或解析DOM，捕捉页面的视觉内容。
- 然后，利用AI技术分析页面中的各种元素（按钮、输入框、图片等），并识别它们的功能和行为。
2. 元素定位与事件触发
- 识别到UI元素后，MidScene.js通过AI定位它们的位置和交互方式，不需要依赖传统的CSS选择器。
- 一旦定位到目标元素，它会模拟用户操作，如点击、输入、滑动等，触发相应的事件。
3. 状态验证与测试反馈
- 在执行操作后，MidScene.js会检查页面的反馈，验证UI是否按照预期行为进行反应。
- 如果出现异常或不符合预期的行为，MidScene.js会生成详细的测试报告。


# MidScene.js到底怎么样？
为了帮助大家更好地理解如何使用MidScene.js，以及MidScene.js到底效果怎么样。 下面我们通过一系列简单的场景，展示如何通过MidScene.js进行UI测试。同时我们把playwright和midscenejs的测试过程和结果进行对比。通过对比让大家更好地理解MidScene.js的强大功能。

## 登录页面自动化测试
登录可以说是web应用测试中的代表场景之一了。这里我实现了一个简单的测试场景，实现登录页面的自动化测试。
![登录页面](./images/midscenejs/login.png)

### playwright
playwright测试脚本如下
```js
import { test, expect } from '@playwright/test';

test('用户可以成功登录', async ({ page }) => {
  // 1. 访问登录页面
  await page.goto('http://localhost:8000/login.html');
  // 2. 输入用户名和密码
  await page.fill('input[name="username"]', 'admin');
  await page.fill('input[name="password"]', '1234');
  // 3. 点击登录按钮
  await page.click('input[type="submit"]');
  // 4. 断言是否跳转到首页或某个特定页面
  await expect(page).toHaveURL(/.*list.*/);
});
```
测试报告如下
![playwright测试报告](./images/midscenejs/playwright-report.png)
### MidScene.js
这款 AI 工具最令人兴奋的一点是它能够使用<font color="#dd0000">自然语言</font>。只需描述测试步骤要做什么，它就可以开始。

MidScene.js测试脚本如下

```js
import { AgentOverChromeBridge } from "@midscene/web/bridge-mode";
import * as dotenv from 'dotenv';

dotenv.config();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
Promise.resolve(
  (async () => {
    const agent = new AgentOverChromeBridge();

    await agent.connectNewTabWithUrl("http://localhost:8000/login.html");

    await agent.ai('在“用户名”输入框里面输入“admin”');
    await agent.ai('在“密码”输入框里面输入“1234”');
    await agent.ai('点击“登录”按钮');
    await sleep(3000);

    await agent.aiAssert("跳转'键盘列表'页面”");
    await agent.destroy();
  })()
);
```
测试过程如下，这里我用的桥接模式进行测试的，方便大家看到整个过程。
![测试过程](./images/midscenejs/midscene-login.gif)
每次测试脚本执行完成之后midscene会生成一份测试报告
![测试报告](./images/midscenejs/login-result.png)
我们可以看到具体的测试结果
![测试结果](./images/midscenejs/login-report.png)

### 对比
从这个场景中我们大致可以得出以下结论：
1. 可写/读性：

  - 👍 可书写算是一大亮点吧 ，大大降低了维护自动化脚本对前端的要求。可读性那必须是MidScene的强项了，基本上是所见即所得，完全不需要去找元素对应。

  - 👎没有办法隐藏一些敏感信息（用户名和密码），需要在提示词中直接发送这些内容，而如果没有 Midscene.js，可以在单独的数据文件中隐藏它们。

  - 👎阅读起来可能比较冗长。 比起代码来说，描述起来的文本可能会稍微长一些。


2. 执行时间：

  - 👎由于 Midscene.js 依赖第三方的AI 提供支持还需要屏幕截图，因此执行时间非常慢。AI 需要时间来规划和“思考”它需要做什么。报告和 JSON 输出清楚地显示了完成每项任务所需的时间。

  - 👎在 Playwright 中，通过角色（role）定位元素是一种推荐的做法，并且能够自然地测试 Web 应用的无障碍性（a11y）。而 Midscene.js 使用的是截图方式，因此偏离了这种做法。

  ![定位](./images/midscenejs/midscene-locate.png)

  整个运行事件也基本上在我们的预期里面吧

  - MidScene.js 的执行时间在 36 秒左右。
  - Playwright 的执行时间在 5 秒左右。

3. 可维护性：
  - 👍如果重构我们上面的登录页面（ ID、标签），测试用例可能仍会正确执行所有的操作。但是如果是 Playwright 就需要做些维护工作了。
  - 👎如果需要对测试脚本进行维护，调试过程将是反复试错。我们需要通过反复更改测试的提示词来进行。
  - 👎Playwright 测试是采用 页面对象模式编写的，这有助于保持代码的可维护性和可扩展性。而在 Midscene.js 中，测试是直接写在测试文件中的，这正是 Midscene.js 设计的初衷。因此，虽然使用自然语言编写测试速度快且简单，但如果需要修改多个测试文件，将会变得非常麻烦。

## 登录失败案例
下面我们来看一个失败的测试案例，看看MidScene.js到底有多智能。

更改上面登录的脚本，把密码改成错误的密码，看看测试结果如何。
```js
Promise.resolve(
  (async () => {
    const agent = new AgentOverChromeBridge();
    await agent.connectNewTabWithUrl("http://localhost:8000/login.html");
    await agent.ai('在“用户名”输入框里面输入“admin”');
    await agent.ai('在“密码”输入框里面输入“wrong password”');
    await agent.ai('点击“登录”按钮');
    await sleep(3000);

    await agent.aiAssert("用户无法登录");
    await agent.destroy();
  })()
);
```
查看报告的结果可以很好的让我们知道它是如何做的断言, 断言也是根据语义结合具体的场景来判断的，非常的灵活！
![失败案例](./images/midscenejs/fail.png)

# 总结
通过AI驱动的 MidScene.js，开发者可以轻松进行自动化UI测试，减少传统UI测试中的元素选择和维护负担。它能够适应动态变化的UI，智能识别和操作页面元素，极大地提升了自动化测试的效率和准确性。无论是回归测试，还是复杂UI交互的自动化，MidScene.js都能够为开发者提供强大的支持。

## 优势：
 - 快速的初始和用例编写，易于使用，简单、快捷
 - 适应动态变化的UI
 - 可读性（自然语言）
 - 可能是一个很好的UI自动化测试工具

## 劣势：
 - 执行时间较长
 - 缺乏使用变量的能力
 - 仅捕获当前窗口中可见的内容 
 - 需要一个框架来在提示中使用正确的语言，以提高操作和断言的准确性（否则可能需要反复调试，或者同一个测试用例偶发失败的问题）
 - 第三方AI需要读取浏览器截图，是否可能存在安全问题（第三方AI是否会存储截图？）

希望这篇文章能帮助你更好地理解和使用MidScene.js，如果你有任何问题或建议，欢迎在评论区留言！感兴趣的老铁也可以访问[MidScene.js](https://midscenejs.com/)的官网了解更多信息，也可访问老夫的[GitHub](https://github.com/ItProHub/midscenejs)获取完整的示例代码