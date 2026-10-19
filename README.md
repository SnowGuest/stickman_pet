# Stickman Pet

**一段住在 Windows 桌面上、可以随时伸手打断的无声火柴人短片。**

[![Godot](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-P0%20baseline-orange)](docs/00-项目/路线图/README.md)

它表现得像 Alan Becker 的 *Animator vs. Animation*：火柴人把桌面当成舞台，把鼠标当成对手/伙伴，用身体和表情演戏。没有对白，但有幽默和情绪。

它能被鼠标抓住任何部位：抓腰时下半身自然下垂，抓头时整个人倒挂，松手会被扔出去、撞墙、落地，再自己爬起来。视觉上参考 Alan Becker 风格的火柴人，但所有动画、线条和音效都是原创；桌面上还可以有 Minecraft 风格的 3D 旋转掉落物。

这是一个**正在开发中**的个人项目，不是成品。当前处于工程基线收尾阶段，游戏逻辑尚未开始。最终体验定义见 [最终产品定义](docs/01-总览/05-最终产品定义.md)。

---

## 现在到哪了

| 项 | 状态 |
|---|---|
| 当前阶段 | **P0 工程基线（95%）** |
| 已完成 | 文档体系、git 仓库、窗口配置、中文字体、发布脚本、项目门禁 |
| 未完成 | 导出模板、真实 exe、远端 CI；游戏逻辑（窗口外壳/骨骼/物理）未开始 |
| 下一步 | **P1 最小可视**：透明窗口外壳 + 静态火柴人；并行准备 AI 协议/Go 客户端 |

完整进度见 [开发路线图](docs/00-项目/路线图/README.md)，版本记录见 [版本迭代](docs/00-项目/版本迭代/README.md)。

---

## 目标能力

这些是项目要做的，不是现在就能用的：

- **像短片一样表演**（后置）：无对白，用表情、停顿、夸张反应和弹性动作表达情绪。
- **可抓取骨骼**：抓任意部位，身体按重力 + 肌肉张力自然下垂、摆动，关节不反折。
- **桌面融合**：透明、无边框、置顶、不抢焦点，空白处点击穿透。
- **2.5D 表现**：前后肢分层、接触阴影、拖拽倾斜，保持手绘火柴人的干净轮廓。
- **3D 掉落物**：离屏 3D 渲染成 2D 精灵，绕 Y 轴旋转，可拖、可扔、可被宠物拿起。
- **可选 AI 控制**：独立 Go 客户端内置模型，通过本机 WebSocket 下发高层意图；AI 不在时桌宠自主运行。

当前已完成的只有"工程能力"：窗口配置、字体、发布脚本、门禁。请不要把上面的目标能力当成已有功能。

---

## 路线图

| 阶段 | 版本 | 主题 | 状态 | 说明 |
|---|---|---|---|---|
| P0 | [v0.1.0](docs/00-项目/版本迭代/v0.1.0.md) | 工程基线 | 🟡 95% | 文档、仓库、配置、字体、门禁 |
| P1 | [v0.2.0](docs/00-项目/版本迭代/v0.2.0.md) | 最小可视 | ⬜ 0% | 透明窗口 + 静态火柴人 |
| P2 | [v0.3.0](docs/00-项目/版本迭代/v0.3.0.md) | 动画 | ⬜ 0% | 剪辑/采样/混合 |
| P3 | [v0.4.0](docs/00-项目/版本迭代/v0.4.0.md) | 手感 | ⬜ 0% | PBD、抓取、投掷、下垂 |
| P4 | [v0.5.0](docs/00-项目/版本迭代/v0.5.0.md) | 行为（alpha） | ⬜ 0% | FSM、表情、IK、音效 |
| A | [v0.5.5](docs/00-项目/版本迭代/v0.5.5.md) | AI 控制桥接 | ⬜ 0% | 独立 Go AI + 本机 WebSocket |
| P5 | [v0.6.0](docs/00-项目/版本迭代/v0.6.0.md) | 表现（beta） | ⬜ 0% | 2.5D、阴影、3D 物品 |
| P6 | [v1.0.0](docs/00-项目/版本迭代/v1.0.0.md) | 稳定发布 | ⬜ 0% | 测试、性能、打包 |

每个阶段的需求、验收和完成状态在 [路线图目录](docs/00-项目/路线图/README.md)；每个版本的迭代说明在 [版本迭代目录](docs/00-项目/版本迭代/README.md)。

---

## 快速开始

1. 安装 **Godot 4.7.2-stable**（Forward+ / D3D12）。
2. 克隆仓库并用编辑器打开本目录。
3. 运行主场景。

> 注意：当前 `scenes/main.tscn` 只是占位 Label，运行不会看到火柴人。第一个可运行角色在 P1 / v0.2.0。

修改前请先读 [AGENTS.md](AGENTS.md)（所有会话/agent 的协作契约）。

---

## 项目结构

```
scenes/           主场景与后续 Pet/Item 场景
assets/           字体、主题、后续动画/贴图/音效
tests/            测试入口（当前为占位）
tools/            门禁、发布、钩子安装脚本
.github/          CI 与 PR 模板
.githooks/        pre-commit / commit-msg
addons/           godot_ai（仅开发期，发布排除）
docs/             分级文档：目标、架构、路线图、版本、领域规范
```

---

## 文档

| 入口 | 内容 |
|---|---|
| [文档中心](docs/README.md) | 全部文档地图、阅读路径、覆盖矩阵 |
| [最终产品定义](docs/01-总览/05-最终产品定义.md) | 像 Alan Becker 的六条特征、体验剧本、表演层缺口 |
| [AI 集成](docs/07-AI集成/README.md) | Go AI 客户端、WebSocket 协议、模式仲裁 |
| [开发路线图](docs/00-项目/路线图/README.md) | P0–P6 需求、验收、当前状态 |
| [版本迭代](docs/00-项目/版本迭代/README.md) | 每个版本的迭代说明与更新 |
| [项目目标](docs/00-项目/01-项目目标.md) | 成功标准、KR、范围 |
| [架构与运行时](docs/01-总览/02-架构与运行时.md) | 分层、模块所有权、帧管线、ADR |
| [Godot 工程基线](docs/01-总览/03-Godot工程基线.md) | 项目设置、字体、输入、导出 |
| [项目门禁](docs/06-工程/04-项目门禁.md) | 规则、检查项、绕过政策 |

---

## 项目门禁

提交/合并前必须通过：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1
```

更严格（需已关闭编辑器 / 已装导出模板）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1 -Full -ReleaseCheck
```

安装 Git 钩子（推荐）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\install_hooks.ps1
```

发布只走脚本：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
```

---

## 技术栈

- Godot 4.7.2 / GDScript
- 自研 PBD 物理 + 程序化线条渲染（无 Spine/骨骼贴图依赖）
- 2D 宠物 + SubViewport 离屏 3D 物品
- 中文字体：Noto Sans SC（OFL 1.1）

---

## 许可

代码 MIT（见 [LICENSE](LICENSE)）；字体为 SIL OFL 1.1（见 [OFL.txt](assets/fonts/OFL.txt)）。

本项目为个人作品，风格上受火柴人动画与体素沙盒游戏启发；所有美术、动画、音效均为原创，与 Alan Becker、Mojang/Microsoft 无关联，未获得其授权或背书。
