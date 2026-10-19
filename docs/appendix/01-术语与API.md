# 术语与 API 索引

> 上级：[文档中心](../README.md)
> 本文只做速查：术语、已在 Godot 4.7.2 中确认的 API、全部文档索引、ADR 索引、文档版本。

---

## 1. 术语表

| 术语 | 含义 | 相关文档 |
|---|---|---|
| Rig | 骨骼数据 + 求解的统称 | 03-仿真/01 |
| Pose | 根位置 + 每骨相对角 + 关节世界坐标 | 03-仿真/01 |
| FK | 正向运动学，由角度算关节位置 | 03-仿真/01 |
| IK | 反向运动学，由目标点算关节角 | 03-仿真/01 |
| PBD | Position-Based Dynamics，位置约束求解 | 03-仿真/02 |
| Tone | 肌肉张力，关节回到目标角的弹簧刚度 | 03-仿真/02 |
| w_sim | 物理权重，0=纯动画，1=纯物理 | 03-仿真/02 |
| Active Ragdoll | 动画目标角与物理共同驱动的布娃娃 | 03-仿真/02 |
| Hull | 凸包，用于鼠标穿透区域 | 02-平台/01 |
| Passthrough | 鼠标穿透，点击落到下层窗口 | 02-平台/01 |
| NO_FOCUS | 点击不抢焦点的窗口标志 | 02-平台/01 |
| DPI scale | 系统缩放比例，100%=1.0 | 02-平台/02 |
| SubViewport | 离屏渲染目标，3D 物品的容器 | 04-表现/02 |
| Tonemap | 色调映射，Linear 才能保像素色 | 04-表现/02 |
| State | 行为状态机的节点 | 05-行为/01 |
| Need | energy / boredom / curiosity 模型 | 05-行为/01 |
| Schema | 配置键、类型、范围、默认值定义 | 06-工程/01 |

---

## 2. 已确认 API（Godot 4.7.2）

以下在本工程编辑器 ClassDB 中核对过，可直接使用：

### 2.1 窗口与屏幕

| API | 说明 |
|---|---|
| `DisplayServer.window_set_flag(flag, enabled)` | 窗口标志 |
| `WINDOW_FLAG_BORDERLESS / TRANSPARENT / ALWAYS_ON_TOP / NO_FOCUS / RESIZE_DISABLED / MOUSE_PASSTHROUGH / POPUP` | 标志枚举 |
| `DisplayServer.window_set_mouse_passthrough(region)` | 多边形穿透区域 |
| `DisplayServer.window_set_size/position` | 尺寸与位置 |
| `DisplayServer.window_get_current_screen()` | 当前屏 |
| `DisplayServer.screen_get_usable_rect(screen)` | 可用区（不含任务栏） |
| `DisplayServer.screen_get_scale(screen)` | DPI 缩放 |
| `DisplayServer.mouse_get_position()` | 全局光标 |
| `Window.transparent_bg` | 根窗口透明 |

### 2.2 2D 绘制

| API | 说明 |
|---|---|
| `Line2D.begin_cap_mode / end_cap_mode` | `LINE_CAP_ROUND` 圆头 |
| `Line2D.joint_mode` | `LINE_JOINT_ROUND` |
| `Line2D.antialiased / width / width_curve` | 线宽与抗锯齿 |
| `Geometry2D.convex_hull(points)` | 凸包 |
| `Geometry2D.is_polygon_clockwise(poly)` | 顶点方向 |
| `Geometry2D.offset_polygon(poly, delta)` | 外扩/内缩 |
| `Geometry2D.merge_polygons(a, b)` | 多边形合并 |

### 2.3 3D 与视口

| API | 说明 |
|---|---|
| `SubViewport.transparent_bg` | 透明背景 |
| `SubViewport.size` | 离屏尺寸 |
| `SubViewport.render_target_update_mode` | `UPDATE_ALWAYS / UPDATE_ONCE` |
| `SubViewport.own_world_3d` | 独立 3D 世界 |
| `Viewport.msaa_3d / screen_space_aa / use_taa / use_debanding` | 全部关闭做像素风 |
| `Camera3D.projection = PROJECTION_ORTHOGONAL` | 正交 |
| `Camera3D.size` | 正交视野高度 |
| `BaseMaterial3D.texture_filter = TEXTURE_FILTER_NEAREST` | 最近邻 |
| `BaseMaterial3D.shading_mode` | Unshaded / Per-Pixel |
| `BaseMaterial3D.transparency = TRANSPARENCY_ALPHA_SCISSOR` | 镂空 |
| `Environment.background_mode = BG_CLEAR_COLOR` | 透明背景 |
| `Environment.ambient_light_source = AMBIENT_SOURCE_COLOR` | 环境光 |
| `Environment.tonemap_mode = TONE_MAPPER_LINEAR` | 保持像素色 |
| `PhysicalBone2D` | 引擎 2D 布娃娃（仅作对照原型，不采用） |

### 2.4 工程

| API | 说明 |
|---|---|
| `OS.low_processor_usage_mode` | 必须关闭 |
| `Engine.max_fps` | 60 |
| `TCPServer.listen(port, "127.0.0.1")` | 单实例锁 |
| `ConfigFile.load/save` | 配置 |
| `DirAccess.rename_absolute` | 原子替换 |
| `Time.get_ticks_msec()` | 时间戳 |
| `Performance.get_monitor()` | 性能 |

---

## 3. 文档索引

| # | 文档 | 一句话 |
|---|---|---|
| 1 | [README](../README.md) | 文档地图、项目状态、覆盖矩阵 |
| 2 | [项目目标](../00-项目/01-项目目标.md) | 愿景、KR、成功定义、范围与约束 |
| 3 | [路线图与进度](../00-项目/02-路线图与进度.md) | 阶段、里程碑、完成度、下一步 |
| 4 | [风险与合规](../00-项目/03-风险与合规.md) | 风险登记、IP/许可/隐私 |
| 5 | [产品与边界](../01-总览/01-产品与边界.md) | 做什么、不做什么、成功标准 |
| 6 | [架构与运行时](../01-总览/02-架构与运行时.md) | 分层、模块、所有权、帧管线、ADR |
| 7 | [Godot工程基线](../01-总览/03-Godot工程基线.md) | 项目设置、输入、层、导入、导出 |
| 8 | [内容设计](../01-总览/04-内容设计.md) | 核心循环、交互目录、内容清单 |
| 9 | [窗口与穿透](../02-平台/01-窗口与穿透.md) | 透明置顶窗与三种穿透策略 |
| 10 | [输入屏幕与生命周期](../02-平台/02-输入屏幕与生命周期.md) | 手势、多屏/DPI、单实例、启动退出 |
| 11 | [骨骼与动画](../03-仿真/01-骨骼与动画.md) | 骨骼、FK、剪辑、混合、IK |
| 12 | [物理与抓取](../03-仿真/02-物理与抓取.md) | PBD、约束、抓取、投掷、调参 |
| 13 | [渲染与2.5D](../04-表现/01-渲染与2.5D.md) | 线条、分层、视差、倾斜、阴影 |
| 14 | [3D物品与像素质感](../04-表现/02-3D物品与像素质感.md) | SubViewport、像素完美、合成 |
| 15 | [音频与界面](../04-表现/03-音频与界面.md) | 音效池、右键菜单、无障碍 |
| 16 | [状态机与交互](../05-行为/01-状态机与交互.md) | FSM、需求模型、表情、手势映射 |
| 17 | [配置与持久化](../06-工程/01-配置与持久化.md) | Schema、原子写、迁移、恢复 |
| 18 | [规范测试与发布](../06-工程/02-规范测试与发布.md) | 规范、调试、测试、性能、打包 |
| 19 | [版本控制与CI](../06-工程/03-版本控制与CI.md) | git、分支、CI、版本号、发布检查 |
| 20 | [项目门禁](../06-工程/04-项目门禁.md) | 契约、自动检查、钩子、绕过政策 |
| 21 | [行业实践对照](../06-工程/05-行业实践对照.md) | 官方/成熟 Godot 项目的规范与取舍 |
| 22 | [开发路线图](../00-项目/路线图/README.md) | P0–P6 需求、验收、当前状态 |
| 23 | [版本迭代](../00-项目/版本迭代/README.md) | 各版本迭代说明与更新 |

---

## 4. ADR 索引

| 编号 | 决策 | 文档 |
|---|---|---|
| ADR-01 | 自研 PBD 物理 | 03-仿真/02 |
| ADR-02 | RigPose 为唯一姿态真源 | 03-仿真/01 |
| ADR-03 | 程序化胶囊线条 | 04-表现/01 |
| ADR-04 | 伪 2.5D 分层 | 04-表现/01 |
| ADR-05 | 全屏透明置顶窗 | 02-平台/01 |
| ADR-06 | JSON 剪辑 + 自研采样 | 03-仿真/01 |
| ADR-07 | 3D 物品用 SubViewport 贴图 | 04-表现/02 |
| ADR-08 | 多岛命中用光标轮询 | 02-平台/01 |
| ADR-09 | 配置 `user://pet.cfg` + Schema 版本 | 06-工程/01 |
| ADR-10 | 单实例 TCP 端口锁 | 02-平台/02 |

---

## 5. 文档版本

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-10-19 | v0.1 | 三份初稿（已归档） |
| 2026-10-19 | v1.0 | 重构为分级文档：总览/平台/仿真/表现/行为/工程/附录，补齐生命周期、手势、多屏、配置迁移、测试与发布 |
| 2026-10-19 | v1.1 | 新增项目管理（目标/路线图/风险合规）、Godot 工程基线、内容设计、版本控制与CI；README 增加项目状态与覆盖矩阵 |
| 2026-10-19 | v1.2 | 补充 git 初始化与远端合并、中文字体与主题、发布构建脚本与排除规则；更新 P0 进度 |
| 2026-10-19 | v1.3 | 新增项目门禁：AGENTS.md 契约、tools/gate.ps1、Git 钩子、CI workflow 与门禁文档 |
| 2026-10-19 | v1.4 | 对照 Godot 官方与成熟项目补齐 .editorconfig、CHANGELOG、PR 模板、测试入口与文本规范检查 |
| 2026-10-19 | v1.5 | 新增开发路线图（P0–P6）与版本迭代目录；README 改为开源项目介绍 + 路线图 |

维护：架构变更先改 `01-总览/02`，再改领域文档，最后同步本索引。
