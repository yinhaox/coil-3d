# Evidence: core-snake-logic

Run result: N/A — 本 story 只交付无渲染逻辑层与场地 JSON，没有改动场景、`src/main.gd` 或任何渲染代码，屏幕上没有可拍摄的本 story 变化；规则正确性由 headless 测试日志证明。

- `check.log` — `python scripts/studio.py check` 输出：Godot 4.7.2 import OK，改动脚本 `src/logic/snake_session.gd` parse 通过（生成该 log 时另外两个脚本已在上一提交里，工作树中仅此脚本有改动），退出码 0。
- `test.log` — `python scripts/studio.py test` 输出：191 checks passed，0 failed，退出码 0；测试脚本直接加载 `ArenaData`、`SnakeSession` 与场地 JSON，覆盖场地解析与非法输入、四向移动与 180° 拒绝、转向队列、成长/计分/加速与速度上限、撞墙/障碍/自己、队尾格合法、满场与食物无空位、三模式共用逻辑、Time Attack 90 秒注入时钟。
