# Nina 本地社区桥接

UIKit 解压 App 自带的 Nina.zip。WKWebView 只导航到当前版本的 `index.html`，读权限限定为其资源目录。消息代理核实实际的主框架和文件 URL。网页通过 `window.webkit.messageHandlers.nina.postMessage` 发送 `{action, data}`。宿主生成请求 ID，React Native 的回覆需要匹配该 ID。

| 命令 | 输入与响应 |
| --- | --- |
| `snapshot` | 返回当前本机档案名、提示、可见素材条目与相关互动。图片路径为相对的 `media/<file>`。 |
| `register`、`signIn` | 邮箱、密码和协议同意标记。校验后返回对应档案状态。密码校验值保存在 Keychain。 |
| `signOut` | 清除当前会话并返回访客状态。 |
| `like`、`save`、`comment` | 只处理素材清单中的可见 ID。评论另需正文。提交成功后返回该条目更新值。 |
| `journal` | 接受 `lines`、`sessions`、`crew`。可传素材 ID 打开相应详情。 |
| `apple`、`policy` | 分别打开 Apple 原生授权入口与独立协议视图。协议名称限定在 terms、privacy、rules。 |

网页和宿主各限制一个进行中的请求。解压与 WebView 加载有可重试反馈，WebView 进程终止会拒绝待处理请求。点赞、收藏和评论由共享本机档案保存成功后更新。支付、相机、任意文件与网络请求没有导出给本地网页。
