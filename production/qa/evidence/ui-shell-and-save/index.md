# Evidence: ui-shell-and-save

Run result: OBSERVED — 启动停在主菜单（Play / How to play / Quit，Play 带金色焦点边框）；Play 进入 Classic 一局，HUD 显示 Score 10、Length 5、Speed 8.2 cells/s、Time 0:01、Best 0；Esc 暂停后场地变暗并保留四角 HUD，面板为 Resume / Restart / Main menu；撞墙后结束面板显示本局 Score 与 Best，破纪录一局额外显示 New best。

- `main-menu.png` — 启动画面：标题、Play / How to play / Quit 三个按钮，Play 获得可见焦点边框，页脚为操作提示。
- `how-to-play.png` — How to play 页：四段规则说明，Back 按钮带焦点；`test.log` 覆盖 Esc 返回主菜单。
- `hud.png` — 进行中的 Classic 一局：左上 Score 10 / Length 5 / Speed 8.2 cells/s / Time 0:01，右上 Best 0；数值来自 `stats_changed` 信号。
- `pause.png` — Esc 暂停：Paused 面板 Resume（焦点）/ Restart / Main menu，场地变暗但四角 HUD 仍可见。
- `end-panel.png` — 撞墙结束：Run over + `Wall hit — run over`，Score 0 / Best 0，Retry（焦点）/ Main menu。
- `new-best.png` — 破纪录结束：Score 10 / Best 10 并显示 New best；上方 HUD 的 Best 同步为 10。
- `run.log` — `python scripts/studio.py run -- --quit-after=3`，退出码 0，启动主菜单后正常退出，无脚本错误。
- `check.log` — `python scripts/studio.py check`，退出码 0，`[check] import OK`，14 个变更脚本解析通过。
- `test.log` — `python scripts/studio.py test`，退出码 0，`PASS: 448 checks passed`。
- `capture-main-menu.log`、`capture-how-to-play.log`、`capture-hud.log`、`capture-pause.log`、`capture-end-panel.log`、`capture-new-best.log` — `python scripts/studio.py capture --out <path> [-- --screen=... --scenario=...]` 的完整输出（目标、命令退出码、PNG 字节数）。
  结束面板与破纪录两张用 `--save-path=user://evidence/<name>/save.json --fresh-save` 从空存档开始，因此 Best 从 0 起算。
