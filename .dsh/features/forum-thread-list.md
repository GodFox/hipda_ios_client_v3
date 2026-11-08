# 版块帖列表

## 职责

展示某个版块的帖子列表：首屏加载、下拉刷新、上拉加载更多、点击进入读帖；提供两种滑动操作（直达最后一页、预载入“待读”）。这是 App 的首屏（`HPRearViewController` 创建它作为 front 导航栈的根）。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPRearViewController.m:100](../../HiPDA/Controller/HPRearViewController.m) | 侧边菜单 `setup` 中创建默认版块的 `HPThreadViewController` |
| [HPThreadViewController.m:76](../../HiPDA/Controller/HPThreadViewController.m) | `-initDefaultForum:title:` |
| [HPThreadViewController.m:88](../../HiPDA/Controller/HPThreadViewController.m) | `-viewDidLoad`：配置导航按钮、行高、KVO、刷新控件并首次加载 |
| [HPThreadViewController.m:191](../../HiPDA/Controller/HPThreadViewController.m) | `-loadForum:title:` 切换版块 |
| [HPThreadViewController.m:197](../../HiPDA/Controller/HPThreadViewController.m) | `-load:refresh:` 核心加载逻辑（区分刷新 / 点击刷新 / 加载更多） |
| [HPThreadViewController.m:327](../../HiPDA/Controller/HPThreadViewController.m) | `-refresh:`（下拉或点击刷新） |
| [HPThreadViewController.m:350](../../HiPDA/Controller/HPThreadViewController.m) | `-loadmore:` |
| [HPThreadViewController.m:398](../../HiPDA/Controller/HPThreadViewController.m) | `-tableView:didSelectRowAtIndexPath:` 打开读帖页 |
| [HPThreadViewController.m:527](../../HiPDA/Controller/HPThreadViewController.m) | `-addActionsForCell:forRowAtIndexPath:` 左右滑手势 |
| [HPThread.m:79](../../HiPDA/Model/HPThread.m) | `+loadThreadsWithFid:page:forceRefresh:block:` 数据入口 |
| [HPThread.m:247](../../HiPDA/Model/HPThread.m) | `+extractThreads:` 列表 HTML 解析 |

## 核心代码位置

- 请求路径：`forum/forumdisplay.php?fid={fid}&page={page}`；当设置项“按发帖时间排序”开启时追加 `orderby=dateline`（[HPThread.m:107](../../HiPDA/Model/HPThread.m)）。
- 解析字段：tid、标题（含 HTML 实体解码）、标题颜色、作者 uid/用户名、开始日期、回复数；4d4y 的列表模板不提供浏览数和附件标记（`openCount` 固定为 0，`hasImage`/`hasAttach` 固定为 NO）。
- 模型：`HPThread`，`pageCount = replyCount / 50 + 1`（[HPThread.m:51](../../HiPDA/Model/HPThread.m)）；`-shortDate` 把日期转成“今天 / 昨天 / 前天 / N天前 / MM-dd / yyyy-MM-dd”（[HPThread.m:310](../../HiPDA/Model/HPThread.m)）；实现 `NSCoding` 以便缓存。
- Cell：[HPThreadCell.m:93](../../HiPDA/View/HPThreadCell.m) `-configure:`（标题、作者、回复数 + 短日期副标题；4d4y 列表不提供浏览数时不再显示 `/0`；有浏览数时显示“回复/浏览”），[HPThreadCell.m:235](../../HiPDA/View/HPThreadCell.m) `+heightForCellWithThread:width:` 自适应行高；标题/副标题宽度不再固定 320，而是按 `contentView` / `tableView.bounds` 的实际宽度计算。
- 翻页/加载更多视图：`EGORefreshTableFooterView`，通过 KVO 监听 `contentOffset` 调整 footer 位置（[HPThreadViewController.m:434](../../HiPDA/Controller/HPThreadViewController.m)、[HPThreadViewController.m:499](../../HiPDA/Controller/HPThreadViewController.m)）。

## 执行流程

### 首次加载 / 刷新

1. `viewDidLoad` 里 `[self refresh:[UIButton new]]`，`refresh:` 判断 sender 类型：`UIRefreshControl` → 下拉刷新，`UIButton` → 点击刷新（右侧刷新按钮换成菊花）。
2. `_current_page = 1`，调用 `-load:refresh:`，最终调用 `HPThread +loadThreadsWithFid:page:forceRefresh:`。
3. 缓存优先：非强制刷新且 `HPCache loadForum:fid:page:` 有值（60 秒内）时直接回调缓存数组，不发请求。
4. 网络成功后：把字典数组构造成 `HPThread` 数组（补 fid）→ `HPCache cacheForum:` → 回调。
5. 控制器：`_threads` 整体替换 → `reloadData`；点击刷新会滚回顶部；结果为空时弹提示（引导去网页个人中心把每页帖子数改回默认，因为置顶帖过多会导致首页解析为空）。
6. 1 秒后添加 load-more 视图。

### 加载更多

1. 拖到底部超过阈值（-65）触发 `-loadmore:`：`_current_page + 1`，`-load:LoadMore`（`forceRefresh:NO`，因此会命中 60s 缓存）。
2. 合并时以 tid 去重（O(50²) 双层遍历），只对新增行做 `insertRowsAtIndexPaths` 动画。
3. 完成后 `-loadMoreDone` 复位内容 inset 与 footer 状态。

### 点击行

- 标记已读（`HPThreadCell -markRead` + `HPCache readThread:`）→ push `HPReadViewController initWithThread:`（默认第 1 页）。详见[读帖页](thread-reader.md)。

### 左右滑操作（MCSwipeTableViewCell）

| 方向/状态 | 图标 | 行为 |
| --- | --- | --- |
| state3 | `last.png` | 打开**最后一页**：`HPReadViewController initWithThread:page:NSIntegerMax forceFullPage:YES` |
| state4 | `clock.png` | 预载入“待读”：标记已读 → `HPIndicator show` → `HPCache cacheBgThread:block:` 拉第 1 页正文并缓存（有效期取设置“待读内容保存时间”）→ 首次使用弹一次提示 |

- 触发阈值 `firstTrigger = 0.18`、`secondTrigger = 0.40`，开启图标动画。

## 数据流

```
HPRearViewController（切换版块时 -loadForum:title:）
        │
HPThreadViewController -load:refresh:
        │
HPThread +loadThreadsWithFid:page:forceRefresh:
        ├─ HPCache loadForum:fid:page:      （命中即返回）
        ├─ HPHttpClient GET forumdisplay.php
        ├─ +extractThreads: 正则 → 字典数组
        ├─ HPThread initWithAttributes:     （pageCount = 回复/50+1）
        └─ HPCache cacheForum:              （EGOCache，60s）
        │
UITableView ← HPThreadCell -configure:
        │
点击 ─→ HPReadViewController
滑右 ─→ HPReadViewController(最后一页)
滑左 ─→ HPCache -cacheBgThread: → HPNewPost 拉正文 → 待读列表
```

## 依赖关系

- 依赖：`HPThread`（模型 + 解析）、`HPCache`（列表缓存 / 已读 / 待读）、`HPTheme`（背景、奇偶行色、指示器）、`HPSetting`（排序方式、头像开关、夜间模式）、`HPThreadCell`、`HPReadViewController`、`HPNewThreadViewController`（右上角发帖）、`HPRearViewController`（左侧菜单按钮、角标）、`HPIndicator`、`MCSwipeTableViewCell`、`EGORefreshTableFooterView`。
- 被依赖：`HPRearViewController`（切换 fid、后台刷新 `threadVCRefresh`）、`HPAppDelegate`（后台抓取时刷新列表并等待 `bgFetchBlock`）。
- 相关功能：[读帖页](thread-reader.md)、[本地缓存](local-cache.md)、[发帖与回帖](compose.md)、[后台刷新](background-fetch.md)、[侧边导航](navigation-menu.md)。

## 已知边界

- 解析正则绑定 4d4y 当前的版块列表模板（`td.list_user`、`td.listcon`、`a.title`、`class="num"`），不再依赖旧的 `normalthread_`；模板再改版会返回空列表而不是崩溃。
- 加载更多用“当前页 +1”策略，若两次请求之间版块有新帖插入，可能出现重复/漏帖；代码用 tid 去重缓解重复。
- `refresh:` 对未知 sender 只打日志，随后仍按“点击刷新”流程走（`type` 保持初值 0，即 PullToRefresh）。
