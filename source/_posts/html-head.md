---
title: 我的 HTML Head 清单：38 个标签的体检报告
date: 2026-09-29 15:10:00
tags:
  - HTML
  - SEO
  - Web 性能
  - Hexo
abstract: 我从没逐行读过自己博客的 head，直到把它 dump 出来数了数：38 个标签里，6 个是历史包袱、6 个是真 bug——分享卡片上我的站点名甚至一直显示成 Hexo。这是一次给自己博客做的元标签体检：哪些该删、哪些该修、哪些值得留。
description: 一次给博客 HTML head 做的逐项体检：38 个标签里挑出 6 个历史包袱和 6 个真 bug，附上判断依据与修法。
---

> 最近读到 Vale.Rocks 的《My HTML Boilerplate》，作者把自己手写的 HTML 骨架逐行拆开讲了一遍取舍，读起来很过瘾。
>
> 但我和他的情况不太一样：我的博客不是手写 HTML，是 Hexo 加主题模板生成的。这意味着 `<head>` 里那些标签**没有一行是我亲手写的** —— 它们是主题作者、插件和我的配置文件三方妥协的产物。
>
> 于是我做了件早该做的事：把线上页面 dump 出来，逐个标签看过去。

---

# 📋 一、为什么 head 值得单独看一遍

HTML 世界里有一条铁律叫 **"Don't Break The Web"** —— 1995 年写的网站在今天的浏览器里仍应能跑。为了这个承诺，HTML 采取了一种“存在即启用”的兼容策略：**新元素你写了就生效，不写就回退到旧行为**。

代价就是 `head` 里堆满了各种“可选但建议写”的标签。它们不决定页面长什么样，却决定了很多别的事：你被分享到微信里长什么样、暗色模式下会不会闪一下白屏、搜索引擎怎么理解这个页面、浏览器要不要提前加载某个字体。

更要命的是：**head 里标签的顺序会显著影响性能**。同样几个标签，换个位置，首屏可能差上几百毫秒。这也是为什么会有 Capo.js 这种专门评估 head 顺序的工具。

所以 `head` 是最容易积累技术债的地方 —— 它不影响功能，没人会因为它报错，于是没人回头清理。

我的博客已经跑了两年多，主题是从别处 clone 来的。我决定给它做一次体检。

---

# 🔬 二、体检方法：别看模板，看输出

这是第一个坑，先记下来：

**不要读你的模板文件，要读生成出来的 HTML。**

模板里写着 `config.description`，你以为输出的是站点描述；模板里写着条件判断，你以为某些标签不会渲染。但模板语言、主题默认值、插件注入会叠加在一起，最终可能和你想象的完全不是一回事。

一行命令就能拿到真相：

```bash
curl -s https://your-domain.com/some-page/ | sed -n '1,60p'
```

或者更省事：浏览器打开页面，`Ctrl+U` 看源码、`Ctrl+A` 全选 `head` 部分。

我把某篇文章的源码拖进编辑器，从 `<!DOCTYPE html>` 数到 `</head>`，结果是 **38 个节点**（不含 `head` 外面的脚本）：

```
身份与必需   █████              5
分享与语义   ████████████      12
样式与资源   █████████████     13
兼容与元信息 ████████           8   ← 包袱集中在这里
```

其中 meta 类 22 个、link 类 10 个、内联 script/style 3 个，外加一个 `meta generator`。

看着没感觉，一个一个念出来就不对劲了。

---

# 🗑️ 三、第一类：可以删掉的 6 个历史包袱

这些标签**没有一个是错的** —— 它们只是过时了，或者从来没真正生效过。删掉它们不影响任何功能。

## 1. `meta keywords` —— 搜索引擎早就不看了

```html
<meta name="keywords" content="hexo,ITProHub,hexo-theme,hexo-blog">
```

Google 在 2009 年就公开说明不再参考这个标签，原因是它被滥用得太彻底。百度也早已弱化。**2026 年了，它唯一的作用是告诉别人你不太懂 SEO。**

更尴尬的是我这份值：`hexo,ITProHub,hexo-theme,hexo-blog` —— 这是主题的**默认 SEO 关键词**，我两年都没改过。每篇文章的 keywords 都是这同一串，跟文章内容毫无关系。

## 2. `meta copyright` —— 非标准，无行为

```html
<meta name="copyright" content="乐予吕">
```

不在 HTML 规范里，没有浏览器或搜索引擎会读它。版权声明应该出现在页脚和 `LICENSE` 文件里，不是这里。

## 3. `meta renderer` —— 国产双核浏览器的遗物

```html
<meta name="renderer" content="webkit">
```

这是当年给 360、QQ 浏览器这类“双核”浏览器指定用哪个内核渲染用的（`webkit` 还是老 IE 核）。现在这些浏览器早已默认极速内核，这个标签的使命结束了。

## 4. `X-UA-Compatible` —— IE 专用，IE 已经退役

```html
<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
```

它的历史使命是让 IE 用最新的渲染引擎、或者借用 Chrome 的引擎。而 **IE 已经在 2022 年 6 月正式停止支持**。这个标签现在只会出现在“从不清理 head”的网站里。

## 5. `meta http-equiv="Cache-control"` —— 缓存该用响应头

```html
<meta http-equiv="Cache-control" content="no-cache">
```

这是常见误解：以为写上这行就能控制缓存。实际上 **缓存策略应该由服务端响应头决定**（`Cache-Control`、`ETag`、`Expires`），`http-equiv` 形式的缓存指令在实践中作用极其有限，而且写 `no-cache` 反而可能让浏览器做更保守的判定。

想要强缓存控制，去配置 Nginx 或 CDN，不要指望这里。

## 6. `meta generator` —— 白白暴露构建工具

```html
<meta name="generator" content="Hexo 6.3.0">
```

它由 Hexo 自动注入，等于在告诉全世界“我用 Hexo 6.3.0 生成”。这不构成真正的安全漏洞，但在自动化爬虫眼里是个有用的指纹 —— 而它对读者、对搜索引擎、对你都没有任何好处。

Hexo 里关掉它很简单，根 `_config.yml` 加一行：

```yaml
meta_generator: false
```

---

# 🐛 四、第二类：真正出问题的 6 个地方

接下来这 6 个不是“过时”，是**确实在产生错误行为**。

## 1. `og:site_name` 一直是 “Hexo”

这是最让我意外的一个。生成出来的源码里躺着这么一行：

```html
<meta property="og:site_name" content="Hexo">
```

站点名为什么会是 “Hexo”？因为 `open_graph` 辅助函数取的是配置里的 **config.title**，而我的根 `_config.yml` 那行还是脚手架生成的默认值：

```yaml
title: Hexo          # ← 从没改过
description: ''      # ← 也是空的
```

也就是说：我的文章被分享到微信、微博、Twitter 时，卡片上的站点名显示的是 **“Hexo”** —— 一个人家的产品名。

而页面 `<title>` 用的是主题里另一套配置（`theme.SEO_title`），显示“个人技术日常分享”，所以**站点内部看着一切正常，只有分享出去才露馅**。这种 bug 不看生成源码根本发现不了。

## 2. 输出了两个 `meta description`，第一个是空的

```html
<meta name="description" content="">
<meta name="description" content="Harness 本义是马具，在 AI 时代……">
```

第一行来自主题模板（读 `config.description`，而它是空的 `''`），第二行来自 Hexo 的 `open_graph`（读文章的 `description`）。两个同名标签是无效 HTML，爬虫取到哪个取决于实现 —— 有可能就是那个空的。

修法是补上站点描述（上面那行 `description: ''`），让两个标签都有意义，或者干脆改模板去掉重复。

## 3. `user-scalable=no` 在禁止用户缩放

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
```

这是主题模板里写的。`user-scalable=no` 会**禁用双指缩放**，对视障用户是硬伤害 —— 他们本来就需要放大来读文字。同理，`minimum-scale` 和 `maximum-scale` 也应该避免。

顺带一提：`initial-scale=1` 现在已经没有必要写了，`width=device-width` 就够了。

```html
<meta name="viewport" content="width=device-width">
```

## 4. 声明了 `twitter:card: summary`，却配了张大图

```html
<meta name="twitter:card" content="summary">
<meta name="twitter:image" content="https://.../cover.png">
```

`twitter:card` 的值决定了卡片样式：`summary` 是**小图**布局，`summary_large_image` 才是**大图横幅**。我的封面图是 1536×1024 的横图，配 `summary` 会被裁成小方图，等于白做。

## 5. 缺 `canonical`

我的博客现在有两个入口：

- `https://itprohub.github.io/blog/`（GitHub Pages 原生地址）
- `https://www.itprohub.site/blog/`（Cloudflare Tunnel 转发）

同一个页面两套 URL，却没有一行 `<link rel="canonical">` 告诉搜索引擎哪个是权威版本 —— 这正是 canonical 存在的意义，也是最该用它的场景。

```html
<link rel="canonical" href="https://www.itprohub.site/blog/2026/09/24/agent-harness/">
```

## 6. 缺 `color-scheme`，暗色模式会闪白

我的主题有完整的暗色样式（`dark.css`）和切换脚本，但没有声明：

```html
<meta name="color-scheme" content="light dark">
```

这一行告诉浏览器“本站支持明暗两套配色”。缺了它，一个系统设为暗色的用户打开我的博客，会先看到一瞬刺眼的白屏，然后脚本跑起来才切到黑色 —— 也就是所谓的 **FOUC（无样式内容闪烁）**。有了这一行，浏览器在解析阶段就知道该用深色底来绘制。

---

# ⚡ 五、第三类：性能上的小账

## 1. jQuery 同步加载，还卡在 `</head>` 和 `<body>` 中间

```html
</head>
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
    <script>
        if (typeof window.$ == undefined) {
            console.warn('jquery load from jsdelivr failed, will load local script')
            document.write('<script src="/blog/lib/jquery.min.js" />')
        }
    </script>
<body>
```

这是我这次找到的**性能问题第一名**：

- 这个 `<script>` 没有 `async` 也没有 `defer`，是**同步**的 → 浏览器必须下载并执行完 jQuery，才能继续解析后面的 `<body>`
- 它从 jsDelivr 加载，国内网络下这个请求的耗时完全不可控 → **首屏白屏时间会被它直接绑架**
- 还夹在 `</head>` 和 `<body>` 之间，位置本身就不规范

主题的用意是好的（从 CDN 拿，失败就 fallback 到本地），但代价太大。改成 `defer`、或者干脆把依赖降到 0（这年头用原生 JS 写前端交互完全够），首屏能立竿见影地变快。

## 2. 字体 preload 用的是 TTF，还缺了 type

```html
<link rel="preload" href="/blog/font/Oswald-Regular.ttf" as="font" crossorigin>
```

两个问题：

- **格式**：TTF 是未压缩的字体格式，同样的字样比 WOFF2 大 2～3 倍。既然都要 preload 了，就该给它最小体积 —— 换成 WOFF2 并补上 `type`：

```html
<link rel="preload" href="/blog/font/Oswald-Regular.woff2" as="font" type="font/woff2" crossorigin>
```

- **跨域属性**：`crossorigin` 是必须的（文中开头那篇作者特意强调过：即使字体同源也要写），这一点主题是对的 ✅

另外还有一行从 `at.alicdn.com` 拉的图标字体 —— **第三方 CDN 是个隐藏依赖**，它慢或者挂掉，你的图标就全变成方块。图标能内联成 SVG 就内联。

## 3. `?v=20211217` —— 版本号停在 2021 年

```html
<link rel="preload" href="/blog/css/style.css?v=20211217" as="style">
```

主题用 `theme.source_version` 给静态资源打版本号来破缓存，但这个值我两年没动过。结果就是：**我改了 CSS，老访客拿到的还是旧文件** —— 缓存失效机制形同虚设。改样式时顺手把这个版本号也改掉，或者交给构建流程自动生成哈希。

## 4. `dark.css` 被重复引用

```html
<link rel="preload" href="/blog/css/dark.css?v=20211217" as="style">
<link rel="stylesheet" href="/blog/css/dark.css">
```

同一文件先 preload（但没有转换逻辑）又直接以 stylesheet 引入。浏览器会去重，不会真的下载两次，但 preload 那一行纯属冗余 —— 后面那行 stylesheet 本身就会立即发起请求。

## 5. `head` 之前漏了 9 行注释和空行

```html
<html lang="zh-cn">
    <!-- title -->
    <!-- keywords -->
    ...
<head>
    <meta charset="utf-8">
```

主题模板里的变量声明逻辑（`<% var title = "" %>` 这类）在渲染后留下了注释和空行，**它们跑到了 head 开始之前**。

这件事的严重性在于：规范要求 `charset` 声明必须出现在**文档前 1024 字节内**，否则浏览器会重新解析。这些空格本身还不至于超限，但白白浪费字节、还让源码第一屏全是噪音。

顺带说，`lang="zh-cn"` 的规范写法是 `lang="zh-CN"` —— **地区子标签需要大写**（RFC 5646 的大小写规范：语言小写、地区大写）。浏览器匹配不区分大小写，所以不算 bug，但不规范。

---

# ✅ 六、第四类：值得留下的

体检不是只删东西。这套 head 里也有做得对的部分，值得点出来：

| 标签 | 为什么对 |
| --- | --- |
| `meta charset` **是 head 第一个元素** | 硬要求（前 1024 字节内），位置完全正确 |
| `viewport: width=device-width` | 响应式的开关，不能少 |
| `<title>` 用「页面名 · 站点名」格式 | 书签、搜索结果、标签页都靠它 |
| `og:*` / `article:*` 一整套 | 分享卡片的完整信息，比缺的强太多 |
| `link rel="icon"` | 品牌识别，尤其标签页多的时候 |
| 字体 preload 带 `crossorigin` | 很多人会漏掉这个属性 |
| 内联 critical CSS + loadCSS 异步加载主样式 | 主题这块做得相当专业，避免样式表阻塞 |
| feed 的 `rel="alternate"` | 让浏览器和阅读器能自动发现 RSS |
| `og:image` 用绝对 URL | 分享平台的硬要求，相对路径不认 |

还有一处可以升级：favicon 现在是 `.ico`。换成 **SVG** 会更好 —— 支持度已经足够，能自适应明暗模式，任何尺寸都清晰，还省掉维护一堆尺寸位图的麻烦。

另外我那张封面图是 1536×1024，而 OG 图片的通用推荐尺寸是 **1200×630**，后面统一一下。

---

# 🧭 七、所以，我怎么审计自己的站点

如果你也想给自己的站点做一次，流程大概是：

1. **看输出，不看模板** —— `curl` 或查看源码，把整个 `head` 复制到编辑器里
2. **逐个数一遍** —— 每个标签问三个问题：它还有效吗？它和我的配置一致吗？它值得占这个位置吗？
3. **查顺序** —— 用 Capo.js 评估 head 里的元素排序对性能的影响
4. **验证分享卡片** —— 用微信/Twitter/Facebook 的调试工具实际抓一次，看卡片长什么样（这一步会立刻暴露 `og:site_name` 那种 bug）
5. **跑一次 Lighthouse** —— 看首屏还有没有阻塞资源

顺便说，我这次是把 dump 出来的 `head` 整段丢给 AI，逐个标签问“这个还需要吗、写对了吗”，再拿 MDN 和规范核对一遍 —— 比我自己翻规范快得多，也比凭印象判断可靠。AI 时代的代码审计，工具链变了，判断力还是得自己出。

---

# 🧾 八、写在最后

这 38 个标签体检下来，我最大的感受不是“我的博客配置很烂”，而是：

> **你没读过的东西，你就不算拥有它。**

主题是别人写的、配置是脚手架生成的、标签是插件注入的 —— 每一环都很合理，叠起来就是一个两年没人看过的 `head`。它不会报错，不会崩溃，只是安静地拖慢你的首屏、在你分享文章时显示别人的产品名。

清理之后，我的 `head` 大概会从 38 个节点降到 30 个左右，多出来的空位留给真正有意义的东西：canonical、color-scheme，还有一张 1200×630 的封面图。

毕竟上一篇里我写过：**模型是引擎，“马具”才是那辆车**。`head` 大概就是网页那副马具 —— 它不提供内容，但决定了别人怎么看待你的内容。

---

# 📚 参考资料

* [Vale.Rocks — My HTML Boilerplate](https://vale.rocks/posts/html-boilerplate)
* [Manuel Matuzović — My HTML boilerplate in 2026](https://www.matuzo.at/blog/html-boilerplate/)
* [MDN — The metadata element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta)
* [MDN — The Document Head](https://developer.mozilla.org/en-US/docs/Learn/HTML/Introduction_to_HTML/The_head_metadata_in_HTML)
* [WHATWG HTML Standard — Pragmas and the head element](https://html.spec.whatwg.org/multipage/semantics.html)
* [Capo.js — head 元素顺序评估工具](https://rviscomi.github.io/capo.js/)
* [Open Graph Protocol 官方文档](https://ogp.me/)

---
