# Evidence: menu-version-footer

Run result: OBSERVED — 主菜单页脚在操作提示后显示 `v0.1.0`（读取 `project.godot` 的 `application/config/version`），Play 仍带金色焦点边框，按钮焦点顺序未变。

- `main-menu.png` — 1152x648 启动画面：页脚文本为 `Arrows / WASD steer — Esc pauses · v0.1.0`，Play 获得可见焦点。
- `run.log` — `python scripts/studio.py run -- --quit-after=3`，退出码 0，`[run] Godot exited with code 0`，无脚本错误。
- `check.log` — `python scripts/studio.py check`，退出码 0，`[check] import OK`，2 个变更脚本解析通过。
- `test.log` — `python scripts/studio.py test`，退出码 0，`PASS: 542 checks passed`，含新增的版本非空与页脚包含版本两条断言。
- `capture-main-menu.log` — `python scripts/studio.py capture --out production/qa/evidence/menu-version-footer/main-menu.png`，退出码 0，PNG 29000 字节。
