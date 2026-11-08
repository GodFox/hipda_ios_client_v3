# 网络层（HPHttpClient）

## 职责

全应用唯一的 HTTP 客户端（`AFHTTPClient` 子类），统一处理：

- 固定 baseURL 与一批伪装浏览器的请求头；
- 响应字节的 GB18030（GBK 超集）解码，UTF-8 兜底；
- cookie 自动处理；
- “响应其实是登录页 / 未登录”这一论坛特有错误的检测与自动重登。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPHttpClient.m:19](../../HiPDA/Model/HPHttpClient.m) | `+sharedClient`：`dispatch_once` 创建单例；设置字符串编码为 GB18030 |
| [HPHttpClient.m:46](../../HiPDA/Model/HPHttpClient.m) | `-initWithBaseURL:`：注册 operation 类、设置默认请求头 |
| [HPHttpClient.m:65](../../HiPDA/Model/HPHttpClient.m) | `-getPathContent:parameters:success:failure:`：业务代码最常用的 GET 封装 |
| [HPHttpClient.m:91](../../HiPDA/Model/HPHttpClient.m) | `-requestWithMethod:path:parameters:`：覆写以强制 `HTTPShouldHandleCookies` |
| [HPHttpClient.m:108](../../HiPDA/Model/HPHttpClient.m) | `+GBKresponse2String:`：GB18030 → UTF-8 兜底 |
| [HPHttpClient.m:123](../../HiPDA/Model/HPHttpClient.m) | `+prepareHTML:error:`：登录页检测 |

## 核心行为

- baseURL 固定为论坛站点根路径（`https://www.4d4y.com/`），所有 path 都是相对路径（`forum/...`、`forum/mypost` 等）。
- 默认请求头包含 Host、移动版 Safari 的 User-Agent、Accept、Accept-Encoding、`Accept-Language: zh-cn`、Referer（指向 Discovery 版块列表页）。
- 字符串编码通过 `setStringEncoding:` 设为 GB18030；同时提供手动解码方法给 `postPath` 的响应使用（`HPSendPost`、`HPMessage`、`HPFavorite` 等在 POST 回调里自行调用 `GBKresponse2String:`）。
- `-getPathContent:` 把 `id` 响应交给 `+prepareHTML:error:` 转成 `NSString`：若转换出错（被判定为需要登录）则走 failure，否则走 success 并带上 HTML 字符串。
- `+prepareHTML:error:` 在 HTML 中找到登录表单标记（`loginform`）时：
  1. 立即调用 `[[HPAccount sharedHPAccount] loginWithBlock:]` 尝试重登（结果只打日志）；
  2. 返回 `NSURLErrorUserAuthenticationRequired` 错误，调用方据此提示或跳过。
- 未显式处理多线程，业务回调里直接操作 UI，依赖 AFNetworking 1.3 的回调队列行为。

## 执行流程（典型 GET）

```
业务代码 [HPHttpClient sharedClient] getPathContent:path
  → AFHTTPClient 组装 NSMutableURLRequest（自动带 cookie）
  → 服务器返回 bytes（GBK 编码的 HTML）
  → +GBKresponse2String: → NSString
  → +prepareHTML:error:
       ├─ 含 loginform → HPAccount 重登 + 返回认证错误
       └─ 正常 → success(operation, html)
  → 业务层正则解析
```

## 数据流

```
Controller / Model ──path+params──> HPHttpClient ──HTTPS──> 4d4y.com
                                        │
                          NSHTTPCookieStorage（会话）
                                        │
                        HPAppDelegate 在 willResignActive 归档 cookie
                        启动时反归档并写回 cookie 存储
```

## 依赖关系

- 依赖：AFNetworking 1.3、`HPAccount`（重登）、`NSString+Additions`（`indexOf`）、系统 `NSURLCache`（被替换为 `SDURLCache`）。
- 被依赖：全部业务 Model（`HPThread`、`HPNewPost`、`HPSendPost`、`HPMessage`、`HPNotice`、`HPMyThread`、`HPMyReply`、`HPFavorite`、`HPAttention`、`HPSearch`、`HPDatabase`）以及 `HPAccount` 自身。
- 相关功能：[账号与登录](account-auth.md)、[本地缓存](local-cache.md)（`SDURLCache` 在启动时替换共享缓存）。

## 注意点

- 错误码约定：`NSURLErrorUserAuthenticationRequired` 表示“需要登录/掉登录态”；`NSURLErrorCancelled` 在读帖页被忽略；`kHPNoAccountCode` 表示“本机没有配置账号”。
- 上传图片走独立分支（`multipartFormRequestWithMethod:` + 自定义 `AFHTTPRequestOperation`），进度回调由 `HPSendPost` 提供，见[发帖与回帖](compose.md)。
- 站点只能通过 HTTP 访问（源码中的 URL 均为 `http://`），未做 HTTPS 配置。
