class_name AIPlayer
extends RefCounted

const Decisions = preload("res://scripts/AIDecisionEngine.gd")
const Difficulty = preload("res://scripts/AIDifficultyPolicy.gd")

const Businesses = preload("res://scripts/BusinessSystem.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const Cards = preload("res://scripts/CardEngine.gd")
const Stocks = preload("res://scripts/StockSystem.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")

static func action_stages() -> Array[String]:
	return ["round_card", "asset_recycle", "land", "build", "talent", "discard", "card", "stock", "listed_stock", "loan", "startup", "ipo", "recovery"]


static func take_turn(player_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for stage: String in action_stages():
		events.append_array(execute_stage_events(player_id, stage))
	return events


static func execute_stage_events(player_id: String, stage: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var maximum_attempts: = 2 if stage in ["card", "round_card"] else 1
	for _attempt in range(maximum_attempts):
		var event: = _execute_once(player_id, stage)
		if event.is_empty():
			break
		events.append(event)
	return events


static func _execute_once(player_id: String, stage: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {}
	if Difficulty.should_pass(player_id, stage):
		return {}
	var before_cash: = int(player.cash)
	if stage == "asset_recycle":
		if not EndlessOperationsSystem.is_enabled():
			return {}
		if int(player.cash) < 90:
			for land_id: String in player.get("land_ids", []):
				var sale := Businesses.sell_land_to_bank(player_id, land_id)
				if bool(sale.get("ok", false)):
					return _event(player, "bank_land_sale", "回收低效资产补充现金", str(sale.get("message", "资产已变现")), before_cash, {"land_id": land_id})
		for business_id: String in player.get("business_ids", []):
			var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
			if int(business.get("last_net", 0)) < 0 and int(business.get("consecutive_loss", 0)) >= 2:
				var demolition := Businesses.start_demolition(player_id, str(business.get("land_id", "")))
				if bool(demolition.get("ok", false)):
					return _event(player, "demolition", "拆除低效企业准备重建", str(demolition.get("message", "拆除启动")), before_cash, {"business_id": business_id})
		return {}
	if stage == "listed_stock":
		if not EndlessOperationsSystem.is_enabled():
			return {}
		var quotes := ListedMarket.snapshot()
		for quote: Dictionary in quotes:
			var ticker := str(quote.get("ticker", ""))
			var held := ListedMarket.holding_shares(player_id, ticker)
			if held >= 100 and (float(quote.get("change", 0.0)) < -0.065 or int(quote.get("risk", 0)) >= 72 or int(player.get("cash", 0)) < 120):
				var sell_shares := maxi(100, floori(float(held) * 0.5 / 100.0) * 100)
				var sell_result := ListedMarket.trade(player_id, str(quote.get("player_id", "")), sell_shares, false)
				if bool(sell_result.get("ok", false)):
					return _event(player, "listed_stock", "调整西岸板持仓", str(sell_result.get("message", "卖出挂牌股票")), before_cash, {"ticker": ticker, "buy": false, "shares": sell_shares})
		if int(player.get("cash", 0)) < 600:
			return {}
		var candidates: Array = quotes.filter(func(quote: Dictionary) -> bool:
			return str(quote.get("player_id", "")) != player_id and int(quote.get("confidence", 0)) >= 52 and int(quote.get("risk", 100)) <= 58 and float(quote.get("change", 0.0)) >= -0.035)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("confidence", 0)) - int(a.get("risk", 0)) > int(b.get("confidence", 0)) - int(b.get("risk", 0)))
		if not candidates.is_empty():
			var target := candidates[0] as Dictionary
			var buy_shares := 1000 if int(player.get("cash", 0)) >= 3000 else 100
			var buy_result := ListedMarket.trade(player_id, str(target.get("player_id", "")), buy_shares, true)
			if bool(buy_result.get("ok", false)):
				return _event(player, "listed_stock", "投资西岸板财团", str(buy_result.get("message", "买入挂牌股票")), before_cash, {"ticker": str(target.get("ticker", "")), "buy": true, "shares": buy_shares})
		return {}
	if stage == "ipo":
		var listed_profile := EndlessOperationsSystem.capital_market_profile(player_id)
		if bool(listed_profile.get("listed", false)):
			var record: Dictionary = listed_profile.get("record", {})
			var actions: Array[String] = []
			var round_number := int(GameState.game_data.get("round", 0))
			var confidence := int(record.get("market_confidence", 60))
			var audit_close := int(record.get("next_audit_round", 999999)) <= round_number + 1
			if int(player.get("risk", 0)) >= 55 or confidence < 48 or float(record.get("disclosure_gap", 0.0)) >= 0.18 or audit_close:
				actions.append("disclose")
			if int(player.get("cash", 0)) < 240 and confidence >= 35:
				actions.append("issuance")
			if int(player.get("cash", 0)) > 1300 and int(record.get("integration_level", 0)) < 3 and int(listed_profile.get("operating", 0)) >= 4:
				actions.append("acquisition")
			if int(player.get("cash", 0)) > 1150 and int(player.get("risk", 0)) < 42 and int(record.get("innovation_level", 0)) < 3:
				actions.append("innovation")
			var guidance_floor := maxi(180, roundi(float(player.get("asset_value", 0)) * 0.055))
			if not record.has("guidance_due_round") and int(player.get("last_round_income", 0)) >= guidance_floor and int(player.get("risk", 0)) < 38 and confidence < 92:
				actions.append("guidance")
			if int(player.get("cash", 0)) > 850 and confidence < 72:
				actions.append("buyback")
			if int(player.get("cash", 0)) > 900 and confidence < 82:
				actions.append("dividend")
			for action: String in actions:
				var capital_result := EndlessOperationsSystem.capital_market_action(player_id, action)
				if bool(capital_result.get("ok", false)):
					return _event(player, "capital_market", "执行上市公司经营", str(capital_result.get("message", "资本市场操作完成")), before_cash, {"action": action})
			return {}
		var eligibility := EndlessOperationsSystem.ipo_eligibility(player_id)
		if not bool(eligibility.get("ok", false)) or int(GameState.game_data.get("round", 0)) < 8:
			return {}
		var aggressive := int(player.get("risk", 0)) < 35 and GameState.rng.randf() < 0.35
		var ipo_result := EndlessOperationsSystem.request_ipo(player_id, aggressive)
		return _event(player, "ipo", "完成上市融资", str(ipo_result.get("message", "融资完成")), before_cash, {"aggressive": aggressive}) if bool(ipo_result.get("ok", false)) else {}
	var plan: = Decisions.choose_stage(player_id, stage)
	if bool(plan.get("abstain", false)):
		return {}
	match stage:
		"round_card":
			var chosen: = str(plan.get("card_id", ""))
			var result: Dictionary = Cards.choose_round_card(player_id, chosen)
			if not bool(result.get("ok", false)):
				return {}
			return _event(player, "round_card", "评估并选择回合策略", str(GameConfig.by_id("cards", chosen).get("name", result.get("message", "获得一张策略卡"))), before_cash, {"card_id": chosen, "decision": plan})
		"land":
			var land: Dictionary = GameState.game_data.lands.get(str(plan.get("land_id", "")), {})
			var result: Dictionary = Businesses.buy_land(player_id, str(land.id))
			if not bool(result.get("ok", false)):
				return {}
			return _event(player, "buy_land", "评估后购入城市地块", "%s  %s" % [str(land.get("district_name", land.id)), str(result.get("message", "交易完成"))], before_cash, {"land_id": str(land.id), "decision": plan})
		"build":
			var land_id: = str(plan.get("land_id", ""))
			var business: = GameConfig.by_id("business_types", str(plan.get("business_type_id", "")))
			var result: Dictionary = Businesses.build_business(player_id, land_id, str(business.id))
			if not bool(result.get("ok", false)):
				return {}
			return _event(player, "build", "按回收期启动建设", "%s  %s" % [str(business.name), str(result.get("message", "已开工"))], before_cash, {"land_id": land_id, "business_type_id": str(business.id), "decision": plan})
		"talent":
			if str(plan.action) == "draw":
				var draw_result: Dictionary = Talents.draw(player_id, int(plan.get("count", 1)))
				if not bool(draw_result.get("ok", false)):
					return {}
				plan = Decisions.choose_stage(player_id, "talent")
			if str(plan.action) in ["recruit", "convert"]:
				var talent_id: = str(plan.get("talent_id", ""))
				var resolved: Dictionary = Talents.resolve(player_id, talent_id, str(plan.action) == "recruit")
				if not bool(resolved.get("ok", false)):
					return {}
				if str(plan.action) == "recruit":
					for business_id: String in player.business_ids:
						var instance: Dictionary = GameState.game_data.businesses[business_id]
						if str(instance.employees[0]).is_empty():
							Businesses.assign_talent(player_id, business_id, talent_id, 0)
							break
				return _event(player, "talent", "评估人才并%s" % ("招募" if str(plan.action) == "recruit" else "转化"), str(GameConfig.by_id("talents", talent_id).get("name", "经营人才")), before_cash, {"talent_id": talent_id, "decision": plan})
			return {}
		"discard":
			var discarded: = 0
			while player.hand.size() > 5:
				var discard_plan: = Decisions.choose_stage(player_id, "discard")
				if Cards.discard(player_id, str(discard_plan.get("card_id", ""))):
					discarded += 1
				else:
					break
			return _event(player, "discard", "整理策略手牌", "转化 %d 张超限卡" % discarded, before_cash) if discarded > 0 else {}
		"card":
			var card_id: = str(plan.get("card_id", ""))
			var target_id: = str(plan.get("target_id", ""))
			var result: Dictionary = Cards.play(player_id, card_id, target_id)
			return _event(player, "card", "按局势发动策略卡", "%s  %s" % [str(GameConfig.by_id("cards", card_id).get("name", card_id)), str(result.get("message", "已生效"))], before_cash, {"card_id": card_id, "target_id": target_id, "decision": plan, "reaction": result}) if bool(result.get("ok", false)) else {}
		"stock":
			var buy: = str(plan.action) == "buy"
			var result: Dictionary = Stocks.trade(player_id, str(plan.stock_id), int(plan.shares), buy)
			if not bool(result.get("ok", false)):
				return {}
			return _event(player, "stock", "调整证券持仓", "%s %d 股" % ["买入" if buy else "卖出", int(plan.shares)], before_cash, {"stock_id": str(plan.stock_id), "decision": plan})
		"loan":
			var result: Dictionary = Bank.direct_loan(player_id, int(plan.amount))
			if not bool(result.get("ok", false)):
				return {}
			return _event(player, "loan", "为明确经营机会融资", str(result.get("message", "获得授信")), before_cash, {"decision": plan})
		"startup":
			var project: Dictionary = Startups.project_by_id(str(plan.project_id))
			if project.is_empty():
				return {}
			var result: Dictionary = Startups.invest(player_id, str(project.id))
			if not bool(result.get("ok", false)):
				return {}
			return _event(player, "startup", "按风险回报投资项目", "%s  %s" % [str(project.get("name", project.id)), str(result.get("message", "已进入尽调"))], before_cash, {"project_id": str(project.id), "decision": plan})
		"recovery":
			var business_id: = str(plan.business_id)
			var troubled: Dictionary = GameState.game_data.businesses[business_id]
			if GameState.apply_cash(player_id, -50, "AI 停业整改"):
				troubled.consecutive_loss = 0
				troubled.state = "operating"
				GameState.game_data.lands[str(troubled.land_id)].state = "operating"
				return _event(player, "recovery", "完成亏损整改", str(troubled.get("name", business_id)), before_cash, {"business_id": business_id, "land_id": str(troubled.land_id), "decision": plan})
	return {}


static func _event(player: Dictionary, action: String, headline: String, detail: String, before_cash: int, extra: = {}) -> Dictionary:
	var event: = {
		"action": action, 
		"player_id": str(player.id), 
		"player_name": str(player.name), 
		"player_color": str(player.color), 
		"headline": headline, 
		"detail": detail, 
		"cash_delta": int(player.cash) - before_cash, 
	}
	event.merge(extra, true)
	return event
