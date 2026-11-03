# Evidence: classic-speed-tune

Run result: OBSERVED — `initial.png` 显示改速后游戏仍以默认 `classic-12` 场地正常启动并渲染（1152×648，青色蛇、黄色食物、左上角 `Score: 0`）；速度 8.0/16.0 是时序数值，单帧画面看不出来，由 `test.log` 的四条断言确认（HUD 未显示速度）。

- `check.log` — `python scripts/studio.py check` 的完整输出：import OK，3 个改动脚本逐个解析通过，退出码 0。
- `test.log` — `python scripts/studio.py test` 的完整输出：`PASS: 280 checks passed`，0 failed，退出码 0；包含 `classic-12 starts at 8.0 cells/s`、`classic-12 caps at 16.0 cells/s`、`classic-16 starts at 8.0 cells/s`、`classic-16 caps at 16.0 cells/s`，以及按新步长推导的 `0.2 s at the Classic speed runs exactly one step`。
- `initial.png` — 1152×648，`capture_command` 真实启动默认 `classic-12` 场地：青色蛇头朝东、黄色食物、左上角 `Score: 0`，证明改速后游戏仍能启动并渲染。
- `capture.log` — `python scripts/studio.py capture --out production/qa/evidence/classic-speed-tune/initial.png` 的完整输出；PNG 30556 bytes，退出码 0。
