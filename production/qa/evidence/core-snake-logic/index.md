# Evidence: core-snake-logic

Run result: N/A — 本 story 只交付无渲染逻辑层与场地 JSON，没有改动场景、`src/main.gd` 或任何渲染代码，屏幕上没有可拍摄的本 story 变化；规则正确性由 headless 测试日志证明。

- `check.log` — `python scripts/studio.py check` 输出：Godot 4.7.2 import OK，`tests/run_tests.gd`、`src/logic/arena_data.gd`、`src/logic/snake_session.gd` 三个改动脚本 parse 通过，退出码 0。
- `test.log` — `python scripts/studio.py test` 输出：191 checks passed，0 failed，退出码 0。覆盖场地解析与非法输入、四向移动与 180° 拒绝、转向队列、成长/计分/加速与速度上限、撞墙/障碍/自己、队尾格合法、满场与食物无空位、三模式共用逻辑、Time Attack 90 秒注入时钟。
