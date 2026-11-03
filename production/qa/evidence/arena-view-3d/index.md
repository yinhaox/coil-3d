# Evidence: arena-view-3d

Run result: OBSERVED — 启动直接进入 `classic-12` 的 3D 场地：地板网格、四面墙、蛇（球头带双眼、逐节变暗的方块身体）与橙色食物全部可见；吃到食物后分数 0→10 且蛇身 4→5 节；转向截图中蛇头停在两格之间、身体分段插值；撞北墙后停止移动并显示一行 `Wall hit — run over`。

- `initial.png` — `python scripts/studio.py capture --out production/qa/evidence/arena-view-3d/initial.png -- --seed=25`：classic-12 开局（12×12 网格、四面墙、4 节青色蛇、1 颗橙色食物），左上角 `Score: 0`。
- `eaten.png` — `python scripts/studio.py capture --out production/qa/evidence/arena-view-3d/eaten.png -- --scenario=eaten --seed=25`：用真实逻辑步导航到第一颗食物后冻结，`Score: 10`，蛇身 5 节，食物已补生。
- `turning.png` — `python scripts/studio.py capture --out production/qa/evidence/arena-view-3d/turning.png -- --scenario=turning --seed=25`：转向已入队并走了一步，表现层停在 0.45 插值处，蛇头位于两格之间、朝向补间中。
- `end-prompt.png` — `python scripts/studio.py capture --out production/qa/evidence/arena-view-3d/end-prompt.png -- --scenario=over --seed=25`：向北撞墙后 `SnakeSession` 进入 OVER，蛇停止移动，底部显示一行 `Wall hit — run over`。
- `maze-obstacles.png` — `python scripts/studio.py capture --out production/qa/evidence/arena-view-3d/maze-obstacles.png -- --arena=maze-01 --seed=25`：Maze 场地的 16 根 2.0 格高障碍柱（橙色顶面）与两颗食物，证明障碍渲染与 `--arena` 选择路径；默认启动仍是第一个 Classic 场地。
- `check.log` — `python scripts/studio.py check` 输出：Godot 4.7.2 import OK，10 个改动脚本 parse 通过，退出码 0。
- `test.log` — `python scripts/studio.py test` 输出：257 checks passed，0 failed，退出码 0；新增检查覆盖格坐标→世界坐标、等距相机角度/正交尺寸/缩放限位/宽高比、SessionDriver 的倒计时与累加器（每帧最多 4 步、暂停与结束不再推进）、蛇身分段插值、转向补间目标与时长、启动场地选择、输入动作注册与游戏场景装配。
