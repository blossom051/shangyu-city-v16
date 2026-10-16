extends Node

const Cheats = preload("res://scripts/EndlessCheatSystem.gd")
const Businesses = preload("res://scripts/BusinessSystem.gd")
const BattleRules = preload("res://scripts/CardBattleRules.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.suppress_disk_save = true
	_test_standard_mode_isolation()
	_test_endless_money_unlock()
	print("V154_ENDLESS_CHEAT_ISOLATION passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_standard_mode_isolation() -> void:
	GameState.start_match("solo", 12, [{"company_id": "hengyue", "human": true}], 15421)
	var player := GameState.game_data.players[0] as Dictionary
	var player_id := str(player.id)
	var before_cash := int(player.cash)
	var result := Cheats.activate(player_id, "money")
	_assert("普通模式拒绝 money 作弊码", not bool(result.get("ok", false)) and int(player.cash) == before_cash)
	_assert("普通模式西岸仍保持锁定", not bool(Businesses.premium_land_eligibility(player_id).get("ok", false)))
	_assert("普通模式资本市场仍保持锁定", not bool(EndlessOperationsSystem.ipo_eligibility(player_id).get("ok", false)))
	_assert("普通模式保留每回合一次购地和建设限制", Businesses.land_action_limit(player) == 1)


func _test_endless_money_unlock() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15422)
	var player := GameState.game_data.players[0] as Dictionary
	var player_id := str(player.id)
	var before_cash := int(player.cash)
	var wrong := Cheats.activate(player_id, "Moneyx")
	_assert("错误作弊码不会改变状态", not bool(wrong.get("ok", false)) and not bool(player.get("endless_cheat", false)))
	var result := Cheats.activate(player_id, " money ")
	_assert("money 增加 1 亿游戏资金", bool(result.get("ok", false)) and int(player.cash) == before_cash + 10000)
	_assert("money 解锁无限购地建设动作", Cheats.is_active(player_id) and Businesses.land_action_limit(player) == -1 and Businesses.remaining_land_actions(player) == 999999)
	_assert("money 直接满足西岸购买资格", bool(Businesses.premium_land_eligibility(player_id).get("ok", false)))
	_assert("money 直接满足上市申请条件", bool(EndlessOperationsSystem.ipo_eligibility(player_id).get("ok", false)))
	var card := GameConfig.list("cards")[0] as Dictionary
	player.strategy_points = 0
	var payment := BattleRules.spend(player, card)
	_assert("money 解除策略点消耗限制", bool(payment.get("ok", false)) and int(payment.get("cost", -1)) == 0)
	var cash_after_first := int(player.cash)
	var repeated := Cheats.activate(player_id, "money")
	_assert("重复输入不会反复叠加资金", bool(repeated.get("already_active", false)) and int(player.cash) == cash_after_first)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
