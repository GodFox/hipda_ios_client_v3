# 发帖与回帖（含图片上传）

## 职责

三类编辑场景共用一套编辑器与提交链路：

- **发新主题**（版块内右上角“写”）；
- **回复主题**（读帖页“回复”按钮）；
- **回复某人 / 引用某人**（读帖页楼层面板）；
- 附带**图片上传**：拍照/相册选图 → 压缩 → 上传到论坛附件接口 → 把附件码插入正文。

## 入口

| 位置 | 说明 |
| --- | --- |
| [HPBaseCompostionViewController.m:49](../../HiPDA/Controller/HPBaseCompostionViewController.m) | 编辑器基类 `viewDidLoad`：正文输入框、工具栏（拍照/表情）、发送/取消按钮、键盘高度适配 |
| [HPBaseCompostionViewController.m:177](../../HiPDA/Controller/HPBaseCompostionViewController.m) | 基类 `-send:`（`assert(0)`，子类必须覆写） |
| [HPBaseCompostionViewController.m:183](../../HiPDA/Controller/HPBaseCompostionViewController.m) | `-doneWithError:`：关闭编辑器并回调 `HPCompositionDoneDelegate` |
| [HPBaseCompostionViewController.m:210](../../HiPDA/Controller/HPBaseCompostionViewController.m) | `-completeWithAttachString:error:`：把上传返回的附件码插入正文并记录到 `imagesString` |
| [HPNewThreadViewController.m:45](../../HiPDA/Controller/HPNewThreadViewController.m) | 发新帖界面（标题框 + 分类选择器） |
| [HPNewThreadViewController.m:128](../../HiPDA/Controller/HPNewThreadViewController.m) | `-loadFormhash` |
| [HPNewThreadViewController.m:169](../../HiPDA/Controller/HPNewThreadViewController.m) | `-send:` |
| [HPReplyTopicViewController.m:37](../../HiPDA/Controller/HPReplyTopicViewController.m) | 回复主题的初始化（`ActionTypeNewPost`） |
| [HPReplyTopicViewController.m:99](../../HiPDA/Controller/HPReplyTopicViewController.m) | `-send:` |
| [HPReplyViewController.m:41](../../HiPDA/Controller/HPReplyViewController.m) | 回复/引用某楼的初始化（`ActionTypeReply` / `ActionTypeQuote`） |
| [HPReplyViewController.m:83](../../HiPDA/Controller/HPReplyViewController.m) | `-loadFormhashAndPid`：补齐 formhash 与目标楼层 pid |
| [HPReplyViewController.m:131](../../HiPDA/Controller/HPReplyViewController.m) | `-send:`（含 30 秒限制的倒计时重发） |
| [HPSendPost.m:25](../../HiPDA/Model/HPSendPost.m) | `+sendPostWithContent:...`：四类动作的统一提交 |
| [HPSendPost.m:350](../../HiPDA/Model/HPSendPost.m) | `+loadParameters:fid:tid:re:block:`：抓 formhash/posttime/uid/hash |
| [HPSendPost.m:425](../../HiPDA/Model/HPSendPost.m) | `+loadFormhashAndPid:post:tid:page:block:` |
| [HPSendPost.m:272](../../HiPDA/Model/HPSendPost.m) | `+uploadImage:imageName:progressBlock:block:` |
| [HPImageUploadViewController.m:47](../../HiPDA/Controller/HPImageUploadViewController.m) | 上传图片界面 |
| [HPImageUploadViewController.m:193](../../HiPDA/Controller/HPImageUploadViewController.m) | `-uploadPic:` |

## 核心代码位置

### 编辑器基类

- 正文是 `UITextView`，初始文案为占位字符串（获得焦点后清空）；颜色、键盘外观跟随夜间模式。
- 底部工具栏含“拍照”（打开 `HPImageUploadViewController`）与“表情”（切到 `WUEmoticonsKeyboard`），@ 按钮已声明但未加进工具栏。
- 监听键盘 frame 变化通知，动态缩短输入框并移动工具栏。
- 右上为“发送”与菊花（token 拉取中的状态指示），左上为“取消”。

### 表单参数

`+loadParameters:fid:tid:re:block:` 实际只请求 `forum/post.php?action=newthread&fid=57`，从 HTML 截取四项：`formhash`、`posttime`、`uid`、`hash`（缺项用 `NSNull` 占位）。源码注释说明“测试下来参数应该是一样的”，因此回复与发帖共用同一入口。

### 提交

- 动作类型枚举：`ActionTypeReply(0)`、`ActionTypeQuote(1)`、`ActionTypeNewPost(2)`、`ActionTypeNewThread(3)`（[HPSendPost.h:14](../../HiPDA/Model/HPSendPost.h)）。
- 路径：
  - 回复/引用/回复主题：`forum/post.php?action=reply&fid=&tid=&extra=&replysubmit=yes`；
  - 发新主题：`forum/post.php?action=newthread&fid=&extra=&topicsubmit=yes`。
- 正文会追加设置里的“小尾巴”（`[Setting postTail]`，格式为 `[size=1]…[/size]`，未设置则为空串），emoji 会先转成论坛可识别的“cheat codes”。
- 引用场景还会拼“引用块”文案（原帖纯文本最多截 150 字）与通知作者字段；回复场景则拼“回复楼层”的引用头。
- 图片：仅当 `images` 非空时，为每个附件名补一个 `attachnew[…]` 描述字段。
- 成败判定：响应 HTML 中出现 `alert_info` 或 `alert_error` 段落即视为失败（文本作为错误描述），否则视为成功。

### 图片上传

1. `+uploadImage:` 先调 `+loadParameters:` 拿 `uid` 与 `hash`（缺失则返回“没抓到”的错误）。
2. 构造 multipart 请求 POST 到 `forum/misc.php?action=swfupload&operation=upload&simple=1&type=image`，字段为 `uid`、`hash`、`Filedata`（文件名默认 `iOS_fly_随机数`，MIME 固定 jpeg）。
3. 用 `setUploadProgressBlock` 回传进度。
4. 响应按 `|` 分割，期望第一段为 `DISCUZUPLOAD`、第二段为 `0`，第三段即附件码；附件码回传编辑器插入正文（`[attachimg]…[/attachimg]`）。
5. 上传界面的压缩策略：按分段控件选择目标边长 400/600/800/1000，默认 600；缩放后固定 JPEG 质量 0.35；拍照来源在无相机时退化为相册。

## 执行流程

### 发新主题

```
HPThreadViewController -newThread:  →  HPNewThreadViewController initWithFourm:delegate:
  ├─ viewDidLoad：按 fid 反查版块名做标题；forumTypeWithFid 读 forums_type.plist 得分类
  ├─ loadFormhash → HPSendPost +loadParametersWithBlock:
  └─ -send:（校验标题/正文非空）
       └─ HPSendPost +sendThreadWithFid:type:subject:message:images:formhash:block:
            └─ +sendPostWithContent:（ActionTypeNewThread）
                 └─ 成功 → -doneWithError: → HPCompositionDoneDelegate
```

### 回复主题

```
HPReadViewController -reply:
  → HPReplyTopicViewController initWithThread:delegate:（ActionTypeNewPost）
       ├─ loadFormhash（同发帖的 loadParameters）
       └─ -send: → HPSendPost +sendReplyWithThread:content:imagesString:formhash:
            └─ +sendPostWithContent:（ActionTypeNewPost）→ POST post.php?action=reply
                 └─ 成功 → doneWithError: → 读帖页 compositionDoneWithType:（跳最后一页重载）
```

### 回复 / 引用某楼

```
HPReadViewController actionForFloor: → -replySomeone: / -quoteSomeone:
  → HPReplyViewController initWithPost:actionType:thread:page:delegate:
       ├─ 已有 thread.formhash 且 post.pid 非 0 → 直接可发
       ├─ 否则 -loadFormhashAndPid → HPSendPost +loadFormhashAndPid:
       │      └─ 强制刷新该页帖子，用“用户名 + 楼层”匹配出带 pid 的目标楼层
       └─ -send:（引用时先把原帖正文转纯文本截 150 字）
            └─ +sendPostWithContent:（ActionTypeReply / ActionTypeQuote）
                 └─ 若返回“两次发表间隔少于 30 秒” → 提供 31 秒倒计时自动重发
```

## 数据流

```
用户输入正文（+ 可选附件码 / 表情 / 小尾巴）
        │
loadParameters → formhash / uid / hash
        │
POST forum/post.php?action=reply|newthread
        ├─ 响应 HTML：alert_info / alert_error → NSError
        └─ 成功 → HPCompositionDoneDelegate
                    ├─ 列表页：-compositionDoneWithType:error: → 刷新列表
                    └─ 读帖页：跳到最后一页并重载、滚动到底部
```

## 依赖关系

- 依赖：`HPSendPost`、`HPNewPost`（引用内容/日期）、`HPThread`、`HPUser`、`HPSetting`（小尾巴）、`HPTheme`、`HPHttpClient`、`HPForum`（版块名与分类）、`HPImageUploadViewController`、`WUEmoticonsKeyboard`、`NSString+Emoji`、`SVProgressHUD`、`HPAlert`。
- 被依赖：`HPThreadViewController`（发新帖）、`HPReadViewController`（三种编辑入口）、`HPBaseCompostionViewController` 的 delegate 协议 `HPCompositionDoneDelegate`。
- 相关功能：[读帖页](thread-reader.md)、[版块帖列表](forum-thread-list.md)、[设置](settings.md)（小尾巴）、[网络层](network-client.md)。

## 已知边界

- `ActionTypeReply` 的请求路径把 fid 写成常量 100 而不是真实 fid（源码中直接写死），只有 `ActionTypeQuote` 与 `ActionTypeNewPost/NewThread` 使用真实 fid——回复仍能成功说明论坛不校验该参数，但这是明显的遗留写法。
- 引用/回复目标楼层靠“用户名 + 楼层号”匹配，若该页在拉取时已被顶动或作者改名，会拿不到正确 pid，进而弹“获取回复token失败”。
- 表情键盘的回调由 WUEmoticonsKeyboard 的 custom builder 提供，`@` 提及功能未实现（`-mentionButtonTouched` 为空）。
- 编辑器没有草稿保存（`-cancelCompose:` 中标注 todo）。
- 图片上传固定 JPEG、固定质量 0.35，不保留原图格式；上传失败只提示错误文本。
