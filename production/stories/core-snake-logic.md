---
id: core-snake-logic
status: done
updated: 2026-11-04
---

# Story: Coil 无渲染核心与场地数据

## Context

Coil 3D 需要一套可以完全脱离窗口运行的规则层：网格、蛇身、转向、食物、碰撞、计分与加速，以及
`assets/data/arenas/*.json` 场地数据。三种模式共用同一套规则，差异只来自场地数据。

设计来源：

- [design/core-rules.md](../../design/core-rules.md)
- [design/game-modes.md](../../design/game-modes.md)
- [design/architecture.md](../../design/architecture.md)

本 story 只交付逻辑层与场地数据，不做渲染。

## Acceptance

- [x] `src/logic/arena_data.gd` 解析 `assets/data/arenas/*.json`（尺寸、障碍、食物上限、初始速度、模式），非法输入返回可读错误。
- [x] `src/logic/snake_session.gd`：四向移动、禁止 180° 反向、蛇身队列增长、食物生成（不与蛇身/障碍重叠）、撞墙撞自己结束、计分、速度随分数提升（有上限）。
- [x] 三种模式（Classic / Maze / Time Attack）共用同一逻辑层，仅由场地数据与模式参数区分；Time Attack 的 90 秒结束条件可注入时钟测试。
- [x] `assets/data/arenas/` 至少 4 个场地（Classic 2 个、Maze 1 个、Time Attack 1 个），均可加载并通过校验。
- [x] `tests/run_tests.gd` 至少新增 30 个断言，覆盖上述规则、模式差异、边界（满场、食物无空位、速度上限）。
- [x] `check_command` 与 `test_command` 通过；证据 `Run result: N/A — 纯逻辑，无运行时表现` + 测试日志。
- [x] 不要动 `src/main.gd` 与场景；这个 story 只交付逻辑层与场地数据。

## Out of scope

- 3D 场景、相机、UI、音频、存档。
- `src/main.gd`、`scenes/`、`project.godot`。
- `design/` 文档修改。

## Evidence

- `production/qa/evidence/core-snake-logic/index.md` — Run result: N/A — 纯逻辑，无运行时表现
