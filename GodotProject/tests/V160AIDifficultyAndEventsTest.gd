extends Node

const Difficulty = preload("res://scripts/AIDifficultyPolicy.gd")
const Decisions = preload("res://scripts/AIDecisionEngine.gd")
const AI = preload("res://scripts/AIPlayer.gd")
const News = preload("res://scripts/NewsSystem.gd")
const Events = preload("res://scripts/RandomEventSystem.gd")
const BusinessFactory = preload("res://scripts/BusinessInstance.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")

var passed := 0
var failed := 0

func _ready() -> void:
	GameState.suppress_disk_save = true
	GameFlow.suppress_background_preload_for_tests = true
	_test_difficulty()
	_test_mode_ui()
	_test_news_and_settlement()
	_test_endless_events()
	_test_financial_crisis()
	_test_cards()
	print("V160_AI_EVENTS passed=%d failed=%d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _start(level: String = "standard") -> void:
	GameState.start_match("ai", 0, [{"company_id":"hengyue","human":true}, {"company_id":"qinghe","human":false}], 160926, level)
	GameState.game_data.round = 2

func _test_difficulty() -> void:
	var cash_by_level := {}
	for level in ["casual", "standard", "hard"]:
		_start(level)
		cash_by_level[level] = int(GameState.player("p2").cash)
		_check("难度写入新局 %s" % level, Difficulty.current() == level)
	_check("三档 AI 起始资源一致", cash_by_level.casual == cash_by_level.standard and cash_by_level.standard == cash_by_level.hard)
	var candidate := {"score": 50.0, "breakdown": {"expected_return": 80.0, "target_threat": 20.0, "cash_safety": 10.0}}
	_start("standard")
	var standard_score := Difficulty.score(candidate, "p2")
	_start("hard")
	_check("困难档提高真实经营收益权重", Difficulty.score(candidate, "p2") > standard_score + 20.0)
	var hard_choice := Decisions._best([{"action":"buy","score":80.0,"breakdown":{"expected_return":0.0},"land_id":"L01"}, {"action":"buy","score":70.0,"breakdown":{"expected_return":80.0},"land_id":"L02"}], "无候选", GameState.player("p2"))
	_start("standard")
	var standard_choice := Decisions._best([{"action":"buy","score":80.0,"breakdown":{"expected_return":0.0},"land_id":"L01"}, {"action":"buy","score":70.0,"breakdown":{"expected_return":80.0},"land_id":"L02"}], "无候选", GameState.player("p2"))
	_check("同局面标准与困难选出不同地块", str(standard_choice.get("land_id", "")) == "L01" and str(hard_choice.get("land_id", "")) == "L02")
	_start("casual")
	var skipped := 0
	for round_number in range(1, 51):
		GameState.game_data.round = round_number
		if Difficulty.should_pass("p2", "land"):
			skipped += 1
	_check("休闲档实际减少部分主动行动", skipped >= 5 and skipped <= 20)
	var saved := GameState.snapshot()
	var restored := GameState.restore_snapshot(saved)
	_check("选定难度存档后恢复", bool(restored.get("ok", false)) and Difficulty.current() == "casual")
	saved.erase("ai_difficulty")
	GameState.restore_snapshot(saved)
	_check("旧存档默认标准难度", Difficulty.current() == "standard")

func _test_mode_ui() -> void:
	var mode_scene := load("res://scenes/ModeSelect.tscn") as PackedScene
	var screen := mode_scene.instantiate()
	add_child(screen)
	screen.call("_set_mode", "ai")
	var chooser := screen.get_node("Content/Config/AIDifficultyChooser") as Control
	_check("人机模式显示三档难度", chooser.visible and chooser.get_node("Choices").get_child_count() == 3)
	var hard_button := chooser.get_node("Choices/hard") as Button
	hard_button.pressed.emit()
	_check("点击困难档更新配置", str(screen.get("ai_difficulty")) == "hard")
	GameFlow.configure("ai", 0, 4, str(screen.get("ai_difficulty")))
	_check("模式配置将难度传到开局数据", str(GameFlow.setup.get("ai_difficulty", "")) == "hard")
	screen.call("_set_mode", "multi")
	_check("本地多人不显示 AI 难度选项", not chooser.visible)
	screen.queue_free()

func _attach_business(business_id: String, type_id: String, land_id: String) -> void:
	var land: Dictionary = GameState.game_data.lands[land_id]
	land.owner_id = "p1"
	land.state = "operating"
	land.asset_state = "OWNED"
	land.business_id = business_id
	GameState.player("p1").land_ids.append(land_id)
	var business := BusinessFactory.create(business_id, "p1", land_id, GameConfig.by_id("business_types", type_id))
	business.state = "operating"
	business.remaining_rounds = 0
	GameState.game_data.businesses[business_id] = business
	GameState.player("p1").business_ids.append(business_id)

func _scenario_net(with_news: bool) -> Dictionary:
	_start()
	GameState.player("p1").cash = 5000
	_attach_business("B001", "restaurant", "L10")
	_attach_business("B002", "clinic", "L05")
	if with_news:
		var event: Dictionary = GameConfig.by_id("news_events", "n10").duplicate(true)
		event.actual_direction = -1
		event.actual_strength = 0.09
		var affected := News.apply_business_news(event)
		_check("食品危机仅命中已建餐饮企业", affected == ["B001"])
	var report := Settlement.settle_round()
	_check("回合结算产生报告", not report.is_empty())
	return {"restaurant": int(GameState.game_data.businesses.B001.last_net), "clinic": int(GameState.game_data.businesses.B002.last_net)}

func _test_news_and_settlement() -> void:
	var baseline := _scenario_net(false)
	var crisis := _scenario_net(true)
	_check("食品危机真实降低餐饮回合净收入", int(crisis.restaurant) < int(baseline.restaurant))
	_check("食品危机不波及医疗企业", int(crisis.clinic) == int(baseline.clinic))
	_start()
	_attach_business("B001", "restaurant", "L10")
	var reversed_news := {"id":"test_reversal", "tags":["消费"], "direction":1, "actual_direction":-1, "actual_strength":0.1}
	News.apply_business_news(reversed_news)
	_check("低可信新闻反转后企业收入方向一致", GameState.game_data.businesses.B001.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "income_multiplier" and float(effect.get("value", 1.0)) < 1.0))
	_start()
	_attach_business("B001", "restaurant", "L10")
	var generated := News.generate_round()
	_check("有已建企业时新闻命中至少一家企业", generated.any(func(item: Dictionary) -> bool: return item.get("affected_business_ids", []).has("B001")))

func _test_endless_events() -> void:
	_start()
	_attach_business("B001", "restaurant", "L10")
	var forced := Events.generate_round(["re11"])
	var receipt: Dictionary = GameState.game_data.active_events[0].get("impact_receipt", {}) if not forced.is_empty() else {}
	_check("永续食品事件命中已建企业并生成回执", not forced.is_empty() and receipt.get("player_outcomes", []).any(func(item: Dictionary) -> bool: return item.get("asset_ids", []).has("B001")))
	_check("食品事件持续影响收入和成本", GameState.game_data.businesses.B001.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "income_multiplier" and int(effect.get("duration", 0)) == 3) and GameState.game_data.businesses.B001.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "cost_multiplier"))
	_check("新增事件契约完整", bool(Events.validate_event_contracts().get("ok", false)))
	_start()
	var distinct := {}
	var all_multiple := true
	for round_number in range(1, 21):
		GameState.game_data.round = round_number
		var generated := Events.generate_round()
		all_multiple = all_multiple and generated.size() >= 2
		for event: Dictionary in generated:
			distinct[str(event.id)] = true
	_check("无限模式每回合至少两个随机事件", all_multiple)
	_check("20回合可遇到多种不同事件", distinct.size() >= 12)

func _test_financial_crisis() -> void:
	_start()
	GameState.game_data.round = 8
	GameState.player("p1").company_id = "qiming"
	GameState.player("p1").cash = 0
	_attach_business("B001", "financial_office", "L10")
	_attach_business("B002", "financial_office", "L11")
	_attach_business("B003", "financial_office", "L12")
	_attach_business("B004", "financial_office", "L13")
	Events.generate_round(["re23"])
	var report := Settlement.settle_round()
	var player := GameState.player("p1")
	_check("金融危机可造成真实企业亏损", int(GameState.game_data.businesses.B001.last_net) < 0)
	_check("无现金偿付亏损转为债务和风险", int(player.get("debt", 0)) > 0 and int(player.get("risk", 0)) > 0 and not report.is_empty())

func _test_cards() -> void:
	var west: Array = GameConfig.list("cards").filter(func(card: Dictionary) -> bool: return str(card.get("series", "")) == "west_bank")
	_check("西岸42张卡均保留", west.size() == 42)
	_check("西岸卡效果文案精简且保留数字", west.all(func(card: Dictionary) -> bool: return str(card.get("description", "")).length() <= 40 and str(card.get("description", "")).length() > 2))

func _check(label: String, okay: bool) -> void:
	if okay:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		printerr("FAIL ", label)
