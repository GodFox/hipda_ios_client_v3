# Parser fixtures

这些 HTML 来自 4d4y.com 的**公开页面**，用于 `HiPDATests/HPCompatibilityTests.m` 的解析回归：

- `forumdisplay.html`：版块列表（fid=7，公开版块）
- `printable.html`：打印版帖子（tid=448060）
- `viewthread.html`：桌面版帖子（tid=448060）

更新：

```sh
./scripts/update_public_fixtures.sh
```

私信、帖子提醒、我的帖子/回帖、收藏、搜索需要登录态，未包含在这里。补这类 fixture 时保持 UTF-8 编码，并在 `HPCompatibilityTests.m` 增加对应断言。
