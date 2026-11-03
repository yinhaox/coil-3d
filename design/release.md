# Design: Release

_1.0 的版本、三平台导出、许可与致谢、已知限制和发布门槛。负责人：release-manager。_

Serves pillar: **再来一局的干净循环**。

## Goals

- 1.0.0 能在三个桌面平台上从同一份工程可重复导出，且每次构建都能追溯到同一个提交。
- 发布包不含任何来源不明或无授权的外部美术、音频或字体。
- 玩家在首次启动的 3 秒内知道这是什么游戏、按什么键玩、如何退出。

## Player experience

下载、解压、双击即开始，不需要安装器或账号。首次启动使用默认设置并创建存档；主菜单页脚显示 `v1.0.0`，制作人员页列出引擎许可与“无外部美术/音频”的说明。窗口默认 1152×648，可缩放；退出后最高分与设置保留。

## Rules

### Version and builds

1. 版本使用语义化版本 `1.0.0`；`project.godot` 的 `application/config/version` 与发布文档、构建文件名三处一致，由技术总监在发布故事中同步。
2. 构建名：`coil-3d-1.0.0-windows-x86_64.zip`、`coil-3d-1.0.0-macos-universal.zip`、`coil-3d-1.0.0-linux-x86_64.zip`；文件名只含小写、数字、点与连字符。
3. 每个平台一个导出预设：`Windows Desktop`、`macOS`、`Linux`；`export_presets.cfg` 由技术总监维护，设计文档只规定目标，不手改该文件。
4. 构建从干净检出开始，先跑 `python scripts/studio.py check` 与 `python scripts/studio.py test`，两者退出码为 0 才允许打包。
5. 发布包内含游戏二进制、`LICENSE`、`CREDITS.md` 与一份 `README.txt`（操作说明、已知限制、存档位置）；不夹带 `.pck` 之外的工程文件。
6. 三个平台的包从同一个提交导出；任一平台失败则整批不发布。
7. 不创建 git tag、不上传商店、不发布公告；这些动作由人类在评审后执行。

### License and credits

8. 代码与设计文档的许可、游戏二进制的最终用户许可由人类决定；本页只列提案：代码 MIT，游戏内容保留所有权利，发布前补齐 `LICENSE` 文件。
9. 必须署名 Godot Engine（MIT 许可）及其版权声明；制作人员页与 `CREDITS.md` 都要有。
10. 不打包第三方字体、贴图、音频；中文优先使用系统字体（[ux-and-persistence.md](ux-and-persistence.md) 的待定项），不随包分发；若最终选择内置字体，须在 `CREDITS.md` 记录许可并更新本页。
11. 若未来引入任何外部资源，必须在 `CREDITS.md` 记录来源、许可与作者，并在同一 PR 更新本页。

### Known limits

12. 仅离线单机；没有在线排行榜、云存档、账号或多人。
13. 仅 `zh_CN` 与 `en` 两种语言；没有配音。
14. 没有背景音乐；只有运行时合成音效。
15. 没有键位重映射、屏幕阅读器支持或移动端构建。
16. 存档只在本机 `user://save.json`；不提供跨设备迁移。
17. 只支持 Godot 4.7 / GL Compatibility；不提供 Vulkan/Forward+ 构建。
18. 同一台机器同时运行两个实例时，后退出者覆盖先退出者的存档；1.0 不实现文件锁。

## Release checklist

| # | Gate | Evidence | Owner |
|---|---|---|---|
| 1 | `check` 退出码 0 | 命令输出日志 | gameplay-programmer |
| 2 | `test` 退出码 0 | 测试日志 | qa-lead |
| 3 | 三平台各启动一次并完成一局 | 每平台截图 + 日志 | qa-lead |
| 4 | 三平台导出包可解压启动 | 构建记录 | release-manager |
| 5 | `project.godot` 版本 = 1.0.0 | 文件行号 | tech-director |
| 6 | 许可与制作人员页可打开 | 截图 | release-manager |
| 7 | 已知限制写入 `README.txt` | 文件路径 | release-manager |
| 8 | 人类批准发布 | 评审记录 | producer |

## Numbers and tuning

| Value | Default | Range | Unit | Tuned in |
|---|---|---|---|---|
| 版本号 | 1.0.0 | SemVer | version | `project.godot`（只读） |
| 导出平台数 | 3 | 3 | platforms | 发布故事 |
| Windows 最低版本 | 10 | 10+ | OS | 发布文档 |
| macOS 最低版本 | 12 | 12+ | OS | 发布文档 |
| Linux 基线 | Ubuntu 22.04 | 22.04+ | OS | 发布文档（以导出模板支持为准） |
| 单平台包体目标 | 80 | ≤120 | MB | 导出预设 |
| 冷启动到主菜单 | 3.0 | ≤5.0 | seconds | 发布检查 |
| 发布阻塞缺陷 | 0 | 0 | issues | 发布检查 |
| 构建可追溯性 | 1 个提交 | 1 | commit | 发布故事 |

_三个平台、版本号与最低系统版本为提案；见 Open questions。_

## Edge cases

- 三个平台中任一导出失败：整批不发布，已成功的包标记为作废。
- `project.godot` 版本与发布文档不一致：发布阻塞，由技术总监修正后重新导出。
- 存档目录不可写：游戏仍可玩，退出时提示一次；不阻止启动。
- 玩家系统语言不是中文或英文：界面回退英文。
- 缺少导出模板：构建失败并报告缺失模板版本，不用旧模板顶替。
- 发布前发现阻塞缺陷：回到 bug-fix 流程，1.0.0 不带着已知崩溃发布。
- 许可文件缺失：发布阻塞，不先用“临时许可”占位。

## Open questions

- 三个平台具体是 Windows/macOS/Linux，还是包含 Android/Web；issue 只写“三平台”，本页按桌面三平台提案；负责人：producer。
- 代码与游戏的最终许可选择（MIT、专有 EULA 或其他）；负责人：producer。
- 1.0 是否收费、定价与商店（Steam/itch.io/自有渠道）；负责人：producer。

## Links

- Related systems: [architecture.md](architecture.md)、[ux-and-persistence.md](ux-and-persistence.md)、[audio.md](audio.md)
- Stories: production/stories/（尚未创建）
- Evidence: production/qa/evidence/（尚未创建）
