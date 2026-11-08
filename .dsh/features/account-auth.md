# 账号与登录

## 职责

- 保存 / 校验账号凭据（用户名存 `NSUserDefaults`，密码与安全提问数据存 Keychain）。
- 用浏览器同款表单流程登录 Discuz 论坛（先 GET 登录页取 formhash；4d4y 登录页没有 formhash，允许为空，再 POST 登录），并把结果广播成通知。
- 未登录时弹登录页；请求过程中被判定为“掉登录态”时自动重登。
- 登出（清 Keychain、清持久化域、恢复默认设置、清 cookie）。
- 注册流程（占位，见“已知边界”）。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPAccount.m:59](../../HiPDA/Model/HPAccount.m) | `+sharedHPAccount` 单例 |
| [HPAccount.m:69](../../HiPDA/Model/HPAccount.m) | `+isSetAccount`：用户名非空 + Keychain 里有 3 段凭据 |
| [HPAccount.m:78](../../HiPDA/Model/HPAccount.m) | `-loginWithBlock:` 登录主入口（第一步 GET 登录页，formhash 可为空） |
| [HPAccount.m:123](../../HiPDA/Model/HPAccount.m) | `-_loginWithFormhash:block:` 第二步提交登录 |
| [HPAccount.m:254](../../HiPDA/Model/HPAccount.m) | `-logout` |
| [HPAccount.m:278](../../HiPDA/Model/HPAccount.m) | `-registerWithBlock:`（fake） |
| [HPLoginViewController.m:51](../../HiPDA/Controller/HPLoginViewController.m) | 登录界面构建；“确定”按钮处理在 [HPLoginViewController.m:117](../../HiPDA/Controller/HPLoginViewController.m) |
| [HPSettingViewController.m:111](../../HiPDA/Controller/HPSettingViewController.m) | 设置页的“登出”项 |
| [HPViewController.m:34](../../HiPDA/Controller/HPViewController.m) | 基类在 `viewWillAppear` 订阅 / `viewWillDisappear` 取消订阅登录通知 |

## 核心代码位置

- 凭据格式：Keychain `service = HPAccount`、`account = 用户名`，密码值为三段用换行拼接：密码、安全提问编号、安全提问答案（[HPAccount.m:69](../../HiPDA/Model/HPAccount.m)、[HPAccount.m:125](../../HiPDA/Model/HPAccount.m)）。
- 登录请求：`forum/logging.php?action=login`（取 formhash，4d4y 登录页可能没有该字段）与 `forum/logging.php?action=login&loginsubmit=yes&inajax=1`（提交）。
- 表单字段：`loginfield=username`、`username`、`password`、`questionid`、`answer`、`cookietime`、`referer`、`formhash`（可为空）（[HPAccount.m:137](../../HiPDA/Model/HPAccount.m)）。
- 成功判定：响应 HTML 中出现“欢迎您回来”；失败时取 CDATA 或整页作为错误文案（[HPAccount.m:153](../../HiPDA/Model/HPAccount.m)）。
- 登录页 UI：RETableViewManager 表单（用户名、密码、安全提问单选、答案、确定），安全提问共 8 个选项对应 0–7（[HPLoginViewController.m:88](../../HiPDA/Controller/HPLoginViewController.m)）。

## 执行流程

### 登录

1. 调用方（列表刷新、读帖、收藏、消息等）在需要登录的操作里调用 `-loginWithBlock:`。
2. `+isSetAccount` 为假：立刻 `present` 登录页，并回调 `kHPNoAccountCode` 错误，不再发请求。
3. 已设置账号：GET 登录页 → 尝试从 HTML 中截取 formhash。
   - 4d4y 登录页没有 formhash 隐藏字段；只要页面包含 `loginform` 就继续用空 formhash 提交。
   - 页面不是登录页（没有 `loginform`）才截取 `alert_info` / `alert_error` 文案作为错误描述返回。
4. `-_loginWithFormhash:` 从 UserDefaults 取用户名、从 Keychain 取三段凭据；凭据段数不足直接返回“Keychain 出问题了”。
5. POST 登录表单 → 判定成功/失败 → post `kHPUserLoginSuccess` 或 `kHPUserLoginError`（附带 error）→ 回调调用方。
6. `HPViewController` / `HPTableViewController` 基类在可见期间收到这两条通知；子类覆盖 `loginSuccess:` / `loginError:` 做 UI 反馈（例如列表页刷新、读帖页重载）。

### 登录界面提交

1. 先 `logout` 清掉旧账号（[HPLoginViewController.m:120](../../HiPDA/Controller/HPLoginViewController.m)）。
2. 校验用户名/密码非空；安全提问取选项字符串首字符作为编号。
3. 用户名写入 UserDefaults（键 `HPAccountUserName`），三段凭据写入 Keychain。
4. 调用 `-loginWithBlock:`；成功则关闭登录页并触发 `[HPRearViewController threadVCRefresh]`，失败提示错误并再次 `logout`。

### 登出

1. 删除该用户名的 Keychain 项。
2. `removePersistentDomainForName:` 清空 App 的 UserDefaults。
3. `[Setting loadDefaults]` 重建默认偏好。
4. 遍历 `NSHTTPCookieStorage` 删除所有 cookie。

### 直接凭据的存放

- 登录成功后，cookie 由 `HPHttpClient` 的请求设置 `HTTPShouldHandleCookies` 自动维护；`HPAppDelegate` 在进入非活跃状态时把 cookie 归档进 UserDefaults（键 `kUserDefaultsCookie`），下次启动恢复（[HPAppDelegate.m:55](../../HiPDA/HPAppDelegate.m)、[HPAppDelegate.m:147](../../HiPDA/HPAppDelegate.m)）。

## 数据流

```
用户输入 → HPLoginViewController
    ├─ NSUserDefaults: HPAccountUserName
    └─ SSKeychain: password\nquestionid\nanswer
                    │
HPAccount.loginWithBlock ──> HPHttpClient
    ├─ GET  logging.php?action=login        → formhash（可为空）
    └─ POST logging.php?...loginsubmit=yes  → HTML
         ├─ NSNotification kHPUserLoginSuccess / kHPUserLoginError
         ├─ NSHTTPCookieStorage（会话 cookie）
         └─ block(isLogin, error)
```

## 依赖关系

- 依赖：`HPHttpClient`（网络、GBK 解码）、`HPCommon`（`NVCWithRootVC` 包导航）、`HPLoginViewController`（未登录时弹出；它负责登录成功后刷新首页）、`HPRearViewController`（更新角标）、`HPSetting` / `HPTheme`、`SSKeychain`、`NSString+Additions`（`stringBetweenString`、`indexOf`）。
- 被依赖：几乎所有需要“登录态”的功能（列表、读帖、发帖、收藏关注、消息、提醒、搜索）在遇到认证错误时会走到这里；`HPHttpClient +prepareHTML:error:` 也会在检测到登录页时反向调用它。
- 相关功能：[网络层](network-client.md)、[设置](settings.md)、[后台刷新](background-fetch.md)（未读轮询由 `HPAccount` 承担，详见[帖子消息提醒](thread-notice.md)）。

## 已知边界

- `+registerWithBlock:` 只请求注册页就回调成功（源码注释 `//fake`），`HPRegisterViewController` 提交后固定提示“感谢您的注册, 请等待管理人员进行审核”，并不提交任何注册字段；界面上 email 输入项被创建但未加入表单分区。
- `logout` 后 `HPAccount` 的定时器不会主动停止（定时器创建逻辑见 `-checkMsgAndNotice`，未做登出清理），后续轮询会因未登录再次走到登录流程——是否算缺陷待确认。
- 登录请求的用户名/密码安全提问参数以明文表单提交（论坛本身即如此），代码未做额外加密。4d4y 登录页不再包含 formhash，提交时 formhash 为空；如果服务端后续要求 Discuz X 的 password3/MD5，需要另行适配（待确认）。
