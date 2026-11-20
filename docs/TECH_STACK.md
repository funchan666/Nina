# Nina 技术栈

2026-11-20 按用户要求恢复 Swift 原生实现。

| 范围 | 当前实现 |
| --- | --- |
| 语言与 UI | Swift 5 语言模式、SwiftUI；系统媒体、授权和网页文档使用 UIKit / WebKit。 |
| 工具链 | iPhoneOS SDK 27.1；最低部署版本 iOS 17.6。 |
| 工程 | Nina.xcodeproj / Nina.xcworkspace，target 与 scheme 为 Nina，Bundle ID 为 com.funchan666.nina。 |
| 启动与导航 | NinaApp → NinaGate → NinaShell。Discover、Sessions、Crew、Inbox、You 五个根页面与独立类型化路由栈。 |
| 资源 | ZIPFoundation 0.9.20 由 Swift Package Manager 提供，精确固定版本与提交。Nina.zip 保留现有优化媒体。 |
| 图文与视频 | SwiftUI 原生列表和图片、AVPlayer 播放本地媒体，单个播放所有者；无自动播放。 |
| 登录 | AuthenticationServices 官方 Sign in with Apple；邮箱格式正确且密码非空即可按邮箱打开档案。密码不保存、不验证。 |
| 数据 | NinaLibrary 管理 Codable version 4 账本；JSON 原子写入，Keychain 保存会话；用户媒体保留原有账号目录。 |
| 付费 | StoreKit 2 原生价格、购买与未完成交易检查；先保存已验证交易再 finish，按交易 ID 幂等。 |
| 官网与协议 | WKWebView，官网线上加载；用户协议和隐私政策失败时读取随包单文件副本；无业务 JS 桥接。 |
| 后端与通话 | 没有业务后端。消息只在同一应用的已有档案间持久化；通话保留权限检查、自拍视频及等待预览。 |

应用已移除 React Native、TypeScript、Metro、npm 和 CocoaPods 源码及配置。打开工程无需启动 JS 开发服务器，也没有 main.jsbundle 构建阶段。ZIP 内既有 HTML/CSS/JS 是旧资源包的兼容内容，不承担当前注册、登录、社区或业务执行；这些页面全部由 SwiftUI 实现。

## 旧数据迁移

读取顺序为 journal-swift-v4.json → journal-rn-v2.json → journal-v1.json。存在的新文件读取失败时显示错误并保留文件，不回退覆盖它。

NinaArchiveImport 兼容此前 version 2/3 的字符串键账号字典、普通对象举报和非 UUID 的记录 ID。非 UUID 的记录 ID 使用固定命名空间的 SHA-256 映射为稳定 UUID，并同步板点、练习、消息、活动及评论举报的引用。账号 UUID、登录摘要、媒体文件名、交易所有者、Grip 账本和 Foundation 日期基准保持不变。version 1 的 UUID 字典与举报枚举也可读取。

只有新 Codable 账本成功原子写入 journal-swift-v4.json 后才清理旧文件。删档级联移除消息、评论、关注和草稿，同时清理账号媒体、Keychain 会话及旧密码校验值。清理失败保留提示并在后续启动重试。

## 验证边界

本轮仅检查源码、工程配置、资源引用、依赖版本、ZIP 与差异；未调用 Swift 编译器、构建、类型检查、测试、Xcode、模拟器或真机。旧版本的构建记录不能作为本次 Swift 迁移的成功证据。
