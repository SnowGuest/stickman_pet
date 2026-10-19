# 测试

P0 工程基线测试入口，不依赖 GUT/gdUnit4。

运行：

```powershell
godot --headless --path . --script res://tests/run_tests.gd
```

或由门禁执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1 -Full
```

覆盖：

- 项目设置：透明、无边框、置顶、不可缩放、stretch 关闭、1280×720；
- 主场景存在、可加载、可实例化；
- 全局 Theme 与中文字体（火/宠）；
- 应用/托盘图标存在；
- 7 个 OGG 音效可加载，wave 循环、whoosh 不循环；
- 骨骼 JSON：13 骨 / 14 关节 / head_radius=18 / 父级顺序；
- 配色 JSON：5 色、默认橙色、橙空心头；
- GDScript 警告等级：untyped / unsafe_* / return_value_discarded 为 warn。

当前：**54 项检查**，失败时退出码 1。
