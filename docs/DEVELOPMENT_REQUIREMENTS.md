# Nina 开发需求与交付

Nina 是滑板运动爱好者社交 App。按用户要求从 SwiftUI 迁移到 React Native 0.88.1 + TypeScript。iPhone target、scheme 和应用显示名均为 Nina，Bundle ID 为 `com.funchan666.nina`。最低支持 iOS 17.6，编译 SDK 采用 iPhoneOS 27.1。

## 主流程

| 入口 | 目标与动作 |
| --- | --- |
| Skate community | React Native 启动后从随包 ZIP 打开本地网页。邮箱注册、登录、示例内容筛选、点赞、收藏和评论共用 Nina 的本机档案，详情和练习入口打开 React Native 页面。 |
| Lines | 按 Street、Park、Flatground、Off the Board 找到图文和影片，查看原图或单实例播放，点赞、收藏、评论、举报，或把素材作为板点与练习参考。Post 打开提交表单。 |
| Sessions | Spot Book 记录场地、地形、障碍、地面状态和可访问说明。Trick Log 记录动作、站姿、目标、尝试、落地、用时和复盘笔记，可关联板点及参考素材。原地复访打开已有记录。 |
| Crew | 按板点与主动分享的练习摘要发现滑手。可编辑档案、查看关系、消息草稿、动态、提交、收藏、钱包和设置。 |

板点名称和地形组成关联键。只有贡献者主动勾选共享且记录了实际尝试的训练才进入 Crew 对应的板点列表。关系由用户主动关注建立。两端互关且未被拉黑才允许保存聊天草稿和打开等待式语音/视频。语音只请求麦克风，视频额外请求摄像头且使用可拖动的真实前置画面。通话窗口只处理等待、退出、权限错误和超时。草稿、活动、报告和关注只落本机档案。

邮箱入口需要勾选协议。邮箱格式正确（不超过 254 字符）、密码非空且不全为空白（不超过 256 字符）即可进入。创建与登录入口使用同一逻辑，首次自动创建档案，已有档案按去除首尾空白并转为小写的邮箱复用，保留原有记录，不要求匹配旧密码。输入密码不持久化，也不验证邮箱归属。旧版 Keychain 密码校验值只在删除档案时清理，不再参与登录。Apple 登录通过 AuthenticationServices，稳定账号和会话由 Keychain 与受保护的应用存储关联。同一台 iPhone 上的不同档案分开存储。

相册通过系统 PHPicker 选择图片或视频。相机桥接支持照片和影片，导入应用沙盒。提交保留为仅本人可查看的待审核记录，可编辑、删除和查看附件。举报保存原因并立即隐藏目标。拉黑同时移除双方关注并隐藏内容、消息和活动。设置提供官网、用户协议、隐私政策和 Crew Rules 入口，统一在 App 内的 WKWebView 中打开。

## 随包媒体

用户授权的 50 张照片、16 条影片和对应的 16 张真实首帧均随 Nina.zip 分发。WebView 通过相对路径读取图片，React Native 的详情与播放器使用同一解压目录中的本地文件。相册和拍摄的用户内容保存在独立沙盒。应用自有业务与预置媒体完全本地化。原生 Apple 登录和 StoreKit 在对应操作时使用 Apple 服务。

原创 Image 2 App Icon 与启动图由 iOS 资源目录打包。社区网页所需的品牌素材与字体随 Nina.zip 分发，React Native 页面专用的底图、图标和封面由 Metro 打包。详见 [素材清单](MEDIA_INVENTORY.md)、[包体预算](SIZE_BUDGET.md)、[UI 设计](UI_DESIGN_FUSION.md) 和 [视觉实现](VISUAL_IMPLEMENTATION_SPEC.md)。

## Grip 内购

七档可消耗占位商品写入 [Products.storekit](../Nina/Resources/Products.storekit) 和 [单应用清单](app-manifest.json)，五档初始加两档扩展。美元计划为 0.99、2.99、4.99、9.99、19.99、49.99、99.99。商品点击时向 StoreKit 请求真实本地化价格，确认后进 Apple 购买界面。只有已验证交易且写入账号账本后才完成交易，按 transaction ID 幂等。未完成交易可重新检查，已消耗的余额没有恢复承诺。Grip 用于 60 Grip 的原创记事本封面，其他互动免费。

Debug scheme 关联 Xcode StoreKit 配置。Release 默认关闭占位商品购买。正式 Bundle 注册、团队签名、Apple 登录能力、真实商品、价格和服务端支付交付/恢复策略需按发布账号配置。

## 官网与协议

英文官网和协议已通过 Sites 公开发布。[Nina 官网](https://nina-skate-journal.amazingpaint.chatgpt.site/) · [用户协议](https://nina-skate-journal.amazingpaint.chatgpt.site/terms) · [隐私政策](https://nina-skate-journal.amazingpaint.chatgpt.site/privacy)

站点部署目录为 `website/dist`。修改协议正文后，运行 `python3 website/sync-policies.py` 同步到 `Nina/Resources/Legal`，再发布网站更新。App 通过 `Nina/Config/Nina.xcconfig` 读取官网和协议地址。用户协议和隐私政策优先展示线上版，加载失败时打开随包副本。Crew Rules 使用随包文件。网站和 App 暂留空联系邮箱。

## 交付边界

- 签名团队由项目方配置。正式发布的经营者资料、支持及投诉处置由项目方提供。当前本机互动与等待式通话均为同一设备内的体验。
- 依据 Apple App Review Guidelines 1.2 核对发布过滤、举报、拉黑和支持入口。服务端审核和发布支持渠道未验收。4.3 的产品区别由板点复访、训练记录和 Crew 动作形成。支付和权限按 Apple 原生流程接入。参考 [Apple 审核指南](https://developer.apple.com/app-store/review/guidelines/)。
- 依据当前 SDK 静态检查 Duo 的场景、安全区、活动保留区和输入连续性。参考 [Apple iPhone Duo 开发指南](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)。

## React Native 工程

工作区是 [Nina.xcworkspace](../Nina.xcworkspace)，入口是 [index.js](../index.js)。`src/screens` 承载 React Native 页面，`src/state` 管理业务和本机账本。UIKit 场景、Apple 授权、相册和相机、AVFoundation、WKWebView 和 StoreKit 在 `Nina/Platform`，通过 React Native 0.88 的 iOS 模块和组件互操作接口供 TypeScript 调用。Debug 和 Release 的 Xcode 构建阶段都内嵌 `main.jsbundle`。Debug 在 Metro 可用时优先使用开发服务器，否则读取内嵌包。依赖版本写入 npm 和 CocoaPods 锁文件。

社区源码与媒体在 `web/community`。运行 `python3 scripts/package-community.py` 按 `CFBundleDisplayName` 打包。iOS 宿主校验 ZIP，并按内容摘要原子安装到 Application Support 的 `NinaCommunity` 子目录。WKWebView 用 `loadFileURL` 载入 `index.html`。本地账号与业务记录存放在独立稳定目录。网页脚本、样式、字体、原创插画及全部预置媒体均随包分发。[技术栈](TECH_STACK.md) · [桥接契约](WEB_BRIDGE_CONTRACT.md) · [Nina.zip](../Nina/Resources/Nina.zip)

首次迁移会读取旧版 `journal-v1.json`，转换 UUID 字典与举报枚举并保留 Foundation 日期基准、账号标识、媒体文件和交易记录。新状态先原子写入 `journal-rn-v2.json`，随后清理旧档。当前会话继续使用既有 Keychain 记录。SwiftUI 产品源码的基线可在 Git 提交 `018be40` 查看。

### 打开工程

- 在 Xcode 打开 `Nina.xcworkspace` 或 `Nina.xcodeproj` 并选择 Nina scheme。`pod install` 会为工程补上 `Pods-Nina` 目标依赖。需要热更新时，在项目根目录执行 `npm start` 启动 Metro。
- 在新检出中安装 Node 依赖和 Pods。更改 `project.yml` 后用 `xcodegen generate` 再执行 `pod install`，以重新接入 Pods 阶段。
- SDK 27.1 的保留区域在 UIKit 宿主测量。JS 视图以当前窗口坐标避让动作栏和摄像头小窗，安全区和键盘变化可单独重排。选项、输入和媒体进度归属同一个业务会话。

### 验证范围

源码、资源目录、ZIP 完整性、本地媒体目录映射和 iOS 资源构建阶段均纳入静态核对。媒体核验包括全流解码和代表帧检查。官网已检查桌面和手机宽度下的排版。2026-11-17 使用 Xcode 27.1 从工程和工作区分别构建了 Debug 模拟器版本（arm64），产物的最低系统版本均为 iOS 17.6，并核对了随包 Nina.zip。Release 的最低部署版本也已核对为 iOS 17.6。App 运行、真机开合、离线端到端交互及设备播放待验收。

[React Native 现有 App 接入规范](https://reactnative.dev/docs/integration-with-existing-apps) · [React Native 0.88 发布说明](https://reactnative.dev/blog/2026/10/19/react-native-0.88)
