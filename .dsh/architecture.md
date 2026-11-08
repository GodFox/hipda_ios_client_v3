# 架构说明

## 1. 总体形态

典型的 Objective-C MVC 三层 + 单例服务，附一层“网页解析”适配层：

```
┌──────────────────────────── Controller 层 ────────────────────────────┐
│ HPViewController / HPTableViewController（登录通知订阅、主题回调）        │
│ HPBaseTableViewController（侧滑手势、刷新控件、翻页按钮、关闭按钮）        │
│ HPRearViewController  侧边菜单与页面容器                                │
│ HPThreadViewController 版块列表   HPReadViewController 读帖             │
│ HPBackgroundViewController 待读   HPFavoriteViewController 收藏         │
│ HPMessageViewController / Detail   HPMyNotice / MyThread / MyReply      │
│ HPSearch / HPSetting / HPSetForums / HPBgFetch                          │
│ HPNewThread / HPReply / HPReplyTopic / HPImageUpload（编辑与上传）       │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ 直接调用类方法 / 单例，回调为 block
┌───────────────────────────────▼──────────── Model 层 ─────────────────┐
│ 业务模型：HPThread / HPNewPost / HPUser / HPForum                        │
│ 功能服务：HPAccount / HPFavorite / HPAttention / HPMessage / HPNotice    │
│           HPMyThread / HPMyReply / HPSearch / HPSendPost                 │
│ 基础设施：HPHttpClient（网络） / HPCache（EGOCache） / HPDatabase（FMDB） │
│           HPSetting（NSUserDefaults 字典） / HPTheme（配色）              │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
        ┌───────────────────────┼──────────────────────────┐
        ▼                       ▼                          ▼
   AFNetworking            EGOCache / SDURLCache       FMDB（uid.db）
   （论坛网页 HTML）        （列表/帖子/已读/待读）       （username→uid）
                                ▲
┌───────────────────────────────┴──────── View 层 ─────────────────────┐
│ HPThreadCell（列表行，含自适应高度） HPRearCell（菜单行）              │
│ MultilineTextCell（RETableViewManager 多行说明行）                     │
│ post_view.html / post_view_dark.html（读帖 WebView 模板与交互脚本）    │
└──────────────────────────────────────────────────────────────────────┘
```

## 2. 模块边界与职责

| 层 | 允许做的事 | 典型文件 |
| --- | --- | --- |
| Controller | 组织视图、触发请求、把模型转成 HTML/单元格、处理用户动作 | `Controller/*.m` |
| 业务 Model | 拼 URL、发请求、解析 HTML 成模型、读写缓存/设置、发通知 | `Model/HPThread.m`、`HPNewPost.m`、`HPSendPost.m` 等 |
| 基础设施 | 无业务语义的存取：HTTP 编解码、缓存 KV、偏好 KV、主题色、数据库查询 | `HPHttpClient`、`HPCache`、`HPSetting`、`HPTheme`、`HPDatabase` |
| View | 仅负责布局与渲染，不持有网络请求 | `View/*.m` |

依赖方向总体是 `Controller → Model → 基础设施`，但存在两类有意的反向依赖（了解改动影响时需注意）：

1. **Model 依赖 Controller**
   - `HPAccount` 在“未设置账号”时直接弹出 `HPLoginViewController`（[HPAccount.m:78](../HiPDA/Model/HPAccount.m)）；
   - `HPAccount` 在未读检查完成后调用 `[[HPRearViewController sharedRearVC] updateBadgeNumber]`（登录成功后刷新首页的动作由 `HPLoginViewController` 自己发起）；
   - `HPCache` 在预载待读时回调 `HPNewPost` 拉取正文。
2. **基础设施依赖业务**：`HPCache` 直接序列化 `HPThread` / `HPNewPost` 数组，`HPDatabase` 被 `HPNewPost` 用来补 uid。

## 3. 主要数据流

### 3.1 浏览版块（读）

```
HPThreadViewController
  └─ +[HPThread loadThreadsWithFid:page:forceRefresh:block:]
       ├─ 先查 HPCache loadForum:fid:page:（60s 有效），命中即回调
       ├─ HPHttpClient getPathContent:forum/forumdisplay.php?...
       │    └─ 响应字节 → GB18030 解码 → 若命中登录页标记则触发 HPAccount 重登并置错
       ├─ +[HPThread extractThreads:] 正则切出 tid/标题/作者/日期/回复数/浏览数/图片附件标记
       ├─ 生成 HPThread 数组（pageCount = replyCount/50 + 1）
       ├─ HPCache cacheForum:...（EGOCache，60s）
       └─ block(threads, nil) → UITableView 重载
```

### 3.2 读帖（读 → 渲染）

```
HPReadViewController
  ├─ loadView 建 UIWebView，加载 post_view.html 或 post_view_dark.html
  └─ -load:refresh:
       ├─ 模板占位替换：标题、字号（txtadjust）、行高（lineHeight）
       ├─ +[HPNewPost loadThreadWithTid:page:...]:
       │    ├─ HPCache 命中且带 find_pid 匹配 → 直接返回
       │    ├─ printable（第 1 页且未“只看某人”）→ 打印版页面解析
       │    └─ 否则桌面版 viewthread / redirect / goto 页面解析
       │         ├─ +[HPNewPost extractFuckPosts:] 按 pid 分块
       │         ├─ 每块解析作者、uid、日期、楼层、正文 HTML、附件图片
       │         ├─ +[HPNewPost findPageInfo:url:] 取 formhash/pageCount/title/fid/当前页/find_pid
       │         └─ HPCache cacheThread:info:tid:page:（默认 300s）
       ├─ 控制器把 posts 拼成 <li> 列表替换模板占位
       ├─ +[HPNewPost preProcessHTML:] 按网络类型决定图片是否折叠为占位
       └─ loadHTMLString 渲染；链接 scheme 由 webView 代理拦截
```

### 3.3 写（发帖 / 回复 / 图片）

```
编辑器（HPNewThread / HPReplyTopic / HPReply）
  ├─ +[HPSendPost loadParametersWithBlock:] → GET post.php?action=newthread&fid=57 → formhash/uid/hash
  │   （回复/引用场景改为 +[HPSendPost loadFormhashAndPid:...]，强制复读帖子页拿到 formhash 与正确楼层）
  ├─ 图片：HPImageUpload → +[HPSendPost uploadImage:...] → misc.php swfupload，成功后把附件码插入正文
  └─ +[HPSendPost sendPostWithContent:...] → POST post.php（reply / newthread）
        ├─ 请求体带 formhash、posttime、正文（正文自动追加设置里的“小尾巴”）
        ├─ 响应 HTML 中找 alert_info / alert_error 判定成败
        └─ 成功 → HPCompositionDoneDelegate → 通知列表/读帖页刷新
```

### 3.4 通知与角标

```
定时（每 5min）或后台 fetch
  HPAccount -_checkMsgAndNoticeStep1  pm.php?checknewpm=... 判断登录态
    └─ -_checkMsgAndNoticeStep2   memcp.php?action=credits 正则取“私人消息(n)”“帖子消息(n)”
         ├─ 写 HPSetting（HPPMCount / HPNoticeCount）
         ├─ -addLocalNotification（1 秒后本地通知，角标 = pm+notice）
         ├─ 回调 noticeRetrieveBlock（后台抓取的完成回调）
         └─ HPRearViewController -updateBadgeNumber（角标 + 侧边栏红点 + 菜单刷新）
```

## 4. 缓存与持久化布局

| 存储 | 位置/键 | 内容与失效 |
| --- | --- | --- |
| NSUserDefaults | `HPSettingDic` 一个字典 | 全部偏好项，`HPSetting` 整体读写；另存 cookie 归档、网络状态、登录用户名、formhash、引导提示标记 |
| Keychain | service `HPAccount` | 一行三段凭据：密码、安全提问编号、安全提问答案（[HPAccount.m:69](../HiPDA/Model/HPAccount.m)） |
| EGOCache | 多个前缀键 | `forum_{fid}_{page}`（60s）、`thread_{tid}_{page}`/`thread_info_{tid}_{page}`（默认 300s，可配置）、`read_{tid}`/`read_notice_{tid}_{pid}`（10 天）、`favorites`、`attention_{tid}`、`myThreads`、`myReplies`、`myNotices`、`myMessageList`、`kHPBgList`（待读列表，10 天） |
| SDURLCache | 内存 10MB / 磁盘 50MB | HTTP 层缓存，App 启动时替换 `NSURLCache` |
| SDImageCache | 默认 | 头像等图片 |
| FMDB | `Documents/uid.db`（首次从包内 `uid.sqlite` 拷贝） | 单表 `user(username, uid)`，约 8.8 万条 |

## 5. 依赖方向图（编译期）

```
Controller ──> Model ──> Helper ──> 系统框架/UIKit
    │            │           ▲
    │            └───────────┘（NSString 分类、颜色、图片工具）
    └────> View ──> Model（Cell 读取 HPThread / 设置 / 主题）
Vender：被 Controller/Model 直接 import（SWReveal、RETableViewManager、Hpple、DZWebBrowser、IDMPhotoBrowser、WUEmoticonsKeyboard、EGOCache 等）
```

- `Vender/` 是源码级引入，修改其源码会直接影响编译结果；`SWRevealViewController` 与 `IDMPhotoBrowser` 目录下有 `modified_log.txt`，说明被本地改过（待确认具体改动点，未逐行比对上游）。
- `Helper/StandardPaths`、`Helper/GTMNSString+HTML` 等为第三方工具分类，业务代码少量使用。

## 6. 线程模型

- 网络回调来自 AFNetworking 的队列，但所有 UI 更新都直接写在回调里（例如 `HPThreadViewController` 的 `block` 内直接 `reloadData`、`HPReadViewController` 直接 `loadHTMLString`），依赖 AFNetworking 1.3 回调在主线程执行的行为，代码中没有显式 `dispatch_async(main)`（仅 `HPImageUploadViewController` 压缩图片、`HPMessageDetailViewController` 滚动到底部、设置页清缓存显式切主线程）。
- 本地通知与后台抓取的完成回调在 `HPAppDelegate` 用计数器凑齐两个分支后再调用 `completionHandler`。

## 7. 扩展 / 修改时需要注意

1. 所有请求经 `+[HPHttpClient prepareHTML:error:]`，它在响应里发现登录表单标记会**立即触发重登**并给调用方一个认证错误；新增功能必须处理该错误码。
2. 新增列表类页面通常继承 `HPBaseTableViewController`，复用侧滑手势、刷新控件、翻页按钮；注意 `-setup` 是数据装载钩子、基类默认 `assert(0)`。
3. 新增偏好项要同时改 `+[HPSetting defualts]`，否则 `loadSetting` 的键补齐逻辑不会带入默认值（键缺失时读取返回 nil）。
4. 新增“主题相关”界面需实现 `-themeDidChanged`，并由 `HPRearViewController -themeDidChanged` 遍历已实例化的页面转发。
5. 读帖页的正文渲染强依赖 `post_view.html` / `post_view_dark.html` 中的占位符与 JS 函数名，改模板需同步 `HPReadViewController` 的替换逻辑。
