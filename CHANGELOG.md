# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- 开发路线图（P0–P6）：每阶段目标、需求、验收与当前状态
- 版本迭代目录：v0.1.0–v1.0.0 的迭代说明与更新记录
- README：开源项目介绍、状态、路线图与快速开始
- 最终产品定义：像 Alan Becker 的六条特征、体验剧本、表演层缺口
- AI 集成：Go 客户端 + 本机 WebSocket 协议、模式仲裁、轨道 A（v0.5.5-ai）
- 光标交互：长按抓取、按住左键变实体推/撞、GlobalMouse 全局按键
- 10 条无 AI 自主小剧场：探头、散步、追光标、木头人、躲猫猫、晃腿、打瞌睡、影子拳击、搬方块、装死
- 系统托盘与基础设置：显示/缩放/静音/置顶/AI 开关/自启/退出
- 素材清单：图标、动画 JSON、约 21 个音效、授权记录
- 移除 3D 道具系统相关内容（本期只做 2.5D）
- 明确无脸火柴人：移除面部系统，改为 HeadAim 与身体语言
- 五色配色与橙色空心头规范
- 7 个 OGG 音效入库（脚步/落地/挥动/坐下/挥手/鼓掌/弹出）
- 挥手 whoosh 重命名为 `sfx_wave_whoosh.ogg`，抛出音效待补
- `sfx_wave.ogg` 设为循环，用作连续挥手
- P0 工程基线测试 54 项，替换占位测试入口
- 纹理审查：21 张 1×1 色块全部丢弃，色号已提取
- 应用/托盘图标入库：多尺寸 ICO + 透明托盘图标
- 骨骼数据：13 骨 / 14 关节，`assets/rigs/stickman.json`
- 项目门禁：AGENTS 契约、`tools/gate.ps1`、Git 钩子、CI 静态检查
- 中文字体：Noto Sans SC（OFL 1.1）与全局 Theme
- 发布构建脚本：staging 排除 `addons/godot_ai`、移除 `_mcp_game_helper`
- 分级文档：总览 / 平台 / 仿真 / 表现 / 行为 / 工程 / 附录

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
