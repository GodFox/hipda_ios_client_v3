# 收藏与关注

## 职责

- **收藏**：在论坛“我的收藏”中添加/删除主题，并在本地用 EGOCache 维护收藏集合与收藏状态，供读帖页图标与“收藏”列表页使用。
- **关注**：只维护“关注状态”（本地缓存 + 论坛关注接口），没有独立的关注列表页；帖子消息页会把“服务端关注列表中的主题”补记到本地关注缓存。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPFavorite.m:26](../../HiPDA/Model/HPFavorite.m) | `+sharedFavorite`：从 EGOCache 恢复收藏数组 |
| [HPFavorite.m:42](../../HiPDA/Model/HPFavorite.m) | `-favoriteWith:block:` 收藏一个主题 |
| [HPFavorite.m:102](../../HiPDA/Model/HPFavorite.m) | `+isFavoriteWithTid:` 本地是否已收藏 |
| [HPFavorite.m:108](../../HiPDA/Model/HPFavorite.m) | `-favoriteThreads:` 用服务器同步结果整体覆盖本地 |
| [HPFavorite.m:125](../../HiPDA/Model/HPFavorite.m) | `-removeFavoritesWithTid:block:` 取消收藏（按 tid） |
| [HPFavorite.m:140](../../HiPDA/Model/HPFavorite.m) | `-removeFavoritesAtIndex:block:` 取消收藏（按列表下标） |
| [HPFavorite.m:214](../../HiPDA/Model/HPFavorite.m) | `+ayscnFavoritesWithBlock:` 从论坛拉收藏列表 |
| [HPAttention.m:27](../../HiPDA/Model/HPAttention.m) | `+isAttention:` |
| [HPAttention.m:37](../../HiPDA/Model/HPAttention.m) | `+addAttention:block:` |
| [HPAttention.m:88](../../HiPDA/Model/HPAttention.m) | `+removeAttention:block:` |
| [HPReadViewController.m:1002](../../HiPDA/Controller/HPReadViewController.m) | 读帖页收藏按钮 |
| [HPReadViewController.m:1034](../../HiPDA/Controller/HPReadViewController.m) | 读帖页关注按钮 |
| [HPFavoriteViewController.m:26](../../HiPDA/Controller/HPFavoriteViewController.m) | 收藏列表页 |
| [HPFavoriteViewController.m:87](../../HiPDA/Controller/HPFavoriteViewController.m) | `-ayscn:` 同步按钮 |

## 核心代码位置

### 收藏

- 缓存键：全局数组 `favorites`，单元键 `favorites_{tid}`（值 `@YES`，10 天有效）。
- 收藏接口：`forum/my.php?item=favorites&tid={tid}&inajax=1&ajaxtarget=favorite_msg`（GET）。
- 取消接口：先经 `HPSendPost +loadParametersWithBlock:` 取 `formhash`，再 POST `forum/my.php?item=favorites&type=thread`，字段 `delete[]=tid` 与 `favsubmit`。
- 同步接口：GET `forum/my.php?item=favorites&type=thread`，正则抽取 tid、标题、fid 三个字段构造 `HPThread`。
- 成功判定：收藏成功识别“此主题已成功添加到收藏夹中”/“您曾经收藏过这个主题”；取消成功识别“收藏夹已成功更新”。

### 关注

- 缓存键：`attention_{tid}`（`@YES`，10 天）。
- 添加：GET `forum/my.php?item=attention&tid={tid}&inajax=1&ajaxtarget=favorite_msg&action=add`，成功识别“指定主题已成功加入到关注列表中”/“您正在关注这个主题”。
- 移除：GET 同路径 `action=remove`，成功识别“已取消对此主题的关注”。
- 本地状态先改、网络后提交：即使网络失败，关注/收藏的本地标记已经变化（收藏会在失败时保留本地记录）。

## 执行流程

### 收藏（读帖页）

1. 点击心形按钮：`HPFavorite isFavoriteWithTid:` 查本地缓存。
2. 未收藏：
   - 先用 tid 做本地去重检查（已有 `favorites_{tid}` → 直接报“您曾经收藏过这个主题”）；
   - `insertObject:atIndex:0` 插到本地数组头部并写两个缓存键；
   - GET 收藏接口 → 成功回调刷新图标，失败提示错误（本地记录不回滚）。
3. 已收藏：`-removeFavoritesWithTid:` → 遍历本地数组找到 tid 的下标 → `-removeFavoritesAtIndex:` → 删除单元键、重写全局数组 → 取 formhash → POST 删除 → 刷新图标。

### 关注（读帖页）

1. `+isAttention:` 查缓存。
2. 未关注：已有缓存则报“您曾经关注过这个主题”；否则先写缓存，再 GET 添加关注接口。
3. 已关注：先删缓存，再 GET 移除关注接口。

### 收藏列表页

1. `setup` 用 `[[HPFavorite sharedFavorite] favorites]` 作为数据源（`HPBaseTableViewController` 的初始化钩子）。
2. 数据为空时自动弹“同步”确认 → `-ayscn:` → 服务端结果用 `-favoriteThreads:` 覆盖本地（同时重建每个 tid 的单元键）。
3. 右侧导航为“同步 + 编辑”；左滑删除走 `commitEditingStyle` → `-removeFavoritesAtIndex:block:`。
4. 点击行 push 读帖页。

### 帖子消息页的关注联动

`HPNotice +ayscnMyNoticesWithBlock:page:` 在解析到“有人回复了您关注的主题”时，会调用 `HPAttention +cacheAttention:` 把该 tid 记为已关注，避免读帖页误显示未关注。

## 数据流

```
读帖页按钮
  ├─ 收藏 → HPFavorite ── EGOCache(favorites, favorites_{tid})
  │                       └─ my.php?item=favorites...（GET 添加 / POST 删除）
  └─ 关注 → HPAttention ── EGOCache(attention_{tid})
                          └─ my.php?item=attention...&action=add|remove

收藏列表页
  ├─ setup ← EGOCache(favorites)
  ├─ 同步 → ayscnFavoritesWithBlock → my.php?item=favorites&type=thread
  │           └─ favoriteThreads: 覆盖本地
  └─ 删除 → removeFavoritesAtIndex: → 单元键删除 + POST 删除
```

## 依赖关系

- 依赖：`HPCache` 之外的直接 EGOCache 使用、`HPSendPost`（取 formhash）、`HPHttpClient`、`HPThread`（模型与 NSCoding）、`NSString+Additions`、`SVProgressHUD`、`HPAlert`。
- 被依赖：`HPReadViewController`（图标状态与动作）、`HPFavoriteViewController`（列表）、`HPNotice`（关注联动）。
- 相关功能：[读帖页](thread-reader.md)、[帖子消息提醒](thread-notice.md)、[本地缓存](local-cache.md)。

## 已知边界

- 本地收藏/关注状态是唯一真源（图标状态完全由 EGOCache 决定），若在网页端收藏/取消，App 内需手动“同步”才一致。
- `-removeFavoritesWithTid:` 在找不到匹配 tid 时，循环会把 `index` 留在最后一个下标（不是 -1），因此可能删除错误条目的本地记录——这是一个可复现的边界缺陷，修复前先确认目标 tid 是否存在于本地数组。
- 关注没有列表页，也没有“取消关注”之外的批量操作；`HPAttention` 只提供静态方法，不持久化关注列表。
- 收藏与关注在读帖页使用同一图标资源（`love.png` / `love_selected.png`），只能靠按钮位置区分。
