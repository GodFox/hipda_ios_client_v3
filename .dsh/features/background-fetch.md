# 后台刷新

## 职责

利用 iOS 7 的 Background Fetch 在系统认为合适的时机：

1. 刷新版块帖子列表（可关闭）；
2. 检查新私信与新帖子消息（可关闭），必要时发本地通知。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HiPDA-Info.plist](../../HiPDA/HiPDA-Info.plist) | `UIBackgroundModes = [fetch]` |
| [HPAppDelegate.m:115](../../HiPDA/HPAppDelegate.m) | 启动时若任一开关开启，设置最小抓取间隔 |
| [HPAppDelegate.m:272](../../HiPDA/HPAppDelegate.m) | `-application:performFetchWithCompletionHandler:` 后台抓取主逻辑 |
| [HPThreadViewController.m:197](../../HiPDA/Controller/HPThreadViewController.m) | 列表加载回调里调用 `_bgFetchBlock` |
| [HPThreadViewController.m:628](../../HiPDA/Controller/HPThreadViewController.m) | 回到前台时提示“已于…前更新” |
| [HPRearViewController.m:129](../../HiPDA/Controller/HPRearViewController.m) | `+threadVCRefresh` 供后台刷新触发列表重载 |
| [HPAccount.m:293](../../HiPDA/Model/HPAccount.m) | `-startCheckWithDelay:` / [HPAccount.m:310](../../HiPDA/Model/HPAccount.m) 未读检查 |
| [HPBgFetchViewController.m:33](../../HiPDA/Controller/HPBgFetchViewController.m) | 开关界面 |

## 核心代码位置

- 开关键：`HPSettingBgFetchThread`（帖子列表，默认关闭）、`HPSettingBgFetchNotice`（新消息，默认开启）。
- 完成回调靠一个局部计数器：两个分支各自完成后 `count++`，`count >= 2` 时才调用系统 `completionHandler`。
- 分支一（帖子列表）的触发条件：开关开启 **且** 前台导航栈顶是 `HPThreadViewController` **且** 侧滑菜单处于收起状态（`FrontViewPositionLeft`）。满足时给列表设置 `bgFetchBlock` 并 `+threadVCRefresh`。
- 分支二（未读消息）：设置 `HPAccount.noticeRetrieveBlock` 后 `-startCheckWithDelay:0`（立即执行一次未读检查，不创建 5 分钟定时器）。
- 列表页回调结果时记录 `_lastBgFetchDate`；App 回到前台（`UIApplicationDidBecomeActiveNotification`）时用 `ZAActivityBar` 弹出“已在 N 秒/分钟前更新”。

## 执行流程

```
系统 Background Fetch
  → HPAppDelegate performFetchWithCompletionHandler:
      ├─ 分支 A：HPSettingBgFetchThread 且当前前台是帖子列表且菜单收起
      │     ├─ tvc.bgFetchBlock = ^(result){ count++; 若 count>=2 → completionHandler(result) }
      │     └─ [HPRearViewController threadVCRefresh]
      │           └─ HPThreadViewController -refresh: → -load:refresh:
      │                 └─ 成功/失败都调用 _bgFetchBlock(UIBackgroundFetchResultNewData/Failed)
      │
      └─ 分支 B：HPSettingBgFetchNotice
            ├─ HPAccount.noticeRetrieveBlock = ^(result){ count++; 若 count>=2 → completionHandler(result) }
            └─ [HPAccount startCheckWithDelay:0]
                  └─ 未读检查 → 回调 NewData / NoData / Failed
      （分支关闭时直接 count++，相当于立即“完成这一半”）
```

## 数据流

```
设置开关（HPSettingBgFetchThread / HPSettingBgFetchNotice）
        │
系统 fetch → HPAppDelegate → 列表刷新（HPCache + 网络） / 未读检查（HPAccount）
        │                              │
        └────── UIBackgroundFetchResult┘
                     │
              count 凑满 2 → completionHandler
                     │
              本地通知 + 角标（HPAccount -addLocalNotification）
```

## 依赖关系

- 依赖：`HPThreadViewController`（`bgFetchBlock` 属性）、`HPRearViewController`（`threadVCRefresh`）、`HPAccount`（`noticeRetrieveBlock`、未读检查、本地通知）、`HPSetting`、`ZAActivityBar`。
- 被依赖：系统调度（`UIApplication`），以及设置页的开关界面。
- 相关功能：[版块帖列表](forum-thread-list.md)、[帖子消息提醒](thread-notice.md)、[账号与登录](account-auth.md)、[设置](settings.md)、[本地缓存](local-cache.md)（后台刷新会更新列表与正文缓存）。

## 已知边界

- 完成回调依赖“两个分支各回调一次”；若某个分支的条件不满足且另一分支的回调没有发生（例如请求既不成功也不失败地挂住），`completionHandler` 不会被调用，系统会判定本次抓取超时。代码没有兜底的超时保护。
- 分支一要求前台必须是帖子列表且菜单收起，否则不刷新列表（此时可能只做未读检查）。
- 后台刷新入口没有判断 iOS 版本以外的能力（`IOS7_OR_LATER` 在启动时用于设置最小间隔）。
- 抓取结果只通过本地通知/角标体现，不会在后台更新界面（界面回前台后由 `applicationDidBecomeActiveNotification` 提示上次更新时间）。
