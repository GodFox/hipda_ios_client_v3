# 我的帖子 / 我的回帖

## 职责

两个只读列表，分别对应论坛“我的主题”和“我的回复”：

- **我的帖子**：`forum/my.php?item=threads`，展示自己发表的主题，点击从第 1 页打开。
- **我的回帖**：`forum/my.php?item=posts`，展示自己回复过的主题及回复摘要，点击按 pid 定位到具体楼层。

两者都是“第 1 页写缓存、进入即覆盖、支持上下页”的结构，没有本地增删操作。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPMyThread.m:23](../../HiPDA/Model/HPMyThread.m) | `+sharedMyThread`（EGOCache 键 `myThreads`） |
| [HPMyThread.m:40](../../HiPDA/Model/HPMyThread.m) | `+ayscnMyThreadWithBlock:page:` |
| [HPMyThread.m:108](../../HiPDA/Model/HPMyThread.m) | `-cacheMyThreads:` |
| [HPMyReply.m:22](../../HiPDA/Model/HPMyReply.m) | `+sharedReply`（EGOCache 键 `myReplies`） |
| [HPMyReply.m:38](../../HiPDA/Model/HPMyReply.m) | `+ayscnMyRepliesWithBlock:page:` |
| [HPMyReply.m:130](../../HiPDA/Model/HPMyReply.m) | `-cacheMyReplies:` |
| [HPMyThreadViewController.m:30](../../HiPDA/Controller/HPMyThreadViewController.m) | “我的帖子”页面 |
| [HPMyThreadViewController.m:103](../../HiPDA/Controller/HPMyThreadViewController.m) | `-ayscn:` |
| [HPMyReplyViewController.m:29](../../HiPDA/Controller/HPMyReplyViewController.m) | “我的回复”页面 |
| [HPMyReplyViewController.m:95](../../HiPDA/Controller/HPMyReplyViewController.m) | `-ayscn:` |
| [HPRearViewController.m:71](../../HiPDA/Controller/HPRearViewController.m) | 侧边栏注册这两个页面（顺序：我的帖子、我的回帖） |

## 核心代码位置

- “我的帖子”解析：从 HTML 中匹配 `<th>` 内的主题链接与版块 fid，得到 tid、标题、fid，构造 `HPThread`（无作者/日期字段）。
- “我的回帖”解析：匹配 `redirect.php?goto=findpost&pid=&ptid=` 形式链接，得到 pid、tid、标题、fid，以及 `lighttxt` 段落里的回复摘要（保留为 `replyDetail`，换行合并为空格）。
- 列表 Cell：均为 `UITableViewCell`；我的帖子单行显示标题；我的回帖用 subtitle 显示标题 + 摘要。
- 页面公共能力来自 `HPBaseTableViewController`：左侧菜单按钮、右上翻页分段控件、下拉刷新、侧滑手势。

## 执行流程

1. 侧边栏选择对应项 → `HPRearViewController -vcAtIndex:` 惰性创建控制器 → `HPBaseTableViewController initWithStyle:` 触发 `-setup`（从缓存单例取数据）→ `refresh:` 拉第 1 页。
2. `-ayscn:` → 对应 Model 的类方法 →
   - 成功且第 1 页：写 EGOCache；
   - 成功：替换本地数组、`reloadData`、滚到顶、闪烁滚动条；
   - 失败：`HPAlert` 提示错误；
   - 空结果：提示“您没有主题帖子 / 您没有回复帖子”。
3. 翻页：上一页要求 `_current_page > 1`；下一页要求当前条数 ≥ 44（我的帖子）/ ≥ 49（我的回复）。
4. 点击行：
   - 我的帖子：`HPReadViewController initWithThread:`（第 1 页）；
   - 我的回帖：`HPReadViewController initWithThread:find_pid:thread.pid`（定位到回复楼层）。
5. 每次请求结束（无论成败）都会 `[HPIndecator dismiss]`，但发起前并未 `show`（调用处被注释），属于无实际效果的历史代码。

## 数据流

```
HPRearViewController → HPMyThreadViewController / HPMyReplyViewController
        │
        ├─ my.php?item=threads  → 正则(tid,title,fid) → HPThread[] → EGOCache myThreads
        └─ my.php?item=posts    → 正则(pid,tid,title,fid,摘要) → HPThread[] → EGOCache myReplies
        │
点击 → HPReadViewController（我的回帖带 find_pid）
```

## 依赖关系

- 依赖：`HPHttpClient`、`HPThread`、`EGOCache`、`HPBaseTableViewController`（公共 UI）、`HPReadViewController`、`HPAlert`、`SVProgressHUD`。
- 被依赖：`HPRearViewController`（侧边菜单的“我的帖子”“我的回帖”两项）。
- 相关功能：[读帖页](thread-reader.md)、[侧边导航](navigation-menu.md)、[本地缓存](local-cache.md)（这两个列表用 EGOCache 但未走 `HPCache` 封装）。

## 已知边界

- 解析结果不含作者、日期、回复数等字段，因此直接构造的 `HPThread` 在列表里只显示标题/摘要；进入读帖页后才会补齐 title/fid/pageCount。
- 无排序、无筛选，翻页靠“本页条数”启发式判断。
- 单例缓存的写入只发生在第 1 页，翻到第 2 页后退出再进入会显示第 1 页缓存。
