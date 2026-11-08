# 读帖页

## 职责

把论坛帖子正文渲染成移动端友好的 HTML 页面并支持交互：翻页 / 跳页 / 跳楼、只看楼主 / 查看全部、收藏与关注、举报、回复 / 引用 / 发短消息、查看图片、字号行距与夜间模式调整、下拉上一页 / 上拉下一页。是整个应用最复杂的界面（1723 行）。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPReadViewController.m:131](../../HiPDA/Controller/HPReadViewController.m) | `-initWithThread:`（第 1 页） |
| [HPReadViewController.m:137](../../HiPDA/Controller/HPReadViewController.m) | `-initWithThread:page:forceFullPage:`（`page = NSIntegerMax` 表示最后一页） |
| [HPReadViewController.m:153](../../HiPDA/Controller/HPReadViewController.m) | `-initWithThread:find_pid:`（按 pid 定位楼层） |
| [HPReadViewController.m:182](../../HiPDA/Controller/HPReadViewController.m) | `-viewDidLoad` |
| [HPReadViewController.m:218](../../HiPDA/Controller/HPReadViewController.m) | `-loadView`：UIWebView + 滚动监听 |
| [HPReadViewController.m:380](../../HiPDA/Controller/HPReadViewController.m) | `-load:refresh:` 核心：拼模板 → 拉正文 → 渲染 |
| [HPReadViewController.m:625](../../HiPDA/Controller/HPReadViewController.m) | `-webView:shouldStartLoadWithRequest:` 自定义 scheme 拦截 |
| [HPReadViewController.m:826](../../HiPDA/Controller/HPReadViewController.m) | `-actionSheet:clickedButtonAtIndex:` 全部动作分发 |
| [HPReadViewController.m:1271](../../HiPDA/Controller/HPReadViewController.m) | `-pageView` 翻页面板 |
| [HPReadViewController.m:1376](../../HiPDA/Controller/HPReadViewController.m) | `-adjustView` 字号/行距/夜间模式面板 |
| [HPNewPost.m:95](../../HiPDA/Model/HPNewPost.m) | `+loadThreadWithTid:page:forceRefresh:printable:authorid:redirectFromPid:block:` 数据入口 |
| [HPNewPost.m:184](../../HiPDA/Model/HPNewPost.m) | `+loadPrintableThreadWithTid:refresh:block:` 打印版解析 |
| [HPNewPost.m:422](../../HiPDA/Model/HPNewPost.m) | `+extractFuckPosts:` 桌面版按 pid 分块解析（4d4y 新模板：主楼 `div.detailcon`，回复 `li` + `div.replycon`） |
| [HPNewPost.m:672](../../HiPDA/Model/HPNewPost.m) | `+findPageInfo:url:` 提取 formhash / pageCount / title / fid / 当前页 / find_pid |
| [HPNewPost.m:836](../../HiPDA/Model/HPNewPost.m) | `+preProcessHTML:` 图片策略 |

## 核心代码位置

- 模板：`View/post_view.html`（明）与 `View/post_view_dark.html`（暗），占位符为标题、字号（`txtadjust`）、行高、楼层列表；页面内置 FastClick、`addNewStyle`、`img_click` 等脚本（模板内的函数名由控制器与解析代码约定）。
- 楼层 HTML 由控制器按 `HPNewPost` 字段拼装：作者、楼层号、相对时间、正文 HTML、头像 URL，并带 `data-id="floor://…"`；`_gotoFloor` 对应楼层加高亮 class。
- 模型：[HPNewPost](../../HiPDA/Model/HPNewPost.h)（pid、user、date、floor、body、body_html、images），实现 `NSCoding`。
- 请求路径（桌面版）：`forum/viewthread.php?tid=&page=`；只看某人加 `authorid=`；`page = 0` 走 `redirect.php?...goto=lastpost`；带 `find_pid` 时走 `redirect.php?goto=findpost&pid=&ptid=` 或 `gotopost.php`（[HPNewPost.m:128](../../HiPDA/Model/HPNewPost.m)）。
- 打印版：`forum/viewthread.php?action=printable&tid=`（无 fid、无 uid、无 formhash，所以需要 `HPNewPost.extractPosts` + 内置 uid 库补 uid，见 [uid 离线库](uid-database.md)）。
- 初始化参数 `printable` 的条件：`!_forceFullPage && 当前页 == 1 && 未开启“只看某人”`（[HPReadViewController.m:415](../../HiPDA/Controller/HPReadViewController.m)）。

## 执行流程

### 加载与渲染

1. `viewDidLoad` 读取字号/行高设置 → 建导航按钮 → 加左右滑手势 → `-load`。
2. `-load:refresh:`：清空 WebView → 按夜间模式选择模板文件 → 替换标题/字号/行高 → 先 `loadHTMLString` 显示空壳 → 调 `HPNewPost +loadThreadWithTid:…`。
3. `HPNewPost` 侧：
   - 缓存：若非强制刷新且缓存存在、且调用方给的 `find_pid` 与缓存 info 的 `find_pid` 一致 → 直接返回缓存；
   - 打印版分支：正则切出作者/时间/正文（4d4y 打印版在时间后多一个“标题”字段、换行由 `\r\n` 变为 `\n`，已兼容）；取首楼用户为作者，标题从前置正则中提取；超过 50 楼时把后 50 楼之后的 posts 缓存到 page=2，前 50 楼缓存到 page=1；
   - 桌面版分支：`+extractFuckPosts:` 解析主楼 `div.detailcon` 与回复 `li`/`div.replycon`，从 `space.php?uid=` 取用户名/uid、从 `authorposton`/`replytop` 取发表时间与楼层；正文里的站内引用链接被改写为自定义 scheme 以便点击跳楼；解析 `findPageInfo` 后按 tid+page 缓存（默认 300 秒）。
4. 回到控制器：保存 posts、用 `-refreshThreadInfo:find_pid:` 回填 thread 的 formhash/title/fid/pageCount/author、当前页、并按 pid 计算 `_gotoFloor`；把 posts 拼成列表 HTML 替换模板占位；`+preProcessHTML:` 按当前网络类型（WiFi / 蜂窝 / 其他）决定图片是否折叠成“点击查看图片”占位；再 `loadHTMLString` 渲染。
5. `-endLoad:` 收尾：结束刷新 HUD、更新 header/footer 视图、若来自“回复成功”则滚动到底部，若 `_gotoFloor` 非 0 则执行 JS 跳楼。

### 交互（WebView 回调）

| 自定义 scheme | 行为 |
| --- | --- |
| `floor://` | 打开该楼层的动作面板（举报/回复/引用/发短消息/只看该作者）；加载中会被忽略 |
| `image://` | 打开图片浏览器（`IDMPhotoBrowser`），并把该帖所有附件图作为图集 |
| `gotofloor://楼层_pid` | 当前页有该楼层 → JS 跳转；否则 push 一个带 `find_pid` 的新读帖页 |
| `video://` | 转成 http 后用系统浏览器打开 |
| `user://` | 预留，未实现 |
| 普通点击 | 若是本站 `viewthread.php?tid=` 链接 → push 新读帖页；其他链接用 `DZWebBrowser` 打开 |

### 动作面板（右上角“更多”）

- 第 1 页：举报 / 只看楼主或查看全部 / 浏览器打开 / 复制链接 / 细节调整。
- 非第 1 页：第一个按钮变为“刷新”。
- 楼层面板：举报 / 回复 / 引用 / 发送短消息 / 只看该作者或查看全部。

### 翻页与跳页

- 左右滑手势：右滑返回（第 1 页时同时取消未完成的正文请求），左滑下一页。
- 点击页码按钮弹出半模态面板：滑杆选页、Go、首页/上一页/下一页/末页；`canNext` 判断依据 `_current_page < pageCount`（pageCount 为 0 时视为还有下一页）。
- 下拉到底/顶部拖拽：第 1 页用 `UIRefreshControl`，其他页用 `EGORefreshTableHeaderView`；尾部 `EGORefreshTableFooterView` 在最后一页显示“没有更多”。

### 阅读设置

- 字号：`UIStepper` 50–200，步长 5，写入设置键 `HPSettingFontSizeAdjust`，用 JS 设置 body 的 `webkitTextSizeAdjust`。
- 行距：80–200，步长 5，写入 `HPSettingLineHeightAdjust`，用 JS 调用模板里的 `addNewStyle`。
- 夜间模式开关：写 `HPSettingNightMode` 后触发全局主题重载并重新加载本页。
- 面板用半透明遮罩点击关闭。

### 收藏 / 关注 / 回复 / 举报

- 收藏：`HPFavorite isFavoriteWithTid:` 决定图标；收藏走 `-favoriteWith:block:`，取消走 `-removeFavoritesWithTid:block:`（详见[收藏与关注](favorites-attention.md)）。
- 关注：`HPAttention isAttention:` / `-addAttention:block:` / `-removeAttention:block:`。
- 回复：`HPReplyTopicViewController`；楼层回复/引用：`HPReplyViewController`（详见[发帖与回帖](compose.md)）；发帖完成后 `compositionDoneWithType:error:` 会把当前页设为最后一页并重载，然后滚动到底部。
- 举报：弹确认框后调用 `HPMessage report:message:block:`（对当前动作楼层的作者，或楼主）。
- 发短消息：弹输入框后调用 `HPMessage sendMessageWithUsername:message:block:`。

## 数据流

```
HPThread（来自列表/搜索/收藏/消息…）
   │
HPReadViewController ── 模板 post_view(.dark).html
   │
HPNewPost +loadThreadWithTid: → 缓存 / 打印版 / 桌面版
   │        ├─ HPHttpClient（GBK 解码、登录检测）
   │        ├─ +[HPDatabase sharedDb]（打印版补 uid）
   │        └─ HPCache cacheThread:info:tid:page:（info 含 formhash/pageCount/find_pid）
   │
拼装 <li> 列表 → preProcessHTML → UIWebView 渲染
   │
JS scheme 回调 → 动作面板 / 图片浏览 / 跳楼 / 打开浏览器
```

## 依赖关系

- 依赖：`HPNewPost`、`HPThread`、`HPUser`、`HPCache`、`HPDatabase`、`HPFavorite`、`HPAttention`、`HPMessage`、`HPAccount`、`HPTheme`、`HPSetting`、`HPHttpClient`；`IDMPhotoBrowser`、`DZWebBrowser`、`IBActionSheet`、`KNSemiModalViewController`、`EGORefreshTableHeader/Footer`、`HPAlert`、`ALActionBlocks`、`UIView+AnchorPoint`。
- 被依赖：列表页（普通/最后一页）、收藏、待读、我的帖子/回帖、帖子消息、搜索、设置页的“回帖建议”入口。
- 相关功能：[版块帖列表](forum-thread-list.md)、[发帖与回帖](compose.md)、[本地缓存](local-cache.md)、[主题与夜间模式](theme.md)、[uid 离线库](uid-database.md)、[收藏与关注](favorites-attention.md)、[短消息](private-message.md)。

## 已知边界

- 正文解析全部基于正则匹配当时的论坛 HTML；`body_html` 直接来自网页，客户端只做链接/图片改写与“作者被禁止或删除”占位，不做完整的 HTML 清洗。
- 桌面版正文正则按第一个 `</div>` 结束；若楼层正文内含嵌套 div，可能截断（待确认，后续可改用 HTML parser）。
- 打印版解析出的 posts 没有 pid，因此“回复/引用”会走 `+loadFormhashAndPid:` 重新拉桌面版页面按“用户名 + 楼层”匹配目标楼层（见 compose 文档）。
- 读帖页 `UIWebView` 的初始 frame 改取当前 `UIWindowScene` 的 bounds；iOS 27 上 `UIScreen.applicationFrame` 可能返回 NaN 高度，会导致 `CALayerInvalidGeometry` 崩溃。
- 自定义 scheme 的 `user://` 分支为空实现（点了没反应）。
- 页码按钮在 `pageCount` 未知（为 0）时显示“当前页/?”，`_current_page` 为 `NSIntegerMax` 时显示“?/?”。
- 收藏与关注目前共用同一对心形图标资源，仅靠按钮位置区分。
- 阅读设置里的 `HPSettingFontSize` / `HPSettingLineHeight` / `HPSettingTextFont` 默认值未被读取（实际只用两个 `*Adjust` 键），属于遗留项。
