# 侧边导航（主菜单）

## 职责

应用的主容器与一级导航：

- 用 `SWRevealViewController` 实现左右抽屉（左侧是自定义菜单，宽度 100）；
- 菜单包含：顶部工具栏（设置、搜索）、7 个固定入口（HOME、短消息、帖子消息、我的帖子、我的回帖、收藏、待读）、以及用户自定义的收藏版块列表；
- 维护未读数红点与 App 角标；
- 在主题/板块设置变化时统一刷新界面。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPAppDelegate.m:121](../../HiPDA/HPAppDelegate.m) | `-setupRootViewControllerWithWindow:` 组装 `SWRevealViewController`（rear = 菜单，front = 帖子列表导航栈），由 `HPSceneDelegate` 在 scene 连接后调用 |
| [HPRearViewController.m:60](../../HiPDA/Controller/HPRearViewController.m) | `+sharedRearVC` 单例（首次创建即 `setup`） |
| [HPRearViewController.m:70](../../HiPDA/Controller/HPRearViewController.m) | `-setup`：定义 7 个入口、读取收藏版块、创建首页 |
| [HPRearViewController.m:106](../../HiPDA/Controller/HPRearViewController.m) | `-vcAtIndex:` 惰性创建页面（用 NSNull 占位） |
| [HPRearViewController.m:125](../../HiPDA/Controller/HPRearViewController.m) | `+threadNavViewController` / [HPRearViewController.m:129](../../HiPDA/Controller/HPRearViewController.m) `+threadVCRefresh` |
| [HPRearViewController.m:192](../../HiPDA/Controller/HPRearViewController.m) | 行数：7 + 收藏版块数 + 1 |
| [HPRearViewController.m:197](../../HiPDA/Controller/HPRearViewController.m) | `-tableView:cellForRowAtIndexPath:`（红点、占位行、版块行） |
| [HPRearViewController.m:287](../../HiPDA/Controller/HPRearViewController.m) | `-tableView:didSelectRowAtIndexPath:` 导航分发 |
| [HPRearViewController.m:359](../../HiPDA/Controller/HPRearViewController.m) | `-switchToMessageVC` / [HPRearViewController.m:363](../../HiPDA/Controller/HPRearViewController.m) `-switchToNoticeVC` / [HPRearViewController.m:367](../../HiPDA/Controller/HPRearViewController.m) `-switchToVC:` |
| [HPRearViewController.m:387](../../HiPDA/Controller/HPRearViewController.m) | `-topCell`：设置与搜索按钮 |
| [HPRearViewController.m:450](../../HiPDA/Controller/HPRearViewController.m) | `-sharedRevealActionBI`：带角标的菜单按钮 |
| [HPRearViewController.m:474](../../HiPDA/Controller/HPRearViewController.m) | `-updateBadgeNumber` |
| [HPRearViewController.m:489](../../HiPDA/Controller/HPRearViewController.m) | `-forumDidChanged`（板块设置返回后刷新） |
| [HPRearViewController.m:499](../../HiPDA/Controller/HPRearViewController.m) | `-themeDidChanged` |
| [HPRearViewController.m:526](../../HiPDA/Controller/HPRearViewController.m) | `-revealController:didMoveToPosition:`（菜单展开时给前层加透明遮罩，点击收起） |

## 核心代码位置

- 固定入口（顺序即菜单顺序，对应 `vc_classes` / `vc_names`）：
  1. `HPThreadViewController` — HOME
  2. `HPMessageViewController` — 短消息
  3. `HPMyNoticeViewController` — 帖子消息
  4. `HPMyThreadViewController` — 我的帖子
  5. `HPMyReplyViewController` — 我的回帖
  6. `HPFavoriteViewController` — 收藏
  7. `HPBackgroundViewController` — 待读
- 收藏版块：`HPSettingFavForums`（fid 数组）与 `HPSettingFavForumsTitle`（名称数组），在设置 → 板块设定中维护；首页默认取第 0 个版块。
- 首页是**单例**：`_threadViewController` 在 `setup` 创建，`-vcAtIndex:0` 恒返回它；切换版块时通过 `-loadForum:title:` 复用同一个控制器，而不是新建实例。
- 菜单行结构（行数 = 7 + 收藏版块数 + 1）：第 0 行是顶部工具栏（高 64/44）；第 1–6 行对应 `vc_names` 的第 1–6 项（短消息…待读，高 44）；第 7 行是纯色“占位行”（高度撑满剩余屏幕）；第 8 行起是收藏版块行（高 44）。HOME 本身不占固定行，从版块行进入（点击版块行时若当前不在 HOME 会切回首页导航栈）。
- 红点：短消息行显示 `HPPMCount`，帖子消息行显示 `HPNoticeCount`（`HPRearCell -showNumber:` / `-hideNumber`）；菜单按钮本身用 `BBBadgeBarButtonItem` 显示两者之和。
- 未选中/选中态用 `HPRearCell` 的文字色切换，背景是打包的纹理图。

## 执行流程

### 打开某个固定入口

1. 用户点击行 `row < 7`：
   - 若 front 导航栈顶不是目标类：`[self vcAtIndex:row]`（必要时新建）→ `setFrontViewController:` 换成新的导航栈 → 0.1 秒后调用该页面的 `refresh:`；
   - 若已经是目标类：只收起菜单并对当前页 `refresh:`。
2. 目标页面都是 `HPBaseTableViewController` 子类，`refresh:` 触发自己的加载逻辑。

### 切换收藏版块

1. 点击 `row > 7`：算出版块下标。
2. 若当前 front 不是 HOME：切回共享的 thread 导航栈；若 fid 与当前不同，把导航栈重置为首页控制器并 `-loadForum:title:`。
3. 若当前就是 HOME：fid 不同则直接 `-loadForum:title:`，然后收起菜单。

### 未读与角标

1. 未读检查或消息/提醒列表加载完成后，写 `HPPMCount` / `HPNoticeCount`。
2. `-updateBadgeNumber`：设置 App 图标角标（之和）、更新菜单按钮角标、`reloadData` 重绘红点。
3. App 进入后台时 `HPAppDelegate` 也会把角标设为 `badgeNumber`。

### 通知弹窗跳转

`HPAppDelegate -alertView:clickedButtonAtIndex:` 点“查看”时调用 `-switchToMessageVC` / `-switchToNoticeVC`，内部复用 `-switchToVC:`（与菜单点击相同的“切换 front + 延时 refresh”逻辑）。

### 主题与板块变更

- 设置页关闭时调用 `-forumDidChanged`：重读收藏版块数组并重载表格（首页 fid 不在此处更新，切换版块时按需处理）。
- 夜间模式/显示头像变化时调用 `-themeDidChanged`：刷新首页与表格，并遍历已实例化的页面逐个转发。

## 数据流

```
HPSceneDelegate → HPAppDelegate -setupRootViewControllerWithWindow:
    → SWRevealViewController(rear=HPRearViewController, front=UINavigationController(HPThreadViewController))
                                     │
HPRearViewController
  ├─ vc_classes / vc_names（固定 7 项）
  ├─ HPSettingFavForums / HPSettingFavForumsTitle（版块行）
  ├─ HPPMCount / HPNoticeCount（红点与按钮角标）
  └─ vc_instances（惰性创建，NSNull 占位）
        │
点击行 → setFrontViewController + refresh: / loadForum:title:
```

## 依赖关系

- 依赖：`SWRevealViewController`、`HPSetting`、`HPAccount`（角标数）、`HPCommon`（导航栈包装、夜间模式）、`HPTheme`、`HPRearCell`、`BBBadgeBarButtonItem`、以及全部 7 个列表页面与 `HPSettingViewController` / `HPSearchViewController`。
- 被依赖：`HPAppDelegate`（根容器、通知跳转、后台刷新入口）、各列表页（左侧菜单按钮、`revealViewController` 手势）、`HPAccount`（更新角标）、`HPSettingViewController`（`forumDidChanged`）、`HPReadViewController`（`themeDidChanged` 转发）。
- 相关功能：[版块帖列表](forum-thread-list.md)、[短消息](private-message.md)、[帖子消息提醒](thread-notice.md)、[我的帖子/回帖](my-posts.md)、[收藏与关注](favorites-attention.md)、[设置](settings.md)、[主题与夜间模式](theme.md)。

## 已知边界

- 固定入口与收藏版块没有“更多/全部版块”入口，版块只能在设置里调整。
- 切换收藏版块只更新首页标题与 fid，不重建控制器；若之前在首页有下钻的历史页面，已在切换前把栈重置为单页（仅当 fid 变化时）。
- `-vcAtIndex:` 用 `[[C alloc] init]` 创建 UITableViewController 子类，而各子类数据装载逻辑在 `-setup`（由 `HPBaseTableViewController initWithStyle:` 调用），`-init` 是否触发 `initWithStyle:` 依赖 UIKit 实现，**待确认**；若不触发，列表页首屏数据只会在 `refresh:` 时加载。
- 菜单按钮是单例（`sharedRevealActionBI` 缓存一个 `BBBadgeBarButtonItem`），会被多个页面的导航栏共用同一个 `UIBarButtonItem` 实例；角标更新统一走 `-updateBadgeNumber` 重设并重载菜单。
