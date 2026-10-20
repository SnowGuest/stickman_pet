# AGENTS.md · 项目门禁与协作契约

> 本文件是**任何 AI 会话、子 agent、自动化脚本、人类贡献者**进入本项目的入口契约。
> 违反"硬规则"的变更一律拒绝，不因"赶进度"或"看起来没问题"而豁免。
> 项目入口：[README](README.md) · 进度：[路线图](docs/00-项目/02-路线图与进度.md) · 门禁说明：[项目门禁](docs/06-工程/04-项目门禁.md)

---

## 1. 开始前必须做

1. 读 [README](README.md) 的"项目状态"和"文档地图"。
2. 读 [项目目标](docs/00-项目/01-项目目标.md) 与 [路线图](docs/00-项目/02-路线图与进度.md)，确认当前阶段和下一步。
3. 读 [架构与运行时](docs/01-总览/02-架构与运行时.md) 的分层与数据所有权。
4. 找到你要改的领域文档（平台/仿真/表现/行为/工程），按其中的接口、参数、验收实现。
5. 先跑一次门禁，确认基线是绿的：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1
```

---

## 2. 十条硬规则

1. **先读后改**：修改文件前必须读取；不要凭文档摘要或记忆改代码。
2. **文档是契约**：接口、单位、坐标系、信号、参数默认值以领域文档为准；代码与文档冲突时，先改文档（或补 ADR），再改代码。
3. **不提交生成物与密钥**：`.godot/`、`build/`、`export/`、`*.exe`、`*.pck`、日志、token、`.env` 一律不得入库。
4. **发布只走脚本**：发布必须用 `tools/build_release.ps1`；不得直接对开发目录导出，不得删除 `_mcp_game_helper` 的剥离逻辑或 `addons/godot_ai` 的排除规则。
5. **不改 vendor**：`addons/godot_ai/` 是第三方插件，除非升级版本，否则不要改其内部文件。
6. **不删许可证**：`LICENSE`、`assets/fonts/OFL.txt`、字体文件必须保留；删除或替换字体需同时更新 `assets/fonts/README.md` 的哈希与授权说明。
7. **不重写历史**：不 `force push`、不 `rebase` 已推送的提交、不删除他人分支；合并冲突必须人工解决并说明。
8. **保持工程不变量**：`project.godot` 的透明/无边框/置顶/1:1 坐标/主题配置不得回退；具体项见 [Godot 工程基线](docs/01-总览/03-Godot工程基线.md)。
9. **完成定义**：代码可运行 + 文档同步 + 验收可复现 + 门禁通过 + 无新增报错，五条缺一不可。
10. **不得绕过门禁**：禁止 `git commit --no-verify`、禁止注释掉检查、禁止把失败改成警告来"通过"。环境导致无法运行时，报告阻塞，不要降低标准。

---

## 3. 工作流

### 3.1 分支与提交

- 小改动直接 `main`；里程碑/跨模块改动开 `feat/<scope>` 或 `fix/<scope>`。
- 提交信息用 Conventional Commits：
  `feat(physics): 增加抓取约束`、`fix(platform): 修正 DPI 坐标`、`docs(rig): 补充 FK 说明`。
- 一次提交只做一件事；格式化与逻辑分开。

### 3.2 提交前

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1
```

- 失败：修到通过，不允许跳过。
- 需要更严格验证（Godot 导入/测试/发布 staging）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1 -Full -ReleaseCheck
```

### 3.3 提交后

- 推送前确认 `git status` 干净、`git log` 无敏感信息。
- 推送失败（认证/网络）时报告，不要伪造"已推送"。

---

## 4. 常用命令

| 目的 | 命令 |
|---|---|
| 门禁（快速） | `powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1` |
| 门禁（含 Godot 导入） | `... -Full -GodotExe "C:\...\Godot_v4.7.2-stable_win64.exe"` |
| 发布 staging 校验 | `... -ReleaseCheck` |
| 生成发布包 | `powershell -ExecutionPolicy Bypass -File tools\build_release.ps1` |
| 穿透 50 点验收 | `powershell -ExecutionPolicy Bypass -File tools\test_passthrough.ps1` |
| 单实例验收 | `powershell -ExecutionPolicy Bypass -File tools\test_single_instance.ps1` |
| 启动耗时验收 | `powershell -ExecutionPolicy Bypass -File tools\test_startup.ps1` |
| Alt+Tab 隐藏验收 | `powershell -ExecutionPolicy Bypass -File tools\test_alt_tab.ps1` |
| 退出清理验收 | `powershell -ExecutionPolicy Bypass -File tools\test_exit.ps1` |
| 抓取点误差验收 | `powershell -ExecutionPolicy Bypass -File tools\test_grab_point.ps1` |
| 右键菜单验收 | `powershell -ExecutionPolicy Bypass -File tools\test_context_menu.ps1` |
| 安装 Git 钩子 | `powershell -ExecutionPolicy Bypass -File tools\install_hooks.ps1` |
| 导入资源 | `Godot.exe --headless --path . --import` |

---

## 5. 代码与文档边界

| 改动类型 | 必须同步 |
|---|---|
| 新增/修改骨骼、物理参数 | `docs/03-仿真/*` 的参数表与验收 |
| 窗口/穿透/输入策略 | `docs/02-平台/*` |
| 渲染层/主题/字体 | `docs/04-表现/*` 与 `assets` 说明 |
| 行为状态/交互 | `docs/05-行为/01` |
| 配置键/迁移 | `docs/06-工程/01` |
| 发布/CI/门禁 | `docs/06-工程/02`、`03`、`04`、`05` |
| 里程碑/进度 | `docs/00-项目/02` |
| 架构决策 | `docs/01-总览/02` 的 ADR 索引 + 对应领域文档 |

> 文档里的代码是"契约级示意"，实现可优化，但**不得改变接口语义、单位、坐标系、信号契约**。

---

## 6. 发布规则

- 开发目录保留 `_mcp_game_helper`（MCP 调试需要）。
- 发布脚本在 `build/staging` 中删除 helper、`[editor_plugins]` 与 `addons/godot_ai`，再导出并扫描禁止字符串。
- 发布前确认 `LICENSE` 与 `OFL.txt` 随包。
- 没有导出模板时，只能验证到 staging，不得声称"已出包"。

---

## 7. 当前环境事实（2026-10-19）

| 项 | 值 |
|---|---|
| 引擎 | Godot 4.7.2-stable，`C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe` |
| 导出模板 | 已安装 4.7.2-stable（`%APPDATA%\Godot\export_templates\4.7.2.stable`） |
| git 远端 | `origin` = `https://github.com/SnowGuest/stickman_pet.git`；提交由用户负责 |
| 发布产物 | `build/release/StickmanPet.exe` 约 118MB（P1 版 117.96MB，2026-10-19） |
| CI | GitHub Actions 已跑通（2026-10-19，用户确认） |
| 字体 | Noto Sans SC 可变字体，17.7MB，OFL，已接入全局 Theme |
| 原生工具链 | .NET Framework `csc.exe` 可用；无 C++/Rust/CMake |
| 当前阶段 | P3 物理（35%）：PBD/张力表/四边硬边界/插值，左键拖拽已接入 |

环境事实变化时更新本表，不要在新会话里假设旧状态。

---

## 8. 交付前检查清单

- [ ] 读了对应领域文档，接口/单位/参数一致
- [ ] 没有提交 `.godot/`、构建物、日志、密钥
- [ ] `project.godot` 不变量未被破坏
- [ ] 发布排除逻辑未被削弱
- [ ] 文档已同步（接口/参数/进度/ADR）
- [ ] `tools\gate.ps1` 通过
- [ ] 验收步骤可复现，结果有记录
- [ ] 没有用 `--no-verify` 或注释检查来绕过门禁

---

## 9. 出问题时的处理

- **门禁失败**：修根因；确实无法修的，在 PR/提交说明里写清阻塞点，不要降低检查标准。
- **文档与实现冲突**：以文档为契约；若文档过时，先修文档并说明原因。
- **环境缺失**（Godot/模板/网络）：记录到路线图"阻塞"，继续可做的部分。
- **不确定的架构改动**：先写 ADR 草稿，不要直接改数据所有权或发布流程。

---

## 10. 外部参考

本项目规范对照了 Godot 官方文档与成熟开源项目，取舍记录在 [行业实践对照](docs/06-工程/05-行业实践对照.md)：

- [Godot Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
- [Godot Version control systems](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
- [Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Pixelorama CONTRIBUTING](https://github.com/Orama-Interactive/Pixelorama/blob/master/CONTRIBUTING.md)
- [abarichello/godot-ci](https://github.com/abarichello/godot-ci)
- [gdUnit4 CI](https://godot-gdunit-labs.github.io/gdUnit4/latest/faq/ci/)

参考不等于照搬：与本项目 ADR 冲突时，以本项目文档为准，并在对照表里写明原因。
