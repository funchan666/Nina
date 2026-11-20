# Nina 开发需求与交付

2026-11-20 按用户要求恢复 Swift + SwiftUI 原生 App。target、scheme、显示名为 Nina，Bundle ID 为 com.funchan666.nina，最低 iOS 17.6。本机 SDK 为 iPhoneOS 27.1。React Native、TypeScript、Metro、npm 和 CocoaPods 已从当前工程移除。

## 主流程

| 入口 | 目标与动作 |
| --- | --- |
| Discover | 原生社区主页面，朋友互动横幅、搜索、地形 / 收藏筛选、图库、图文与短片详情、点赞、收藏、评论、举报和发布。 |
| Sessions | Sessions / Plans / Spots 三个分区。保存场地、地形、障碍、地面与访问说明；记录动作、站姿、目标、尝试、落地、用时、笔记和媒体参考，编辑或删除记录。 |
| Crew | 在已有档案中按姓名、关注或共享板点查找，查看资料、关系与共享训练，关注、聊天、举报和拉黑。 |
| Inbox | Chats / Drafts / Activity。互关后保存消息、显示收件人未读、打开会话标记已读、删除自己的消息及保存 / 丢弃草稿。 |
| You | 编辑头像、姓名、站姿与简介；关系、个人练习、发布与审核队列、完整收藏、钱包、封面、设置、官网协议、黑名单、退出和删档。 |

只有贡献者主动选择共享且记录实际尝试的训练才进入 Crew 的板点列表。关注由用户操作建立，互关且未被拉黑或举报才允许发送消息、保存草稿和打开等待预览。语音只检查麦克风权限，视频额外检查摄像头并显示可移动的真实前置画面；没有远端接通状态。

会话、关注、评论、举报、未读和练习均保存于同一应用的档案，没有跨设备投递、同步或业务后端。不创建虚构用户、自动回关、远端回复或虚假在线状态。

## 登录与媒体

邮箱入口需要勾选协议。有效邮箱不超过 254 字符；密码非空、不全为空白且不超过 256 字符即可打开档案。邮箱去除首尾空白并转小写，首次创建、后续复用，不验证邮箱归属或已存密码，不保存输入密码。Keychain 保留既有会话和账号 UUID。苹果入口使用官方 SignInWithAppleButton 和 AuthenticationServices 系统授权。

相册使用 PHPicker，照片和影片拍摄使用系统相机，导入独立账号沙盒。提交保留为仅本人可见的待审核记录，可编辑、删除和查看附件。举报保存原因并立即隐藏目标；拉黑移除双方关注，隐藏内容、会话和活动。删档级联清理数据及媒体，并重试未完成的清理。

## 资源与原生工程

用户授权的 50 张照片、16 条影片和 16 张首帧仍随 Nina.zip 分发，未重命名或再次转码。OfflineArchive 以资源摘要复用安装目录，限制路径、条目数量、解压量并检查 CRC。NinaConfiguration 验证清单与本地媒体存在，SwiftUI 图片和 AVPlayer 直接读解压目录。

全部业务页面位于 Nina/Sources；入口为 Application/NinaApp.swift，导航为 Application/NinaFlow.swift，数据由 NinaLibrary 与 Features 中的扩展管理。原创欢迎、底图、图标和封面由 Asset Catalog 打包，字体及许可仍保留。旧 ZIP 内的网页只是兼容资源，不再承担登录或业务界面。

Xcode 可打开 Nina.xcodeproj 或 Nina.xcworkspace；选择 Nina scheme。ZIPFoundation 0.9.20 通过 Swift Package Manager 精确固定，两个入口均保留 Package.resolved。修改 project.yml 后执行 xcodegen generate，不需要 pod install、npm 或 JS 开发服务器。

## 数据兼容

当前账本为 Codable version 4，路径 journal-swift-v4.json。读取优先级为当前文件、此前 journal-rn-v2.json（version 2/3）、再到 journal-v1.json。保留账号、媒体、交易、余额、关注、评论、计划、消息及 Foundation 日期基准。

RN 版本的非 UUID 记录标识由固定命名空间映射为稳定 UUID，板点、练习、评论举报、消息及活动的交叉引用同步转换。账号 UUID 与交易所有者不变。先成功原子写入新文件，之后才清理旧文件；解码失败不创建空档覆盖源数据。详细实现见 [技术栈](TECH_STACK.md)。

## Grip 内购

七档可消耗占位商品继续使用 Products.storekit 与 app-manifest.json 中的 ID。计划价格为 0.99、2.99、4.99、9.99、19.99、49.99、99.99 美元。价格由 Apple 返回，真实购买使用 StoreKit 2。已验证交易按 transaction ID 幂等；账号账本保存成功后才完成交易。未完成交易可重新检查，不承诺恢复已消耗余额。60 Grip 可解锁原创记事本封面，其他互动免费。

Debug scheme 保留 StoreKit 配置；Release 继续关闭占位购买。正式签名、Apple 登录能力与真实商品仍按发布账号配置。

## 官网与协议

You → Settings 提供 Official website、Terms of Use、Privacy Policy、Crew Rules，统一在 WKWebView 打开。条款和隐私优先线上，失败时使用随包副本；官网没有离线内容；联系邮箱保持空。

[官网](https://nina-skate-journal.amazingpaint.chatgpt.site/) · [用户协议](https://nina-skate-journal.amazingpaint.chatgpt.site/terms) · [隐私政策](https://nina-skate-journal.amazingpaint.chatgpt.site/privacy)

站点源目录为 website/dist。修改条款后通过 website/sync-policies.py 同步离线文章，再单独发布。2026-11-18 的发布记录为 Sites 第 5 版，本次 Swift 迁移没有重新发布网站或变更链接。支持与正式发布主体资料继续由项目方提供。

## 布局与验证

保留原有原创素材、纸白墨绿配色和五个 Tab。背景铺满窗口，导航和关键动作按局部容器避让。Duo 使用当前容器和活动保留区，不以窗口尺寸重建导航、编辑或播放状态。键盘使用 SwiftUI 的编辑滚动区，不重复加全局键盘高度。

本轮只做源码、工程配置、资源引用、包体和 git diff 静态检查，未编译、类型检查、测试、启动 Xcode、运行 App、模拟器或设备。旧 RN 构建记录不作为本次原生迁移的编译证据。数据迁移、Apple 授权、支付、键盘、媒体和设备开合仍待运行验收。
