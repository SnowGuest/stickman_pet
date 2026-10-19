# AI 集成

> 上级：[文档中心](../README.md) · 架构：[架构与运行时](../01-总览/02-架构与运行时.md)
> 决策：**表演层（FaceRig/ActingLayer/ReactionLibrary）后置；先接入独立 Go AI 客户端，通过 WebSocket 下发高层控制意图。**
> 本文是 AI 集成的入口；协议细节见 [控制架构与协议](01-控制架构与协议.md)。

---

## 1. 一句话

Godot 负责"怎么动"（动画、物理、状态机、渲染），Go 客户端负责"想做什么"（训练好的模型推理），两者通过本机 WebSocket 交换**状态快照**与**高层意图**。

```
┌──────────────────────┐        WebSocket (127.0.0.1)        ┌──────────────────────┐
│ Godot 桌宠            │  state 15Hz  ───────────────────►  │ Go AI 客户端          │
│  - AiBridge (server)  │  ◄───────────────────  command ≤30Hz│  - 模型推理            │
│  - PetBrain / Solver  │  event / ack / ping                 │  - 策略 / 行为选择      │
│  - Renderer           │                                     │  - 重连 / 日志          │
└──────────────────────┘                                     └──────────────────────┘
```

---

## 2. 为什么是 Godot 做 Server

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| **Godot 做 WS Server，Go 做 Client** | 桌宠可独立运行；AI 可选、可重启；用户输入始终优先；端口与生命周期由产品掌控 | Godot 需要实现一个轻量 WS server | **采用** |
| Go 做 Server，Godot 做 Client | Go 服务可独立运行；Godot 客户端代码更少 | 没有 AI 时桌宠无法启动；端口/生命周期归 AI 进程 | 不采用 |
| 进程内嵌（GDExtension/子进程管道） | 延迟最低 | 与"独立 Go 客户端"目标冲突；调试/热重载差 | 不采用 |

> 如果未来 AI 必须独立于桌宠运行，可把协议角色反转；消息格式保持不变。

---

## 3. 控制层级：意图，而不是关节

| 层级 | 例子 | 谁负责 | 是否采用 |
|---|---|---|---|
| 高层意图 | `look_at`、`walk_to`、`emote`、`sleep` | AI 决策，Godot 执行 | **采用** |
| 参数化动作 | 目标点、速度、表情名 | AI 给参数，Godot 校验 | **采用** |
| 逐帧姿态/关节角 | 每 16ms 发 13 根骨角度 | AI 直接控制 | 不采用 |
| 动作片段 id | 直接播放某个 clip | AI 选片段 | 仅调试 |

原因：网络抖动、推理频率（10–20Hz）与物理频率（120Hz）不匹配；让 Godot 保留动画/物理/限位的最终控制权，AI 只做"决策"。

> 如果未来接入动作生成模型，可增加独立的 `pose_stream` 能力（30Hz、带时间戳、带权重），作为**可选扩展**，不混入基础协议。

---

## 4. 模式与优先级

```
MANUAL（用户拖拽/点击） > REMOTE_AI（AI 控制） > AUTONOMOUS（自主行为）
```

- 默认 `AUTONOMOUS`；AI 连接并通过 `hello` 后请求 `set_mode: remote`。
- 用户一旦拖拽/点击，立即进入 `MANUAL`；AI 命令被拒绝（`ack.ok=false, reason=user_override`）。
- 用户松手后 300ms 无输入，AI 可重新取得控制（需再次 `set_mode` 或自动恢复，按配置）。
- AI 断开/超时 1s → `AUTONOMOUS`，不阻塞桌宠。
- `AUTONOMOUS` 永远可用：没有 AI 也是一只完整桌宠。

---

## 5. 生命周期

```
Godot 启动
  → AiBridge.listen(127.0.0.1:8765)
  → 生成一次性 token（启动参数/环境变量传给 Go）
  → 等待 hello（5s 超时）
  → welcome（screen/pet/protocol）
  → state 15Hz / command ≤30Hz
  → 断开 → 1s 后 AUTONOMOUS，等待重连
```

Go 客户端：

```
读取 --url / --token / --model
  → 连接（指数退避 0.5s→5s）
  → hello → welcome
  → 推理循环 10–20Hz
  → 发送 command（带 id/ttl）
  → 处理 state/ack/event
  → 断开重连，不退出
```

---

## 6. 模型接入（Go）

推荐接口：

```go
type Policy interface {
    Reset()
    Act(state State) Action
}

type Action struct {
    Name   string
    Params map[string]any
    TTL    time.Duration
}
```

模型形态与运行时：

| 模型 | Go 方案 | 说明 |
|---|---|---|
| 小型策略网络（分类/回归） | ONNX Runtime Go（`yalue/onnxruntime_go`） | 推荐；导出 ONNX，输入特征向量，输出动作 logits |
| TensorFlow Lite | `galeone/tfgo` | 可用，但依赖与构建更重 |
| 纯 Go 小模型 | Go 原生矩阵运算 | 适合极小 MLP，避免 cgo |
| LLM/大模型 | 本地 llama.cpp 服务或 Go 绑定 | 延迟高，只适合 0.5–2Hz 的高层决策，不适合逐帧 |

推理循环：

- 10–20Hz，独立 goroutine；WS 读写不阻塞推理。
- 输入特征：宠物状态、相对鼠标位置、屏幕尺寸、最近事件、冷却时间。
- 输出：动作名 + 参数；Godot 校验/限幅。
- 日志：JSONL 记录 `state → action`，用于回放与再训练。
- 超时：单次推理超过 500ms 时复用上一条未过期意图，不阻塞。

---

## 7. 安全与稳定性

- 只绑定 `127.0.0.1`，不监听公网。
- 一次性 token：Godot 启动时生成，通过命令行/环境变量给 Go；不写进仓库。
- 消息大小上限 64KB；JSON 解析失败直接拒绝。
- 动作白名单 + 参数范围校验；未知动作返回 `ack.ok=false`。
- 命令 TTL 默认 250ms；过期丢弃，避免"补执行"造成抖动。
- 背压：只保留最新状态；命令队列最多 8 条，旧命令丢弃。
- 单客户端：第二个连接拒绝（`reason=busy`）。
- 断线：AI 退出不影响桌宠；桌宠退出时 Go 自动重连等待。

---

## 9. 托盘开关

- 托盘菜单 `AI 控制` 对应配置 `ai.enabled`。
- 关闭：`AiBridge` 停止监听、断开客户端、模式回 `AUTONOMOUS`。
- 开启：启动监听，状态"等待连接"；AI 连上后"已连接"，但仍默认自主，直到 `set_mode: remote`。
- 运行中关闭：发送 `error ai_disabled` 并关闭连接；Go 客户端退避重连。
- 托盘只控制"是否允许 AI 接入"，不直接控制角色。
- 详见 [托盘与设置](../02-平台/03-托盘与设置.md)。

---

## 10. 与现有路线图的关系

- AI 控制是**并行轨道 A**，依赖 P1 的状态/输入、P3 的物理、P4 的状态机；
- 不阻塞 P2/P3/P4 的主线；
- 表演层（P2 的表演性关键帧、P4 的 FaceRig/ReactionLibrary）标记为**后置**，不进入 v1.0 硬验收；
- 版本计划：`v0.5.5-ai`（协议 + Godot AiBridge + Go 客户端骨架 + 模型接口）。

详见 [轨道 A](../00-项目/路线图/轨道A-AI控制桥接.md) 与 [协议](01-控制架构与协议.md)。
