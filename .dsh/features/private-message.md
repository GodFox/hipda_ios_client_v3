# 短消息（私人消息）

## 职责

- 拉取“私人消息”列表（对方、摘要、日期、未读标记）并缓存首屏；
- 进入某个对话，用气泡式聊天界面展示历史消息、发送新消息；
- 未读清零（忽略提醒）、举报当前主题或楼层作者。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPMessage.m:31](../../HiPDA/Model/HPMessage.m) | `+sharedMessage`：从 EGOCache 恢复消息列表 |
| [HPMessage.m:53](../../HiPDA/Model/HPMessage.m) | `+loadMessageListWithBlock:page:` 消息列表 |
| [HPMessage.m:146](../../HiPDA/Model/HPMessage.m) | `+loadMessageDetailWithUid:daterange:block:` 对话详情 |
| [HPMessage.m:248](../../HiPDA/Model/HPMessage.m) | `+ignoreMessage` 忽略全部未读 |
| [HPMessage.m:290](../../HiPDA/Model/HPMessage.m) | `+sendMessageWithUsername:message:block:` 发送 |
| [HPMessage.m:381](../../HiPDA/Model/HPMessage.m) | `+report:message:block:` 举报 |
| [HPMessageViewController.m:32](../../HiPDA/Controller/HPMessageViewController.m) | 消息列表页 |
| [HPMessageViewController.m:98](../../HiPDA/Controller/HPMessageViewController.m) | `-ayscn:` 加载/翻页 |
| [HPMessageDetailViewController.m:29](../../HiPDA/Controller/HPMessageDetailViewController.m) | 对话页（`JSMessagesViewController` 子类） |
| [HPMessageDetailViewController.m:72](../../HiPDA/Controller/HPMessageDetailViewController.m) | `-refresh:` 拉取对话 |
| [HPMessageDetailViewController.m:112](../../HiPDA/Controller/HPMessageDetailViewController.m) | `-didSendText:fromSender:onDate:` 发送 |
| [HPRearViewController.m:359](../../HiPDA/Controller/HPRearViewController.m) | 侧边栏“短消息”入口 / 通知弹窗“查看”跳转 |

## 核心代码位置

- 列表接口：`forum/pm.php?filter=privatepm&page={page}&inajax=1`。4d4y 对旧 iPhone UA 会优先走 WAP 模板；不带 `inajax=1` 的 `pm.php`/`notice.php` 会返回 HTTP 500，加上后返回带 CDATA 的 AJAX HTML。
- 列表解析：新版模板为 `li#pm_*` + `p.cite` + `div.summary`，取 uid、用户名、日期串、摘要；未读标记（旧模板的 `NEW`）已不再出现。
- 对话接口：`forum/pm.php?uid={uid}&filter=privatepm&daterange=5&inajax=1#new`。
- 对话解析：`cite`（发言者）、日期、`div.summary`（正文，结构为 `<cite>名字</cite>日期</p><div class="summary">…`）；正文中的论坛小黄脸图片会被替换成“表情(路径)”文本，再整体转纯文本；日期按 `yyyy-MM-dd HH:mm` 解析；新模板已没有 `NEW` 标记，当前未读默认 NO（待确认）。
- 发送接口：先 `HPSendPost +loadParametersWithBlock:` 取 `formhash`，再 POST `forum/pm.php?action=send&pmsubmit=yes&infloat=yes&sendnew=yes`，字段 `formhash`、`message`、`msgto`、`pmsubmit`；成功识别“短消息发送成功”，否则截 `alert_` 段落作错误。
- 举报：GET `forum/?username={username}&message={message}`，只要网络返回即回调成功（见边界说明）。
- 列表缓存：EGOCache 键 `myMessageList`，只在第 1 页时写入（[HPMessage.m:47](../../HiPDA/Model/HPMessage.m)）。

## 执行流程

### 列表页

1. `HPRearViewController` 首次点击“短消息”时惰性创建 `HPMessageViewController` 并调用 `refresh:`。
2. `refresh:`：重置到第 1 页 → 下拉控件/菊花 → `-ayscn:` → `HPMessage +loadMessageListWithBlock:page:`。
3. 成功后：第 1 页写缓存 → 替换 `_message_list` → `reloadData` → 滚到顶部 → **把 `HPPMCount` 置 0 并调用 `HPRearViewController -updateBadgeNumber`**（进入列表即视为已读全部）。
4. 翻页：上一页按钮要求 `_current_page > 1`；下一页按钮要求当前列表条数 ≥ 50（论坛每页 50 条）。
5. 点击某行：构造 `HPMessageDetailViewController`，把该行的 `HPUser` 传进去。

### 对话页

1. `viewDidLoad`：设置标题“与 {用户名}”，气泡字体、输入框占位、“刷新”按钮、右滑返回手势；发送者取当前登录用户名。
2. `viewWillAppear` 自动 `-refresh:` → `+loadMessageDetailWithUid:daterange:` → 成功后 `reloadData` 并在主线程滚动到底部。
3. 发送：`-didSendText:` 调 `+sendMessageWithUsername:message:block:`；成功后把新消息追加到本地数组、播放发送音效、收起键盘并滚到底部。
4. 消息方向由 `username` 是否等于对方用户名决定（对方=incoming，自己=outgoing）；时间戳始终显示。

### 忽略未读（通知弹窗的“忽略”）

1. `+ignoreMessage` 拉第 1 页消息列表 → 对每条未读消息调用 `+loadMessageDetailWithUid:daterange:5` → 回调里把 `HPPMCount` 置 0。
2. 若遇到认证错误，3 秒后自动重试一次（仅一次）。

## 数据流

```
HPRearViewController / HPAppDelegate(通知“查看”)
        │
HPMessageViewController -ayscn:
        │
HPMessage +loadMessageListWithBlock:page:
        ├─ GET pm.php?filter=privatepm&page=
        ├─ EGOCache myMessageList（仅第 1 页）
        └─ 数组[{user, summary, dateString, isUnread}]
        │
点击行（传 HPUser）
        │
HPMessageDetailViewController
        ├─ GET pm.php?uid=…&daterange=5#new  → [{username, date, message, isUnread}]
        └─ 发送 → POST pm.php?action=send…（需 formhash）
```

## 依赖关系

- 依赖：`HPHttpClient`、`HPSendPost`（formhash）、`HPUser`（头像/uid）、`HPSetting`（未读计数）、`HPRearViewController`（更新角标）、`HPMessageDetailViewController`（JSMessagesViewController）、`NSString+HTML`（正文转纯文本）、`NSString+Emoji`（发送前转 emoji cheat codes）。
- 被依赖：`HPRearViewController`（菜单入口、通知跳转）、`HPAppDelegate`（“忽略”按钮）、`HPReadViewController`（楼层面板“发送短消息”/举报）。
- 相关功能：[账号与登录](account-auth.md)（掉登录态时重试）、[帖子消息提醒](thread-notice.md)（同一个未读计数体系）、[侧边导航](navigation-menu.md)。

## 已知边界

- 无网络撤销：发送成功后只是追加一条本地消息，没有服务端回执 id；刷新后以服务端数据为准。
- 对话页每次进入都重新拉 `daterange=5` 的固定范围，不能无限上翻历史。
- `+report:message:block:` 的接口形态与其他功能不同（把用户名与文本拼在 GET 路径里），且成功判定只看网络是否返回，实际是否被论坛接受未验证（待确认）。
- 列表页判断“还有下一页”用条数 ≥ 50，最后一页恰好 50 条时会多请求一次空页。
