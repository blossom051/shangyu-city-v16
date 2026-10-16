extends Node

const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	_test_listing_thresholds_and_routes()
	_test_guidance_has_real_commitment()
	_test_innovation_progression_preserves_value()
	_test_audit_creates_meaningful_restriction()
	_test_ai_uses_long_term_operations()
	_test_listed_company_price_truth()
	_test_players_and_ai_trade_each_other()
	print("V154_CAPITAL_MARKET_BALANCE passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start_listed(seed_value := 15490) -> Dictionary:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], seed_value)
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 50000
	player.asset_value = 5000
	player.risk = 20
	player.last_round_income = 260
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	GameState.game_data.round = 16
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "MARKET-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id)
		land.asset_state = "OWNED"
		land.state = "operating"
		land.business_id = business_id
		player.land_ids.append(land_id)
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "financial_office", "state": "operating", "value": 800, "employees": ["", ""]}
	var application := EndlessOperationsSystem.request_ipo(str(player.id), false)
	_assert("满足高门槛后才能进入上市审核", bool(application.get("ok", false)))
	var record: Dictionary = GameState.game_data.ipo_records[str(player.id)]
	record.status = "listed"
	record.listed_round = 19
	GameState.game_data.round = 20
	ListedMarket.initialize_listing(str(player.id), record)
	return player


func _test_listing_thresholds_and_routes() -> void:
	var player := _start_listed()
	var player_id := str(player.id)
	var conservative: Dictionary = GameState.game_data.ipo_records[player_id].duplicate(true)
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15491)
	player = GameState.game_data.players[0] as Dictionary
	player.cash = 50000
	player.asset_value = 5000
	player.risk = 20
	GameState.game_data.round = 16
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "ROUTE-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id); land.asset_state = "OWNED"; land.state = "operating"; land.business_id = business_id
		player.land_ids.append(land_id); player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "state": "operating", "value": 800, "employees": ["", ""]}
	var aggressive_result := EndlessOperationsSystem.request_ipo(str(player.id), true)
	var aggressive: Dictionary = GameState.game_data.ipo_records[str(player.id)]
	_assert("成长上市融资更高但通过率更低", bool(aggressive_result.get("ok", false)) and int(aggressive.funding) > int(conservative.funding) and float(aggressive.approval_chance) < float(conservative.approval_chance))
	_assert("成长上市承担显著更高披露风险", float(aggressive.disclosure_gap) >= float(conservative.disclosure_gap) + 0.20)
	_assert("两条上市路径拥有不同发行价与股权稀释", float(aggressive.issue_price) > float(conservative.issue_price) and float(aggressive.dilution_ratio) > float(conservative.dilution_ratio))
	_assert("成长上市的挂牌波动系数高于稳健上市", float(aggressive.volatility_factor) > float(conservative.volatility_factor))
	var implied_growth_funding := roundi(float(aggressive.offered_shares) * float(aggressive.issue_price) / 10000.0)
	_assert("融资额由发行价与发行股数统一计算", absi(implied_growth_funding - int(aggressive.funding)) <= 1)


func _test_guidance_has_real_commitment() -> void:
	var player := _start_listed(15492)
	var player_id := str(player.id)
	var record: Dictionary = GameState.game_data.ipo_records[player_id]
	var cash_before := int(player.cash)
	var guidance := EndlessOperationsSystem.capital_market_action(player_id, "guidance")
	var target := int(record.get("guidance_target", 0))
	_assert("业绩指引要求增长并收取顾问成本", bool(guidance.get("ok", false)) and target >= roundi(260.0 * 1.18) and int(player.cash) == cash_before - 25)
	player.last_round_income = target
	GameState.game_data.round = 22
	EndlessOperationsSystem.begin_round()
	var confidence_after_success := int(record.market_confidence)
	GameState.game_data.round = 23
	var cooldown := EndlessOperationsSystem.capital_market_action(player_id, "guidance")
	_assert("兑现指引会增信且不能连续刷取", confidence_after_success > 73 and not bool(cooldown.get("ok", false)))
	GameState.game_data.round = 24
	var second := EndlessOperationsSystem.capital_market_action(player_id, "guidance")
	player.last_round_income = 0
	GameState.game_data.round = 26
	EndlessOperationsSystem.begin_round()
	_assert("指引落空会降低信心并增加风险", bool(second.get("ok", false)) and int(record.market_confidence) < confidence_after_success and int(player.risk) >= 30)


func _test_innovation_progression_preserves_value() -> void:
	var player := _start_listed(15493)
	var player_id := str(player.id)
	var record: Dictionary = GameState.game_data.ipo_records[player_id]
	var first := EndlessOperationsSystem.capital_market_action(player_id, "innovation")
	record.innovation_success_chance = 1.0
	GameState.game_data.round = 23
	EndlessOperationsSystem.begin_round()
	_assert("研发成功形成可见的一级长期收益", bool(first.get("ok", false)) and int(record.innovation_level) == 1 and int(record.innovation_income) == EndlessOperationsSystem.IPO_INNOVATION_INCOME_PER_LEVEL)
	var second := EndlessOperationsSystem.capital_market_action(player_id, "innovation")
	record.innovation_success_chance = 0.0
	GameState.game_data.round = 26
	EndlessOperationsSystem.begin_round()
	_assert("后续研发失败不会抹除既有成果", bool(second.get("ok", false)) and int(record.innovation_level) == 1 and int(record.innovation_income) == EndlessOperationsSystem.IPO_INNOVATION_INCOME_PER_LEVEL and int(player.risk) >= 27)
	record.innovation_level = EndlessOperationsSystem.IPO_MAX_INNOVATION_LEVEL
	GameState.game_data.round = 27
	var capped := EndlessOperationsSystem.capital_market_action(player_id, "innovation")
	_assert("研发成长设有三级上限避免无限滚雪球", not bool(capped.get("ok", false)))


func _test_audit_creates_meaningful_restriction() -> void:
	var player := _start_listed(15494)
	var player_id := str(player.id)
	var record: Dictionary = GameState.game_data.ipo_records[player_id]
	record.disclosure_gap = 1.0
	record.market_confidence = 0
	var exposed := false
	for round_number in range(20, 32):
		GameState.game_data.round = round_number
		record.next_audit_round = round_number
		var audit := EndlessOperationsSystem.settle_player(player_id).get("audit", {}) as Dictionary
		if bool(audit.get("exposed", false)):
			exposed = true
			break
	var restriction_round := int(record.get("capital_restriction_until_round", 0))
	var blocked := EndlessOperationsSystem.capital_market_action(player_id, "issuance")
	_assert("披露爆雷会罚款降信并进入监管整改", exposed and int(record.get("audit_strikes", 0)) >= 1 and restriction_round > int(GameState.game_data.round) and int(record.market_confidence) == 0)
	_assert("整改期真实限制增发回购与并购", not bool(blocked.get("ok", false)) and str(blocked.get("message", "")).contains("监管整改"))


func _test_ai_uses_long_term_operations() -> void:
	var player := _start_listed(15495)
	var player_id := str(player.id)
	var record: Dictionary = GameState.game_data.ipo_records[player_id]
	record.integration_level = 3
	record.next_audit_round = 99
	record.market_confidence = 75
	player.cash = 5000
	player.last_round_income = 0
	var innovation_events := AIPlayer.execute_stage_events(player_id, "ipo")
	var innovation_action := str(innovation_events[0].get("action", "")) if not innovation_events.is_empty() else ""
	_assert("AI 会主动投入长期研发而非只做融资", innovation_action == "innovation")
	record.erase("innovation_due_round")
	record.innovation_level = 3
	player.last_round_income = 320
	var guidance_events := AIPlayer.execute_stage_events(player_id, "ipo")
	var guidance_action := str(guidance_events[0].get("action", "")) if not guidance_events.is_empty() else ""
	_assert("AI 会在有兑现能力时发布业绩指引", guidance_action == "guidance")
	_assert("AI 行动阶段包含上市申请与上市后经营", AIPlayer.action_stages().has("ipo"))


func _test_listed_company_price_truth() -> void:
	var player := _start_listed(15496)
	var player_id := str(player.id)
	var record: Dictionary = GameState.game_data.ipo_records[player_id]
	var issue_price := float(record.get("issue_price", 0.0))
	player.last_round_income = 900
	player.risk = 8
	record.market_confidence = 95
	ListedMarket.queue_impulse(player_id, 0.16, "重大经营利好")
	ListedMarket.price_all(21)
	var price_after_good := float(record.get("share_price", 0.0))
	_assert("财团上市后生成独立代码、发行价与走势", not str(record.get("ticker", "")).is_empty() and issue_price > 0.0 and record.get("price_history", []).size() >= 2)
	_assert("盈利、低风险与利好会推动但限制单轮涨幅", price_after_good > issue_price and float(record.get("last_price_change", 0.0)) <= ListedMarket.MAX_EVENT_CHANGE)
	player.last_round_income = -900
	player.risk = 96
	record.market_confidence = 5
	record.disclosure_gap = 0.8
	ListedMarket.queue_impulse(player_id, -0.20, "披露爆雷")
	ListedMarket.price_all(22)
	_assert("亏损、高风险与披露问题会真实压低股价", float(record.get("share_price", 0.0)) < price_after_good and float(record.get("last_price_change", 0.0)) < 0.0)
	_assert("财团挂牌市场快照与成熟证券分离", ListedMarket.snapshot().size() == 1 and not GameState.game_data.stocks.has(str(record.get("ticker", ""))))


func _test_players_and_ai_trade_each_other() -> void:
	GameState.start_match("local", 0, [
		{"company_id": "hengyue", "human": true},
		{"company_id": "qiming", "human": false},
	], 15497)
	var buyer := GameState.game_data.players[0] as Dictionary
	var issuer := GameState.game_data.players[1] as Dictionary
	buyer.cash = 50000
	issuer.cash = 50000
	issuer.asset_value = 5200
	issuer.risk = 18
	issuer.last_round_income = 360
	GameState.game_data.round = 20
	GameState.game_data.ipo_records[str(issuer.id)] = {"status": "listed", "listed_round": 19, "market_confidence": 82, "disclosure_gap": 0.05, "aggressive": false}
	var record := GameState.game_data.ipo_records[str(issuer.id)] as Dictionary
	ListedMarket.initialize_listing(str(issuer.id), record)
	var ticker := str(record.get("ticker", ""))
	var cash_before := int(buyer.cash)
	var buy := ListedMarket.trade(str(buyer.id), str(issuer.id), 1000, true)
	_assert("玩家可按百股整数买入其他玩家或 AI 的挂牌股票", bool(buy.get("ok", false)) and ListedMarket.holding_shares(str(buyer.id), ticker) == 1000 and int(buyer.cash) < cash_before)
	var dividend_before := int(buyer.cash)
	var dividend := ListedMarket.distribute_dividend(str(issuer.id), 500)
	_assert("挂牌公司分红会按真实持股结算给其他玩家", int(dividend.get("recipients", 0)) == 1 and int(buyer.cash) > dividend_before)
	var sell := ListedMarket.trade(str(buyer.id), str(issuer.id), 500, false)
	_assert("玩家可卖出挂牌持仓并实时恢复现金", bool(sell.get("ok", false)) and ListedMarket.holding_shares(str(buyer.id), ticker) == 500)
	buyer.human = false
	buyer.cash = 50000
	buyer.listed_stocks.clear()
	var ai_events := AIPlayer.execute_stage_events(str(buyer.id), "listed_stock")
	_assert("AI 会评估并交易其他财团的挂牌股票", not ai_events.is_empty() and str(ai_events[0].get("action", "")) == "listed_stock")


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
