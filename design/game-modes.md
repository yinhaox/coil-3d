# Design: Game modes and arena data

_三种模式与 `assets/data/arenas/*.json` 场地格式：同一套规则，不同的场地配置。负责人：game-designer。_

Serves pillar: **一眼读懂的三维空间**、**再来一局的干净循环**。

## Goals

- 用一份场地 JSON 决定一局的地图、食物上限、初始速度和时间上限，代码不按模式分支。
- 让新增模式/场地成为“加一个 JSON 文件 + 校验通过”，而不是改逻辑。
- 三个模式在模式选择页各自有清晰的规则一句话和最高分。

## Player experience

- **Classic**：没有障碍的空场，只有一条食物，速度一路爬升。玩家学习转向和加速。
- **Maze**：场上固定摆放深色高柱，食物同时有两颗；路线被切碎，玩家要在柱子之间规划两步。
- **Time Attack**：90 秒内尽量吃，食物同时三颗、初始速度最快；剩余秒数在顶部收紧，时间到就结算。

三种模式共用同一条蛇、同一套碰撞和计分规则；玩家换模式时不需要重新学习操作。

## Rules

1. **模式即场地**：1.0 中每个模式恰好对应一个场地文件，`mode` 字段决定它出现在哪张模式卡；加载器按 `mode` 建立模式列表，重复的 `mode` 被拒绝。
2. **Classic**：`mode: "classic"`，无障碍，`food_max: 1`，初始速度 6.0 cells/s，无时间上限。
3. **Maze**：`mode: "maze"`，固定障碍至少 8 格，`food_max: 2`，初始速度 5.0 cells/s，无时间上限；障碍与墙一样致命。
4. **Time Attack**：`mode: "time_attack"`，无障碍，`food_max: 3`，初始速度 7.0 cells/s，`time_limit_seconds: 90`；计时使用逻辑时间，暂停时不走。
5. **共用逻辑**：模式不改变移动、转向、碰撞、成长或计分；唯一差异来自场地的尺寸、障碍、食物上限、初始/上限速度和时间上限。
6. **加载**：启动时按文件名字典序读取 `assets/data/arenas/` 下全部 `*.json`，逐个校验；任一文件失败只禁用对应模式卡并在日志中给出行号，其他模式仍可玩。
7. **选择**：模式选择页按 `classic → maze → time_attack` 固定顺序显示；每张卡显示模式名、一句规则、最高分；数据无效的卡显示“场地数据错误”并禁用。
8. **新增场地**：复制一个现有 JSON，改 `id` 与 `mode`，按 schema 校验，启动后即出现对应模式卡；1.0 不允许两个文件共用同一个 `mode`。
9. **坐标**：障碍与起点使用 `[x, z]` 整数格；`x` 向右、`z` 向屏幕下方（世界 +Z）；所有索引从 0 开始。
10. **起始空间**：起点必须在场内，且沿 `direction` 反方向的 3 格（初始长度 - 1）必须为空、非障碍，供蛇身铺开。
11. **不可变性**：场地数据在加载后只读；一局中的障碍和尺寸不会变化。
12. **回退**：缺失目录或全部文件损坏时使用内置的 `classic` 默认场地，并在日志中报告，保证游戏仍能启动。

## Arena JSON schema

```json
{
  "schema_version": 1,
  "id": "classic-16",
  "mode": "classic",
  "size": { "columns": 16, "rows": 16 },
  "obstacles": [],
  "food_max": 1,
  "initial_speed_cells_per_second": 6.0,
  "max_speed_cells_per_second": 14.0,
  "time_limit_seconds": null,
  "start": { "cell": [8, 8], "direction": "east" }
}
```

| Key | Type | Unit / values | Rule |
|---|---|---|---|
| `schema_version` | int | `1` | 不认识的版本拒绝加载 |
| `id` | string | kebab-case | 全局唯一且永久稳定 |
| `mode` | string | `classic` / `maze` / `time_attack` | 1.0 中唯一 |
| `size.columns` / `size.rows` | int | cells, 4–16 | 四面为墙 |
| `obstacles` | array | `[x, z]` cells | 不重复、不压起点、不越界 |
| `food_max` | int | items, 1–8 | 同时存在的食物上限 |
| `initial_speed_cells_per_second` | float | cells/s, 4.0–10.0 | 第 1 步速度 |
| `max_speed_cells_per_second` | float | cells/s, ≥ initial、≤ 20.0 | 加速上限 |
| `time_limit_seconds` | float / null | seconds, 0–600 | 仅 Time Attack 非空 |
| `start.cell` | `[x, z]` | cells | 蛇头起点 |
| `start.direction` | string | `east` / `west` / `north` / `south` | 初始朝向 |

未知键被忽略并记一条警告；缺失键、类型错误、重复 `id`/`mode`、越界障碍都使该文件加载失败。

## Numbers and tuning

| Value | Default | Range | Unit | Tuned in |
|---|---|---|---|---|
| Classic 场宽/高 | 16 / 16 | 4–16 | cells | `classic-16.json` |
| Maze 场宽/高 | 16 / 16 | 4–16 | cells | `maze-01.json` |
| Time Attack 场宽/高 | 16 / 16 | 4–16 | cells | `time-attack-16.json` |
| Classic 食物上限 | 1 | 1–8 | items | 场地 JSON |
| Maze 食物上限 | 2 | 1–8 | items | 场地 JSON |
| Time Attack 食物上限 | 3 | 1–8 | items | 场地 JSON |
| Maze 障碍数 | 16 | 8–64 | cells | 场地 JSON |
| Time Attack 时间上限 | 90 | 30–600 | seconds | 场地 JSON |
| `schema_version` | 1 | 1 | version | 加载器 |

_表中未被 issue 固定的默认值均为提案；见 Open questions。_

## Edge cases

- 两个文件同 `mode`：按文件名字典序，第一个文件胜出，其余被拒绝并记录。
- 障碍覆盖起点或起始 3 格：文件加载失败，模式卡禁用。
- `time_limit_seconds` 出现在非 Time Attack：拒绝，避免规则含糊。
- 场地太小放不下初始长度：加载失败并报告最小尺寸。
- 目录为空：使用内置 Classic 默认场地，其余模式卡隐藏。
- 一局中更换 JSON：已加载的场地不变，下一局重新读取。
- 新增模式未翻译：回退显示 `mode.<id>.name` 的英文键，不崩溃。

## Open questions

- 1.0 是否每个模式只保留一张场地，还是 Maze/Time Attack 需要多张供玩家轮换；负责人：game-designer。
- Maze 障碍布局由设计师手写 JSON 还是在编辑器里可视化生成，哪种更适合后续维护；负责人：technical-artist。
- 1.0 之后是否把场地扩到 16×16 以上，以及届时的节点与渲染预算；负责人：game-designer。

## Links

- Related systems: [core-rules.md](core-rules.md)、[ux-and-persistence.md](ux-and-persistence.md)、[architecture.md](architecture.md)
- Stories: production/stories/（尚未创建）
- Evidence: production/qa/evidence/（尚未创建）
