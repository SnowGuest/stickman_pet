# 音效

来源：项目所有者提供，2026-10-19 确认可用于本项目。
格式：OGG Vorbis，44.1kHz，双声道；未做转码或响度处理。

| 文件 | 原文件 | 时长 | 用途 |
|---|---|---|---|
| `sfx_step_01.ogg` | `Footstep.ogg` | 0.17s | 走路脚步（左右脚共用） |
| `sfx_land_soft.ogg` | `Land.ogg` | 0.29s | 轻落地 |
| `sfx_wave_whoosh.ogg` | `Swoosh.ogg` | 0.16s | 挥手/挥动统一 whoosh |
| `sfx_sit.ogg` | `Sit.ogg` | 0.93s | 坐下 |
| `sfx_wave.ogg` | `Wave.ogg` | 0.89s | 挥手/打招呼 |
| `sfx_clap.ogg` | `Clap.ogg` | 1.27s | 鼓掌/得意 |
| `sfx_pop.ogg` | `Pop.ogg` | 0.07s | 戳/弹出 |

## 脚步映射

- 事件 `step_l` / `step_r` 都播放 `sfx_step_01.ogg`；
- 左右脚交替时音高随机 ±8%，避免机械重复；
- 当前只有 1 个变体，`sfx_step_02/03` 待补。

## 挥手映射

- 挥手、挥臂、拍手等动作统一使用 `sfx_wave_whoosh.ogg`；
- 与 `sfx_wave.ogg` 区分：后者是打招呼音，前者是动作 whoosh；
- 抛出如需独立音效，后续补 `sfx_throw_whoosh.ogg`。

## 授权

当前记录为“项目所有者提供并确认可用”，未声明第三方许可证。
如果未来对外发布，需要补齐作者、来源与许可证（或替换为 CC0/原创音效）。
