---
id: classic-speed-tune
status: done
updated: 2026-11-04
---

# Story: 提高 Classic 初速与上限（方案 A）

## Context

Issue: https://github.com/yinhaox/coil-3d/issues/15

玩家反馈“后期不够紧张”。在 A（提高基础速度）与 B（增加难度档位）之间，产品决策选择了 A：

- Classic 的初始速度 6.0 → 8.0 cells/s，速度上限 14.0 → 16.0 cells/s。
- 不改逻辑、存档、UI；难度档位（B）不在本 story。
- 速度仍是场地数据（`assets/data/arenas/classic-*.json`），加速公式保持 `min(initial + 0.2 × food_eaten, max)`（[design/core-rules.md](../../design/core-rules.md) 规则 9）。

启动默认取文件名第一个 Classic 场地，即 `classic-12`（`src/game/game_controller.gd:114`），所以两张 Classic 场地都要改。

## Acceptance

- [x] `classic-12.json` 与 `classic-16.json` 的 `initial_speed_cells_per_second` 为 8.0，`max_speed_cells_per_second` 为 16.0。
- [x] `tests/run_tests.gd` 断言两张 Classic 场地的 8.0/16.0；依赖旧 6 cells/s 的步进断言改为按当前步长推导，其余测试不变并通过。
- [x] `check_command` 与 `test_command` 通过；截图确认游戏仍以 `classic-12` 正常启动。
- [x] 设计文档 `design/core-rules.md` 与 `design/game-modes.md` 不在本 story 修改。

## Out of scope

- `src/logic/snake_session.gd` 的加速公式或规则改动。
- HUD 加速度显示、难度档位、存档、菜单（方案 B）。
- Maze（5.0/12.0）与 Time Attack（7.0/14.0）的速度。
- `design/`、`project.godot`、`studio.yaml`。

## Risks / not covered

- design/core-rules.md:27,40-42 与 design/game-modes.md:24,46-47 仍写 Classic 6.0/14.0；本 story 不修改 design/，这处设计漂移交给后续设计工单。
- HUD 不显示速度，单帧截图无法证明 8.0/16.0；数值由 test.log 断言，截图只证明游戏仍能启动。

## Evidence

- `production/qa/evidence/classic-speed-tune/index.md` — Run result: OBSERVED — 改速后游戏仍以默认 `classic-12` 正常启动；速度 8.0/16.0 由 `test.log` 的四条断言确认。
