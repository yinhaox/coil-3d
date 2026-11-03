# Design: Architecture

_纯逻辑层、场景划分、输入注册与性能预算。负责人：tech-director。_

Serves pillar: **一眼读懂的三维空间**、**再来一局的干净循环**。

## Goals

- 一局的全部规则能在没有窗口、没有渲染、没有输入设备的 headless 测试里跑完。
- 逻辑、表现、UI 三层边界清晰：UI 不碰规则，表现不写状态，逻辑不依赖场景树。
- 在 1152×648、GL Compatibility、集成显卡上稳定 60 FPS。

## Player experience

玩家感知不到架构；它体现为：按方向键的同一帧蛇头就转向、窗口切回来不卡顿、连续重开不会越来越慢、结算页数字与 HUD 一致。

## Rules

### Layers

1. **逻辑层** `src/logic/`：`RefCounted` 类，不继承 `Node`，不读 `Input`、不访问场景树、不写文件；所有状态可由测试直接构造和断言。
2. **表现层** `src/game/`：读取逻辑状态并插值，发出表现事件；不修改逻辑状态，不直接改 UI 节点。
3. **UI 层** `scenes/ui/` + `scripts/ui/`：只发意图信号（开始、暂停、重开、改设置），不改游戏状态；符合 `.dsh/rules/ui.md`。
4. **入口**：主场景仍为 `res://scenes/main.tscn`；它只负责加载主菜单，不承载规则。
5. **自动加载**：1.0 不新增 autoload；现有 `StudioCapture` 保持唯一，存档与音频由场景内节点持有。

### Logic model

6. `SnakeSim` 持有场地、蛇、食物、分数、速度、状态与随机数生成器；`step() -> StepResult` 推进一个逻辑步并返回本步事件（移动、吃到、加速、碰撞、清场、时间到）。
7. `StepResult` 是只读数据（字典或轻量类），表现层据此播放补间与音效；表现层不回写。
8. 随机数使用注入种子的 `RandomNumberGenerator`；同一场地 + 同一种子 + 同一输入序列产生同一局，测试可复现。
9. `ArenaLoader.load_all(dir) -> ArenaLoadResult` 是唯一 JSON 入口；返回成功场地与逐文件错误，不静默用默认值覆盖坏文件。
10. `SaveStore` 是唯一 `user://` 入口；接受路径注入，便于测试写到临时目录；`SnakeSim` 永不触碰磁盘。
11. 计分、速度、碰撞判定是纯函数或纯方法，不读取 `delta`；帧循环只负责决定“什么时候调用 `step()`”。

### Frame and input

12. 帧循环累加器：`accumulator += delta`；当 `accumulator >= step_duration` 时调用 `step()`，最多 4 次；剩余时间用于表现插值。卡顿超过 4 步时丢弃多余时间，不追帧。
13. 输入在 `GameController._ready()` 中用 `InputMap.add_action()` / `action_add_event()` 注册：`snake_up`、`snake_down`、`snake_left`、`snake_right`、`snake_pause`；菜单使用 Godot 内建 `ui_*`。
14. 输入只入待转队列，不直接改蛇方向；每个逻辑步消费一个有效转向。
15. `_process` 只做插值、UI 更新与音频调度；禁止在 `_process` 中分配新节点或新数组（稳态零分配）。
16. 蛇身用单个 `MultiMeshInstance3D` 提交全部节（每实例 transform + 颜色），节点数与节数解耦；蛇头、食物、墙、障碍各自是独立网格。
17. 暂停通过 `get_tree().paused` 与逻辑状态双保险；逻辑状态是权威，避免 UI 暂停与模拟暂停不同步。

### Tests

18. `tests/run_tests.gd` 直接实例化 `SnakeSim`、`ArenaLoader`、`SaveStore`，覆盖：180° 拒绝、进入队尾格、撞墙/障碍/自己、吃食物成长与加速、食物补生、时间到、清场、存档往返与损坏回退。
19. 每个规则数字来自常量或场地数据，测试断言使用同一常量，不在测试里另写一份魔法数。

## File map

| Path | Responsibility | Owner |
|---|---|---|
| `src/logic/snake_sim.gd` | 状态机、`step()`、碰撞、计分、速度 | gameplay-programmer |
| `src/logic/arena.gd` / `arena_loader.gd` | 场地数据与校验 | gameplay-programmer |
| `src/logic/save_store.gd` | 存档读写、版本、回退 | tech-director |
| `src/game/game_controller.gd` | 累加器、输入注册、事件分发 | gameplay-programmer |
| `src/game/snake_view.gd` / `food_view.gd` / `arena_view.gd` | 网格与补间 | technical-artist |
| `src/game/audio_synth.gd` | 运行时 PCM 合成与播放池 | technical-artist |
| `scenes/main.tscn` | 启动入口 | tech-director |
| `scenes/game.tscn` | 场地、相机、HUD 装配 | gameplay-programmer |
| `scenes/ui/*` | 菜单、暂停、结算、设置场景 | game-designer |
| `scripts/ui/*` | UI 意图信号与本地化文本 | game-designer |
| `tests/run_tests.gd` | headless 断言入口 | qa-lead |

## Numbers and tuning

| Value | Default | Range | Unit | Tuned in |
|---|---|---|---|---|
| 目标帧率 | 60 | ≥60 | FPS | 项目设置（只读） |
| 每帧最大逻辑步 | 4 | 1–8 | steps | 帧循环 |
| 逻辑帧上限 | 60 | 30–120 | steps/s | 帧循环 |
| 稳态 draw calls | 80 | ≤120 | calls | 场景与材质 |
| 场景节点上限 | 250 | ≤300 | nodes | 场景 |
| 蛇身最大节数 | 256 | ≤256 | segments | 场地尺寸 |
| 食物最大数量 | 8 | 1–8 | items | 场地 JSON |
| 内存预算 | 256 | ≤512 | MB | 发布检查 |
| 冷启动到主菜单 | 3.0 | ≤5.0 | seconds | 发布检查 |
| 光源数量 | 2 | ≤2 | lights | 场景 |
| 存档写入上限 | 16 | ≤16 | KB | 存档模块 |

_表中预算为提案，发布前用实测替换；见 Open questions。_

## Edge cases

- 一帧卡顿 1 秒：只补 4 步，其余时间丢弃；蛇不会瞬移穿过墙。
- 暂停发生在累加器已有余量时：余量保留，恢复倒计时结束后继续，不丢失半步。
- 窗口最小化：`_process` 停走，累加器不增长；恢复时不补帧。
- 场地 JSON 全部损坏：加载内置 Classic 默认场地，其他模式隐藏，游戏仍可启动。
- 存档目录只读：使用内存设置，退出时提示一次。
- 速度在一步中途变化：步长下一步生效，当前步不变。
- 蛇长达 256 节：仍只渲染可见部分（全部在 16×16 场内），不触发对象池扩容。
- 两个场景同时存在（切换中）：旧场景先释放，避免重复音频与输入。

## Open questions

- 场地注册表是否需要在 1.0 支持每个模式多张地图；若要，`ArenaLoader` 返回结构需扩展；负责人：tech-director。
- 测试是否引入 GUT 等插件，还是继续扩展 `tests/run_tests.gd`；提案不加依赖；负责人：tech-director。
- 程序化几何是否全部在运行时生成，还是允许保存为 `.tres` 网格资源；提案运行时生成，减少仓库二进制；负责人：technical-artist。

## Links

- Related systems: [core-rules.md](core-rules.md)、[game-modes.md](game-modes.md)、[camera-and-presentation.md](camera-and-presentation.md)、[ux-and-persistence.md](ux-and-persistence.md)
- Stories: production/stories/（尚未创建）
- Evidence: production/qa/evidence/（尚未创建）
