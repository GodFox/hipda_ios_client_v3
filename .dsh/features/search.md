# 搜索

## 职责

提供两种搜索：**按标题**与**全文搜索**。搜索结果分页展示，点击结果打开读帖页（标题搜索从第 1 页打开；全文搜索按命中的 pid 定位楼层）。界面从侧边菜单顶部的放大镜图标以模态方式弹出。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPSearchViewController.m:36](../../HiPDA/Controller/HPSearchViewController.m) | 搜索页 `viewDidLoad`（搜索栏 + 范围按钮“标题/全文”） |
| [HPSearchViewController.m:106](../../HiPDA/Controller/HPSearchViewController.m) | `-search:` 发起搜索 / 翻页 |
| [HPSearchViewController.m:189](../../HiPDA/Controller/HPSearchViewController.m) | `-prevPage:` |
| [HPSearchViewController.m:199](../../HiPDA/Controller/HPSearchViewController.m) | `-nextPage:` |
| [HPSearchViewController.m:300](../../HiPDA/Controller/HPSearchViewController.m) | `-tableView:didSelectRowAtIndexPath:` |
| [HPSearch.m:21](../../HiPDA/Model/HPSearch.m) | `+searchWithParameters:type:page:block:` 唯一数据入口 |
| [HPRearViewController.m:443](../../HiPDA/Controller/HPRearViewController.m) | `-showSearchVC:` 模态打开搜索页 |

## 核心代码位置

- 类型枚举：`HPSearchTypeTitle` / `HPSearchTypeFullText`（来自 [HPSearch.h](../../HiPDA/Model/HPSearch.h)），与搜索栏 scope 下标一一对应。
- 路径：
  - 标题：`forum/search.php?srchtxt=…&srchtype=title&searchsubmit=true&st=on&…&page=`
  - 全文：`forum/search.php?srchtype=fulltext&srchtxt=…&…&page=`
  - 关键词以 GB18030 编码做百分号转义后拼入路径。
- 页数：从页面文本中截取“相关主题 N 个”，按每页 50 条换算页数，并封顶 20 页（论坛搜索限制）。
- 结果解析（标题）：tid、标题、fid、版块名、uid、用户名、日期。
- 结果解析（全文）：pid、标题、正文摘要、fid、版块名、uid、用户名。
- 关键词高亮 `em style="color:red;"` 在标题/摘要里被替换成「」，多余换行合并为空格。
- 单元格：标题搜索显示“标题 + 版块/作者/日期”；全文搜索显示“摘要 + 标题/作者”；行高按内容 `boundingRect` 计算，最小 50。

## 执行流程

1. 读取搜索栏文本与 scope；关键词为空则提示并聚焦搜索栏。
2. 标题临时改为“搜索: 关键词”；请求中显示 HUD。
3. `+searchWithParameters:type:page:block:` 成功后：
   - 保存结果与页数；
   - 标题变成“搜索: 关键词 (当前页/总页数)”；
   - 右上按钮从“搜索”换成翻页分段控件（上一页/下一页）。
4. 翻页：上一页要求当前页 > 1；下一页要求当前页 < 计算出的页数；两者都会以“前往第 N 页…”重新调 `-search:`。
5. 失败或空结果：恢复标题“搜索”和右上“搜索”按钮；空结果提示“没有找到匹配结果”并聚焦搜索栏。
6. 点击结果：
   - 用字典字段构造临时 `HPThread`（fid/tid/title）；
   - 全文结果额外取 `pidString` 作为 `find_pid`；
   - push `HPReadViewController`（全文用 `initWithThread:find_pid:`，标题用 `initWithThread:`）。

## 数据流

```
HPRearViewController -showSearchVC:（模态）
        │
HPSearchViewController（UISearchBar + 结果表格）
        │
HPSearch +searchWithParameters:type:page:
        ├─ GB18030 转义 → GET forum/search.php
        ├─ “相关主题 N 个” → pageCount（/50 向上取整，封顶 20）
        └─ 正则 → 字典型结果数组（title/detail/fidString/forum/uidString/username/…）
        │
点击 → HPThread(临时) → HPReadViewController（全文带 find_pid）
```

## 依赖关系

- 依赖：`HPSearch`（解析与拼 URL）、`HPHttpClient`、`HPThread`、`HPReadViewController`、`HPBaseTableViewController`（关闭按钮、翻页控件）、`SVProgressHUD`、`HPAlert`、`NSString+Additions`。
- 被依赖：只有 `HPRearViewController`（放大镜入口）。
- 相关功能：[读帖页](thread-reader.md)、[侧边导航](navigation-menu.md)、[网络层](network-client.md)（全文结果依赖 pid 跳转）。

## 已知边界

- 单次搜索期间不缓存结果，翻页等于重新请求，切页/改 scope 会重置到第 1 页且清空标题状态。
- 页数完全依赖“相关主题 N 个”这段文案，取不到则页数为 0，从而“下一页”直接提示已是最后一页（即使有结果）。
- 搜索接口本身受论坛频率限制，代码没有做节流或错误重试（认证错误只在 `HPHttpClient` 层触发一次重登）。
- 结果字典用字符串键存取（`tidString`/`pidString`/`fidString` 等），未统一成模型对象；全文结果为空的 pid 时 `find_pid` 为 0，会退回第 1 页。
