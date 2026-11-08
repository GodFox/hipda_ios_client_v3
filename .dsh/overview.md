# HiPDA iOS 客户端 v3 —— 项目总览

## 项目用途

HiPDA（`www.4d4y.com`，一个基于 Discuz! 的论坛）的第三方 iOS 客户端。项目自述见 [README.md](../README.md)：论坛没有提供 API，客户端直接请求论坛网页，再用正则 / 字符串解析把 HTML 转成模型对象（这一点在代码中得到证实，见各 `Model/*.m` 中的解析方法）。应用定位为浏览版块、读帖、发帖回帖、查收短消息与帖子消息、收藏关注、搜索。

- 版本号：`CFBundleShortVersionString` = 3.1.0，`CFBundleVersion` = 20140413（见 [HiPDA-Info.plist](../HiPDA/HiPDA-Info.plist)）。
- 仅支持 iPhone 竖屏；`UIBackgroundModes` 仅声明 `fetch`（后台抓取）。

## 技术栈（来自清单文件与工程配置）

| 项 | 内容 | 依据 |
| --- | --- | --- |
| 语言 / UI | Objective-C + UIKit，纯代码构建界面 | 工程内无 `.xib` / `.storyboard`；[main.m](../HiPDA/main.m) |
| 最低系统 | iOS 15.0 | `IPHONEOS_DEPLOYMENT_TARGET = 15.0`（App/Tests；Pods 由 [Podfile](../Podfile) 的 `post_install` 统一设置，见 [project.pbxproj](../HiPDA.xcodeproj/project.pbxproj)） |
| 内存管理 | ARC | `CLANG_ENABLE_OBJC_ARC = YES`（同上） |
| 依赖管理 | CocoaPods（`platform :ios, '15.0'`，`target 'HiPDA'`） | [Podfile](../Podfile) |
| 网络 | AFNetworking 1.3.3（`AFHTTPClient` 子类） | Podfile + [HPHttpClient.h](../HiPDA/Model/HPHttpClient.h) |
| 图片 | SDWebImage、SDWebImage-ProgressView | Podfile |
| 缓存 | EGOCache（vender 源码，非 Pod）+ SDURLCache | Podfile 无 EGOCache；[HPCache.m](../HiPDA/Model/HPCache.m)、[HPAppDelegate.m](../HiPDA/HPAppDelegate.m) |
| 数据库 | FMDB | Podfile + [HPDatabase.m](../HiPDA/Model/HPDatabase.m) |
| 登录凭据 | SSKeychain | Podfile + [HPAccount.m](../HiPDA/Model/HPAccount.m) |
| 设置表单 | RETableViewManager（vender 源码） | [HPSettingViewController.m](../HiPDA/Controller/HPSettingViewController.m) |
| 侧滑菜单 | SWRevealViewController（vender 源码，含修改） | [HPAppDelegate.m](../HiPDA/HPAppDelegate.m) |
| 聊天式界面 | JSMessagesViewController | Podfile + [HPMessageDetailViewController.h](../HiPDA/Controller/HPMessageDetailViewController.h) |
| 表情键盘 | WUEmoticonsKeyboard（vender 源码） | [HPBaseCompostionViewController.m](../HiPDA/Controller/HPBaseCompostionViewController.m) |
| 正则 | RegexKitLite（Pod）+ RegExCategories（Helper） | Podfile + [HPCommon.h](../HiPDA/Model/HPCommon.h) |
| 其他 | SVProgressHUD、ZAActivityBar、MCSwipeTableViewCell、JDStatusBarNotification、HMSegmentedControl、ALActionBlocks、NSString+Emoji、MTLog | Podfile |

## 目录划分

```
HiPDA/
  main.m                     进程入口
  HPAppDelegate.{h,m}        生命周期、启动装配、后台抓取、本地通知与角标
  HPCommon.h/.plist/.pch     全局宏、常量键名、前缀头、Info.plist、资源
  Controller/                23 个界面控制器（含 2 个基类，见“核心模块表”）
  Model/                     20 个模型 / 单例服务（账号、HTTP、解析、缓存、设置、主题、数据库）
  View/                      表格 Cell、多行文本 Cell、两张读帖 HTML 模板
  Helper/                    分类与工具（字符串、HTML 实体、UserDefaults、图片、颜色等）
  Vender/                    以源码形式引入的第三方库（不改依赖，随工程编译）
  Image/、Images.xcassets/   图标与图片资源
  zh-Hans.lproj/en.lproj/    本地化字符串
HiPDATests/                  XCTest 模板，仅含一个必然失败的示例用例
```

## 主要入口

1. [main.m:12](../HiPDA/main.m) `main()`：直接启动 `HPAppDelegate`。
2. [HPAppDelegate.m:38](../HiPDA/HPAppDelegate.m) `application:didFinishLaunchingWithOptions:`：
   - 建立 `SDURLCache`、恢复归档的 cookie；
   - `[Setting loadSetting]` 载入偏好、注册网络可达性回调、`[HPDatabase prepareDb]` 准备 uid 库；
   - 按夜间模式设置导航栏样式；
   - 启动 `[[HPAccount sharedHPAccount] startCheckWithDelay:30]`（每 5 分钟轮询未读）；
   - 按设置开启后台抓取间隔。
3. Scene 入口：Info.plist 的 `UIApplicationSceneManifest` 指定 `HPSceneDelegate`（定义在 [HPAppDelegate.m:380](../HiPDA/HPAppDelegate.m)）；`scene:willConnectToSession:` 创建 `UIWindow` 并调用 `-[HPAppDelegate setupRootViewControllerWithWindow:]`（[HPAppDelegate.m:121](../HiPDA/HPAppDelegate.m)）组装 `SWRevealViewController`：rear = `HPRearViewController`，front = `HPRearViewController` 持有的 `UINavigationController`（根为 `HPThreadViewController`）。
4. 后台入口 [HPAppDelegate.m:272](../HiPDA/HPAppDelegate.m) `application:performFetchWithCompletionHandler:`。
5. 本地通知入口 [HPAppDelegate.m:177](../HiPDA/HPAppDelegate.m) 与 [HPAppDelegate.m:263](../HiPDA/HPAppDelegate.m)（冷启动时从 launchOptions 取通知）。

## 核心模块表

| 模块 | 关键文件 | 职责 |
| --- | --- | --- |
| 应用装配与生命周期 | `HPAppDelegate.m` | 启动依赖装配、cookie 持久化、后台抓取、本地通知/角标、首次安装清理 |
| 网络客户端 | `Model/HPHttpClient.{h,m}` | `AFHTTPClient` 子类，固定 baseURL 与请求头、GBK 解码、cookie 处理、登录态检测 |
| 账号 | `Model/HPAccount.{h,m}` | 凭据存取（Keychain）、Discuz 登录两步流程、登出、未读轮询、角标数 |
| 帖子列表模型 | `Model/HPThread.{h,m}` | 解析 `forumdisplay.php` 列表行、日期短格式、NSCoding |
| 帖子正文模型 | `Model/HPNewPost.{h,m}` | 解析桌面版/打印版帖子页、正文 HTML 预处理、分页与 formhash 提取 |
| 发帖 | `Model/HPSendPost.{h,m}` | 获取 formhash/uid/hash、发新帖/回复/引用、图片上传、按 pid 校正楼层 |
| 收藏 / 关注 | `Model/HPFavorite.{h,m}`、`Model/HPAttention.{h,m}` | 本地缓存 + 论坛 my.php 收藏/关注增删 |
| 短消息 | `Model/HPMessage.{h,m}` | 消息列表/会话解析、发送、忽略未读、举报 |
| 帖子消息 | `Model/HPNotice.{h,m}` | 解析 `notice.php` 的 thread/quote/reply 三类提醒 |
| 我的帖子/回帖 | `Model/HPMyThread.{h,m}`、`Model/HPMyReply.{h,m}` | 解析 `my.php` 两个列表 |
| 搜索 | `Model/HPSearch.{h,m}` | 标题/全文搜索 URL 拼装与结果解析 |
| 设置 | `Model/HPSetting.{h,m}` | 单例字典形式的偏好存取、默认值、小尾巴校验 |
| 主题 | `Model/HPTheme.{h,m}` | 按夜间模式返回颜色/键盘/指示器样式 |
| 缓存 | `Model/HPCache.{h,m}` | EGOCache 封装：版块列表、帖子页、已读标记、待读列表、头像存在性 |
| uid 库 | `Model/HPDatabase.{h,m}` + `uid.sqlite` | 内置用户名→uid 表；另含未接入 UI 的 uid 抓取工具代码 |
| 视图 | `View/HPThreadCell`、`View/HPRearCell`、`View/post_view(.dark).html` | 列表 Cell、菜单 Cell、读帖 WebView 模板 |
| 基类 | `Controller/HPViewController.{h,m}`、`Controller/HPBaseTableViewController.{h,m}` | 登录通知订阅、主题回调；侧滑手势/刷新控件/翻页控件等公共 UI 工具 |

## 功能清单

> 每个功能一份文档，新增功能请在此表登记。

| 功能名 | 文档路径 | 一句话职责 |
| --- | --- | --- |
| 账号与登录 | [features/account-auth.md](features/account-auth.md) | 凭据存 Keychain、两步登录论坛、失败自动重登、登出与注册占位 |
| 网络层 | [features/network-client.md](features/network-client.md) | 单例 HTTP 客户端：固定请求头、GB18030 解码、cookie 与登录态检测 |
| 版块帖列表 | [features/forum-thread-list.md](features/forum-thread-list.md) | 抓版块列表、下拉刷新/加载更多、左右滑操作、帖子预载入待读 |
| 读帖页 | [features/thread-reader.md](features/thread-reader.md) | 抓正文并用本地 HTML 模板渲染，翻页/跳楼/只看楼主/图片浏览/字号行距 |
| 发帖与回帖 | [features/compose.md](features/compose.md) | 新帖、回复、引用、图片上传的编辑器与提交链路 |
| 收藏与关注 | [features/favorites-attention.md](features/favorites-attention.md) | 收藏/关注主题的本地状态维护与论坛接口同步 |
| 短消息 | [features/private-message.md](features/private-message.md) | 私人消息列表、会话气泡视图、发送、忽略未读与举报 |
| 帖子消息提醒 | [features/thread-notice.md](features/thread-notice.md) | 解析 notice.php 帖子消息，维护未读计数与角标 |
| 我的帖子/回帖 | [features/my-posts.md](features/my-posts.md) | “我的帖子”“我的回帖”两个列表的抓取与打开 |
| 搜索 | [features/search.md](features/search.md) | 标题/全文搜索与结果分页跳转 |
| 设置 | [features/settings.md](features/settings.md) | 偏好项、板块设定、缓存清理、重置、登出、后台刷新开关 |
| 后台刷新 | [features/background-fetch.md](features/background-fetch.md) | iOS 后台抓取同时驱动帖子列表刷新与未读消息检查 |
| 本地缓存 | [features/local-cache.md](features/local-cache.md) | EGOCache 封装：版块/帖子页缓存、已读标记、待读镜像、头像探测 |
| 主题与夜间模式 | [features/theme.md](features/theme.md) | 全局明暗配色、WebView 明暗模板、字号行距持久化 |
| 侧边导航 | [features/navigation-menu.md](features/navigation-menu.md) | SWReveal 侧边菜单：7 个入口 + 收藏版块，未读数字与角标 |
| uid 离线库 | [features/uid-database.md](features/uid-database.md) | 内置 uid.sqlite 把用户名映射成 uid（打印版页面缺 uid 时使用） |

## 已知边界与待确认事项

- **无服务端 API**：所有数据来自网页解析，解析规则与论坛 HTML 结构强耦合；参数不足的问题在 README 中自述。
- `HPDatabase` 中除 `prepareDb` / `sharedDb` / `open` / `close` / `loadProfilePageWithUid` 外的 `setup`、`genDb`、`run`、`start`、`stop`、`getUserWithUid`、`test` 是抓取全站 uid 的开发工具，界面上没有调用方（`test` 内部会调用 `genDb`），属于遗留代码。
- `HPAccount -registerWithBlock:` 只 GET 注册页并直接回调成功，注释也标为 fake；`HPRegisterViewController` 提交后固定提示“等待审核”，并未真正提交注册表单。
- `HPForum +getType:` 注释写明“app 里无用”；`HPCommon +fetchSSIDInfo` 直接返回 nil（实现整段被注释）。
- 偏好默认值中的 `HPSettingFontSize`、`HPSettingLineHeight`、`HPSettingTextFont` 没有任何读取方（界面只用 `*Adjust` 两个键），用途待确认。
- `HPRearViewController` 用 `[[C alloc] init]` 惰性创建列表类控制器，而各控制器的数据装载逻辑放在 `-setup`（由 `HPBaseTableViewController initWithStyle:` 调用）。`-init` 是否最终走到 `initWithStyle:` 依赖 UIKit 行为，待确认。
- 早期 iOS7 适配代码（`IOS7_OR_LATER` 分支、iOS6 兼容布局）仍存在；UI7Kit 已移除（其 UIView category `+initialize` 在 iOS 16+ 会阻止 UIKit 注册自定义 dealloc，触发 `UIButton` dealloc 断言），读帖仍依赖 UIWebView，运行时行为需逐项验证。

## 构建与验证

- 解析回归测试：[HiPDATests/HPCompatibilityTests.m](../HiPDATests/HPCompatibilityTests.m)，fixture 在 [HiPDATests/Fixtures](../HiPDATests/Fixtures/README.md)。当前覆盖公开页面：版块列表、打印版帖子、桌面版帖子、畸形 HTML 不崩溃，读帖页初始 frame 必须有限（防 iOS 27 NaN 几何崩溃），以及设置字典从 UserDefaults 读出后仍可保存。
- 运行：`xcodebuild test -workspace HiPDA.xcworkspace -scheme HiPDA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HiPDATests`（或 Xcode 里 Cmd+U）。
- 刷新公开 fixture：`./scripts/update_public_fixtures.sh`；静态兼容性扫描：`./scripts/compat_audit.sh`。
- 私信、帖子提醒、我的帖子/回帖、收藏、搜索需要登录态 HTML，目前没有 fixture，解析尚未纳入回归；补 fixture 后在 `HPCompatibilityTests.m` 增加对应断言。
