# Nina 技术栈

| 范围 | 版本与配置 |
| --- | --- |
| React Native 宿主 | React Native 0.88.1、React 19.3.0、TypeScript 6.0.3。npm 锁定依赖。 |
| 工具链 | 本机 Node 22.17.0、CocoaPods 1.16.2、iPhoneOS SDK 27.1。Nina 的最低部署版本为 iOS 17.6。 |
| iOS 工程 | `Nina.xcworkspace`、`Nina` scheme 与 target、Bundle ID `com.funchan666.nina`。UIKit 宿主在 `Nina/Platform`。 |
| 本地网页 | `web/community/index.html`、HTML/CSS/JavaScript、iOS SDK 的 WKWebView 及受限主框架桥接。 |
| 资源 ZIP | ZIPFoundation 0.9.20 解压 `Nina/Resources/Nina.zip`。媒体位于 ZIP 的 `media/` 目录。 |
| 视频 | MP4 容器。新优化片使用 HEVC `hvc1`，兼顾尺寸、帧率和画质。已足够精简的片使用 H.264。iOS 用 AVPlayer 播放本地文件。 |
| 持久化 | iOS Keychain 保存会话，TypeScript 账本通过原生层原子写入独立应用目录。邮箱入口只校验输入格式，不保存或核对密码。删除档案仍清理旧版密码校验值。 |

既有 WKWebView 宿主负责文件加载和真实主框架来源检查。Apple 登录、购买和相机继续使用 iOS 原生 API。[WKWebView 本地文件加载](https://developer.apple.com/documentation/webkit/wkwebview/loadfileurl(_:allowingreadaccessto:)) · [Apple 平台视频格式](https://developer.apple.com/documentation/technologyoverviews/video) · [ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.20)

登录后由同一 Journal 承载 Discover、Sessions、Crew、Inbox、You 五个 Tab，各自保留路由栈。会话消息及收件人未读事件使用现有原子 JSON 账本，Archive version 3 保存会话，兼容读取 version 2 并补空 messages；继续使用 journal-rn-v2.json 的稳定位置，后续写入 version 3。没有跨设备消息服务器或 RTC。
