# 主题与夜间模式

## 职责

集中提供全局配色与外观样式，使界面在“日间/夜间”两套主题间切换：

- 背景色、正文色、次要文字色、已读色、奇偶行色；
- 指示器样式、键盘外观；
- 两个功能性强调色（“跳到最后一页”滑动背景、“预载待读”滑动背景）；
- 读帖页另有两套 HTML 模板（`post_view.html` / `post_view_dark.html`）。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPTheme.m:14](../../HiPDA/Model/HPTheme.m) | `+sharedTheme` 单例（实际全部为类方法，单例未被业务使用） |
| [HPTheme.m:23](../../HiPDA/Model/HPTheme.m) | `+backgroundColor` |
| [HPTheme.m:38](../../HiPDA/Model/HPTheme.m) | `+textColor` |
| [HPTheme.m:53](../../HiPDA/Model/HPTheme.m) | `+blackOrWhiteColor` |
| [HPTheme.m:69](../../HiPDA/Model/HPTheme.m) | `+readColor` |
| [HPTheme.m:85](../../HiPDA/Model/HPTheme.m) | `+oddCellColor` / [HPTheme.m:100](../../HiPDA/Model/HPTheme.m) `+evenCellColor` |
| [HPTheme.m:116](../../HiPDA/Model/HPTheme.m) | `+indicatorViewStyle` |
| [HPTheme.m:132](../../HiPDA/Model/HPTheme.m) | `+keyboardAppearance` |
| [HPTheme.m:148](../../HiPDA/Model/HPTheme.m) | `+threadJumpColor` / [HPTheme.m:154](../../HiPDA/Model/HPTheme.m) `+threadPreloadColor` |
| [HPSettingViewController.m:157](../../HiPDA/Controller/HPSettingViewController.m) | 设置页夜间模式开关 |
| [HPReadViewController.m:1530](../../HiPDA/Controller/HPReadViewController.m) | 阅读面板夜间模式开关 |
| [HPRearViewController.m:499](../../HiPDA/Controller/HPRearViewController.m) | `-themeDidChanged` 统一转发 |
| [HPReadViewController.m:1734](../../HiPDA/Controller/HPReadViewController.m) | 读帖页 `-themeDidChanged`（重载正文） |

## 核心代码位置

- 开关真源：`HPSettingNightMode`（`HPSetting`）。
- 颜色取值（日间 / 夜间）：

| 用途 | 日间 | 夜间 |
| --- | --- | --- |
| 背景 | 浅灰（241,241,239） | 近黑（10,11,14） |
| 正文 | 黑 | 灰（156,156,156） |
| 黑/白（强调文字） | 黑 | 白 |
| 已读色 | 灰（100,100,100） | 灰（100,100,100） |
| 奇偶行 | 243,243,243 / 白 | 均为 10,11,14 |
| 指示器 | Gray | White |
| 键盘 | Default | iOS7 为 Dark（更早系统用 Alert） |

- 两个滑动强调色不随主题变化：跳末页用绿（85,213,80），预载待读用棕（206,149,98）。
- 读帖模板选择：`HPReadViewController -load:refresh:` 中按 `HPSettingNightMode` 读取 `post_view` 或 `post_view_dark`；模板内 `<font color="Black">` 在夜间被替换成 White，日间把 White 替换成 Red（`+[HPNewPost preProcessHTML:]`）。

## 执行流程

### 切换夜间模式

1. 入口：设置页开关，或读帖页“细节调整”面板里的开关。
2. 写 `HPSettingNightMode`。
3. 调用 `[[HPRearViewController sharedRearVC] themeDidChanged]`：
   - 更新帖子列表页样式（导航按钮、表格重载、背景色）；
   - 遍历侧边菜单里**已实例化**的页面，逐个调用 `-themeDidChanged`（未创建过的页面无操作，创建时再按当前主题初始化）；
   - 同步 `UINavigationBar` 外观（`UIAppearance` 的 barStyle）与状态栏样式（夜间 LightContent）。
4. 读帖页的 `-themeDidChanged` 额外把自身 `view` 背景设为主题色并**重新加载正文**（切换模板）。
5. 设置页的“显示头像”开关也会触发同一个 `themeDidChanged`（因为头像开关改变了列表布局与 Cell 高度）。

### 启动时

`HPAppDelegate` 在启动早期按 `HPSettingNightMode` 预设导航栏与状态栏样式，然后才创建窗口根控制器。

## 数据流

```
HPSettingNightMode（NSUserDefaults 中的 HPSettingDic）
        │
   HPTheme +backgroundColor/+textColor/…（每次调用即时判断）
        │
各 Controller / Cell 拉取颜色
        │
HPRearViewController -themeDidChanged ──转发──> 各已实例化页面 -themeDidChanged
        │                                        └─ 读帖页重新载入模板
        └─ UINavigationBar appearance / 状态栏样式
```

## 依赖关系

- 依赖：`HPSetting`（唯一开关）、UIKit。
- 被依赖：几乎全部 Controller / Cell（列表、收藏、待读、我的帖子/回帖、提醒、私信、搜索、设置、编辑器、上传页、读帖页）。
- 相关功能：[设置](settings.md)、[读帖页](thread-reader.md)、[版块帖列表](forum-thread-list.md)、[侧边导航](navigation-menu.md)。

## 已知边界

- 颜色以静态变量缓存（`static UIColor *`），切换主题后不会重新创建，但因为取值只依赖“当前是否夜间”的两个固定值，缓存本身不会出错。
- `HPCommon.h` 里定义了通知名 `kHPThemeDidChanged`，但全项目没有 post/observe，主题传播完全靠 `HPRearViewController` 手动遍历。
- 夜间模式下部分界面仍写死浅色（例如私信对话页背景仍设为白色、图片上传页的容器色只在夜间改一部分），属于未完全适配。
- `HPTheme +sharedTheme` 没有调用方，属于形式上的单例。
