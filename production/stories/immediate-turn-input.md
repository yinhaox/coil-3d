---
id: immediate-turn-input
status: done
updated: 2026-11-04
---

# Story: 转向即时响应（不改步进时序）

## Context

Issue: https://github.com/yinhaox/coil-3d/issues/11

玩家按方向键后，弯道要“立刻”有反应；但 `src/logic/` 的固定步进时序和待转队列规则不能改，也不引入输入队列或缓冲。

设计来源：

- [design/architecture.md](../../design/architecture.md) — 第 15 行要求“按方向键的同一帧蛇头就转向”，第 40 行要求“输入只入待转队列，不直接改蛇方向；每个逻辑步消费一个有效转向”。
- [design/core-rules.md](../../design/core-rules.md) — 规则 3、4：方向输入进入长度 2 的待转队列，逻辑按固定步长推进。
- [design/camera-and-presentation.md](../../design/camera-and-presentation.md) — 第 28、49、57 行：蛇头转向补间 0.08 s（区间 0.03–0.15 s），步长更短时取步长。

### “零延迟”与“不改时序”的取舍

两者可以同时成立的唯一读法是：**输入接受与可见的蛇头转向是零延迟的，格子推进仍按固定步长。**

- 输入在事件帧就进入逻辑待转队列（`SnakeSession.turn()` 当帧返回 true），不需要等到下一步。
- 蛇头偏航补间在同一个输入事件里从当前朝向开始，1 个 60 Hz 帧后已有可见转角；不再等到下一个逻辑步才起转。
- 格子位置只在 `step()` 时推进。若要让蛇身在本帧就换格，就必须提前调用 `step()`，那正是 issue 禁止的时序改动；因此“零延迟”按“感知”（输入接受 + 蛇头起转）定义，而不是按“本帧换格”定义。

## Acceptance

可测参数与判据（测试见 `tests/run_tests.gd`，证据见 `production/qa/evidence/immediate-turn-input/`）：

- [x] 输入接受延迟 = 0 帧：一步进行中（累加器 < `step_duration`）按方向键，`SnakeSession.turn()` 当帧返回 true；`direction()` 在 `step()` 之前保持旧值，下一次 `step()` 沿新方向移动。
- [x] 可见转向延迟 = 1 个 60 Hz 帧：同一输入事件内 `SnakeView.preview_turn()` 开始补间（进度 0），`advance_turn(1.0/60.0)` 后进度 = 0.0167 / 0.10 ≈ 1/6，无需等待逻辑步。
- [x] 逻辑时序不变：`SessionDriver` 仍只在累加器 ≥ `step_duration` 时调用 `step()`；相同输入序列下每步落点与改动前一致（`_test_turn_queue`、`_test_snake_start_and_movement` 保持通过，另加中途输入断言）。
- [x] 转弯补间不变慢：`SnakeView.TURN_TWEEN_SECONDS` 仍为 0.10 s，步长更短时仍取 `min(0.10, step_duration)`。
- [x] 下一步消费该转向时蛇头不回跳、不重新计时：预览方向与 `step()` 消费的方向一致时沿用同一条补间；预览只在逻辑接受转向后开始，第二次快速输入不会覆盖下一步的转向预览。
- [x] 证据：`capture_command` 截图显示“逻辑步尚未结束（插值 alpha 0.45）、蛇头已朝新方向转过 0.75 个补间”；`test.log` 记录上述数值与断言。

## Out of scope

- `src/logic/snake_session.gd` 的任何时序或规则改动（待转队列长度、180° 拒绝、每步消费一次转向、固定步长）。
- 新增输入队列、输入缓冲、输入预测或提前 `step()`。
- 触屏、手柄输入；暂停/恢复 UI；相机行为。
- `project.godot`、`design/`、`studio.yaml`。

## Notes

- 实现只动表现层：`GameController._unhandled_input()` 在 `SnakeSession.turn()` 接受后调用 `SnakeView.preview_turn()`，同帧从当前朝向开始 0.10 s 补间；`SnakeView.apply_step()` 在逻辑步消费同一方向时沿用这条补间，不回跳、不重新计时。
- `SnakeSession`、`SessionDriver` 未改。方向仍只进入待转队列，格子仍只在 `step()` 时推进，因此“零延迟”按输入接受（0 帧）与蛇头起转（1 帧）衡量，而不是本帧换格。
- 预览只针对下一步会消费的那个转向；同一步内第二次按键仍按规则进入待转队列，但不覆盖已开始的蛇头预览（`_test_turn_preview` 断言）。
- 截图来自 `--scenario=turn-preview` 的真实启动运行：脚本用真实 `SnakeSession.turn()` 与 `SnakeView.preview_turn()` 构造输入帧，再冻结插值与补间，未伪造渲染。

## Evidence

- `production/qa/evidence/immediate-turn-input/index.md` — Run result: OBSERVED — 逻辑步 alpha 0.45 时蛇头已朝新方向转过 0.75 个 0.10 s 补间，测试日志记录输入当帧接受与步进时序断言
- 截图：`initial.png`、`turn-preview.png`、`turning.png`（均来自本机 `capture_command`，1152×648）
- 日志：`check.log`（退出码 0）、`test.log`（278 checks passed）、`run.log`（真实窗口退出码 0）、`capture-turn-preview.log`、`capture-turning.log`
