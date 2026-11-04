# Evidence: audio-and-settings

Run result: OBSERVED — 设置页显示 `Master volume` / `SFX volume` 两个 80 滑块、`Mute` 开关与 `Back` 按钮，焦点提示为 `Master volume`；同一次 `run_command -- --audio-log --quit-after=6` 的 cue 日志按 `turn`、`eat`、`speed_up`、`crash` 顺序记录了 4 个事件。

- `settings.png` — `--screen=settings` 启动的设置页截图（1152x648）：标题 Settings、Master volume / SFX volume 两个 0–100 滑块（均停在 80）、Mute 开关、Back 按钮，Accent 色焦点提示为 Master volume；空格播放一次，无脚本错误。
- `audio-cue.log` — `python scripts/studio.py run -- --audio-log --quit-after=6` 在 `user://audio_cue.log` 写出的 cue 顺序：`turn` → `eat` → `speed_up` → `crash`，分别由转向成功、吃到食物、速度跨过 +1.0 档、撞墙结束触发。
- `run.log` — 上面同一条 `run_command` 的完整输出，退出码 0，没有脚本错误或遗留对象告警。
- `capture-settings.log` — `python scripts/studio.py capture --out production/qa/evidence/audio-and-settings/settings.png -- --screen=settings --save-path=user://evidence/audio-and-settings/save.json --fresh-save` 的完整输出（25114 bytes，PNG 校验通过）。
- `check.log` — `python scripts/studio.py check`，退出码 0，`[check] import OK`，9 个变更脚本解析通过。
- `test.log` — `python scripts/studio.py test`，退出码 0，`PASS: 540 checks passed`；其中音频/设置新增 92 条断言覆盖 cue 表范围、音量→dB、夹取、静音仍触发、设置往返、重复触发间隔、未知 cue 与事件接线。
