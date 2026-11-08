# 本地缓存

## 职责

在断网/弱网与快速返回场景下复用数据，并记录“已读/未读”状态。分四层：

| 层 | 载体 | 内容 | 失效 |
| --- | --- | --- | --- |
| HTTP 缓存 | `SDURLCache`（内存 10MB / 磁盘 50MB） | 所有 `NSURLConnection`/AFNetworking 响应 | 系统 URL 缓存规则；设置页“清理缓存”可清 |
| 业务缓存 | `HPCache` 封装的 `EGOCache` | 版块列表、帖子页、待读列表、已读标记、头像存在性 | 见下表 |
| 业务缓存（直接用 EGOCache） | 各 Model | 收藏、关注、我的帖子/回帖、帖子消息、私信列表 | 10 天或不过期 |
| 图片缓存 | `SDImageCache` | 头像等 | 设置页“清理缓存” |

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPCache.m:20](../../HiPDA/Model/HPCache.m) | `+sharedCache`：恢复待读列表 |
| [HPCache.m:41](../../HiPDA/Model/HPCache.m) | `-cacheForum:fid:page:` / [HPCache.m:53](../../HiPDA/Model/HPCache.m) `-loadForum:page:`（60s） |
| [HPCache.m:62](../../HiPDA/Model/HPCache.m) | `-cacheThread:info:tid:page:expiredAfter:` / [HPCache.m:75](../../HiPDA/Model/HPCache.m) 默认 300s 版本 |
| [HPCache.m:82](../../HiPDA/Model/HPCache.m) | `-loadThread:page:` / [HPCache.m:89](../../HiPDA/Model/HPCache.m) `-loadThreadInfo:page:` |
| [HPCache.m:97](../../HiPDA/Model/HPCache.m) | `-cacheBgThread:block:` 预载入待读 |
| [HPCache.m:130](../../HiPDA/Model/HPCache.m) | `-allBgThreads` / [HPCache.m:136](../../HiPDA/Model/HPCache.m) `-clearBgThreads` / [HPCache.m:141](../../HiPDA/Model/HPCache.m) `-removeBgThreadAtIndex:` |
| [HPCache.m:146](../../HiPDA/Model/HPCache.m) | 提醒条目已读：`-isReadThread:pid:` / [HPCache.m:156](../../HiPDA/Model/HPCache.m) `-readThread:pid:` |
| [HPCache.m:167](../../HiPDA/Model/HPCache.m) | 主题已读：`-isReadThread:` / [HPCache.m:177](../../HiPDA/Model/HPCache.m) `-readThread:` |
| [HPCache.m:187](../../HiPDA/Model/HPCache.m) | 头像存在性：`-existAvatar:` / [HPCache.m:198](../../HiPDA/Model/HPCache.m) `-notExistAvatar:` |
| [HPAppDelegate.m:51](../../HiPDA/HPAppDelegate.m) | 启动时用 `SDURLCache` 替换共享缓存 |
| [HPAppDelegate.m:355](../../HiPDA/HPAppDelegate.m) | `-clean`：首次安装清理 cookie 与 EGOCache |

## 核心代码位置

- 键命名：`forum_{fid}_{page}`、`thread_{tid}_{page}`、`thread_info_{tid}_{page}`、`read_{tid}`、`read_notice_{tid}_{pid}`、`favorites`、`favorites_{tid}`、`attention_{tid}`、`myThreads`、`myReplies`、`myNotices`、`myMessageList`、`kHPBgList`（待读数组）。
- 缓存的值必须是可 `NSCoding` 或 plist 原生对象：`HPThread`、`HPNewPost`、`HPUser` 都实现了 `NSCoding`，因此可以整体归档数组。
- 待读（`bgThreads`）持久化：数组写入 `kHPBgList`（有效期 10 天 = 864000 秒），App 重启后从 EGOCache 恢复；预载的正文用 `thread_{tid}_1` 与 `thread_info_tid_1` 承载，有效期取设置里的“待读内容保存时间”（分钟 × 60）。
- 已读标记：主题级（列表点击时写）与提醒条目级（tid+pid，用于帖子消息列表的变灰判定），均 10 天。
- 头像探测：`existAvatar:` / `notExistAvatar:` 记录“该 uid 没有头像”，避免重复请求失败的图片（同名键，语义为“不存在”）。
- 首次安装清理：UserDefaults 中无标记 `hp-mark-old-273` 时执行 `-clean`（清空所有 cookie、清空 EGOCache），并写入标记，避免旧版本残留数据。

## 执行流程

### 读列表

`HPThread +loadThreadsWithFid:` 先查 `forum_{fid}_{page}`：命中且非强制刷新则直接回调，不请求网络；网络成功后立即写回（60 秒内重复进入列表不会发请求）。

### 读帖子

`HPNewPost +loadThreadWithTid:` 查询 `thread_{tid}_{page}` 与 `thread_info_tid_page`：
- 只有在“非强制刷新 **且** 调用方带 `find_pid` **且** 缓存 info 里的 `find_pid` 与之相等”时才直接用缓存（避免从提醒跳转时定位到过期楼层）；
- 请求成功且 `tid != 0`、`page != 0` 时写缓存（`find_pid` 跳转、最后一页这类 page 为 0/未知的情况不写）；
- 打印版特例：第 1 页前 50 楼写 page=1，其余写 page=2。

### 待读（预载）

列表左滑 → `cacheBgThread:block:`：
1. `HPThread` 对象追加进 `bgThreads` 并持久化；
2. 调 `HPNewPost` 拉该主题第 1 页正文（`printable:YES`、不强制刷新）；
3. 用设置里的保存时长写 `thread_/thread_info_` 缓存；
4. 回调结束（控制菊花）。
待读列表页读取 `allBgThreads`；删除单条或清空同步更新 EGOCache。

### 清理

设置页“清理缓存”：后台清 `SDImageCache` 磁盘缓存 + `SDURLCache` 全部响应；清理前会先算一次图片缓存大小作为按钮标题。EGOCache 没有从 UI 清理的入口（仅首次安装时清一次）。

## 数据流

```
网络 HTML ──解析──> HPThread / HPNewPost（NSCoding）
                          │
                    HPCache（EGOCache）
        ┌─────────────────┼──────────────────┐
        ▼                 ▼                  ▼
  列表 60s 缓存     帖子页 300s/自定义     待读列表 10 天
        │                 │                  │
   HPThreadVC        HPReadVC           HPBackgroundVC
        │
   已读标记 read_{tid} / read_notice_{tid}_{pid}（10 天）
```

## 依赖关系

- 依赖：EGOCache（vender 源码）、`HPThread`/`HPNewPost` 的 `NSCoding`、`HPSetting`（待读时长）、`HPNewPost`（预载正文）。
- 被依赖：列表页、读帖页、待读页、帖子消息页（已读标记）、收藏/关注/我的帖子/我的回帖/私信/提醒（各自直接用 EGOCache）。
- 相关功能：[版块帖列表](forum-thread-list.md)、[读帖页](thread-reader.md)、[帖子消息提醒](thread-notice.md)、[收藏与关注](favorites-attention.md)、[设置](settings.md)。

## 已知边界

- 缓存没有“总容量/淘汰策略”控制，完全依赖 EGOCache 的过期时间；待读正文按设置时长可能长期占用磁盘。
- 收藏/关注/列表缓存都直接把模型归档，模型字段增删会影响旧缓存反序列化结果（代码没有缓存版本号）。
- 读帖缓存命中条件较苛刻（必须带同一 find_pid），普通翻页进入都走网络；列表缓存只有 60 秒。
- 头像“不存在”的键一旦写入，10 天内不会重新尝试加载该用户头像（即使用户后来上传了头像）。
