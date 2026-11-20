# Nina 原生页面与网页边界

2026-11-20 按用户要求改回 Swift。原 React Native / H5 双向业务桥接已移除。本文件保留原路径，说明新的所有权与资源边界。

| 对象 | 所有者与行为 |
| --- | --- |
| 欢迎、登录、社区 | SwiftUI；不加载旧 index.html 执行业务。 |
| 五个 Tab 与详情 | NinaFlow、NinaShell；每个 Tab 保留独立路由与原生表单状态。 |
| 账号与社交记录 | NinaLibrary；写入成功后才发布新状态。没有网页命令通道或任意 JS 执行入口。 |
| 预置媒体 | OfflineArchive 校验 Nina.zip 的路径、数量、展开上限与 CRC，按资源摘要原子安装；NinaConfiguration 验证完整素材清单，图片与 AVPlayer 直接读本地 media 文件。 |
| Apple 登录 | SwiftUI 官方 SignInWithAppleButton 发起 AuthenticationServices 系统授权。 |
| 相册与相机 | Swift 的 PHPicker / UIImagePickerController / AVFoundation；不向网页提供采集权限。 |
| 购买与恢复检查 | GripStore；StoreKit 2 验证、账号归属和幂等交付。 |
| 官网、条款、隐私、规则 | NinaPolicyPage 与 WKWebView。允许 HTTPS，以及当前协议的单个随包文件；无业务消息处理器。 |

官网入口位于 You → Settings → Official website，用户协议、隐私政策和 Crew Rules 使用同一原生网页容器。重试才重新加载，容器尺寸变化不触发加载。条款和隐私线上导航失败或返回非成功 HTTP 状态时回退随包单文件；官网没有伪造的离线页面。联系邮箱保持空。

Nina.zip 仍保留旧 HTML/CSS/JS，便于保持资源包校验及历史分发契约。它们不被 WKWebView 打开，也不能调用已删除的桥接。当前业务与状态均由 Swift 源码负责。
