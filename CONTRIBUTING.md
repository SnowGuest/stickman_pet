# 贡献指南

> 本项目的协作契约以 [AGENTS.md](AGENTS.md) 为准；本文只给人类贡献者的最短路径。

## 快速开始

1. Godot **4.7.2-stable** 打开工程。
2. 读 [README](README.md) → [路线图](docs/00-项目/02-路线图与进度.md) → 对应领域文档。
3. 提交前跑门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1
```

4. 发布只走：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
```

## 提交规范

Conventional Commits：

```
feat(physics): 增加抓取约束
fix(platform): 修正 DPI 坐标
docs(rig): 补充 FK 说明
```

## 不要做

- 提交 `.godot/`、`build/`、日志、密钥。
- 直接对开发目录导出，或删除发布排除逻辑。
- 修改 `addons/godot_ai` 内部文件（升级除外）。
- 删除字体/许可证文件。
- 用 `--no-verify` 绕过门禁。

## 门禁与 CI

- 本地：`tools/gate.ps1`
- 钩子：`tools/install_hooks.ps1`（可选，但推荐）
- CI：`.github/workflows/gate.yml`

详细规则与检查项见 [项目门禁](docs/06-工程/04-项目门禁.md)。
