# 商域之城：资本版图 V16 · 永续经营版

基于 Godot 4 的中文城市经营与回合策略游戏源码。玩法涉及土地竞拍、企业经营、银行借贷、股票投资、人才、卡牌、人机对战与无限经营。

> **当前为源码发布，不包含完整美术、字体、音频或 Windows 游戏包。克隆后不能直接运行完整游戏。** 场景和脚本仍引用原项目素材；缺失资源不是下载损坏。请先阅读 [素材与授权边界](docs/ASSETS.md)。

## 本次公开内容

- 普通本机版 V16 的 GDScript、场景结构、主题配置与测试源码。
- 经营、拍卖、卡牌、结算、AI 难度、事件、存档等实现。
- 游戏配置数据，按下方独立的内容授权范围提供。
- 不包含售卖版、授权签发工具、个人存档、编辑器缓存、历史运行包或生成模型权重。

## 阅读入口

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

本次仅进行了上传文件范围、复制一致性、数据格式及常见敏感信息检查；没有把既往游戏测试成绩当成这个素材不完整快照的运行验收结果。

## 许可证

项目程序代码按 [MIT License](LICENSE) 发布。允许学习、修改、再分发和商用，需保留版权及许可声明。

MIT 的范围为程序实现（GDScript、shader、场景/主题的程序结构、测试和工程配置），不包括游戏名称、标识、原创美术、音乐以及独立的叙事/展示文案。`GodotProject/data/` 内的原创文案与内容数据保留权利，详见 [CONTENT-LICENSE.md](CONTENT-LICENSE.md)。若要把原游戏内容用于另一款游戏，请先联系作者获得许可。

本仓库不是完整游戏资产的开源许可，也不授予商标使用权。第三方资源应遵循各自原始许可。

## 反馈与贡献

欢迎通过 Issues 反馈代码问题。请附复现步骤、Godot 版本与相关报错，并删除存档中的个人信息。提交程序代码补丁表示愿意按本仓库 MIT 许可贡献；不要提交授权不明的素材、音乐、密钥或售卖资料。
