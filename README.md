# Stickman Pet

一只住在 Windows 桌面上的火柴人宠物：透明置顶、可抓可扔、被抓时按重力与肌肉张力自然下垂，还能和 Minecraft 风格的 3D 掉落物互动。

> 当前阶段：**P0 收尾**（工程基线 + 门禁完成，游戏逻辑未开始）。
> 进度与里程碑见 [路线图](docs/00-项目/02-路线图与进度.md)。

---

## 快速开始

1. 安装 **Godot 4.7.2-stable**（Forward+ / D3D12）。
2. 用编辑器打开本目录，运行主场景。
3. 修改前先读 [AGENTS.md](AGENTS.md)（所有会话/agent 的协作契约）。

## 文档

| 入口 | 内容 |
|---|---|
| [文档中心](docs/README.md) | 全部文档地图、阅读路径、覆盖矩阵 |
| [项目目标](docs/00-项目/01-项目目标.md) | 成功标准、KR、范围 |
| [架构与运行时](docs/01-总览/02-架构与运行时.md) | 分层、模块所有权、帧管线、ADR |
| [Godot 工程基线](docs/01-总览/03-Godot工程基线.md) | 项目设置、字体、输入、导出 |
| [项目门禁](docs/06-工程/04-项目门禁.md) | 规则、检查项、绕过政策 |

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

## 技术栈

- Godot 4.7.2 / GDScript
- 自研 PBD 物理 + 程序化线条渲染（无 Spine/骨骼贴图依赖）
- 2D 宠物 + SubViewport 离屏 3D 物品
- 中文字体：Noto Sans SC（OFL 1.1）

## 许可

代码 MIT（见 [LICENSE](LICENSE)）；字体为 SIL OFL 1.1（见 [OFL.txt](assets/fonts/OFL.txt)）。
本项目为个人作品，与 Alan Becker、Mojang/Microsoft 无关联。
