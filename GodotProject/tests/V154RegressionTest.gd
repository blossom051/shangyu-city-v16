extends Node

const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const StartupDialog = preload("res://scripts/StartupDueDiligenceDialog.gd")
const Talents = preload("res://scripts/TalentSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	_test_startup_confirmation_and_cycle()
	_test_offer_rotation()
	_test_red_portrait_fallback()
	_test_complaint_loss_and_pr_reduction()
	_test_capital_market_operations()
	print("V154_REGRESSION passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start() -> Dictionary:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15429)
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 50000
	player.asset_value = 1600
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	GameState.game_data.round = 2
	GameState.game_data.startup_schedule = [2, 3]
	GameState.game_data.startup_offers = {}
	GameState.game_data.startup_offer_history = []
	return player


func _test_startup_confirmation_and_cycle() -> void:
	var player := _start()
	GameState.game_data.economic_cycle = {"index": 1, "phase": "boom", "name": "上行", "started_round": 2, "ends_round": 6}
	var project: Dictionary = Startups.projects_for_round()[0]
	var cash_before := int(player.cash)
	var dialog := StartupDialog.new()
	dialog.open_for_project(str(player.id), str(project.id))
	_assert("查看创投详情不会直接扣款", int(player.cash) == cash_before)
	var preview := Startups.investment_preview(str(player.id), str(project.id))
	_assert("创投详情展示经济周期修正", str(preview.get("cycle", {}).get("phase", "")) == "boom" and float(preview.get("success_breakdown", {}).get("cycle", 0.0)) > 0.0)
	var result := dialog.confirm_investment()
	_assert("二次确认后才完成投资扣款", bool(result.get("ok", false)) and int(player.cash) < cash_before)
	dialog.free()


func _test_offer_rotation() -> void:
	_start()
	GameState.game_data.economic_cycle = {"index": 1, "phase": "boom", "name": "上行", "started_round": 2, "ends_round": 6}
	var first := Startups.projects_for_round(2)
	GameState.game_data.round = 3
	var second := Startups.projects_for_round(3)
	var first_ids := first.map(func(item: Dictionary) -> String: return str(item.id))
	var repeated := second.filter(func(item: Dictionary) -> bool: return first_ids.has(str(item.id)))
	_assert("上行期每批提供四个创投项目", first.size() == 4)
	_assert("项目池未耗尽前不立即重复", repeated.is_empty())


func _test_red_portrait_fallback() -> void:
	_start()
	var external := VisualAssets.get_talent_portrait("red", "t18")
	_assert("红色人才不再把多人图集作为单人头像", external == null)


func _test_complaint_loss_and_pr_reduction() -> void:
	var player := _start()
	var type := GameConfig.by_id("business_types", "shopping_mall")
	if type.is_empty():
		type = GameConfig.list("business_types")[0]
	var business := {"id": "BC", "employees": ["", ""], "consecutive_loss": 0}
	var raw := Talents.complaint_quote(str(player.id), business, type, 200.0, 0.0)
	business.employees[0] = "t07"
	var reduced := Talents.complaint_quote(str(player.id), business, type, 200.0, 0.0)
	_assert("客诉敏感企业会产生真实投诉损失", bool(raw.get("occurred", false)) and int(raw.get("loss", 0)) > 0)
	_assert("公关人才按卡面比例降低投诉损失", int(reduced.get("loss", 0)) < int(raw.get("loss", 0)) and int(reduced.get("reduction", 0)) > 0)


func _test_capital_market_operations() -> void:
	var player := _start()
	player.asset_value = 5000
	player.risk = 20
	GameState.game_data.round = 16
	for index in range(6):
		var business_id := "IPO%d" % index
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id); land.asset_state = "OWNED"; land.state = "operating"; land.business_id = business_id
		player.land_ids.append(land_id)
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "state": "operating", "value": 800, "employees": ["", ""]}
	var ipo := EndlessOperationsSystem.request_ipo(str(player.id), false)
	GameState.game_data.ipo_records[str(player.id)].status = "listed"
	GameState.game_data.round = 19
	var disclose := EndlessOperationsSystem.capital_market_action(str(player.id), "disclose")
	GameState.game_data.round = 20
	var dividend := EndlessOperationsSystem.capital_market_action(str(player.id), "dividend")
	GameState.game_data.round = 21
	var buyback := EndlessOperationsSystem.capital_market_action(str(player.id), "buyback")
	GameState.game_data.round = 22
	var issuance := EndlessOperationsSystem.capital_market_action(str(player.id), "issuance")
	GameState.game_data.round = 23
	var acquisition := EndlessOperationsSystem.capital_market_action(str(player.id), "acquisition")
	var settlement := EndlessOperationsSystem.settle_player(str(player.id))
	_assert("符合高门槛后可提交上市审核", bool(ipo.get("ok", false)) and str(ipo.get("status", "")) == "preparing")
	_assert("上市后可持续执行披露经营", bool(disclose.get("ok", false)))
	_assert("上市后可执行现金分红", bool(dividend.get("ok", false)))
	_assert("上市后满足冷却可增发融资", bool(issuance.get("ok", false)))
	_assert("上市后可回购股份稳定市场信心", bool(buyback.get("ok", false)))
	_assert("上市后并购存在成功与失败两种真实结果", bool(acquisition.get("ok", false)) and acquisition.get("details", {}).get("changes", {}).has("success_chance") and int(settlement.get("listed_synergy", 0)) in [0, EndlessOperationsSystem.IPO_INTEGRATION_INCOME_PER_LEVEL])


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
