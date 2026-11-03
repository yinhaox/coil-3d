# Evidence: perf-fps-log

Run result: OBSERVED — 真实窗口以 `classic-12` 场地运行 10 秒后由 `--quit-after=10` 自动退出（`run.log`，退出码 0）：`initial.png` 是同一工程的 1152×648 启动画面（Score: 0、青色蛇、黄色食物）；`fps.log` 有 38365 行 `t_ms,frame_ms,fps` 采样，平均 3941.41 FPS、最小 12.68 FPS、p95 帧时间 0.328 ms，达到 `design/release.md` 的 ≥60 FPS 发布门禁。

- `fps.log` — `python scripts/studio.py run -- --fps-log=production/qa/evidence/perf-fps-log/fps.log --quit-after=10` 写出的真实采样：38365 行，`t_ms` 从 62 到 10000（10 秒），每行严格为 `t_ms,frame_ms,fps`。
- `run.log` — 上述 run 命令的完整输出：Godot 4.7.2、OpenGL Compatibility、NVIDIA GeForce RTX 3070 Ti，无 WARNING/ERROR，`[run] Godot exited with code 0`；进程在 10 秒到点退出，没有外部关闭窗口。
- `summary.log` — `"$env:STUDIO_GODOT" --headless --path . -s res://tests/fps_summary.gd -- --log=production/qa/evidence/perf-fps-log/fps.log` 的完整输出：`samples=38365 average_fps=3941.41 min_fps=12.68 p95_frame_ms=0.328`，退出码 0。数字来自 `src/perf/fps_log.gd` 的 `parse_line`/`summarize`，与 `tests/run_tests.gd` 断言的是同一实现。
- 统计口径与补充数字（同一份 `fps.log`）：平均帧时间 0.261 ms、中位帧时间 0.248 ms、最大帧时间 78.896 ms（启动后第一帧，即最小 FPS 12.68 的来源）、38365 帧中只有 2 帧超过 16.667 ms（60 FPS 的单帧预算）。60 FPS 判定：平均 3941.41 FPS ≥ 60，p95 帧时间 0.328 ms 远低于 16.67 ms，目标达成；本机窗口未受 vsync 限制（`run.log` 无 vsync 相关设置，实测约 3900 FPS），所以这组数字证明的是 60 FPS 预算余量，不是 60 Hz 刷新下的逐帧节奏。
- `initial.png` — `python scripts/studio.py capture --out production/qa/evidence/perf-fps-log/initial.png` 的真实启动截图（1152×648，30576 字节）：默认 `classic-12` 场地、左上角 `Score: 0`、四格青色蛇与黄色食物，证明本 story 的工程仍能正常开窗渲染。
- `capture.log` — 上述 capture 命令的完整输出：`[capture] OK: ... (30576 bytes)`，退出码 0。该次运行没有传 `--fps-log`，也没有产生任何采样文件，是无参数路径不写文件的旁证。
- `illegal-path.log` — `python scripts/studio.py run -- --fps-log=Z:/no/such/directory/fps.log --quit-after=2` 的完整输出：只打印一行 `WARNING: fps_log: cannot write 'Z:/no/such/directory/fps.log' (error 7); frame sampling stays off`，随后 `--quit-after=2` 正常退出（退出码 0），`Z:/no/such/directory/fps.log` 不存在；非法路径不崩溃。
- `check.log` — `python scripts/studio.py check` 的完整输出：import OK，6 个改动脚本逐个解析通过（含新增的 `src/perf/fps_log.gd` 与 `tests/fps_summary.gd`），退出码 0。
- `test.log` — `python scripts/studio.py test` 的完整输出：`PASS: 333 checks passed`，退出码 0。其中 `_test_fps_log` 新增 20 条断言，覆盖采样行格式（`123,16.667,60.000`）、解析器（字段数、表头、非法行）、非法路径（`is_logging()` 为 false 且不崩溃）、退出计时（199 ms 不退出、200 ms 退出、0 表示不退出）与无参数（不创建 sampler）。
- Run context: branch `agent/fps-log-sampling-3e95a0ef6d69`，Godot 4.7.2 GL Compatibility，窗口 1152×648，NVIDIA GeForce RTX 3070 Ti（本机）。
