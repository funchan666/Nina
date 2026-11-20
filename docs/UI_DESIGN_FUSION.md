# Nina 原生 UI

2026-11-20 将既有五 Tab 产品迁回 SwiftUI，保留原有滑板刊物风格、原创朋友插画、功能图标、媒体和业务范围。这次是技术栈迁移，不另做网页原型。

Discover 是浏览型界面：原创朋友互动横幅、搜索、地形与收藏筛选、图文和短片、图库入口、点赞收藏以及原生评论详情。Sessions 是操作型界面：日志、计划、板点分区。Crew 是真实已有档案的查找与关系界面。Inbox 展示会话、草稿和活动。You 汇集资料、关系、训练、发布审核队列、收藏、钱包和设置。

## 视觉语言

- 骨白纸面 #F5F0E5、墨绿 #182620、亮黄绿 #DFF075、鼠尾草 #DDE4D5；亮色用于主要动作和选中状态。
- 标题采用 Barlow Condensed Bold；正文和控件采用 Barlow，字体和 OFL 许可随包。
- 按钮至少 50 pt 高，图标动作保持 46 pt 触控区；输入和反馈使用统一圆角与清晰文字。主操作可以铺满行，整块可点击。
- 背景延伸至窗口四边。前景文字、导航和底部动作只处理所需局部遮挡，不给整页套安全区色带。
- 原创图片来自现有 Image 2 输出；本次将 40 份压缩位图逐字节拷入原生 Asset Catalog，没有重绘或替换为系统图标。

## 欢迎与登录

沿用四位成年朋友在滑板场分享视频的 WelcomeGround。欢迎标题为 See you at the spot.，副文案为 For the clips you replay and the friends you skate with.，Create profile 和 Sign in 两个明确入口。应用内不重复显示 App Icon 或应用名称。

表单有可见邮箱和密码标签、协议勾选、独立 Terms / Privacy Policy 链接、提交状态和错误恢复。没有 local profile 或 this iPhone 等实现文案。苹果登录使用官方黑色 SignInWithAppleButton，不用自绘的替代图形。

## 状态与适配

五个根页面和每个 Tab 的路由保持稳定身份，切换和容器变化不重建业务会话。仅根页面显示同一底栏，详情使用原创返回动作。输入保留在对应页面；异步媒体保存记录发起位置，完成后不会弹出另一个 Tab 的页面。共享 AVPlayer 在离开或后台时暂停。

Duo 使用容器 GeometryProxy、动态内容边距与活动 division / occlusion，仅避让实际与动作栏交叠的区域；视频小窗在同坐标系避让。iOS 27.1 新 API 已对照官方文档和本机 SDK 声明，旧系统保留普通边距。键盘由 SwiftUI 编辑滚动区处理，不另加全局键盘高度。

## 技能选择与证据

应用 ui-design-reference、ui-taste 的 iOS / Operate / Craft、Impeccable 的文本工作流与 craft floor、Duo，并结合 Claude Design / Design 的既有品牌与页面目的判断。Taste 的营销页工作流与 Garden 的浏览器产物流程不强套到本次原生迁移；沿用 Garden / Image 2 已生成的原创素材，不调用新图像生成服务。

已查看当前欢迎和朋友互动横幅原图；该观察只证明素材内容。源码、配置、资源和差异静态核对不等于界面渲染验收。本轮未编译、运行 App、浏览器或模拟器，未实测键盘、大字、RTL、开合和相机行为。

[页面映射](VISUAL_IMPLEMENTATION_SPEC.md) · [素材映射](../assets/brand/original-asset-plan.json)
