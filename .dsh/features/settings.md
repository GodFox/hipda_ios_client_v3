# 设置

## 职责

集中管理客户端偏好：阅读外观（夜间模式、头像、排序）、发帖相关（小尾巴）、图片加载策略、缓存清理、待读保存时长、后台刷新开关、板块设定、关于/致谢/反馈/登出/重置。所有偏好都存进 `NSUserDefaults` 的**单个字典**（键 `HPSettingDic`），由 `HPSetting` 统一读写。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPSetting.m:28](../../HiPDA/Model/HPSetting.m) | `+sharedSetting` 单例 |
| [HPSetting.m:40](../../HiPDA/Model/HPSetting.m) | `-loadSetting`：读字典并补齐新增默认键 |
| [HPSetting.m:67](../../HiPDA/Model/HPSetting.m) | `-loadDefaults`：重置为默认值 |
| [HPSetting.m:78](../../HiPDA/Model/HPSetting.m) | `+defualts`：全部默认值 |
| [HPSetting.m:101](../../HiPDA/Model/HPSetting.m) | `-save` 整体写回 |
| [HPSetting.m:157](../../HiPDA/Model/HPSetting.m) | `-postTail` / [HPSetting.m:171](../../HiPDA/Model/HPSetting.m) `-isPostTailAllow:`（小尾巴组装与校验） |
| [HPSettingViewController.m:58](../../HiPDA/Controller/HPSettingViewController.m) | 设置页 `viewDidLoad`（四个分区 + 后台刷新 + 登出 + 版本） |
| [HPSettingViewController.m:151](../../HiPDA/Controller/HPSettingViewController.m) | `-addPreferenceControls` 偏好分区 |
| [HPSettingViewController.m:239](../../HiPDA/Controller/HPSettingViewController.m) | `-addImageControls` 图片/缓存/待读分区 |
| [HPSettingViewController.m:394](../../HiPDA/Controller/HPSettingViewController.m) | `-addAboutControls` 关于分区 |
| [HPSettingViewController.m:498](../../HiPDA/Controller/HPSettingViewController.m) | `-reset:` 重置 |
| [HPSetForumsViewController.m:36](../../HiPDA/Controller/HPSetForumsViewController.m) | 板块设定页 |
| [HPBgFetchViewController.m:33](../../HiPDA/Controller/HPBgFetchViewController.m) | 后台刷新设置页 |

## 设置项与存储键

| 设置项 | 存储键 | 默认值 | 生效位置 |
| --- | --- | --- | --- |
| 夜间模式 | `HPSettingNightMode` | NO | `HPTheme` 全局配色；读帖模板明/暗；导航栏与状态栏样式 |
| 显示头像 | `HPSettingShowAvatar` | YES | 列表 Cell 行高与头像显示、读帖楼层头像 |
| 按发帖时间排序 | `HPSettingOrderByDate` | NO | 版块列表请求是否追加 `orderby=dateline` |
| 小尾巴 | `HPSettingTail` | `iOS fly ~` | 发帖/回帖正文末尾追加；校验：不允许 `[`/`]`，GB18030 字节数 ≤ 16 |
| 收藏版块 fid 数组 | `HPSettingFavForums` | `[2, 6, 59]` | 侧边菜单的版块列表 |
| 收藏版块标题数组 | `HPSettingFavForumsTitle` | Discovery / Buy & Sell / E-INK | 同上 |
| 移动网络图片 | `HPSettingImageWWAN` | 0（全部显示） | `+[HPNewPost preProcessHTML:]` |
| Wi-Fi 图片 | `HPSettingImageWifi` | 0 | 同上 |
| 待读保存时长（分钟） | `HPSettingBGLastMinite` | 20 | `HPCache -cacheBgThread:` 的缓存有效期 |
| 后台刷新-新消息 | `HPSettingBgFetchNotice` | YES | 后台抓取分支二 |
| 后台刷新-帖子列表 | `HPSettingBgFetchThread` | NO | 后台抓取分支一 |
| 字号百分比 | `HPSettingFontSizeAdjust` | 100 | 读帖页（50–200） |
| 行高百分比 | `HPSettingLineHeightAdjust` | 150 | 读帖页（80–200） |
| 私信/提醒未读数 | `HPPMCount` / `HPNoticeCount` | 0 | 角标、侧边菜单红点 |
| 网络状态 | `kHPNetworkStatus` | — | 图片策略判断（Wi-Fi / 蜂窝） |

图片策略取值：`HPImageDisplayStyleFull=0`（全部显示）、`One=1`（只显示最后一张）、`None=2`（全部折叠为“点击查看图片”占位）。

## 执行流程

### 启动与读写

1. `HPAppDelegate` 启动时 `[Setting loadSetting]`：读出 `HPSettingDic` 字典；若存在，则把“默认值里有、存档里没有”的键补进去（用于版本升级新增设置项）；完全不存在则 `loadDefaults`。
2. 每次 `saveObject:forKey:` 都是“改内存字典 + 整体序列化写回 + synchronize”，粒度较粗但调用方无需关心。

### 设置页

1. 顶部左“完成”、右“重置”；页面由 `RETableViewManager` 描述式构建。
2. **偏好分区**：夜间模式（切换后调用 `[[HPRearViewController sharedRearVC] themeDidChanged]`）、显示头像（同样触发主题刷新）、按发帖时间排序、小尾巴（结束编辑时校验并提示成功/错误）、板块设定（push 设置页）。
3. **图片分区**：移动网络 / Wi-Fi 两个单选（三档），清理缓存（后台清 SDImageCache 与 SDURLCache，标题显示当前图片缓存大小，单位 MB），待读内容保存时间（10/20/30 分钟、1/3 小时、1/3 天、永远）。
4. **后台刷新**（仅 iOS7+）：push `HPBgFetchViewController`，两个开关 + 一段说明文字。
5. **关于分区**：联系作者（MFMailCompose，正文自动带设备型号、系统版本、客户端版本）、回帖建议（直接打开固定主题）、致谢（加载包内 `acknowledgement.html`，链接用系统浏览器打开）、GitHub 仓库链接。
6. **登出分区**：确认后 `[[HPAccount sharedHPAccount] logout]` 并关闭设置页。
7. 底部显示 `CFBundleShortVersionString`。
8. “完成”关闭时通知 `[HPRearViewController sharedRearVC] forumDidChanged]`，让侧边菜单重新读取收藏版块。

### 板块设定

1. 数据源：设置里的标题数组 + `[HPForum forumsTitle]`（可选项，首项“删除该板块”用于删除）。
2. 每个当前收藏版块是一行单选；点击弹出选项控制器选新版块（或“删除该板块”）。
3. 约束：第 1 个（首页）不可删；至少保留 1 个；不允许重复版块。
4. 右上“+”按顺序补一个尚未收藏的版块。
5. `viewWillDisappear` 自动保存：按标题反查 `[HPForum forumsDict]` 得到 fid 数组，连同标题数组一起写回设置。

### 重置

`-reset:` 确认后 `[Setting loadDefaults]`（覆盖内存字典并写回），提示“设置已重置”，随后关闭设置页。

## 数据流

```
NSUserDefaults[HPSettingDic] ←→ HPSetting 单例
        │                            │
        │                     defualts（键补齐/重置）
        ▼
HPTheme / 列表 / 读帖 / 发帖 / 后台抓取 / 图片策略 / 侧边菜单
```

## 依赖关系

- 依赖：`HPForum`（版块名与 fid 映射、分类 plist）、`HPAccount`（登出）、`HPRearViewController`（主题/菜单刷新）、`HPTheme`、`SDURLCache`、`SDImageCache`、`RETableViewManager`、`MFMailComposeViewController`。
- 被依赖：几乎所有模块都通过 `Setting` 宏读取偏好；`HPBgFetchViewController` 是设置页的子页面。
- 相关功能：[主题与夜间模式](theme.md)、[侧边导航](navigation-menu.md)（板块设定影响菜单）、[后台刷新](background-fetch.md)、[读帖页](thread-reader.md)（字号行距在阅读面板里改，写入同一组键）、[发帖与回帖](compose.md)（小尾巴）。

## 已知边界

- 默认值里的 `HPSettingFontSize`、`HPSettingLineHeight`、`HPSettingTextFont` 没有任何读取方（界面使用两个 `*Adjust` 百分比键），属于遗留配置。
- 偏好整体存一个字典，任何一次 set 都会重写整个字典；没有迁移版本号，仅靠“键补齐”处理升级。
- 设置页没有“清除收藏/关注缓存”“清除 EGOCache”入口（清理缓存只清图片与 URL 缓存）。
- `HPSetForumsViewController` 的保存只在 `viewWillDisappear` 触发，异常退出可能丢改动。
- 联系作者与 GitHub 链接、固定主题 tid 均为硬编码。
