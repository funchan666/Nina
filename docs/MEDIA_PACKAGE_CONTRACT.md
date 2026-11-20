# Nina 原生媒体包

Nina.zip 是 Swift App 的媒体资源包，只包含 media/ 下的 50 张照片、16 条影片和 16 张首帧。界面、字体、按钮、封面和登录逻辑由原生资源与 Swift 源码提供。旧 H5 社区及其双向桥接已删除。

## 打包与读取

Nina/Resources/LinesCatalog.json 是唯一的媒体目录。scripts/package-media.py 按清单重整 Nina.zip；可选传入一份完整媒体文件夹。脚本不转码图片或视频，验证新归档的条目、CRC 和逐项 SHA-256 后原子替换，不生成备份。

OfflineArchive.mediaDirectory(filenames:) 接收原生清单中的精确文件名集合，校验 ZIP 的路径、文件类型、重复条目、数量、展开上限及 CRC。展开目录使用整包摘要命名；全部所需媒体安装后才供 SwiftUI 图片和 AVPlayer 读取。成功安装后清理旧摘要对应的可重建资源缓存，其中可能含历史 H5 文件。账号、用户媒体、消息和内购记录位于独立目录。

NinaConfiguration.prepareMedia() 只在启动时准备资源。容器、键盘或 Duo 布局变化不会触发重新解包或重建业务状态。

## 当前网页边界

仅官网、用户协议、隐私政策和 Crew Rules 使用 NinaPolicyPage / WKWebView。条款和隐私在线失败时使用随包单文件副本；官网没有离线替代页。网页没有业务命令处理器，不提供任意文件、采集或购买权限。官网和离线协议源码继续保留。

本轮只检查源码、工程、归档和资源引用；没有编译、测试、启动 App 或验证设备播放。
