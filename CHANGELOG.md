# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- 开发路线图（P0–P6）：每阶段目标、需求、验收与当前状态
- P4 自主行为首版：`PetBrain` 四状态 Idle/Walk/Wave/Look，按权重与最短停留自动切换
- P2 交叉淡化：0.2s idle→walk 连续性自动测试通过
- P4 自主细节：energy/boredom/curiosity、Look 头部偏转、脚步/挥手音效
- P5 接触阴影 + 走路起伏/整体轻摆
- 默认 SDF 笔画：13 骨胶囊并集 + 空心头圆环，`--line` 回退单笔 Line2D
- SDF 双臂改为二次贝塞尔曲线，肘部自然弯折、手部随摆
- 站立双腿从骨盆单点分出：左腿 70° 向右、右腿 90°，不再加骨盆横线
- 2D/3D 火柴人加回 L 形双脚：双脚朝同一方向，脚长从 10 缩短到 3
- P6 绿色版：`tools/package_release.ps1` 生成 zip + SHA256；180s soak
- 版本迭代目录：v0.1.0–v1.0.0 的迭代说明与更新记录
- README：开源项目介绍、状态、路线图与快速开始
- 最终产品定义：像 Alan Becker 的六条特征、体验剧本、表演层缺口
- AI 集成：Go 客户端 + 本机 WebSocket 协议、模式仲裁、轨道 A（v0.5.5-ai）
- 光标交互：长按抓取、按住左键变实体推/撞、GlobalMouse 全局按键
- 10 条无 AI 自主小剧场：探头、散步、追光标、木头人、躲猫猫、晃腿、打瞌睡、影子拳击、搬方块、装死
- 系统托盘与基础设置：显示/静音/置顶/AI 开关/自启/退出
- 素材清单：图标、动画 JSON、约 21 个音效、授权记录
- 移除 3D 道具系统相关内容（本期只做 2.5D）
- 明确无脸火柴人：移除面部系统，改为 HeadAim 与身体语言
- 五色配色与橙色空心头规范
- 7 个 OGG 音效入库（脚步/落地/挥动/坐下/挥手/鼓掌/弹出）
- 挥手 whoosh 重命名为 `sfx_wave_whoosh.ogg`，抛出音效待补
- `sfx_wave.ogg` 设为循环，用作连续挥手
- P0 工程基线测试 157 项，替换占位测试入口
- `gate -Full` 增加主场景启动冒烟
- 真实 Windows exe 导出成功（首版 117.92MB，P1 版 117.96MB），exe 冒烟退出 0
- GitHub Actions 跑通，P0 工程基线 100% 完成
- P1：透明窗口 + 动态穿透 + 单实例 + 13 骨静态火柴人
- 火柴人改为单条 Line2D 21 点一笔画，纯色、无白色/深色描边
- P1 托盘 fallback：PowerShell NotifyIcon，缩放/退出命令可用
- P1 原生托盘 helper：C# `TrayHelper.cs`，`build_release` 用 csc 编译
- P1 GlobalMouse：C# 写状态文件，Godot 读取
- P1 GrabProbe：启动自检 0px；手动点击误差 0.116px
- P1 右键菜单系统层打开验收
- P1 FloatPanel：线宽/色板/骨架点热调
- P1 宠物右键菜单；打开时锁定全窗穿透，关闭恢复凸包
- 修复火柴人底部裁切：按实际缩放计算包围盒，顶部 32px、底部按线宽留安全边距
- 开启 2D MSAA 8×，线条/头部边缘更平滑
- 窗口尺寸变化/失焦恢复时重新布局，修复首次无焦点裁切
- 修复高 DPI 下穿透凸包未按渲染缩放生成、导致头部/边缘被窗口区域裁切
- P2 动画：AnimClip/AnimLibrary/PoseSampler/PoseBlender/AnimPlayer
- P2 剪辑：idle/walk/drag_idle，F2/F3/F4 切换，`--anim=` 截图
- P2 加性呼吸层、事件去重、FloatPanel 动画剪辑/时间轴
- P2 `wave` 表演剪辑（预备/停顿/过冲）与骨骼高亮
- P3 物理首版：RagdollSolver Verlet/距离/角度限位/抓取/碰撞/休眠
- P3 交互：左键抓任意骨骼、拖动、松手抛出/落地
- P3 四套张力表、spine 世界偏置、120Hz 物理插值
- P3 屏幕四边硬边界：任何约束后都夹回窗口内，头部半径单独保护
- P3 落地去弹性：restitution=0、接触/约束额外耗散、松手后快速休眠
- P3 修复按住时绕鼠标自转、松手后不坠落；抓取主动角驱动清零，空中/接触阻尼分离，落地才休眠
- P3 质量感：抓取目标 14/s 平滑、按逆质量分配修正；抓取不做刚性混合，头/四肢完整受重力
- P3 重力提高：1500→2300 px/s²，恢复自然下坠与跟随摆动
- P3 自由落体加速：damping 1.0、max_speed 6000，速度线性增加；抓取时单独 0.985 阻尼
- P3 关节抓取修复：点中关节时只钉住该粒子并按逆质量保护相邻骨长，肘/膝骨长误差 <1px
- P3 头部抓取：头部圆按渲染缩放命中，抓头映射到 neck_top 并保留头心偏移，头/颈不再拉伸
- P3 重叠命中优先级：四肢 > 颈/头 > 躯干，肘/膝压躯干时不再误抓手部
- P3 鼠标跟随修复：每帧轮询 viewport 鼠标位置，移除按全局键状态自动松手；输入用 event.position
- P3 停手防抽动：鼠标停住 80ms 后冻结求解器并清零速度，移动时唤醒
- P3 人体限位：肘后弯 ≤20°/前屈 150°，膝 ≤90°/反向 ≤10°，spine/neck/head 收紧
- P3 躯干/肩稳定：max_corr 0.20→0.12，移除 spine 世界扶正，抓取角阻尼 0.35
- P3 颈/头稳定：neck/head 限位收紧到 ±10°，spine ±15°，抓颈不再抖
- P3 下臂稳定：抓臂时锁定肘相对角（tone 1.0），上肢速度额外阻尼，重叠命中容差 30px
- P3 抓颈稳定：头部圆改为 neck_top 锚点，抓颈/躯干锁定 elbow+hand 相对 chest，下臂速度 <100
- P3 坠落表演序列暂缓：移除 panic_fall/land/get_up，松手后恢复纯物理坠落
- 托盘 helper 设置 `WS_EX_TOOLWINDOW`，隐藏 Alt+Tab/任务栏条目
- 新增 `tools/test_alt_tab.ps1` 验收脚本
- 发布脚本增加导出模板预检，缺失时给出明确路径
- 发布脚本增加 `-PackOnly`，PCK 导出验证通过（约 13.7MB）
- 纹理审查：21 张 1×1 色块全部丢弃，色号已提取
- 应用/托盘图标入库：多尺寸 ICO + 透明托盘图标
- 骨骼数据：13 骨 / 14 关节，`assets/rigs/stickman.json`
- 项目门禁：AGENTS 契约、`tools/gate.ps1`、Git 钩子、CI 静态检查
- 中文字体：Noto Sans SC（OFL 1.1）与全局 Theme
- 发布构建脚本：staging 排除 `addons/godot_ai`、移除 `_mcp_game_helper`
- 分级文档：总览 / 平台 / 仿真 / 表现 / 行为 / 工程 / 附录

### Removed

- 移除全部鼠标交互：抓取、拖动、投掷、右键菜单、FloatPanel、GrabProbe、GlobalMouse 全局轮询
- 角色只播放待机/走路/挥手动画，不再响应鼠标
- C# 托盘 helper 不再写 `stickman_mouse.txt`

### Changed

- `project.godot`：关闭 stretch 缩放，开启透明/无边框/置顶，设置主场景与版本号
- `.editorconfig`：补齐 Godot 风格（Tab、LF、UTF-8、去尾随空格）
- CI：增加并发取消、超时与最小权限

## [0.1.0] - 2026-10-19

### Added

- Godot 4.7.2 工程骨架与 git 仓库
- 中文 UI 字体与主题
- 发布预设与构建脚本
- 项目门禁与协作契约

[Unreleased]: https://github.com/SnowGuest/stickman_pet/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/SnowGuest/stickman_pet/releases/tag/v0.1.0
