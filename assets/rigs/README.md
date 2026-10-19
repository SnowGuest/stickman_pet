# 骨骼数据

文件：`stickman.json`
来源：[骨骼与动画](../../docs/03-仿真/01-骨骼与动画.md) 第 2.1 节拓扑表。
规模：**13 骨 / 14 关节**，骨盆为根关节；总质量 24.1；1× 高度约 126px。

## 约定

- 单位：1× 缩放下的像素；
- 角度：+X 右、+Y 下，正角顺时针，"向上" = -90°；
- `limit_lo_deg` / `limit_hi_deg` 是**相对静止角**的限位；
- `rest_rel_deg` 由运行时 `compile()` 计算，不写进 JSON，避免两份真源；
- `head_radius = 18.0` 为美术调参值，覆盖类默认 13.0；
- `render.line_width = 6.0` 是全身单笔路径的统一线宽；`width` 仅保留给物理/命中参考，P1 渲染不再逐骨取宽；
- `render.stroke = "single_path"`：17 点单条 `Line2D`，纯色、无 halo、无描边。

## 派生值（供核对）

| 骨 | parent | rest_abs | rest_rel | 限位 |
|---|---|---|---|---|
| spine | — | -90 | -90 | -22..22 |
| neck | spine | -90 | 0 | -30..30 |
| head | neck | -90 | 0 | -25..25 |
| upper_arm_l | spine | 96 | -174 | -165..165 |
| forearm_l | upper_arm_l | 100 | 4 | -150..0 |
| upper_arm_r | spine | 84 | 174 | -165..165 |
| forearm_r | upper_arm_r | 80 | -4 | -150..0 |
| thigh_l | — | 94 | 94 | -100..45 |
| shin_l | thigh_l | 90 | -4 | -150..0 |
| foot_l | shin_l | 0 | -90 | -40..40 |
| thigh_r | — | 86 | 86 | -100..45 |
| shin_r | thigh_r | 90 | 4 | -150..0 |
| foot_r | shin_r | 0 | -90 | -40..40 |

> 上臂相对 spine 的 rest_rel 落在 ±180 附近（-174 / 174），这是"脊柱朝上、手臂朝下"的正常结果；运行时用最短路径归一化，不能直接线性插值跨 ±180。

## 校验

- 13 骨、14 关节，关节无重复；
- 每根骨的 start/end 关节都存在；
- 父骨必须先于子骨；
- length/mass/width > 0；
- `limit_lo_deg <= limit_hi_deg`；
- 所有关节至少被一根骨引用。

生成时已用脚本校验；后续修改 JSON 后应重新跑同样的检查。
