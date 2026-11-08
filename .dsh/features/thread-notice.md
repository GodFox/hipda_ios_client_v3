# 帖子消息提醒

## 职责

- 解析论坛“帖子消息”（`notice.php?filter=threads`）里的提醒，区分“有人回复/引用了你”和“你关注的主题有了新回复”两类，转成带 tid/pid 的 `HPThread` 供列表展示，点击后定位到对应楼层。
- 维护未读计数（`HPNoticeCount`）与角标，配合本地通知与后台抓取。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPNotice.m:24](../../HiPDA/Model/HPNotice.m) | `+sharedNotice`：从 EGOCache 恢复提醒数组 |
| [HPNotice.m:41](../../HiPDA/Model/HPNotice.m) | `+ayscnMyNoticesWithBlock:page:` 抓取与解析 |
| [HPNotice.m:219](../../HiPDA/Model/HPNotice.m) | `+ignoreNotice` 忽略全部提醒 |
| [HPNotice.m:247](../../HiPDA/Model/HPNotice.m) | `-cacheMyNotices:` 缓存第一页 |
| [HPMyNoticeViewController.m:41](../../HiPDA/Controller/HPMyNoticeViewController.m) | “帖子消息”列表页 |
| [HPMyNoticeViewController.m:107](../../HiPDA/Controller/HPMyNoticeViewController.m) | `-ayscn:` |
| [HPMyNoticeViewController.m:250](../../HiPDA/Controller/HPMyNoticeViewController.m) | `-tableView:didSelectRowAtIndexPath:` 跳转 |
| [HPRearViewController.m:363](../../HiPDA/Controller/HPRearViewController.m) | 侧边栏“帖子消息”入口 / 通知弹窗“查看” |
| [HPAccount.m:357](../../HiPDA/Model/HPAccount.m) | `-_checkMsgAndNoticeStep2`：从个人中心页正则取两类未读数 |

## 核心代码位置

- 列表接口：`forum/notice.php?filter=threads&page={page}&inajax=1`；不带 `inajax=1` 时旧 iPhone UA 会命中 WAP 模板并返回 HTTP 500。
- 外层分块：按 `div class="f_{type}"` 把页面切成若干块，`type` 可能是 `thread`（关注主题有新回复）、`quote`（引用）、`reply`（回复）。
- `thread` 块解析：取最后回复者名（多人时追加省略号）、pid、tid、标题，详情文案为“「{某人}」回复了您关注的主题”；同时调用 `HPAttention +cacheAttention:` 把该 tid 记为已关注。
- 非 `thread` 块解析：取 tid、标题、自己的原帖内容、对方名字、对方内容、fid、pid，详情文案为两段对比（“你说”/“他说”），并把多行合并为单行。
- 未读计数：`HPAccount` 在个人中心积分页用正则匹配“私人消息 (n)”“帖子消息 (n)”，写入设置键 `HPPMCount` / `HPNoticeCount`。
- 角标：`HPAccount -badgeNumber` = 私信未读 + 提醒未读；`HPRearViewController -updateBadgeNumber` 同步 App 角标、菜单按钮角标与表格重载。

## 执行流程

### 定时/后台检查未读（HPAccount）

1. `-startCheckWithDelay:` 延迟后 `-checkMsgAndNotice` 创建每 5 分钟触发的定时器（`-startCheckWithDelay:0` 时立即执行一次，用于后台抓取）。
2. `-_checkMsgAndNoticeStep1`：GET `forum/pm.php?checknewpm=…&inajax=1`；响应中出现“您还未登录”则调用 `HPAccount loginWithBlock:` 重登，成功后继续第 2 步；否则直接进入第 2 步。
3. `-_checkMsgAndNoticeStep2`：GET `forum/memcp.php?action=credits` → 正则取两类未读数 → 写设置 → 有未读则 `-addLocalNotification` → 回调 `noticeRetrieveBlock`（后台抓取用）→ `updateBadgeNumber`。

### 列表页（帖子消息）

1. 侧边栏进入后 `refresh:`：重置第 1 页 → 菊花 → `-ayscn:`。
2. `HPNotice +ayscnMyNoticesWithBlock:page:`：第 1 页写缓存 `myNotices` → 替换数据 → `reloadData` → **把 `HPNoticeCount` 置 0 并更新角标**。
3. 单元格：标题（已读变灰，依据 `HPCache isReadThread:tid pid:`）+ 多行详情（按字号/宽度自适应行高）。
4. 点击：已读标记（`HPCache readThread:tid pid:`）→ 若该条有 pid 用 `HPReadViewController initWithThread:find_pid:` 定位楼层；否则用第 1 页全量模式打开。
5. 翻页：上一页要求 `_current_page > 1`；下一页要求当前条数 ≥ 44（论坛该列表每页 45 条左右的启发式判断）。

## 数据流

```
HPAccount（每 5 分钟 / 后台抓取）
   └─ memcp.php?action=credits ──正则──> HPPMCount / HPNoticeCount
        ├─ UILocalNotification（1 秒后触发；角标 = 两类之和）
        └─ HPRearViewController.updateBadgeNumber（App 角标 + 菜单红点）

HPMyNoticeViewController
   └─ HPNotice +ayscnMyNoticesWithBlock:
        ├─ notice.php?filter=threads&page=
        ├─ 外层 f_<type> 分块 → thread / quote / reply 两套正则
        ├─ HPThread{tid,pid,title,fid?,replyDetail}
        ├─ HPAttention.cacheAttention(tid)
        └─ EGOCache myNotices（第 1 页）
```

## 依赖关系

- 依赖：`HPHttpClient`、`HPSetting`、`HPAttention`、`HPCache`（已读标记）、`HPThread`、`HPAccount`（未读计数与角标）、`HPRearViewController`、`HPReadViewController`、`NSString+Additions`（可选正则分类）。
- 被依赖：`HPAppDelegate`（本地通知弹窗、后台抓取分支）、`HPRearViewController`（菜单入口与角标）、`HPMyNoticeViewController`。
- 相关功能：[短消息](private-message.md)（共用未读计数与角标体系）、[后台刷新](background-fetch.md)、[账号与登录](account-auth.md)（未登录时先重登）。

## 已知边界

- 未读计数取自“个人中心积分页”，与提醒列表页是两个入口；两处数据可能短暂不一致（进入列表页才把计数清零，不逐个已读）。
- `thread` 类提醒的解析注释说明：匹配到的只是“最后回复者”，跳转到该主题的第一条回复后可能误导；`quote`/`reply` 类依赖 pid 精确定位。
- 解析正则绑定论坛当时的 HTML 结构（`f_<type>`、`summary`、`dl/dt/dd` 等），改版即失效；解析失败只打日志。
- 页面底部注释掉的旧实现与 `HPMessage` 中同名的 `checkPMWithBlock:` 注释代码属于历史遗留，未参与编译。
