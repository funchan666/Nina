# Nina 视觉实现

原创美术采用 90 年代独立滑板刊物的丝网印刷，墨绿、骨白、亮黄绿和少量锈红。赛博朋克强度为 0。标题使用 Barlow Condensed，交互文字与元数据用 Barlow。字形与 OFL 许可随工程提供。社区 WebView 与 React Native 页面共用业务数据、预置媒体和视觉语言。生成的方向板放在仓库素材目录，供构图参考。

| 页面或弹层 | 原创位图 | 布局与动作 |
| --- | --- | --- |
| 启动、欢迎、邮箱 | WheelMark、WelcomeGround、InkLoad、InkCheck | 欢迎插画与邮箱表单分区，显示提交状态，校验失败时指出需要修改的字段。提供 Apple 授权和 App 内协议入口。 |
| Lines | LinesGround、InkLines、InkAdd、InkRamp | 刊头、四类筛选、主图、横向影片和接触印样式的图集。Post 与刷新有明确状态。 |
| Line、媒体全屏 | InkPlay、InkPause、InkThumb、InkExpand、InkSpeaker、InkMuted、InkLike、InkSave、InkFlag | 同一 AVPlayer。原生拖拽和 VoiceOver 可调进度。照片保持比例，影片首帧对应源片。 |
| 编辑、提交、附件 | LinesGround、InkDeck、InkCamera、InkVideo、InkCheck | 触控选取、捕获、编辑、保存审核队列、删除和全屏查看。 |
| Sessions | SessionsGround、InkSessions、InkSpot、InkDeck | 班次日记、板点与实记的落地进度、封面入口。 |
| 板点、Spot 编辑、Trick Log | SessionsGround、InkSpot、InkEdit、InkAdd、InkCheck | 空白日志先引导新建板点，训练表单区分计划与实记，数字校验提示对应字段。 |
| Crew、他人档案、关系列表 | CrewGround、InkCrew、InkAvatar、InkMore、InkComment | 查找、板点来源、跟随、聊天入口与互动安全操作。 |
| 自己的档案、编辑 | CrewGround、InkAvatar、InkCamera、InkEdit、InkSettings、InkGrip | 图片选择、站姿、练习进度、关系、提交、收藏和钱包。 |
| Messages、Chat | CrewGround、InkComment、InkSend、InkPhone、InkVideo | 分开的草稿与动态。真实动作形成未读计数。 |
| 等待通话 | InkPhone、InkVideo、InkClose、InkSettings | 等待、权限失败和结束。视频仅显示前置自拍。 |
| Report、Block、黑名单、删档、设置 | CrewGround、InkFlag、InkCheck、InkClose、InkSettings | 设置按应用信息、Crew 安全和个人档案分组。删除确认使用独立页面和明确的危险操作样式。 |
| 条款与规则 | InkClose、InkLoad | WKWebView 负责文档正文，原生壳负责关闭与错误恢复。 |
| 本机社区 | WheelMark、WelcomeGround、原创 Ink 图标 | WebView 的预览图可以直接打开线路。空收藏提供返回全量列表的入口，取消收藏只移除对应卡片。较宽容器切换双列，宿主调整视口以避让活动折叠分隔。 |
| 钱包、购买确认、封面 | InkGrip、InkCheck、CoverBowl、CoverWax、CoverNight | 余额和 Apple 报价由真实状态驱动。消费后所选原画应用在 Sessions 账簿。 |

底部三个入口只在根页面展示。返回与关闭使用独立位图和 VoiceOver 名称。滚动区域按容器宽度限宽，宿主以 UIKit 场景读取内容边距，并在 iOS 27.1 及以上提供活动保留区。React Native 动作栏和自拍视频框按自身窗口坐标避让交叠的区域。键盘由可见的编辑滚动区处理。真实内外屏、RTL、大字、分屏和折叠姿态未运行验证。

目录 [assets/brand](../assets/brand) 与 [assets/navigation](../assets/navigation) 保存 Host-Native 输出、提示词与从独立素材格取出的位图。运行时资源映射见 [原创素材清单](../assets/brand/original-asset-plan.json)。
