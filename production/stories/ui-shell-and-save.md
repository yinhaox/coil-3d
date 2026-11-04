---
id: ui-shell-and-save
status: done
updated: 2026-11-04
---

# Story: UI 壳、暂停、结束面板与最佳成绩存档

## Context

核心玩法已经能完整跑一局：3D 场地、蛇、食物、等距相机与逻辑层规则都在。
但玩家启动后直接落进场地，没有主菜单、没有 HUD 数据、没有暂停与结算，最高分也不会跨启动保留。
本 story 补齐玩家从启动到再来一局的完整外壳，并把每模式最高分写入 `user://save.json`。

设计来源：

- [design/ux-and-persistence.md](../../design/ux-and-persistence.md)
- [design/architecture.md](../../design/architecture.md)
- [design/game-modes.md](../../design/game-modes.md)

Issue: https://github.com/yinhaox/coil-3d/issues/24

UI 脚本放在 `src/ui/`：design/architecture.md 的 file map 提议 `scripts/ui/`，但 story-implement 的写入边界
只覆盖 `src/`、`scenes/`、`tests/`，因此 UI 代码落在 `src/ui/` 并保持同样的“只发意图信号”分层。

## Acceptance

- [x] 启动进主菜单：`Play`（当前只有标准 Classic）、`How to play`、`Quit`；键盘可达、焦点可见；`Esc` 返回上一级。
- [x] HUD：分数、蛇长、当前速度（cells/s）、本局时间、最佳分数；数据由信号驱动，不闪烁。
- [x] `Esc` 暂停：`Resume`、`Restart`、`Main menu`；暂停时蛇不前进、不响应转向；恢复后从暂停点继续。
- [x] 结束面板：显示本局分数、最佳分数（破纪录时标注 `New best`）、`Retry`、`Main menu`；键盘可达。
- [x] `src/logic/save_store.gd`：`user://save.json` 保存每模式最佳分数与设置（`master_volume` / `sfx_volume`），
      原子写入；损坏文件备份为 `save.corrupt-<ts>.json` 并回到默认；版本字段与迁移骨架。
- [x] `tests/run_tests.gd` 新增 115 条断言（总 448）：存档往返、损坏恢复、最佳分数只增不减、暂停阻断、结束面板数据、菜单路由。
- [x] 截图：主菜单、HUD、暂停、结束面板、破纪录；`Run result: OBSERVED — …`。
- [x] `check_command` 与 `test_command` 通过。

## Out of scope

- 模式选择器；Play 直接进入标准 Classic，Maze / Time Attack 的入口留给下一张。
- 音频、本地化、触屏与手柄导航、设置页、失焦自动暂停。
- `save.json` 中 `master_volume` / `sfx_volume` 之外的设置键。

## Notes

- Esc 在各层的语义：主菜单无上一级；`How to play` → 主菜单；暂停 → 继续（带 1 秒恢复倒计时，逻辑层规则）；
  结束面板 → 主菜单。
- 结束面板在出现后 0.4 秒内忽略确认输入（design/ux-and-persistence.md 第 6 条），避免结束一局的按键顺手触发 `Retry`。
- `save.json` 由 `JSON.stringify(..., sort_keys = true)` 写出，键顺序稳定；读取时 `save.json` 失败会先保留损坏文件，
  再尝试 `save.bak`，两者都失败才用默认值。
- HUD 时间使用 `m:ss`；截图里的 `0:01` 来自被快进到吃食物时刻的短局，不是轮询值。

## Evidence

- `production/qa/evidence/ui-shell-and-save/index.md` — Run result: OBSERVED — 主菜单、HUD（Score 10 / Length 5 / Speed 8.2 / Time 0:01 / Best 0）、暂停面板、结束面板与 New best 均由本机 `capture_command` 截到。
- 截图：`main-menu.png`、`how-to-play.png`、`hud.png`、`pause.png`、`end-panel.png`、`new-best.png`（1152x648）。
- 日志：`run.log`（退出码 0）、`check.log`（退出码 0）、`test.log`（448 checks passed）、`capture-*.log`。

