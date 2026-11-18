# Nina 本地社区桥接

UIKit 解压 App 自带的 Nina.zip。WKWebView 只导航到当前版本的 `index.html`，读权限限定为其资源目录。消息代理核实实际的主框架和文件 URL。网页通过 `window.webkit.messageHandlers.nina.postMessage` 发送 `{action, data}`。宿主生成请求 ID，React Native 的回覆需要匹配该 ID。

| 命令 | 输入与响应 |
| --- | --- |
| `snapshot` | 返回当前本机档案名、提示、可见素材条目与相关互动。图片路径为相对的 `media/<file>`。 |
| `register`、`signIn` | 邮箱、密码和协议同意标记。两个入口共用格式校验：邮箱必须含有效的地址格式且不超过 254 字符，密码不能全为空白且不超过 256 字符。校验通过后按规范化邮箱复用档案，首次自动创建，不要求预先注册或匹配旧密码。输入密码不写入持久层。会话仍保存在 Keychain。 |
| `signOut` | 清除当前会话并返回访客状态。 |
| `like`、`save`、`comment` | 只处理素材清单中的可见 ID。评论另需正文。提交成功后返回该条目更新值。 |
| `journal` | Tab 白名单为 lines、sessions、crew、messages、profile。page 仅接受 post、collection、savedLines、report；report 还需可见素材 ID。可单传素材 ID 打开详情。宿主构建类型化路由，不接受任意路由对象。 |
| `authState` | 仅传 visible、accepted、busy 三个布尔值，同步登录表单显示、协议勾选及提交状态。宿主在登录区显示官方原生 Apple 按钮。该布局状态独立于进行中的业务请求，不占用业务 pending 槽。 |
| `policy` | 打开独立协议视图。协议名称限定在 terms、privacy、rules。 |

网页和宿主各限制一个进行中的请求。解压与 WebView 加载有可重试反馈，WebView 进程终止会拒绝待处理请求。点赞、收藏和评论由共享本机档案保存成功后更新。支付、相机、任意文件与网络请求没有导出给本地网页。

Apple 登录由登录页底部的 `ASAuthorizationAppleIDButton(type: .signIn, style: .black)` 发起。按钮由既有 `NinaSurface` 原生组件承载，点击直接调用 `library.signInApple()` 并进入 `ASAuthorizationController`。按钮与网页表单共享协议勾选状态，表单提交和 Apple 授权互斥。授权期间网页暂停触控，取消保留表单，失败在登录区反馈。离开登录表单或网页失败时收起按钮。旧的 HTML 中转按钮和单独 Apple 入口页已移除。

社区视图的 React Native 属性 `contentInsets` 包含 top、right、bottom、left 数值。宿主仅对已加载的包内入口使用参数化 `callAsyncJavaScript`，更新对应的 `--content-*` CSS 长度变量。页面根视口铺满窗口，前景操作按变量避让。尺寸变化只更新布局，不重载网页或改写业务数据。这是宿主向页面的布局传值，不增加网页可调用命令。

已登录状态直接进入五 Tab 的 Journal，Discover 位于导航壳内。原生 `active` 属性从 false 变为 true 时，仅向已校验的包内入口调用固定的 `window.ninaRefresh()`；离开时关闭键盘。网页将刷新排在进行中的业务请求之后，继续使用单请求桥接。素材卡片按 ID 复用 DOM，返回后同步收藏、评论、举报与资料，保留筛选、搜索、展开状态和未提交的评论。几何变化只更新内容边距，不触发刷新或重建网页。
