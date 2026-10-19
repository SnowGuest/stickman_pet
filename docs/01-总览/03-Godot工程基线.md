# Godot 工程基线

> 上级：[文档中心](../README.md) · 领域：总览/工程
> 本文把"标准 Godot 项目该有的工程配置"落成清单：版本、项目设置、autoload、输入、层、导入、场景规范、插件、导出。
> 当前工程只有 `project.godot` + Godot AI 插件，**大部分配置尚未落地**，按第 12 章逐项完成。

---

## 1. 版本固定

| 项 | 值 |
|---|---|
| 引擎 | Godot **4.7.2-stable** |
| 渲染 | Forward+ / D3D12（Windows） |
| 语言 | GDScript（静态类型优先） |
| 版本文件 | `tools/godot-version.txt`，内容 `4.7.2` |

规则：

- 升级引擎必须单独开分支，跑完整测试与三种 DPI 验收。
- 不用 `4.x` 浮动版本；CI 与本地版本一致。
- `.godot/` 永不提交。

---

## 2. 当前 vs 目标

| 配置 | 当前 | 目标 | 优先级 |
|---|---|---|---|
| 主场景 | `res://scenes/main.tscn`（占位） | 正式入口场景 | P0 |
| 窗口透明 | 已开启 | `transparent=true` + per-pixel allowed | P0 |
| 无边框/置顶 | 已开启 | 均 true | P0 |
| stretch | `disabled` | **`disabled`** | P0 |
| 渲染背景透明 | `true` | `rendering/viewport/transparent_background=true` | P0 |
| 版本号 | `0.1.0` | `application/config/version` | P0 |
| 中文主题 | 已接入 Noto Sans SC | 全局 Theme 生效 | P0 |
| autoload | `_mcp_game_helper`（仅开发） | 发布脚本自动移除 | P0 |
| 输入映射 | 无 | 见第 5 章 | P1 |
| 2D 物理层 | 默认 | Pet/Item/World | P1 |
| 导入预设 | 无 | 纹理 nearest、音频 ogg | P1 |
| 导出预设 | `export_presets.cfg` 已创建 | Windows Desktop | P1 |
| git | 已初始化，`origin/main` | 初始化并提交 | P0 |

---

## 3. project.godot 目标片段

```ini
[application]

config/name="Stickman Pet"
config/version="0.1.0"
config/features=PackedStringArray("4.7", "Forward Plus")
run/main_scene="res://scenes/main.tscn"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/transparent=true
window/per_pixel_transparency/allowed=true
window/size/borderless=true
window/size/always_on_top=true
window/size/resizable=false
window/stretch/mode="disabled"
window/dpi/allow_hidpi=true

[gui]

theme/custom="res://assets/themes/pet_theme.tres"

[rendering]

renderer/rendering_method="forward_plus"
viewport/transparent_background=true
```

> 尺寸只是占位；运行时由 `DesktopShell` 覆盖为屏幕可用区。

---

## 4. Autoload

| 名称 | 路径 | 用途 | 发布版 |
|---|---|---|---|
| `App` | `res://scripts/app/app.gd` | 启动装配、单实例、服务注册 | 保留 |
| `_mcp_game_helper` | `res://addons/godot_ai/runtime/game_helper.gd` | 开发期 MCP 调试 | **移除** |

规则：

- autoload 只放"全局服务"，不放游戏状态。
- 不用 autoload 传数据；依赖通过 `setup()` 注入。
- 发布导出时在导出预设里排除 `addons/godot_ai/**`，并清除 project.godot 中的 autoload 项。

---

## 5. 输入映射

桌宠只用鼠标，但仍建立动作，避免代码里散落按钮常量。

| 动作 | 绑定 | 用途 |
|---|---|---|
| `pet_primary` | 鼠标左键 | 抓取/戳 |
| `pet_secondary` | 鼠标右键 | 菜单 |
| `debug_toggle` | F1（仅开发） | 调试面板 |
| `debug_step` | F5（仅开发） | 单步 |
| `debug_slow` | F4（仅开发） | 慢动作 |

规则：

- 运行时代码读动作，不读 `MOUSE_BUTTON_*` 常量（调试动作除外）。
- 调试动作在发布版不注册（`OS.is_debug_build()` 判断）。

---

## 6. 层与组

### 6.1 2D 物理层

| 层 | 名称 | 用途 |
|---|---|---|
| 1 | `pet` | 宠物碰撞（v1 主要用自研 PBD，预留） |
| 2 | `item` | 物品落地/拾取 |
| 3 | `world` | 屏幕边界/地面 |

> v1 的宠物物理不依赖 `PhysicsServer2D`，层名主要用于未来玩具/物品碰撞，先规范化避免后期改。

### 6.2 渲染层

- 2D 深度用 `z_index`（宠物内部 -5..30），不建大量 `CanvasLayer`。
- UI 用 `CanvasLayer`（layer 10），保证永远在最上。
- 3D 物品在 `SubViewport` 内部，不参与主视口 3D 排序。

### 6.3 组

| 组 | 成员 |
|---|---|
| `pet` | 宠物根节点 |
| `item` | 所有掉落物 |
| `ui` | 菜单/调试面板 |
| `debug` | 调试可绘制对象 |

---

## 7. 导入预设

| 资源 | 设置 |
|---|---|
| 纹理（16×16 像素图） | Filter **Nearest**、Mipmaps **Off**、Compression **Lossless** |
| 音频（短音效） | OGG Vorbis，单声道，44.1kHz |
| 动画 JSON | 不导入为资源，运行时 `FileAccess` 读取 |
| 字体 | 只保留实际字重，开 MSDF（可选） |

在 Godot 导入面板设置后，把 `.import` 文件提交；同一目录的同类资源用"Preset → Set as Default for Folder"。

---

## 8. 场景与脚本规范

| 项 | 规范 |
|---|---|
| 场景根节点 | 与文件名一致（`main.tscn` → `Main`） |
| `owner` | 由场景保存的节点必须设置 owner；运行时动态节点不设 |
| 信号连接 | 优先代码连接（可追踪），编辑器连接不超过 3 条 |
| 脚本类型 | 全部静态类型；`func foo(x: int) -> void` |
| `class_name` | 需要跨文件引用的类才注册，避免全局污染 |
| 节点查找 | 只在 `_ready()` 用 `@onready` 缓存；热路径不 `get_node` |
| 场景切换 | v1 单场景；不做 `change_scene_to_file` |
| 可编辑子节点 | 默认关闭；需要时显式开启并注释原因 |

### 8.1 GDScript 风格

- 遵循官方 [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)。
- 缩进 Tab（项目现状），行宽 ≤ 100。
- 常量 `SCREAMING_SNAKE_CASE`，私有成员 `_` 前缀。
- 警告：未使用变量/参数、未声明类型、隐式转换，在 Project Settings → Debug → GDScript 中设为 Warn/Error。
- 可选工具：`gdformat` / `gdlint` 作为本地钩子，不强制进 CI。

---

## 9. 资源与 UID

- 所有 `.gd` / `.tscn` 旁的 `.uid` **必须提交**，不要手改或删除。
- 移动资源用编辑器/`filesystem_manage`，不要直接 `mv`（会丢 UID 引用）。
- 资源命名：`snake_case`，场景 `PascalCase` 文件名除外（与根节点一致）。
- 不引用 `res://` 绝对路径以外的外部文件；不把用户配置写进 `res://`。

---

## 10. 插件策略

| 插件 | 用途 | 发布版 |
|---|---|---|
| `addons/godot_ai` | 开发期 MCP（场景编辑、测试、截图） | 移除 |
| 其他 | 需评审许可证、体积、维护状态 | 默认不引入 |

规则：

- 插件只用于开发期，不在运行时依赖。
- 引入前记录到 [合规文档](../00-项目/03-风险与合规.md)。
- 发布前用 `tools/build_release.ps1` 复制 staging、删除 `addons/godot_ai` 与 `_mcp_game_helper`，再导出；不要直接对开发目录导出。

---

## 11. 版本控制基线

```gitignore
# Godot
.godot/
export/
build/
*.tmp
*.log

# 本地
.vscode/workspaceStorage/
```

```gitattributes
* text=auto eol=lf
*.png binary
*.ogg binary
*.wav binary
*.ttf binary
*.otf binary
```

- `.vscode/settings.json` 提交（团队共享），`workspaceStorage` 忽略。
- `.editorconfig` 已存在（UTF-8），保留。
- 首次提交前确认没有 `.godot/`、日志、导出物。

---

## 12. 落地清单（P0）

- [x] `git init` + 首次提交 + 远端合并
- [x] 修正 `window/stretch/mode` 为 `disabled`
- [x] 补齐透明/无边框/置顶/背景透明设置
- [x] 设置主场景与版本号
- [x] 中文字体 + 全局 Theme
- [x] 发布脚本移除 `_mcp_game_helper`（开发期仍保留）
- [ ] 创建 `App` autoload
- [ ] 创建输入动作（至少 `pet_primary` / `pet_secondary`）
- [ ] 命名 2D 物理层与组
- [ ] 建立纹理/音频导入预设
- [x] 创建 Windows 导出预设与构建脚本
- [ ] CI 跑通 headless 导入

---

## 13. 验收

- [ ] 新机器 clone 后，用 4.7.2 打开无报错
- [ ] 启动即透明置顶，鼠标坐标 1:1
- [ ] 导入一张 16×16 贴图默认就是 Nearest/无 mipmap
- [ ] 导出包不含 `addons/godot_ai` 与 `tests/`
- [ ] `.godot/` 未被提交，`.uid` 全部在版本库
- [ ] 项目设置与本文档逐项一致
