# 图标

来源：项目所有者提供，2026-10-19。
原始尺寸：16 / 32 / 64 / 128 / 256 / 512 PNG。

| 文件 | 用途 |
|---|---|
| `icon_16.png` … `icon_512.png` | 原始 PNG，保留各尺寸 |
| `icon.ico` | Windows exe / 窗口图标，含 16/24/32/48/64/128/256 |
| `tray_16.png` … `tray_256.png` | 托盘用透明背景版本（去掉黑色底、空心头内部透明） |
| `tray.ico` | 通知区图标，含 16/24/32/48/64/128/256 |

说明：

- 应用图标保留原始黑色背景；
- 托盘图标去掉了外部黑色背景，并把橙色空心头的内部改为透明，避免在任务栏上变成黑色实心圆；
- 项目设置：`application/config/icon = res://assets/icons/icon_512.png`；
- Windows 导出：`application/icon = res://assets/icons/icon.ico`。
