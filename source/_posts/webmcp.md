---
title: WebMCP：让网站直接对 AI Agent 说话
date: 2026-10-15 16:20:00
tags:
abstract: AI 操作网页不该靠截屏猜按钮。WebMCP 让网页自己把能力声明成结构化工具，由浏览器里的 Agent 直接调用。本文用一个能跑的求职项目，实测 14 个工具的三层权限、人工闸门与踩坑。
description: 网页自己把能力声明成结构化工具，浏览器里的 AI Agent 直接调用——这才是 WebMCP 想做的事。本文用 Career Copilot 项目实测 14 个工具的三层权限与人工闸门，并附国内数据源的绕行方案。
photos:
  - /blog/images/webmcp/cover.png
---

![WebMCP：让网站直接对 AI Agent 说话](./images/webmcp/cover.png)

> 前面几篇一直在讲 [MCP](https://itprohub.github.io/blog/2025/03/18/MCP/) —— 那是**给服务端开的一扇门**，站点要专门开发接口、配认证，Agent 还得能独立访问它。
>
> 这次把位置往前挪一步：如果这些工具不是服务端提供的，而是**你正在浏览的那个页面**当场声明出来的呢？
>
> 我把这个想法做成了一个能跑的项目，下面是完整记录 —— 包括它怎么工作、谁真的能调用它、以及我在国内环境下撞到的几堵墙。

---

# 🎬 一、让 AI 用网站，难在哪

先说一个具体的活：让 AI 帮我找工作。

它要看懂我的简历，去几个真实招聘板抓岗位、按我的情况打分排序、找出技能缺口、把过线的岗位准备成申请材料。整条链路十几步，其中只有最后一步是真正以我的名义对外动作 —— 提交申请。

问题在于，**怎么让 AI 用上“招聘网站”这个能力？**

今天最主流的办法是视觉自动化：截屏、识别像素、模拟点击、再截屏。这条路能跑通，但它有三个天生的毛病：

* **脆弱** —— 页面改一个 CSS 类名，脚本就可能瞎了；
* **慢** —— 每一步都要等页面渲染、等跳转；
* **没有语义** —— 模型知道它点了一个按钮，但不知道“点下去意味着什么”。它分不清“加入收藏”和“提交申请”，因为两者在像素层面长得很像。

我此前写 [Midscene.js](https://itprohub.github.io/blog/2025/02/27/midscenejs/) 和 [OpenAI Operator](https://itprohub.github.io/blog/2025/02/12/openai-operator/) 时，讲的就是这条路线上的两种实践。它们已经很聪明了，但**AI 依然是在猜一个界面，而不是在调用一个能力**。

WebMCP 把这件事反过来做：**让网页自己把能力声明出来。**

---

# 🕰️ 二、三代做法：从像素到函数

![从视觉自动化到 WebMCP 的三代做法](./images/webmcp/three-generations.png)

画面上的三代做法，本质是**作用范围在收敛**：

| 做法 | AI 看到的 | 依赖 |
| --- | --- | --- |
| 视觉自动化 | 一片像素 | 页面长相稳定 |
| 远程 MCP | 一组服务端接口 | 站点愿意开发并开放 |
| **WebMCP** | **一组页面内的具名函数** | **页面愿意声明** |

WebMCP 的核心 API 只有几个，短得不像一个“框架”：

```js
document.modelContext.registerTool({
  name: 'match_profile',
  description: '给每个岗位按简历打分并排序',
  inputSchema: { type: 'object', properties: { topN: { type: 'number' } } },
  annotations: { readOnlyHint: true },      // ← 告诉 Agent：这一步只是读
  async execute(args) {
    return { scored: 131, aboveThreshold: 1 };   // ← 必须返回结构化数据
  },
});
```

工具跑在**页面自己的 JS 上下文**里，所以它天然继承了两样东西：**你已经登录的会话**，以及**页面自己定的权限边界**。

这两点恰恰是远程 MCP 拿不到的。也是 WebMCP 与 MCP 最根本的分野 —— 后面第九节会专门讲它替代不了谁。

---

# 🧱 三、把它做成一个能跑的东西

空谈 API 没意思。我把它落成了一个真实的项目：**Career Copilot**，一个单文件页面（`index.html`）+ 一个零依赖的本地 Node 代理。

它把求职流程拆成 **14 个 WebMCP 工具**，打开页面就注册进浏览器：

![页面顶部：WebMCP 已就绪，注册了 14 个工具](./images/webmcp/page-top.png)

数据是真的 —— 不是 mock。海外源直连 Greenhouse / Ashby 的公开职位板，一次能抓 150 个在招岗位（GitLab 一个板就有 215 个岗，保留 117 个工程/设计岗）；国内源接腾讯招聘。匹配打分也是本地确定性算法，不看模型脸色。

![真实抓取：腾讯招聘 30 个岗位保留 26 个，GitLab 215 个保留 117 个](./images/webmcp/mission-log.png)

上图这段日志值得多看一眼。它是页面中栏的实时记录，每一行都对应**一次真实的工具调用**：

```text
→ tool parse_resume({})
✓ result Parsed profile: 陈默 · staff · 13 yrs · focus 后端 · 18 skills
→ tool set_preferences({"keywords":["前端"],"remoteOnly":false,"minScore":60})
→ tool aggregate_openings({"sources":["gitlab","tencent"],"limit":150})
  抓取 腾讯招聘（关键词：前端） …
✓ result 腾讯招聘: 30 个岗位 → 保留 26 个工程/设计岗
✓ result Aggregated 143 live roles. (2665ms)
→ tool match_profile({})
✓ result Scored 131 real job descriptions. 1 above the 60% threshold. (348ms)
```

**注意：上面这一串不是我手点的，是 Agent 自己决定的调用顺序。** 这就是整件事最关键的一步 —— 页面没有写任何“给 Agent 用”的适配代码，它只是把工具声明出来了。

---

# 🚪 四、核心设计：三层权限与一道人工闸门

14 个工具不是平铺的，我按**“这个动作能不能撤销”**把它们分成三层：

![14 个工具的三层权限划分](./images/webmcp/tiers.png)

| 层级 | 数量 | 典型工具 | 约束 |
| --- | --- | --- | --- |
| 只读 `readOnlyHint` | 7 | `parse_resume`、`match_profile`、`find_gaps` | 自由调用 |
| 可逆 | 6 | `set_preferences`、`shortlist`、`import_openings` | 自由调用，随时可改回 |
| 不可逆 `consequentialHint` | 1 | `submit_batch` | **必须由人点击批准** |

页面右栏就是这份清单的实拍 —— 每个工具都带着它的分级和权限标注：

![页面里的工具面板：14 个工具按只读 / 可逆 / 不可逆三档列出](./images/webmcp/tools-panel.png)

只有 1 个工具需要人工确认 —— 因为只有 1 个真的**以我的名义对外动作**。

![人工审批闸门：唯一不可逆的工具，Agent 无法自行通过](./images/webmcp/gate.png)

这里有个我特意验证过的设计，也是整个项目我最想讲的一点：

> **即使 Agent 在调用时传了 confirm 为 true，闸门依然会拒绝。**

实测返回值：

```json
{ "status": "awaiting_approval", "blocked": true, "pending": 4 }
```

原因很简单 —— 闸门代码只看 `state.gate.approved` 这个状态，而这个状态**只能由页面里的一次真实点击产生**。Agent 说什么都没用。

> **提示词是建议，代码才是约束。**

我在 [AI 安全那篇](https://itprohub.github.io/blog/2026/01/15/ai-security/) 里写过类似的观点：永远不要指望模型“自己判断”自己是否有权执行高危操作。这里就是它的一个具体实现 —— 你把安全边界写进系统提示词，那是君子协定；写进代码，那才是边界。

这个设计不是我拍的脑袋。它来自一篇文章，我在最后会说明出处。

---

# 📡 五、谁来当这个“浏览器里的 Agent”

这部分是我花时间最多、也最容易踩坑的地方。

WebMCP 的消费方不是你我，是**浏览器里的 AI Agent**。而“浏览器里的 AI Agent”目前有好几种形态，能力差别很大：

| 消费方 | 能读页面工具吗 | 说明 |
| --- | --- | --- |
| **Gemini in Chrome** | ✅ | 浏览器自带，无需装扩展 |
| **ChatGPT Site Tools** | ⚠️ 仅限桌面 App 内置浏览器 | 网页版与 Chrome 扩展**都不支持** |
| **Model Context Tool Inspector** | ✅ | Google 出的调试扩展，需自备 Gemini Key |
| 视觉自动化 Agent | ❌ | 它只会看屏幕，看不见工具清单 |

## 📌 为什么“网页版 ChatGPT”不行

这不是“还没做”，是**架构决定的**：

* **工具绑在“页面 + 你的登录会话”上。** Agent 必须和你在同一个活着的页面里工作，工具的 `execute` 跑在页面的 JS 上下文里，继承你的 cookie。而网页版 ChatGPT 是另一个网站，它手上没有“你正在浏览的那个页面”。
* **想用 iframe 嵌进来也不行。** WebMCP 明确规定 **iframe 内注册的工具不被发现** —— 工具注册受 `tools` 这个 Permissions Policy 管控，默认只允许同源。

一句很形象的总结：**网页版没长手** —— 它连你本机的 `localhost` 都够不到。

这也解释了一个容易被忽略的事实：**页面的“注册工具”这件事本身就是对接**。你不需要为 Inspector 写一套代码、为 ChatGPT 再写一套 —— 换谁当大脑，工具契约都是同一份。

---

# 🧪 六、实测踩坑记录

这一段可能是全文对你最有用的部分。以下每一条都是我在真机上撞出来的。

## 🛠️ 1. 浏览器开关的名字，不是文档里那个

Chrome 155 默认**不启用** WebMCP。我是从 flags 页面里看到实验室开关名是 `enable-webmcp-testing`，兴冲冲地把它当命令行参数传：

```bash
# ❌ 无效 —— 这只是 flags UI 里的 labs 名字
chrome --enable-webmcp-testing

# ✅ 有效
chrome --enable-features=WebMCPTesting
```

验证办法很直接：在控制台敲 `document.modelContext`，能打印出对象才算开了。

## 🔌 2. `file://` 打不开这条路

我一度想省掉本地服务，直接双击 `index.html`。实测结论是**页面这一半可以，另一半不行**：

* 页面本身**没问题** —— `document.modelContext` 存在，14 个工具照样注册成功；
* 但**扩展不会注入本地文件协议的页面** —— 即使它声明了 `<all_urls>`，Chrome 的默认策略也不覆盖 `file://`。

所以必须走 http。（顺带一提，WebMCP 还要求页面处于 **origin-isolated agent cluster**，我在静态响应里显式加了 `Origin-Agent-Cluster: ?1`，比依赖浏览器默认启发式更稳。）

## 📦 3. 工具的返回值必须给机器看，不能给人看

这是最坑的一条。我一开始让工具返回一句人话：

```js
return '已解析简历，共 18 个技能';
```

结果 Agent 第 4 步直接卡死 —— 下一步要按 `jobId` 去查岗位，但它**从这句话里拿不到任何 id**。

改成结构化返回后一路畅通：

```js
return { profileId: 'p_1', skills: 18, seniority: 'staff' };
```

> 教训：工具返回值是**喂给模型的 observation**，不是给人看的文案。给人看的文案应该由页面的 `render()` 单独负责。

## ⏱️ 4. 真模型规划一次调用，可能要 60 秒以上

接了模型增强后，简单问答 1.5 秒就回，但让它**规划下一步调哪个工具**时，单步经常超过 60 秒。我原本的代理超时是 60 秒，于是频繁失败 —— 改成 120 秒后才稳定下来。

## 🈶 5. 中文 JD 提不出技能

技能词典原本是纯英文的（`React`、`Kubernetes`…），结果中文 JD 一个都命不中 —— 30 个腾讯岗位只能打分 2 个。

扩了中文别名表（前端/后端/算法/运维…）并做规范名合并后，能打 20 个。**这不是模型问题，是词典问题** —— 本地确定性算法吃的是词表质量。

## 🧱 6. 国内招聘接口，一律没有 CORS 头

这是最有中国特色的一堵墙：

| 站点 | 障碍 | 我的解法 |
| --- | --- | --- |
| 腾讯招聘 | 无 CORS 头，浏览器直连必被拦 | 本地 Node 代理转发（代理只转发，不落库） |
| BOSS 直聘 | 无公开 API + `__zp_stoken__` 反爬 + 协议禁止自动化 | **你自己点一下**的书签桥接 |

BOSS 那条我最终没有硬闯。做法是给浏览器加一个书签：在 BOSS 搜索页点一下，它把当前页的岗位读成 JSON 放进剪贴板，再粘回页面导入。

为此加了第 14 个工具 `import_openings`（属可逆层），导入时按 url 或“标题 + 公司”**幂等判重** —— 同一份数据粘十次，也只算一次。

![](./images/webmcp/sources-panel.png)

## 🔀 7. 页面和代理分属两个端口时，得让它自己找

开发后期我的 4173 端口被本机一个 IIS 站点占用（物理路径正好就是项目目录），于是页面归 IIS、接口归 Node，分家了。

解决办法是给页面写了**代理自动发现**：启动时依次探测 `?proxy=` 参数 → 同源 → 若干候选端口，命中就挂上；全都失败就明确标记为“静态托管模式”，把国内源置灰并写明恢复方式，而不是让人勾了之后才失败。

代理侧的跨源放行**只认本机来源**（`127.0.0.1` / `localhost` 任意端口），刻意不做 `ACAO: *` —— 因为代理手里可能存着模型 Key，全网放行等于让任何网站的 JS 都能白嫖它。

---

# 🚧 七、它替代不了远程 MCP

WebMCP 很漂亮，但它有一个硬边界：**它只在标签页活着的时候存在，而且需要浏览器开关。**

| 维度 | 远程 MCP | WebMCP |
| --- | --- | --- |
| 位置 | 服务端，独立进程 | 页面内，随标签页生死 |
| 认证 | OAuth / Token | 直接继承浏览器会话 |
| 可发现性 | 事先配置好 | 打开页面即出现 |
| 能否对外服务 | ✅ 可长期运行、可多人共用 | ❌ 页面关了工具就没了 |
| 当前可用性 | 广泛支持 | 需要 flag，仍在实验阶段 |

所以这个项目**没法当作公开网站给普通人用** —— 它依赖浏览器实验开关。想分享给别人的话，分享代码和验证记录，而不是链接。

一句话总结两者的分工：

> **MCP 解决“Agent 怎么够到某个能力”，WebMCP 解决“Agent 怎么和你正在看的那个页面协作”。**

---

# 🧭 八、写在最后

把这条线串起来看，其实一直是在同一件事上往前走：

* [函数调用](https://itprohub.github.io/blog/2025/02/21/function-calling/) 解决了“模型怎么输出结构化动作”；
* [MCP](https://itprohub.github.io/blog/2025/03/18/MCP/) 解决了“工具怎么标准化地被发现和调用”；
* [Agent Harness](https://itprohub.github.io/blog/2026/09/24/agent-harness/) 说明了“模型之外那层骨架才决定下限”；
* **WebMCP 把这条链的最末端交给了网站自己** —— 站点不再被动地被爬、被猜，而是主动声明“我能做这几件事，以及哪些事你必须问我”。

我在 Harness 那篇里有个结论：**大模型的能力上限是模型决定的，但你实际拿到的能力下限，是 harness 决定的。** 放到这里可以再加一句：

> **当 Agent 真的开始替你操作真实世界时，“它会做什么”由模型决定，“它能不能做”必须由代码决定。**

最后做个坦白的说明：这个项目的**工具集设计、三层分级的思路，来自 Sreenath Menon 的文章**《WebMCP: Teaching Your Website to Talk to AI Agents》。我做的事情有三件 —— 把它在中文环境里真正跑起来、补上了国内数据源（腾讯 + BOSS 书签桥接 + 第 14 个工具 `import_openings`）、以及记录了上面这一路的实测坑。

原作者在那篇文章里有一个我很认同的判断：真正难的不是前面每一步自动化，而是**最后一英里** —— 那些企业的申请系统故意不开放接口，躲在登录和机器人检测后面。所以他的选择是“自动化到提交前一步，把提交留给人”。而 WebMCP 本该补上的，就是那个洞：如果招聘站自己暴露一个 `submit_application` 工具，Agent 就能在你已登录的会话里干净地提交。

一个悄悄用你名义投简历的 Agent 是**负债**；干完全部活、动手前问你一句的，才是**超能力**。

---

# 📚 参考资料

* [Sreenath Menon — WebMCP: Teaching Your Website to Talk to AI Agents](https://sreenathmenon.com/blog/2026-08-04-webmcp-teaching-websites-to-talk-to-ai-agents/)
* [Chrome for Developers — WebMCP 实验性 API](https://developer.chrome.com/blog/webmcp-epp)
* [Model Context Tool Inspector（Chrome 扩展）](https://chromewebstore.google.com/detail/model-context-tool-inspec/gbpafapgefenggkahomfgkhfehlcenpd)
* [Chrome Platform Status — WebMCP](https://chromestatus.com/feature/5113594882125824)
* [Ashby Job Board API](https://api.ashbyhq.com/posting-api/job-board/linear)
* [Greenhouse Job Board API](https://boards-api.greenhouse.io/v1/boards/gitlab/jobs?content=true)
* [腾讯招聘查询接口](https://careers.tencent.com/tencentcareer/api/post/Query)

---
