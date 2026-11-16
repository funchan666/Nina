# Nina 开发需求与交付

用户指定 Nina、滑板运动爱好者社交、当前目录和内购商品 ID 占位。盘点时目录只有 Git、照片和视频。新建单一 SwiftUI 原生 iPhone 工程，最低 iOS 15，当前工具链 iPhoneOS 27.1 SDK。新拟 Bundle ID 为 `com.funchan666.nina`。Xcode scheme 和 target 均为 Nina。

## 主流程

| 入口 | 目标与动作 |
| --- | --- |
| Lines | 按 Street、Park、Flatground、Off the Board 找到图文和影片，查看原图或单实例播放，点赞、收藏、评论、举报，或把素材作为板点与练习参考。Post 打开提交表单。 |
| Sessions | Spot Book 记录场地、地形、障碍、地面状态和可访问说明。Trick Log 记录动作、站姿、目标、尝试、落地、用时和复盘笔记，可关联板点及参考素材。原地复访打开已有记录。 |
| Crew | 按板点与主动分享的练习摘要发现滑手。可编辑档案、查看关系、消息草稿、动态、提交、收藏、钱包和设置。 |

板点名称和地形组成关联键。只有贡献者主动勾选共享且记录了实际尝试的训练才进入 Crew 对应的板点列表。关系由用户主动关注建立。两端互关且未被拉黑才允许保存聊天草稿和打开等待式语音/视频。语音只请求麦克风，视频额外请求摄像头且使用可拖动的真实前置画面。通话窗口只处理等待、退出、权限错误和超时。草稿、活动、报告和关注只落本机档案。

欢迎与邮箱入口需要勾选协议，邮箱校验格式与非空密码，密码即弃。真实 Apple 登录通过 AuthenticationServices，稳定账号和会话由 Keychain 与受保护的应用存储关联。登录后替换根页面。同一台 iPhone 上的不同档案分开存储。登出、级联删档、权限设置入口、主题化报告和黑名单均有明确路径。

相册通过系统 PHPicker 选择图片或视频。相机桥接支持照片和影片，导入应用沙盒。提交保留为仅本人可查看的待审核记录，可编辑、删除和查看附件。举报保存原因并立即隐藏目标。拉黑同时移除双方关注并隐藏内容、消息和活动。设置提供 Crew Rules 与统一 WKWebView 条款/隐私入口。

## Supabase 和媒体

Supabase 项目 Nina 使用用户指定的浏览器当前组织，目前是 Free 计划，区域为 us-east-1。Storage 的 `nina-media` 桶只托管用户已授权的 50 张照片、16 条影片和各自首帧。客户端只访问公开 HTTPS 媒体对象，上传后的每项摘要与本地优化文件一致。未配置 Auth、业务表、Realtime 或客户端管理密钥。相册和拍摄的用户内容保存在沙盒。

原创 Image 2 App Icon、启动图、Tab 底图、页面图标和封面独立打包。详见 [素材清单](MEDIA_INVENTORY.md)、[UI 设计](UI_DESIGN_FUSION.md) 和 [视觉实现](VISUAL_IMPLEMENTATION_SPEC.md)。

## Grip 内购

七档可消耗占位商品写入 [Products.storekit](../Nina/Resources/Products.storekit) 和 [单应用清单](app-manifest.json)，五档初始加两档扩展。美元计划为 0.99、2.99、4.99、9.99、19.99、49.99、99.99。商品点击时向 StoreKit 请求真实本地化价格，确认后进 Apple 购买界面。只有已验证交易且写入账号账本后才完成交易，按 transaction ID 幂等。未完成交易可重新检查，已消耗的余额没有恢复承诺。Grip 用于 60 Grip 的原创记事本封面，其他互动免费。

Debug scheme 关联 Xcode StoreKit 配置。Release 默认关闭占位商品购买。正式 Bundle 注册、团队签名、Apple 登录能力、真实商品、价格和服务端支付交付/恢复策略需按发布账号配置。

## 交付边界

- 条款、隐私、Crew Rules 有可读的随包版本。签名团队、正式条款和隐私 URL、支持邮箱留在 `Nina/Config/Nina.xcconfig`。正式发布的经营者资料、支持及投诉处置由项目方提供。当前本机互动与等待式通话不能描述为跨设备社交或远端通话。
- 依据 Apple App Review Guidelines 1.2 核对发布过滤、举报、拉黑和支持入口。服务端审核和发布支持渠道未验收。4.3 的产品区别由板点复访、训练记录和 Crew 动作形成。支付和权限按 Apple 原生流程接入。参考 [Apple 审核指南](https://developer.apple.com/app-store/review/guidelines/)。
- 依据当前 SDK 静态检查 Duo 的容器、边距、保留区和输入连续性。尚未执行 App 编译、测试、分析、模拟器或设备验收。Storage 公开读取的结果独立记录。参考 [Apple iPhone Duo 开发指南](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) 和 [Supabase Storage 访问控制](https://supabase.com/docs/guides/storage/security/access-control)。

## 已完成的静态核对

应用清单、单项目结构、Xcode 项目、plist、scheme、原创图件及 7 档内购配置引用均已检查。Git 差异检查覆盖暂未跟踪的新增文件。发布前对 82 个公开对象完成字节级校验，并读取 Storage 的元数据确认 82 个对象、RLS 已启用、写入策略 0 条、公开 schema 业务表 0 张。

技能自带仓库扫描对 `NavigationStack`、`TabView`、`UserDefaults`、系统通知和 UIKit 生命周期做了固定符号匹配。对应源码实际走主题化 SwiftUI 路由、原子 JSON 和 Keychain、应用内动态、`scenePhase` 与主动刷新，逐项人工审查。产品化脚本在扫描共用美术时存在未定义的 `warnings` 变量，因此这两项启发式脚本结果不列为通过。
