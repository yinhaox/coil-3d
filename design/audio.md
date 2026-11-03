# Design: Audio

_运行时合成的音效：路线、cue 表、混音与失败回退。负责人：technical-artist。_

Serves pillar: **越吃越快的心跳**。

## Goals

- 每个规则事件都有即时、可区分的听觉反馈，玩家不看 HUD 也能知道吃到了、加速了、撞了。
- 不打包任何音频文件；全部波形在启动时由代码生成，包体与授权成本为零。
- 混音在 8 个并发 cue 下不削波，且在无音频设备时游戏照常可玩。

## Player experience

转向是一声很短的“嗒”，吃食物是向上滑的“叮”，速度跨过整数档时叠一声三音上行；撞墙/撞障碍/撞自己是一声低频闷响加噪声碎裂，结算页出现时如果刷新纪录，补一段四音上行。所有声音都很短，不盖住下一次转向，也没有背景音乐。

## Rules

- **合成方式**：启动时用代码生成 PCM，封装为 `AudioStreamWAV`，44.1 kHz、16-bit、单声道；每个 cue 一个缓存流，不在游戏中实时合成。
- **播放**：8 个 `AudioStreamPlayer` 组成池，非定位播放；池满时按优先级抢占最低优先级、最早开始的实例。
- **总线**：`Master → SFX` 两级；设置页主音量控制 Master，音效音量控制 SFX；没有 Music 总线，1.0 不含音乐。
- **波形**：正弦、三角、方波、白噪声四种基元；每段 cue 用频率扫掠 + 指数包络；首尾各 5 ms 淡入淡出，避免爆音。
- **归一化**：每个 cue 峰值归一化到 −6 dBFS；Master 总线挂 `AudioEffectLimiter`，阈值 −1 dBFS，兜住同帧多个 cue 的叠加。
- **优先级**：`crash`、`high_score` 最高；`eat`、`speed_up` 次之；`turn`、`ui_*` 最低。
- **暂停**：暂停时停止 `turn`/`eat`/`speed_up` 的尾音，允许 `ui_*` 与 `pause`；恢复倒计时每拍一声 `count`。
- **速度提示**：只在速度跨过 +1.0 cells/s 的整数边界时播放 `speed_up`，不是每吃一颗都播。
- **无设备**：AudioServer 没有输出设备时静默继续，不阻塞启动，不重复报错。
- **随机性**：不使用随机音高，保证同一事件每次听感一致；`crash` 的噪声段用固定种子。

## Cue table

| Cue | Event | Waveform | Pitch sweep | Duration | Envelope | Gain | Priority |
|---|---|---|---|---|---|---|---|
| `turn` | 蛇头改变方向 | square | 440 → 520 Hz | 60 ms | 2 ms attack, exp decay | −18 dB | low |
| `eat` | 吃到食物 | sine | 660 → 990 Hz | 120 ms | 5 ms attack, exp decay | −9 dB | mid |
| `speed_up` | 速度跨 +1.0 档 | triangle | 523 → 659 → 784 Hz | 180 ms | 3 音各 60 ms | −12 dB | mid |
| `crash` | 撞墙/障碍/自己 | noise + sine | 110 → 55 Hz | 250 ms | 5 ms attack, 200 ms decay | −6 dB | high |
| `cleared` | 清场 | sine arpeggio | 523 → 784 → 1046 Hz | 300 ms | 3 音各 100 ms | −9 dB | high |
| `ui_move` | 菜单焦点移动 | square | 300 Hz 恒定 | 40 ms | 2 ms attack | −20 dB | low |
| `ui_confirm` | 确认/开始 | sine | 520 → 780 Hz | 90 ms | 5 ms attack | −15 dB | low |
| `ui_back` | 返回 | sine | 520 → 390 Hz | 80 ms | 5 ms attack | −16 dB | low |
| `pause` | 打开暂停 | sine | 440 → 220 Hz | 120 ms | 5 ms attack | −15 dB | low |
| `count` | 倒计时每拍 | sine | 660 Hz 恒定 | 80 ms | 2 ms attack | −15 dB | low |
| `high_score` | 结算刷新纪录 | triangle arpeggio | 523 → 659 → 784 → 1046 Hz | 300 ms | 4 音各 75 ms | −9 dB | high |

## Numbers and tuning

| Value | Default | Range | Unit | Tuned in |
|---|---|---|---|---|
| 采样率 | 44100 | 22050–48000 | Hz | 音频合成器 |
| 位深 | 16 | 16 | bits | 音频合成器 |
| 声道 | 1 | 1–2 | channels | 音频合成器 |
| 播放器池 | 8 | 4–16 | players | 音频合成器 |
| 主音量默认 | 80 | 0–100 | percent | 设置 |
| 音效音量默认 | 80 | 0–100 | percent | 设置 |
| 单 cue 峰值 | −6 | −12–0 | dBFS | cue 表 |
| 总线峰值 | −1 | −3–0 | dBFS | 音频合成器 |
| 最长 cue | 0.30 | ≤0.50 | seconds | cue 表 |
| 淡入/淡出 | 5 | 2–10 | ms | 音频合成器 |
| 速度提示阈值 | 1.0 | 0.5–2.0 | cells/s | 游戏控制器 |

_表中采样率与音量为提案，需一次试听确认；见 Open questions。_

## Edge cases

- 同一帧吃食物并刷新纪录：先 `eat`，结算面板出现时再 `high_score`，不抢占。
- 连续快速吃食物：池中最多 8 个，第 9 个按优先级替换 `ui_*`/`turn`，不替换 `crash`。
- 暂停时正在播放 `crash`：让尾音播完；其他 cue 立即停止。
- 音量为 0：仍生成并调度 cue（逻辑一致），不产生可听输出。
- 音频设备中途拔出：Godot 切到 dummy 驱动，游戏继续，不弹错。
- 倒计时被暂停打断：停止 `count`，恢复时重新从 1.0 秒开始。
- 高优先级 cue 同时到达：`crash` 先于 `cleared`，`high_score` 最后（结算页覆盖）。

## Open questions

- 1.0 是否加入一段程序化环境音乐；issue 只要求 cue，提案不加，作为已知限制；负责人：producer。
- 合成音色偏“电子提示音”，是否符合商业观感需要试听确认；负责人：technical-artist。
- 触屏设备是否需要触觉/震动替代部分听觉反馈；负责人：game-designer。

## Links

- Related systems: [core-rules.md](core-rules.md)、[ux-and-persistence.md](ux-and-persistence.md)、[accessibility.md](accessibility.md)
- Stories: production/stories/（尚未创建）
- Evidence: production/qa/evidence/（尚未创建）
