# uid 离线库

## 职责

App 包内附带一个用户名 → uid 的 SQLite 表（约 8.8 万条）。用途：**打印版帖子页面不包含作者 uid**，客户端只有用户名，需要用该表反查 uid，才能拼出头像 URL（头像地址由 uid 计算）。除此之外不提供任何用户资料功能。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPDatabase.m:67](../../HiPDA/Model/HPDatabase.m) | `+prepareDb`：首次启动把包内 `uid.sqlite` 拷贝到 `Documents/uid.db` |
| [HPDatabase.m:40](../../HiPDA/Model/HPDatabase.m) | `+sharedDb`：以 `Documents/uid.db` 建 `FMDatabase` |
| [HPDatabase.m:57](../../HiPDA/Model/HPDatabase.m) | `-open` / [HPDatabase.m:63](../../HiPDA/Model/HPDatabase.m) `-close` |
| [HPAppDelegate.m:92](../../HiPDA/HPAppDelegate.m) | 启动时调用 `prepareDb` |
| [HPNewPost.m:313](../../HiPDA/Model/HPNewPost.m) | 打印版解析后 `open` 数据库 |
| [HPNewPost.m:321](../../HiPDA/Model/HPNewPost.m) | 按用户名查询 uid |
| [HPNewPost.m:331](../../HiPDA/Model/HPNewPost.m) | 用完 `close` |
| [HPDatabase.m:355](../../HiPDA/Model/HPDatabase.m) | `+loadProfilePageWithUid:block:` 抓用户资料页（供抓取工具使用） |

## 核心代码位置

- 表结构：单表 `user(username text PRIMARY KEY, uid integer)`（可用 sqlite3 对包内 `HiPDA/uid.sqlite` 验证；包内约 87,967 行）。
- 数据库文件：`HiPDA/uid.sqlite`（作为资源打进 App），运行时路径 `Documents/uid.db`。
- 查询：`SELECT uid FROM user WHERE username = ?`（[HPNewPost.m:321](../../HiPDA/Model/HPNewPost.m)）。
- 头像 URL 拼装：`HPUser +avatarStringWithUid:` 由 uid 计算三段目录（[HPUser.m:80](../../HiPDA/Model/HPUser.m)）；`HPNewPost` 拿到 uid 后设置 `post.user.uid` 与 `avatarImageURL`。
- 打印版的楼层号在该流程中按数组下标 +1 补齐（打印版没有楼层字段），作者取第一楼的用户。

## 执行流程

```
启动
  └─ +[HPDatabase prepareDb]
       ├─ Documents/uid.db 不存在 → 从 bundle 拷贝 uid.sqlite
       └─ 已存在 → 直接使用

读打印版帖子（HPNewPost +loadPrintableThreadWithTid:）
  └─ +extractPosts:
       ├─ 正则解析“作者 / 时间 / 正文”若干楼
       ├─ [[HPDatabase sharedDb] open]
       ├─ 逐楼：SELECT uid FROM user WHERE username = ?
       │        └─ post.user.uid / avatarImageURL
       └─ [[HPDatabase sharedDb] close]
```

## 数据流

```
uid.sqlite（bundle，只读源）
   └─ 首次启动拷贝 → Documents/uid.db
                        │
            HPNewPost 打印版解析（username 查询）
                        │
              HPUser.uid / avatarImageURL → 读帖页头像
```

## 依赖关系

- 依赖：FMDB、`NSString+Additions`、`HPHttpClient`（仅 `loadProfilePageWithUid:` 用）、`HPUser`（头像 URL 规则）。
- 被依赖：`HPNewPost`（打印版解析）、`HPAppDelegate`（准备数据库）。
- 相关功能：[读帖页](thread-reader.md)、[网络层](network-client.md)、[本地缓存](local-cache.md)。

## 未接入界面的开发者代码（重要）

`HPDatabase` 中除上述公共方法外，还有一套**抓取全站 uid 的一次性工具**，当前没有任何界面入口调用：

| 方法 | 位置 | 行为 |
| --- | --- | --- |
| `-setup` | [HPDatabase.m:97](../../HiPDA/Model/HPDatabase.m) | 打开 `Documents/user.db`（注意与 `uid.db` 不是同一个文件），注释掉的建表语句 |
| `-test` | [HPDatabase.m:144](../../HiPDA/Model/HPDatabase.m) | 开发者调试入口，内部调用 `genDb` |
| `-genDb` | [HPDatabase.m:220](../../HiPDA/Model/HPDatabase.m) | 把 `Documents/uid.db` 的数据整理后写入新表 |
| `-run` / `-start` / `-stop` | [HPDatabase.m:261](../../HiPDA/Model/HPDatabase.m) | 1 秒定时器，每轮并发抓 50 个 uid（常量 `START`/`END`） |
| `-getUserWithUid:` | [HPDatabase.m:290](../../HiPDA/Model/HPDatabase.m) | GET `forum/space.php?uid=`，从资料页解析用户名与“上次访问”，插入本地表 |

- 这套代码会大量请求论坛资料页，启动方式为调用 `-start`（或 `-test`），当前编译进来但不执行。若要启用/删除，需注意它与主流程共用 `FMDatabase` 属性但路径不同（`user.db` vs `uid.db`）。
- 包内 `uid.sqlite` 的生成过程没有在仓库中记录（推断由上述工具抓取后整理），**待确认**。

## 已知边界

- 数据是离线快照：新注册用户查不到 uid，打印版该用户将没有头像。
- 查询是精确匹配用户名；论坛改名后旧名失效。
- `prepareDb` 只在文件不存在时拷贝，App 升级不会更新内置表（除非用户删 App）。
- 数据库打开/关闭是显式成对调用（无引用计数），若同一时刻多处使用需注意线程与开关状态；目前只在实际解析打印版时使用。
