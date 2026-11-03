---
id: arena-view-3d
status: done
updated: 2026-11-04
---

# Story: 3D 场地、蛇与等距相机

## Context

逻辑层（`snake_session.gd`、`arena_data.gd`）已经能在 headless 下跑完整一局，但玩家还看不到任何画面。
本 story 是第一个“能看到画面”的切片：把核心逻辑接到 3D 场景，渲染场地、蛇、食物与等距相机，
并把转向、吃食物、死亡变成可读的表现。

设计来源：

- [design/camera-and-presentation.md](../../design/camera-and-presentation.md)
- [design/architecture.md](../../design/architecture.md)
- [design/core-rules.md](../../design/core-rules.md)

Issue: https://github.com/yinhaox/coil-3d/issues/7

实现前用 subagent 按 `.dsh/agents/tech-director.md` 做了一次角色复核，结论摘要写在 PR 正文。

## Acceptance

- [x] 启动进入 `assets/data/arenas/` 的第一个 Classic 场地，3D 地板网格、四面墙、障碍、蛇（头与身体可区分）、食物（形状区别于蛇身）都可见。
- [x] 蛇按逻辑层速度自动前进；方向键/WASD 转向；转向被补间（0.10 秒，快于 0.10 秒的步长取步长）且在格子间平滑，不瞬移。
- [x] 相机为等距视角：`Q`/`E` 旋转 90°，滚轮缩放有上下限（整场可见尺寸到其 2 倍）；相机始终能看到整个场地（正交尺寸同时按垂直投影与“水平投影 ÷ 宽高比”取大值，窗口缩放时重算）。
- [x] 吃到食物时蛇变长、分数增加；撞墙或撞自己时停止前进并显示一行结束提示（完整结束面板留给 UI story）。
- [x] `tests/run_tests.gd` 新增 66 个断言（总 257），覆盖格坐标→世界坐标、相机角度/缩放限位、蛇身分段位置、转向补间目标、结束状态不再推进等。
- [x] 截图证据：初始场地、吃到食物后、转向中、撞墙结束提示、Maze 障碍；`Run result: OBSERVED — …`。
- [x] 使用 subagent 做了一次 tech-director 角色复核（逻辑层/场景层边界、每帧更新与计时器、相机跟随），结论摘要写进 PR 正文。
- [x] `check_command` 与 `test_command` 通过。

## Out of scope

- UI 菜单、存档、音频、皮肤、触屏。
- 完整结束面板、暂停菜单、模式选择页（留给后续 UI story）。
- 跟随相机模式与设置页；本 story 只交付固定等距相机。
- 假阴影、死亡变暗与减少动态、障碍顶面十字亮纹（设计提案，留给表现打磨 story）。

## Notes

- `Q`/`E` 的四个 90° 固定机位来自 issue 验收标准，是对 design/camera-and-presentation.md 第 19 行
  “固定视角，不允许玩家自由旋转”的补充解释：只有四档离散朝向，没有连续旋转。该补充由 tech-director 记录。
- 转向补间取 issue 的 0.10 秒（设计文档写 0.08 秒，属同一 0.03–0.15 秒区间；issue 的 0.1–0.15 秒优先）。
- 方向键按世界轴映射（W = north = -Z），与 design/core-rules.md 第 21 行的提案一致，待试玩确认。

## Evidence

- `production/qa/evidence/arena-view-3d/index.md` — Run result: OBSERVED — 启动即见 3D 场地/蛇/食物/等距相机，吃到食物后分数 10 且蛇身变长，撞墙后停止并显示一行结束提示
