---
id: input-and-visual-regression
status: done
updated: 2026-11-04
---

# Story: 输入事件测试与截图基线比对

## Context

Issue: https://github.com/yinhaox/coil-3d/issues/17

现有回归测试直接调用逻辑层，没有证明“真实键盘事件”能走通输入注册、事件分发与状态切换；截图证据也只靠人眼，没有像素级的回归基线。本 story 增加两样回归能力：

- 真实输入事件驱动的测试：`tests/input_events.gd` 通过 `Input.parse_input_event()` 注入按键并 `Input.flush_buffered_events()`，让测试驱动 `GameController` 的真实事件路径。
- 截图基线比对：`tests/visual_diff.py`（纯标准库）比较基线图与 `capture_command` 新截图，输出差异像素数与比例，超过容差退出 1。

设计来源：

- [design/architecture.md](../../design/architecture.md) 规则 13：`GameController._ready()` 注册 `snake_up`/`snake_down`/`snake_left`/`snake_right`/`snake_pause`。
- [design/core-rules.md](../../design/core-rules.md) 规则 3、10：方向输入进待转队列，`playing ⇄ paused`，恢复先走 1.0 秒倒计时。

## Acceptance

- [x] `tests/input_events.gd`：一个测试辅助，用 `Input.parse_input_event()` 注入按键（按下与抬起），并 `Input.flush_buffered_events()`；支持方向键与动作名。
- [x] `tests/run_tests.gd` 用真实事件驱动断言：按左键后蛇头方向变为左；同一逻辑步内重复按反向键不会 180°；暂停动作能暂停、再按恢复；结束状态下按键不再改变状态。至少 12 条断言（实际新增 33 条）。
- [x] `tests/visual_diff.py`：纯标准库，比较两张 PNG，输出差异像素数与比例，超过阈值退出 1；参数 `--baseline --candidate --tolerance`。
- [x] 提交一张基线 `tests/baselines/arena-initial.png`（就是现有证据里的初始画面），并在证据里记录：用 `capture_command` 重新截一张，`python tests/visual_diff.py --baseline ... --candidate ... --tolerance 0.02` 的差异比例与退出码。
- [x] `check_command` 与 `test_command` 通过；证据 `Run result: OBSERVED — …`（截图 + 差异日志）。

## Out of scope

- CI 工作流改动、性能数据、玩法改动。
- 只改 `tests/`、`src/`（仅当事件注入需要）、故事与证据。

## Notes

- `src/game/game_controller.gd` 只补了事件接线：`_unhandled_input()` 在 `snake_pause` 按下时调用 `SnakeSession.pause()` / `resume()`（这两个方法已存在，规则未改）。暂停菜单、`get_tree().paused` 与失焦自动暂停仍属于后续 UI story。
- `tests/run_tests.gd` 的检查改到第一个 `process_frame` 之后运行，因为 `Input.flush_buffered_events()` 只有在场景树运行后才能把事件派发到 `GameController._unhandled_input()`。
- `tests/visual_diff.py` 只依赖 `zlib`/`struct`；支持非交错 8-bit 的灰度、灰度+Alpha、RGB、RGBA 与调色板 PNG，尺寸不一致按失败处理（退出 1），文件或格式错误退出 2。
- 基线截图与本次候选截图的随机食物位置不同，差异区域只覆盖两处食物落点；其余像素一致。

## Evidence

- `production/qa/evidence/input-and-visual-regression/index.md` — Run result: OBSERVED — 启动初始画面正常；截图与基线差异 1420 像素 / 0.001902，容差 0.02，退出码 0；`test.log` 记录 313 checks passed（含 33 条真实输入事件断言）
- `production/qa/evidence/input-and-visual-regression/arena-initial.png` — `capture_command` 重新截取的 `classic-12` 启动画面。
- `production/qa/evidence/input-and-visual-regression/visual-diff.log` — 基线比对输出与退出码。
