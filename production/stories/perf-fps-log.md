---
id: perf-fps-log
status: done
updated: 2026-11-04
---

# Story: 帧率采样与真实 10 秒运行

## Context

Issue: https://github.com/yinhaox/coil-3d/issues/21

`design/release.md` 的性能与包体预算把「1152×648、GL Compatibility、集成显卡，一局全程平均 ≥60 FPS」列为发布门禁；`design/architecture.md` 的 Numbers and tuning 同样以 60 FPS 为目标帧率。目前没有任何可复现的帧率采样：性能只能靠肉眼或外部工具估计，也没有一条命令能稳定跑满固定时长后留下数据。

本 story 增加默认关闭的每帧采样与 `--quit-after` 自动退出，让「真实窗口跑 10 秒并留下数据」成为一条可重复的命令。无参数启动时行为不变：不写文件、不注册采样节点。

## Acceptance

- [x] 启动参数 `--fps-log=<path>`（在 `--` 之后）每帧写一行 `t_ms,frame_ms,fps`；`--quit-after=<seconds>` 到点退出（本条不存在，由本 story 新增）。
- [x] 无参数时不写文件、不改变行为；非法路径不崩溃，打印一行警告。
- [x] `tests/run_tests.gd` 至少 8 条断言：采样行格式、解析器、非法路径、退出计时（`_test_fps_log` 共 20 条）。
- [x] 真实运行 `run_command -- --fps-log=production/qa/evidence/perf-fps-log/fps.log --quit-after=10`，日志至少 300 行（实测 38365 行）。
- [x] 证据 `index.md` 给出：平均 FPS、最小 FPS、p95 帧时间、样本数，以及是否达到 `design/release.md` 的 60 FPS 目标；`Run result: OBSERVED — …`。
- [x] 只改 `src/`、`tests/`、故事与证据；不改导出配置或 CI。

## Out of scope

- 包体测量、导出、压力场景（issue 的 Out of scope）。
- `design/` 文档更新：`design/architecture.md` 的 File map 未列出新文件，属设计漂移，交给 design-doc 工单。
- 采样开销之外的重构；不新增 autoload。

## Risks / not covered

- `src/perf/fps_log.gd` 的 `_process` 每帧格式化一行字符串，违反 `design/architecture.md` 规则 15 的「稳态零分配」；该路径只在显式传 `--fps-log` 时启用，普通运行不创建节点。
- 本机窗口未受 vsync 限制（实测约 3900 FPS），所以本次数据证明 60 FPS 预算余量，不证明 60 Hz 刷新下的逐帧节奏。
- `--quit-after` 只按墙钟计时退出，不区分暂停或窗口失焦。

## Evidence

- `production/qa/evidence/perf-fps-log/index.md` — Run result: OBSERVED — 真实窗口运行 10 秒后自动退出，`fps.log` 38365 行采样，平均 3941.41 FPS、最小 12.68 FPS、p95 帧时间 0.328 ms，达到 ≥60 FPS 目标。
