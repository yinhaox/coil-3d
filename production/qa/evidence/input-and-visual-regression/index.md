# Evidence: input-and-visual-regression

Run result: OBSERVED — `arena-initial.png` 是 `classic-12` 的启动初始画面（Score 0、蛇、黄色食物）；`visual-diff.log` 记录该截图与基线 `tests/baselines/arena-initial.png` 的差异为 1420 像素 / 0.001902，低于收紧后的默认容差 0.01（1%），退出码 0。

- `arena-initial.png` — 1152×648，`python scripts/studio.py capture --out production/qa/evidence/input-and-visual-regression/arena-initial.png` 的真实启动截图：默认 `classic-12` 场地、Score 0、四格蛇与一颗食物。
- `capture.log` — 上述 capture 命令的完整输出；PNG 写出 30737 字节，退出码 0。
- `visual-diff.log` — `python tests/visual_diff.py --baseline tests/baselines/arena-initial.png --candidate production/qa/evidence/input-and-visual-regression/arena-initial.png`（不传 `--tolerance`，使用 0.01 默认值）的完整输出：`differing pixels: 1420`、`difference ratio: 0.001902`、`tolerance: 0.010000`、`result: PASS`，退出码 0。
- 仍能通过的理由：实际差异比例 0.001902 只有默认容差 0.01 的约 19%，余量 0.008098；差异全部落在 (345,223)–(519,460) 的两颗随机食物落点（基线左上、本次截图下方），没有渲染漂移或布局变化。收紧到 0.01 后同一张截图仍然 PASS，因此不需要重新截图。
- `check.log` — `python scripts/studio.py check` 的完整输出：导入 OK，3 个改动脚本逐个解析通过，退出码 0。
- `test.log` — `python scripts/studio.py test` 的完整输出：`PASS: 313 checks passed`，退出码 0；其中 `_test_real_input_events` 用真实键盘事件（`Input.parse_input_event()` + `Input.flush_buffered_events()`）新增 33 条断言，覆盖左转、同步内反向拒绝、暂停/恢复与结束态输入。
- 差异位置：逐像素统计显示差异全部落在 (345,223)–(519,460) 的矩形内；该矩形正好覆盖基线（左上）与本次截图（下方）两颗随机食物的落点，其余画面像素一致。食物位置由未固定的随机种子决定，所以差异不是 0。
- 基线来源：`tests/baselines/arena-initial.png` 按 issue #17 的要求，从既有证据 `production/qa/evidence/arena-view-3d/initial.png`（30614 字节，同为 1152×648 的 `classic-12` 启动画面）复制而来，只作为像素比对基准，不是本 story 的证据截图。
- Run context: branch `agent/input-visual-regression-8fcf38107b5b`, Godot 4.7.2 GL Compatibility, window 1152×648.
