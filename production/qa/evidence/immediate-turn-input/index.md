# Evidence: immediate-turn-input

Run result: OBSERVED — `turn-preview.png` 中逻辑步尚未结束（插值 alpha 0.45）时蛇头已朝北转过 0.75 个补间；`initial.png` 与 `turning.png` 显示正常启动与既有转向补间，测试日志记录输入当帧接受与步进时序断言。

- `initial.png` — 1152×648，真实窗口启动即见的 `classic-12` 场地；蛇头朝东、双眼朝屏幕右下，作为转向前的朝向基准。
- `turn-preview.png` — 1152×648，`--scenario=turn-preview`：倒计时后走两步，然后调用一次已接受的 `NORTH` 转向并在逻辑步进行到 alpha 0.45 时冻结。蛇头已朝北转过 0.45 × (1/6) s ÷ 0.10 s = 0.75 个补间（约 67.5°），双眼转到背向相机一侧，蛇身仍停在向东的这一步上，证明蛇头在下一步开始前就已响应。
- `turning.png` — 1152×648，`--scenario=turning` 回归对照：转向由逻辑步消费后仍以同一条 0.10 s 补间播放，并在 50% 处冻结。
- `check.log` — `python scripts/studio.py check` 的完整输出；导入 OK，4 个改动脚本逐个解析通过。
- `test.log` — `python scripts/studio.py test` 的完整输出；`PASS: 278 checks passed`，包含中途按键接受、1 个 60 Hz 帧的偏航进度、0.10 s 补间与步进时序断言。
- `run.log` — `python scripts/studio.py run --capture production/qa/evidence/immediate-turn-input/initial.png` 的完整输出；真实窗口启动，Godot 退出码 0。
- `capture-turn-preview.log` — `python scripts/studio.py capture --out production/qa/evidence/immediate-turn-input/turn-preview.png -- --scenario=turn-preview` 的完整输出。
- `capture-turning.log` — `python scripts/studio.py capture --out production/qa/evidence/immediate-turn-input/turning.png -- --scenario=turning` 的完整输出。
