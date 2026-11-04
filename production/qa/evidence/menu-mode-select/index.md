# Evidence: menu-mode-select

Run result: OBSERVED — 主菜单 Play 下方出现 Classic / Maze / Time Attack 三个模式入口，Classic 以青色文字高亮为当前模式，Play 仍持有金色焦点框；Maze 场地 HUD 显示 16 根障碍柱与 5.0 cells/s 的初始速度。

- `main-menu.png` — 1152x648 启动画面：标题、副标题、Play（焦点）、一行三个模式按钮（Classic 高亮、Maze / Time Attack 未选中）、How to play / Settings / Quit，页脚 `Arrows / WASD steer — Esc pauses · v0.1.0` 位于面板之外。
- `maze-hud.png` — `--screen=game --arena=maze-01` 直接进入 Maze 场地的 HUD：左上 `Score: 0` / `Length: 4` / `Speed: 5.0 cells/s` / `Time: 0:00`，右上 `Best: 0`，场地上摆着 16 根深色障碍柱。
- `capture-main-menu.log` — `python scripts/studio.py capture --out production/qa/evidence/menu-mode-select/main-menu.png`，退出码 0，`[capture] OK`（34597 字节）。
- `capture-maze-hud.log` — `python scripts/studio.py capture --out production/qa/evidence/menu-mode-select/maze-hud.png -- --screen=game --arena=maze-01`，退出码 0，`[capture] OK`（48958 字节）。
- `check.log` — `python scripts/studio.py check`，退出码 0，`[check] import OK`，`[check] parsed 4 changed script(s)`。
- `test.log` — `python scripts/studio.py test`，退出码 0，`PASS: 555 checks passed`；新增断言为“the main menu shows the three mode entries”“Classic is the highlighted mode by default”“the keyboard focus order runs through the three mode entries”“choosing the Maze entry starts the maze-01 arena”。
- `run.log` — `python scripts/studio.py run -- --quit-after=3`，退出码 0，`[run] Godot exited with code 0`，日志无脚本错误。
