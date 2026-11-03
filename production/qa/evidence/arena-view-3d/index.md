# Evidence: arena-view-3d

Run result: OBSERVED — 启动即见 3D 场地网格、四面墙、蛇（头与身体可区分）、黄色食物与固定等距相机；吃到食物后分数为 10 且蛇身变长；转向中蛇头停在格子之间；撞墙后停止并显示一行 `Wall hit — run over`；Maze 场地显示障碍柱。

- `initial.png` — `capture --out …/initial.png -- --scenario=initial`：默认启动第一个 Classic 场地 `classic-12`，Score 0，地板网格、四面墙、蛇、食物都可见。
- `eaten.png` — `capture --out …/eaten.png -- --scenario=eaten`：Score 10，蛇身比 `initial.png` 更长，食物重新出现在场地另一侧。
- `turning.png` — `capture --out …/turning.png -- --scenario=turning`：蛇头位于格子之间、身体折弯，画面停在转向补间中，不是瞬移。
- `end-prompt.png` — `capture --out …/end-prompt.png -- --scenario=over`：撞墙后停在墙边，屏幕底部显示一行 `Wall hit — run over`。
- `maze-obstacles.png` — `capture --out …/maze-obstacles.png -- --arena=maze-01`：Maze 场地，棕色顶面的障碍柱与场地边界可见。
- `check.log` — `python scripts/studio.py check` 输出：Godot 4.7.2 import OK，工作树无改动的 `.gd` 文件，退出码 0。
- `test.log` — `python scripts/studio.py test` 输出：257 checks passed，0 failed，退出码 0。
- `capture.log` — 五次 `python scripts/studio.py capture` 的完整输出：五张 PNG 均写出，退出码均为 0。
- `run.log` — `python scripts/studio.py run` 输出：Godot 4.7.2 以 GL Compatibility 启动；窗口标题 `Game Studio (DEBUG)` 出现在进程列表后关闭，以便继续采集。

Run context: branch `agent/arena-view-3d-evidence-9d40a6b849e8` at commit `2c34d8d`, 2026-11-04, window 1152x648, engine `Godot 4.7.2.stable.steam.ed1daf0bf` (`STUDIO_GODOT`). `Q`/`E` 旋转与滚轮缩放是交互行为，静帧不覆盖；相机角度与缩放限位由 `test.log` 的断言覆盖。
