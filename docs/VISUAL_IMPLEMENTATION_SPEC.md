# Nina 视觉实现

原创美术采用 90 年代独立滑板刊物的丝网印刷，墨绿、骨白、亮黄绿和少量锈红。赛博朋克强度为 0。标题使用 Barlow Condensed，交互文字与元数据用 Barlow。字形与 OFL 许可随工程提供。全部业务页面采用 SwiftUI，共用 Codable 账本、预置媒体和视觉语言。生成的方向板放在仓库素材目录，供构图参考。

| 页面或弹层 | 原创位图 | 布局与动作 |
| --- | --- | --- |
| 启动、欢迎、邮箱 | WelcomeGround、InkLoad、InkCheck、InkBack | 四位成年朋友在滑板场分享视频、聊天的整屏插画配 See you at the spot. 标题，Create profile 与 Sign in 入口进入邮箱表单。脸部与共同活动集中在上半部，深绿前景承接标题和按钮。启动加载使用功能图标及状态文案，应用内去除重复应用图标和名称。单一主提交按钮配紧凑协议区域，显示提交状态并关联字段错误。登录区直接承载官方原生 Apple 按钮，协议勾选后发起系统授权。 |
| Discover、图库 | LinesGround、InkLines、InkAdd、InkRamp | 刊头、四类筛选、主图、横向影片和接触印样式的图集。Post 与刷新有明确状态。 |
| Line、媒体全屏 | InkPlay、InkPause、InkThumb、InkExpand、InkSpeaker、InkMuted、InkLike、InkSave、InkFlag | 同一 AVPlayer。原生拖拽和 VoiceOver 可调进度。照片保持比例，影片首帧对应源片。 |
| 编辑、提交、附件 | LinesGround、InkDeck、InkCamera、InkVideo、InkCheck | 触控选取、捕获、编辑、保存审核队列、删除和全屏查看。 |
| Sessions | SessionsGround、InkSessions、InkSpot、InkDeck | 班次日记、板点与实记的落地进度、封面入口。 |
| 板点、Spot 编辑、Trick Log | SessionsGround、InkSpot、InkEdit、InkAdd、InkCheck | 空白日志先引导新建板点，训练表单区分计划与实记，数字校验提示对应字段。 |
| Crew、他人档案、关系列表 | CrewGround、InkCrew、InkAvatar、InkMore、InkComment | 查找、板点来源、跟随、聊天入口与互动安全操作。 |
| 自己的档案、编辑 | CrewGround、InkAvatar、InkCamera、InkEdit、InkSettings、InkGrip | 图片选择、站姿、练习进度、关系、提交、收藏和钱包。 |
| Messages、Chat | CrewGround、InkComment、InkSend、InkPhone、InkVideo | 会话、草稿与动态。真实消息持久化、收件人未读、打开会话标记已读，发送者可删除自己的消息。 |
| 等待通话 | InkPhone、InkVideo、InkClose、InkSettings | 等待、权限失败和结束。视频仅显示前置自拍。 |
| Report、Block、黑名单、删档、设置 | CrewGround、InkFlag、InkCheck、InkClose、InkSettings | 设置按应用信息、Crew 安全和个人档案分组。删除确认使用独立页面和明确的危险操作样式。 |
| 条款与规则 | InkClose、InkLoad | WKWebView 负责文档正文，原生壳负责关闭与错误恢复。 |
| 原生社区 | CrewSession、LinesGround、原创 Ink 图标 | SwiftUI 的 Discover 页面承载发布、搜索、地形 / 收藏筛选、完整图库、互动与媒体详情。横幅打开 Sessions，底部为统一五 Tab。旧网页不参与业务执行。 |
| 钱包、购买确认、封面 | InkGrip、InkCheck、CoverBowl、CoverWax、CoverNight | 余额和 Apple 报价由真实状态驱动。消费后所选原画应用在 Sessions 账簿。 |

登录后各根页面统一显示 Discover、Sessions、Crew、Inbox、You 五个 Tab。返回与关闭使用独立位图和 VoiceOver 名称。滚动区域按容器宽度限宽，SwiftUI GeometryProxy 读取内容边距，并在 iOS 27.1 及以上查询活动保留区。原生动作栏和自拍视频框按同一局部坐标系避让交叠区域。键盘由可见的编辑滚动区处理。真实内外屏、RTL、大字、分屏和折叠姿态未运行验证。

2026-11-18 调整了全应用的屏幕边缘策略。社区、通用详情、官网与协议、通话和媒体页的根容器取消整页安全区 padding。背景延伸至窗口四边，导航栏与底部动作单独处理遮挡。媒体页的关闭栏叠在内容上方。欢迎页使用完整竖图与底部双入口。后续按用户要求去除了应用内重复图标、名称和相关占位，清理了表单、社区和评论控件中的本地实现文案。Apple 登录使用黑色官方原生按钮，直接进入授权流程。此次更新仅进行了源码、资源与 ZIP 静态核对。

文案统一为自然的滑板社交语气。欢迎副文案为 For the clips you replay and the friends you skate with. 登录和注册分别使用 Welcome back 与 Meet your next crew，切换入口直接说明目标。社区、照片与短片、评论、板点和日志空状态提供明确动作，Crew 搜索无结果时与首次空列表使用不同提示。文案调整没有引入在线匹配或消息送达承诺。

目录 [assets/brand](../assets/brand) 与 [assets/navigation](../assets/navigation) 保存 Host-Native 输出、提示词与从独立素材格取出的位图。运行时资源映射见 [原创素材清单](../assets/brand/original-asset-plan.json)。

2026-11-20 恢复 Swift 原生实现：所有业务页面、欢迎与邮箱表单均为 SwiftUI，保留五个 Tab 和原创素材；40 份运行位图拷入原生 Asset Catalog。仅官网和协议使用 WKWebView。原生样式和布局仅完成静态检查，未渲染验收。
