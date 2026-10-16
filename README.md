# 商域之城：资本版图 V16 · 永续经营版

这是我自己设计制作的《商域之城：资本版图》，一款基于 Godot 4 的中文城市经营与回合策略游戏。你需要在土地竞拍、企业经营、金融投资和人才卡牌之间做取舍，应对竞争与不断变化的经营环境。

我希望把制作过程中积累的实现公开出来，和对游戏设计、经营模拟、Godot 开发感兴趣的朋友一起学习。欢迎你 Fork 项目、改进规则、设计新玩法，再分享自己的版本或提交代码贡献。你不需要先把整个项目读懂，可以从一个感兴趣的小模块开始。

> **普通玩家：[下载 Windows 无背景音乐运行包](https://github.com/blossom051/shangyu-city-v16/releases/tag/v16.0.0-no-music)。** 下载 ZIP，完整解压，双击 `ShangyuCity.exe`，无需安装 Godot。不要把 GitHub 自动生成的 “Source code” 压缩包当成游戏安装包。
>
> 开发者：本仓库公开程序源码，仍不包含完整美术、字体或音频，克隆源码不能直接运行完整游戏。场景和脚本仍引用原项目素材；请阅读 [素材与授权边界](docs/ASSETS.md)。

运行包不附背景歌曲、伴奏或 BTS 录音，保留游戏音效。你可以把自己的合法音乐放入 `music/` 文件夹后重启游戏，详见 [添加音乐说明](docs/MUSIC.md)。

## 本次公开内容

- 普通本机版 V16 的 GDScript、场景结构、主题配置与测试源码。
- 经营、拍卖、卡牌、结算、AI 难度、事件、存档等实现。
- 游戏配置数据，按下方独立的内容授权范围提供。
- 不包含售卖版、授权签发工具、个人存档、编辑器缓存、历史运行包或生成模型权重。

## 阅读入口

可以从这些方向开始参与：调整 AI 决策、设计新的经营事件、补充经济系统测试、改善界面交互，或者使用你自己的原创内容设计新的卡牌与产业。建议先提 Issue 说明想法，再做一个范围清楚的修改。

| 模块 | 文件 |
| --- | --- |
| 工程与自动加载服务 | `GodotProject/project.godot` |
| 游戏状态 | `GodotProject/scripts/GameState.gd` |
| 回合流程 | `GodotProject/scripts/GameFlow.gd`、`TurnDirector.gd` |
| AI 难度与决策 | `GodotProject/scripts/AIDifficultyPolicy.gd`、`AIDecisionEngine.gd` |
| 经营与结算 | `GodotProject/scripts/BusinessSystem.gd`、`TurnSettlement.gd` |
| 卡牌与西岸扩展 | `GodotProject/scripts/CardEngine.gd`、`CardEffectResolver.gd` |
| 多存档 | `GodotProject/scripts/SaveSlotService.gd` |
| 配置数据 | `GodotProject/data/` |
| 回归测试 | `GodotProject/tests/` |

## 开发环境与运行边界

原工程使用 Godot 4.7 系列；原本机版交付记录使用 Godot 4.7.1。这个源码快照没有附带 Godot 或导出模板。

1. 下载源码，阅读目录和模块。
2. 如需运行，先获得合法可用的资源，并按原有 `res://assets/...` 路径补齐，或自行修改引用使用你的资源。仓库不提供原游戏素材下载授权。
3. 使用对应 Godot 版本导入 `GodotProject/project.godot`，检查缺失资源与脚本解析错误，再运行主场景。
4. 原测试包含场景、渲染与素材依赖。在缺失素材的本仓库中，不能将它们视为可直接通过的测试套件。

首批源码检查与 Windows 公开运行包检查分别记录；本次运行包验证见 [运行检查记录](docs/RUNTIME-CHECKS.md)。不把既往游戏测试成绩当成本次验收结果。

## 许可证

项目程序代码按 [MIT License](LICENSE) 发布。允许学习、修改、再分发和商用，需保留版权及许可声明。

MIT 的范围为程序实现（GDScript、shader、场景/主题的程序结构、测试和工程配置），不包括游戏名称、标识、原创美术、音乐以及独立的叙事/展示文案。`GodotProject/data/` 内的原创文案与内容数据保留权利，详见 [CONTENT-LICENSE.md](CONTENT-LICENSE.md)。若要把原游戏内容用于另一款游戏，请先联系作者获得许可。

本仓库不是完整游戏资产的开源许可，也不授予商标使用权。第三方资源应遵循各自原始许可。

## 反馈与贡献

欢迎通过 Issues 反馈代码问题。请附复现步骤、Godot 版本与相关报错，并删除存档中的个人信息。提交程序代码补丁表示愿意按本仓库 MIT 许可贡献；不要提交授权不明的素材、音乐、密钥或售卖资料。

分享项目可以使用 [中文项目介绍](docs/SHARE.md)。欢迎分享你的设计思路，也请保留源码版的运行限制说明。
