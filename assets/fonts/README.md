# Noto Sans SC（中文字体）

| 项 | 值 |
|---|---|
| 文件 | `NotoSansSC-Variable.ttf`（可变字体，字重 100–900） |
| 来源 | https://github.com/google/fonts/tree/main/ofl/notosanssc |
| 版本 | 2026-10 从上游 `main` 获取 |
| 许可证 | SIL Open Font License 1.1（见 `OFL.txt`） |
| 大小 | 17,772,300 字节（约 17.0 MB） |
| SHA-256 | `A3041811A78C361B1DE50F953C805E0244951C21C5BD412F7232EF0D899AF0DA` |
| 覆盖 | 31036 字形，已验证菜单/错误提示常用汉字 |

## 用法

`assets/themes/pet_theme.tres` 将本字体设为 `default_font`，项目设置 `gui/theme/custom` 指向该主题，因此所有 Control（菜单、Label、按钮）默认使用中文字体。

## 注意

- 字体文件是 OFL 授权，发布时必须随包附带 `OFL.txt`。
- 不要修改字体文件；需要子集化时保留版权信息与许可证。
- **必须使用完整文件**。下载被截断时 Godot 会报 `FreeType: Error loading font`，文字整段不显示；校验方法：表目录最大偏移 ≤ 文件大小。
- 若未来做多语言，可为日文/韩文追加对应 Noto 字体，主题里用 `FontVariation` 组合 fallback。
