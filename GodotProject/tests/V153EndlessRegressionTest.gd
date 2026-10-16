extends Node

const Businesses = preload("res://scripts/BusinessSystem.gd")
const Stocks = preload("res://scripts/StockSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	_test_fifty_round_cycle()
	_test_stock_liquidation()
	_test_unlimited_land_purchase()
	_test_construction_talent()
	_test_land_recycling()
	_test_finance_cluster_and_ipo()
	_test_discount_card_lot()
	print("V153_ENDLESS_TESTS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start() -> Dictionary:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15329)
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 50000
	player.asset_value = 1000
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	return player


func _test_fifty_round_cycle() -> void:
	_start()
	for round_number in range(1, 51):
		GameState.game_data.round = round_number
		EndlessOperationsSystem.begin_round()
	_assert("50 回合后仍为永续经营", EndlessOperationsSystem.is_enabled() and not EndlessOperationsSystem.is_final_round())
	_assert("经济周期持续轮转", int(GameState.game_data.economic_cycle.get("index", 0)) != 0 or int(GameState.game_data.economic_cycle.get("started_round", 1)) > 1)
	_assert("创投机会持续生成", GameState.game_data.startup_schedule.filter(func(value: Variant) -> bool: return int(value) > 24).size() > 0)
	_assert("AI 始终保有滚动规划期", EndlessOperationsSystem.planning_rounds_left() == 12)


func _test_stock_liquidation() -> void:
	var player := _start()
	var stock_id := str(GameState.game_data.stocks.keys()[0])
	player.stocks[stock_id] = {"shares": 40, "avg": float(GameState.game_data.stocks[stock_id].price)}
	var result := Stocks.liquidate_position(str(player.id), stock_id)
	_assert("旧存档零散股可一键清仓", bool(result.get("ok", false)) and int(player.stocks[stock_id].shares) == 0 and int(result.get("shares", 0)) == 40)


func _test_unlimited_land_purchase() -> void:
	var player := _start()
	for land_id in ["L01", "L02", "L03", "L04", "L05", "L06", "L07", "L08", "L09"]:
		player.actions.land = 0
		var result := Businesses.buy_land(str(player.id), land_id)
		if not bool(result.get("ok", false)):
			break
	_assert("土地总持有数量不再封顶", player.land_ids.size() == 9)


func _test_construction_talent() -> void:
	var player := _start()
	player.actions.land = 0
	Businesses.buy_land(str(player.id), "L11")
	player.actions.build = 0
	var type_id := str(GameConfig.list("business_types")[0].id)
	var built := Businesses.build_business(str(player.id), "L11", type_id)
	var business: Dictionary = GameState.game_data.businesses[str(built.get("data", {}).get("business_id", ""))]
	player.talent_ids.append("t03")
	var before := int(business.remaining_rounds)
	var assigned := Businesses.assign_talent(str(player.id), str(business.id), "t03", 0)
	_assert("建设人才可在施工期入驻并缩短工期", bool(assigned.get("ok", false)) and int(business.remaining_rounds) < before)
	var after := int(business.remaining_rounds)
	Businesses.assign_talent(str(player.id), str(business.id), "t03", 1)
	_assert("同一建设人才不会重复叠加工期", int(business.remaining_rounds) == after)


func _test_land_recycling() -> void:
	var player := _start()
	var land: Dictionary = GameState.game_data.lands["L12"]
	land.owner_id = str(player.id)
	land.asset_state = "OWNED"
	land.state = "operating"
	land.acquired_round = 1
	land.business_id = "B-L12"
	player.land_ids.append("L12")
	player.business_ids.append("B-L12")
	GameState.game_data.businesses["B-L12"] = {"id": "B-L12", "owner_id": str(player.id), "land_id": "L12", "name": "金融办公中心", "type_id": "financial_office", "state": "operating", "operating_since_round": 1, "value": 500, "employees": ["", ""], "mortgaged": false}
	GameState.game_data.round = 5
	var demolition := Businesses.start_demolition(str(player.id), "L12")
	_assert("经营满 3 回合后可拆除重建", bool(demolition.get("ok", false)) and str(GameState.game_data.businesses["B-L12"].state) == "demolishing")
	GameState.game_data.businesses["B-L12"].state = "operating"
	land.state = "operating"
	var before_cash := int(player.cash)
	var sold := Businesses.sell_land_to_bank(str(player.id), "L12")
	if not bool(sold.get("ok", false)):
		printerr("BANK_SALE_RESULT %s" % str(sold))
	_assert("持有满 2 回合可低价售予银行", bool(sold.get("ok", false)) and not player.land_ids.has("L12") and int(player.cash) > before_cash)


func _test_finance_cluster_and_ipo() -> void:
	var player := _start()
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "BF%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id)
		land.asset_state = "OWNED"
		land.state = "operating"
		land.business_id = business_id
		player.land_ids.append(land_id)
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "financial_office", "state": "operating", "value": 300, "employees": ["", ""]}
	var cluster := EndlessOperationsSystem.finance_cluster_bonus(str(player.id))
	_assert("三处金融资产形成协同收益", int(cluster.get("count", 0)) >= 3 and int(cluster.get("cash", 0)) > 0)
	player.asset_value = 5000
	player.risk = 20
	GameState.game_data.round = 16
	var before_cash := int(player.cash)
	var ipo := EndlessOperationsSystem.request_ipo(str(player.id), false)
	_assert("符合高门槛的财团可提交上市审核", bool(ipo.get("ok", false)) and str(ipo.get("status", "")) == "preparing")
	_assert("上市申请不会当场到账", int(player.cash) < before_cash and str(GameState.game_data.ipo_records[str(player.id)].status) == "preparing")


func _test_discount_card_lot() -> void:
	var card := GameConfig.by_id("cards", "f01")
	_assert("折价证券卡为合理整百股数", int(card.get("value", 0)) >= 100 and int(card.get("value", 0)) % 100 == 0)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
