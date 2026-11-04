---
id: audio-and-settings
status: done
updated: 2026-11-04
---

# Story: 运行时合成音效与设置页

## Context

游戏已经能从主菜单完整跑一局，但所有规则事件都没有听觉反馈，玩家不看 HUD 就不知道吃到了、加速了或撞了；
设置页也还不存在，`SaveStore` 里的 `master_volume` / `sfx_volume` 只写不读。

本 story 用 `AudioStreamGenerator` 在运行时合成 5 个 cue（turn / eat / speed_up / crash / ui_click），
把规则事件接到 cue 上，并补一个可从主菜单和暂停菜单进入的设置页：主音量、音效音量、静音，
改动实时作用于 `AudioServer` 的 Master / SFX 总线并写入存档。

设计来源：

- [design/audio.md](../../design/audio.md)
- [design/ux-and-persistence.md](../../design/ux-and-persistence.md)

Issue: https://github.com/yinhaox/coil-3d/issues/26

实现取舍：design/audio.md 提议“启动时生成 PCM 并封装为 `AudioStreamWAV`”，issue 的验收标准明确要求
`AudioStreamGenerator` 运行时合成，因此按 issue 的写法实现；cue 表仍沿用设计里的波形、基频、包络与优先级。
design/architecture.md 的 file map 写的是 `src/game/audio_synth.gd`，issue 指定 `src/audio/audio_director.gd`，
本 story 以 issue 的路径为准。

## Acceptance

- [x] `src/audio/audio_director.gd`：用 `AudioStreamGenerator` 运行时合成 5 个 cue（turn / eat / speed_up / crash / ui_click），参数（时长、波形、基频、包络、最小间隔）放在可测试的表里；不提交任何二进制音频。
- [x] 事件接线：转向成功、吃到食物、速度档提升、撞墙结束、按钮按下各触发一次；同一事件重复触发有最小间隔，不叠爆音。
- [x] 设置页：主音量、音效音量两个滑块（0–100）与静音开关；改动实时作用于 `AudioServer` 的 Master/SFX 总线，并写入 `SaveStore` 的 `master_volume`/`sfx_volume`；`Esc` 返回上一级。
- [x] 0 音量静音但仍正常触发；重启后设置保留。
- [x] `tests/run_tests.gd` 至少 15 条断言：cue 表范围、音量→dB、夹取、静音、设置往返、重复触发间隔、未知 cue 不崩溃。
- [x] 证据：设置页截图、一次 `run_command -- --audio-log --quit-after=6` 的 cue 顺序日志（转向 → 吃 → 加速 → 撞墙），`Run result: OBSERVED — …`。
- [x] `check_command` 与 `test_command` 通过。

## Out of scope

- 背景音乐、外部音频资源、本地化、导出。
- 设计表里 turn / eat / speed_up / crash / ui_click 之外的 cue（`cleared`、`high_score`、`pause`、`count`、`ui_move` 等）。
- 设置页的语言、相机、色盲、字号等其余设置项（只做音量与静音）。
- 音频设备热插拔监听与主总线 `AudioEffectLimiter`；本 story 用每个 cue 的最小间隔与低于 0 dB 的增益避免叠加爆音。

## Evidence

- `production/qa/evidence/audio-and-settings/index.md` — Run result: OBSERVED — 设置页截图（主/音效音量 80、Mute、Back、焦点提示）与 `run_command -- --audio-log --quit-after=6` 的 cue 顺序日志（turn → eat → speed_up → crash）均来自本机真实运行。
- 截图：`settings.png`（1152x648）。
- 日志：`audio-cue.log`（4 条 cue）、`run.log`（退出码 0）、`check.log`（`[check] import OK`）、`test.log`（`PASS: 540 checks passed`）、`capture-settings.log`。
- `tests/run_tests.gd` 新增 92 条断言（总 540）：cue 表范围、音量→dB、夹取、静音仍调度、设置往返、重复触发间隔、未知 cue、事件接线与 cue 顺序。
