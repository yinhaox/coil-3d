# Evidence: remember-last-mode

Run result: N/A — 纯逻辑与状态，无新的运行时表现

- `check.log` — `python scripts/studio.py check`，退出码 0：`[check] import OK`，改动过的 `save_store.gd` / `main.gd` / `main_menu.gd` / `run_tests.gd` 逐个 `--check-only` 通过，`[check] parsed 5 changed script(s)`。
- `test.log` — `python scripts/studio.py test`，退出码 0：`PASS: 559 checks passed`（基线 555，新增 4 条：默认值、写回、非法值回退、存档往返）。
- `run.log` — `python scripts/studio.py run -- --quit-after=3`，退出码 0：`[run] Godot exited with code 0`，日志无脚本错误。
- 没有新增截图：`last_mode` 只改变存档字段和主菜单打开时的按钮选中态，画面构成与 `production/qa/evidence/menu-mode-select/main-menu.png` 相同；该截图仍然是当前主菜单的真实运行画面。
