class_name TurnSettlement
extends RefCounted

const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const Businesses = preload("res://scripts/BusinessSystem.gd")
const Stocks = preload("res://scripts/StockSystem.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const Auctions = preload("res://scripts/AuctionSystem.gd")
const Districts = preload("res://scripts/DistrictSystem.gd")
const Traffic = preload("res://scripts/TrafficSystem.gd")
const MarketImpacts = preload("res://scripts/MarketImpactSystem.gd")
const BusinessRecommendations = preload("res://scripts/BusinessRecommendationEngine.gd")
const Insolvency = preload("res://scripts/InsolvencySystem.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const TimedEffects = preload("res://scripts/TimedEffectSystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const CashflowAudit = preload("res://scripts/RoundCashflowAudit.gd")
const Regions = preload("res://scripts/RegionalEconomySystem.gd")
const Feedback = preload("res://scripts/CityFeedbackSystem.gd")
const Radar = preload("res://scripts/OpportunityRadar.gd")
const ReportBuilder = preload("res://scripts/RoundReportBuilder.gd")
const AssetStates = preload("res://scripts/AssetStateService.gd")
const CompetitionFeed = preload("res://scripts/CompetitiveEventFeed.gd")
const EconomyDebug = preload("res://scripts/EconomyDebugAudit.gd")
const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")


static func settle_round() -> Dictionary:
	var round_id: = int(GameState.game_data.get("round", 0))
	var settled_reports: Dictionary = GameState.game_data.get_or_add("settled_round_reports", {})
	var settlement_key: = str(round_id)
	if settled_reports.has(settlement_key):
		var reused: Dictionary = settled_reports[settlement_key].duplicate(true)
		reused["reused"] = true
		return reused
	Districts.recalculate()
	if GameState.game_data.get("traffic_routes", []).is_empty():
		Traffic.generate_round()
	var before_snapshots: Dictionary = GameState.game_data.get("round_open_snapshots", {}).duplicate(true)
	for player: Dictionary in GameState.game_data.players:
		if not before_snapshots.has(str(player.id)) or int(before_snapshots[str(player.id)].get("round", -1)) != int(GameState.game_data.round):
			before_snapshots[str(player.id)] = {
				"round": int(GameState.game_data.round), "log_index": GameState.game_data.get("log", []).size(), 
				"asset": int(player.asset_value), "rank": int(player.rank), "risk": int(player.risk), 
				"cash": int(player.cash), "debt": int(player.debt), 
				"stock_holdings": player.get("stocks", {}).duplicate(true), "stock_prices": {}, 
			}
	var traffic_report: = Traffic.settle()
	var report: = {"round": int(GameState.game_data.round), "players": {}, "traffic": traffic_report, "phases": ["business", "traffic", "control", "interest", "startup", "stock", "assets", "ranking"]}
	for player: Dictionary in GameState.game_data.players:
		var previous: Dictionary = before_snapshots[str(player.id)]
		var lines: Array = []
		var total: = 0
		for business_id: String in player.business_ids.duplicate():
			var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
			if business.is_empty() or str(business.get("state", "")) in ["closed", "acquired"]:
				continue
			if str(business.get("state", "")) == "demolishing":
				business.demolition_remaining_rounds = maxi(0, int(business.get("demolition_remaining_rounds", 1)) - 1)
				if int(business.demolition_remaining_rounds) <= 0:
					var demolition_land: Dictionary = GameState.game_data.lands.get(str(business.get("land_id", "")), {})
					if not demolition_land.is_empty():
						demolition_land.state = "owned_empty"
						demolition_land.business_id = ""
					business.state = "closed"
					player.business_ids.erase(business_id)
					lines.append({"label": "%s 拆除完成" % str(business.get("name", "企业")), "value": 0})
				continue
			var owning_land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
			if owning_land.is_empty() or not AssetStates.income_eligible(owning_land, str(player.id)):
				continue
			if str(business.state) == "constructing":
				var build_paused := _has_business_effect(business, "pause_build")
				if build_paused:
					lines.append({"label": "%s 停工中" % business.name, "value": 0})
				var completed := ConstructionProgressService.advance(business, int(GameState.game_data.round), build_paused)
				if completed:
					business.state = "operating"
					business.operating_since_round = int(GameState.game_data.round)
					GameState.game_data.lands[str(business.land_id)].state = "operating"
					lines.append({"label": "%s 建成" % business.name, "value": 0})
					AudioManager.build_complete()
				_tick_business_effects(business)
				continue
			if str(business.state) not in ["operating", "loss_watch", "mortgaged"]:
				continue

			var type: = GameConfig.by_id("business_types", str(business.type_id))
			var income: = float(type.income) * CompanyRules.income_multiplier(str(player.company_id), type, int(GameState.game_data.round))
			var adjacency_multiplier: = CompanyRules.adjacency_income_multiplier(player, business)
			income *= adjacency_multiplier
			var cost: = float(type.fixed_cost) * CompanyRules.fixed_cost_multiplier(str(player.company_id))
			for player_effect: Dictionary in player.effects:
				if str(player_effect.kind) == "all_income_multiplier":
					income *= float(player_effect.value)
			for effect: Dictionary in business.effects:
				match str(effect.kind):
					"income_multiplier":
						income *= float(effect.value)
					"cost_multiplier":
						cost *= float(effect.value)
					"suspended":
						income = 0.0

			var land: Dictionary = GameState.game_data.lands[str(business.land_id)]
			var location_profile: Dictionary = BusinessRecommendations.evaluate(type, land)
			income *= float(location_profile.get("income_multiplier", 1.0))
			var district_modifiers: = Districts.business_modifiers(str(business.id))
			income *= float(district_modifiers.income_multiplier)
			var regional_multiplier: = Regions.business_income_multiplier(business, land)
			income *= regional_multiplier
			if bool(business.mortgaged):
				income *= 0.85
			var credit_multiplier: = Bank.operating_income_multiplier(str(player.id))
			income *= credit_multiplier
			var talent_result: = Talents.business_contribution(str(player.id), business, type, income, cost)
			var talent_income: = float(talent_result.get("income_bonus", 0))
			var talent_cost_saving: = float(talent_result.get("cost_saving", 0))
			var complaint := Talents.complaint_quote(str(player.id), business, type, income + talent_income)
			for effect: Dictionary in business.effects:
				if str(effect.kind) == "steal_talent_income":
					var stolen: = roundi(talent_income * float(effect.value))
					talent_income -= stolen
					var thief_id: = str(effect.get("source_player_id", ""))
					if not thief_id.is_empty():
						GameState.apply_cash(thief_id, stolen, "商业挖角收益")

			var final_cost: = maxf(0.0, cost - talent_cost_saving)
			var complaint_loss := int(complaint.get("loss", 0))
			var net: = roundi(income + talent_income - final_cost) - complaint_loss
			business.last_net = net
			business.last_ledger = {
				"round": int(GameState.game_data.round), 
				"base_income": int(type.get("income", 0)), 
				"operating_revenue": roundi(income), 
				"talent_income": roundi(talent_income), 
				"fixed_cost": roundi(cost), 
				"talent_cost_saving": roundi(talent_cost_saving), 
				"complaint": complaint.duplicate(true),
				"complaint_loss": complaint_loss,
				"final_cost": roundi(final_cost), 
				"net": net, 
				"district_multiplier": float(district_modifiers.income_multiplier), 
				"regional_multiplier": regional_multiplier, 
				"credit_multiplier": credit_multiplier, 
				"company_adjacency_multiplier": adjacency_multiplier, 
				"employee_contributions": talent_result.get("employees", []).duplicate(true), 
			}
			if bool(complaint.get("occurred", false)):
				lines.append({"label": "%s 客诉处置" % str(business.name), "business_id": str(business.id), "value": -complaint_loss, "raw_loss": int(complaint.get("raw_loss", 0)), "pr_reduction": int(complaint.get("reduction", 0))})
				GameState._record(str(player.id), "complaint_loss", {"business_id": str(business.id), "raw_loss": int(complaint.get("raw_loss", 0)), "reduction": int(complaint.get("reduction", 0)), "loss": complaint_loss})
			business.value = maxi(roundi(float(type.cost) * 0.6 + float(net) * 3.0), roundi(float(type.cost) * 0.5))
			if net < 0:
				if _consume_business_effect(business, "block_loss_watch"):
					business.consecutive_loss = 0

					lines.append({"label": "%s 稳定经营挡下亏损观察" % business.name, "value": 0, "actual_net": net, "informational": true})
				else:
					business.consecutive_loss = int(business.consecutive_loss) + 1
			else:
				business.consecutive_loss = 0
			if int(business.consecutive_loss) == 3:
				business.state = "loss_watch"
				GameState.game_data.lands[str(business.land_id)].state = "loss_watch"
			elif int(business.consecutive_loss) >= 4:
				Auctions.create_for_business(str(business.id))
			_tick_business_effects(business)
			total += net
			lines.append({"label": str(business.name), "business_id": str(business.id), "value": net + complaint_loss, "net_after_complaint": net, "talent": roundi(talent_income + talent_cost_saving), "talent_income": roundi(talent_income), "talent_cost_saving": roundi(talent_cost_saving), "complaint_loss": complaint_loss, "complaint_reduction": int(complaint.get("reduction", 0)), "employee_contributions": talent_result.get("employees", []).duplicate(true), "district_multiplier": float(district_modifiers.income_multiplier), "regional_multiplier": regional_multiplier, "credit_multiplier": credit_multiplier, "controller_id": str(district_modifiers.controller_id)})
			var sector: = str(type.get("sector", ""))
			if not sector.is_empty():
				var impact: = clampf(float(net) / maxf(1.0, float(type.cost) * 6.0), -0.06, 0.06)
				MarketImpacts.add(sector, impact, "business_performance", str(player.id), {"business_id": str(business.id), "net": net, "district_id": str(land.district)})
		var joint_operation: = Districts.joint_operation_dividend(str(player.id))
		for dividend_line: Dictionary in joint_operation.get("lines", []):
			lines.append(dividend_line)
		total += int(joint_operation.get("total", 0))
		var endless_bonus := EndlessOperationsSystem.settle_player(str(player.id))
		if int(endless_bonus.get("finance_cash", 0)) > 0:
			lines.append({"label": "金融集群协同", "value": int(endless_bonus.finance_cash)})
		if int(endless_bonus.get("listed_synergy", 0)) > 0:
			lines.append({"label": "上市并购协同", "value": int(endless_bonus.listed_synergy)})
		total += int(endless_bonus.get("cash", 0))
		if total < 0:
			for reserve: Dictionary in player.get("effects", []).duplicate():
				if str(reserve.get("kind", "")) != "west_liquidity_reserve" or int(reserve.get("uses", 0)) <= 0:
					continue
				var covered := mini(abs(total), int(reserve.get("value", 0)))
				if covered > 0:
					total += covered
					reserve.uses = int(reserve.get("uses", 1)) - 1
					lines.append({"label": "西岸流动性储备补偿", "value": covered})
					GameState._record(str(player.id), "west_liquidity_reserve_used", {"covered": covered, "remaining_loss": maxi(0, -total)})
				if int(reserve.get("uses", 0)) <= 0:
					player.effects.erase(reserve)
				break
		if total >= 0:
			GameState.apply_cash(str(player.id), total, "企业结算")
		else:
			GameState.settle_obligation(str(player.id), abs(total), "企业亏损结算", "operating_shortfall", 6)


		var interest: = Bank.settle_interest(str(player.id), not bool(player.get("human", false)))
		var delinquency_bankruptcy: Dictionary = {}
		if Bank.has_judicial_bankruptcy_due(str(player.id)):
			delinquency_bankruptcy = Insolvency.force_delinquency_bankruptcy(str(player.id))
		var startup_stories: = Startups.settle(str(player.id))
		var startup_value: = Startups.unresolved_value(str(player.id))
		CompanyRules.apply_end_round(player)
		var risk_recovery: Dictionary = Risks.apply_end_round_recovery(str(player.id))
		var critical_risk: Dictionary = {}
		var risk_bankruptcy: Dictionary = {}
		if not bool(player.get("eliminated", false)):
			critical_risk = Risks.process_critical_risk_round(str(player.id))
			if bool(critical_risk.get("bankruptcy_pending", false)):
				risk_bankruptcy = Insolvency.force_risk_bankruptcy(str(player.id))
		var traffic_player: Dictionary = traffic_report.players.get(str(player.id), {"traffic_income": 0, "control_income": 0, "competition_cost": 0})
		report.players[str(player.id)] = {
			"net": total + int(traffic_player.traffic_income) + int(traffic_player.control_income) - int(traffic_player.competition_cost) - interest, 
			"business_income": total, 
			"traffic_income": int(traffic_player.traffic_income), 
			"control_income": int(traffic_player.control_income), 
			"competition_cost": int(traffic_player.competition_cost), 
			"asset_before": int(previous.asset), 
			"cash_before": int(previous.cash), 
			"debt_before": int(previous.debt), 
			"rank_before": int(previous.rank), 
			"risk_before": int(previous.risk), 
			"stock_value_before": Stocks.snapshot_market_value(str(player.id), previous), 
			"business_count": player.business_ids.size(), 
			"lines": lines, 
			"interest": interest, 
			"loan_settlement": player.get("last_loan_settlement", {}).duplicate(true), 
			"delinquency_bankruptcy": delinquency_bankruptcy, 
			"risk_recovery": risk_recovery, 
			"critical_risk": critical_risk, 
			"risk_bankruptcy": risk_bankruptcy, 
			"startups": startup_stories, 
			"startup_asset_value": startup_value
		}
		_tick_player_effects(player)
		_tick_player_guards(player)
	Stocks.generate_round()
	for player: Dictionary in GameState.game_data.players:
		var player_id: = str(player.id)
		var startup_value: = Startups.unresolved_value(player_id)
		var stock_after: = Stocks.market_value(player_id)
		var listed_stock_after := ListedMarket.market_value(player_id)
		player.asset_value = int(player.cash) + Businesses.estimate_assets(player_id) + stock_after + listed_stock_after + startup_value - int(player.debt) - _risk_penalty(player)
		var player_report: Dictionary = report.players[player_id]
		player_report.stock_value_after = stock_after
		player_report.listed_stock_value_after = listed_stock_after
		var stock_activity: = Stocks.round_activity(player_id, int(GameState.game_data.round))
		stock_activity.opening_market_value = int(player_report.stock_value_before)
		stock_activity.closing_market_value = stock_after
		stock_activity.market_pnl = stock_after - int(player_report.stock_value_before) - int(stock_activity.buy_cash) + int(stock_activity.sell_gross_cash)
		player_report.stock_activity = stock_activity
		player_report.stock_pnl = int(stock_activity.market_pnl)
		player_report.cash_after = int(player.cash)
		player_report.cash_change = int(player.cash) - int(player_report.cash_before)
		player_report.cash_audit = CashflowAudit.build(player_id, before_snapshots[player_id], int(player.cash))
		player_report.debt_after = int(player.debt)
		player_report.debt_change = int(player.debt) - int(player_report.debt_before)
		player_report.loan_principal_paid = maxi(0, int(player_report.debt_before) - int(player.debt))
		player_report.talent_value = 0
		for line: Dictionary in player_report.get("lines", []):
			player_report.talent_value = int(player_report.talent_value) + int(line.get("talent", 0))
		player_report.asset_after = int(player.asset_value)
		player_report.asset_change = int(player.asset_value) - int(player_report.asset_before)
		player_report.risk_after = int(player.risk)
		player_report.risk_change = int(player.risk) - int(player_report.risk_before)
		player_report.bankruptcy = Insolvency.audit(player_id)
	GameState.game_data.players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.asset_value) > int(b.asset_value))
	for i in GameState.game_data.players.size():
		GameState.game_data.players[i].rank = i + 1
		var ranked_player: Dictionary = GameState.game_data.players[i]
		var ranked_report: Dictionary = report.players[str(ranked_player.id)]
		ranked_report.rank_after = i + 1
		ranked_report.rank_change = int(ranked_report.rank_before) - (i + 1)
		ranked_player.round_history.append({"round": int(GameState.game_data.round), "summary": ranked_report.duplicate(true)})
		var rank_delta: = int(ranked_report.get("rank_change", 0))
		if rank_delta != 0:
			CompetitionFeed.publish("rank_change", str(ranked_player.id), "%s排名%s%d位，现列第%d" % [str(ranked_player.name), "上升" if rank_delta > 0 else "下降", abs(rank_delta), i + 1], {"rank": i + 1, "rank_change": rank_delta})
	report["competition"] = ReportBuilder.build(report)
	report["reused"] = false
	GameState.game_data.battle_ledger.append({
		"round": int(GameState.game_data.round), 
		"category": "settlement", 
		"player_id": "system", 
		"title": "第 %d 回合商业战况结算完成" % int(GameState.game_data.round), 
		"details": report.duplicate(true), 
	})
	GameState.game_data.last_report = report
	settled_reports[settlement_key] = report.duplicate(true)
	GameState.game_data.last_settled_round_id = round_id
	Feedback.finalize_round(report)
	Radar.refresh()
	TimedEffects.finish_round(int(GameState.game_data.round))
	GameState._record("system", "round_settlement", report)
	EconomyDebug.emit_round(report)
	GameState.save_to_disk()
	return report


static func finalize_match() -> Dictionary:
	var existing: Dictionary = GameState.game_data.get("final_settlement", {})
	if not existing.is_empty():
		return existing
	var report: = {
		"round": int(GameState.game_data.get("round", 0)), 
		"players": {}, 
		"property_recovery_rate": 0.55, 
		"stock_recovery_rate": 0.7, 
		"project_recovery_rate": 0.45, 
	}
	for player: Dictionary in GameState.game_data.get("players", []):
		var player_id: = str(player.id)
		var result: = Bank.finalize_player_debt(player_id)
		result["risk"] = int(player.get("risk", 0))
		result["cash_after"] = int(player.get("cash", 0))
		result["property_value"] = Businesses.estimate_assets(player_id)
		result["stock_value"] = Stocks.market_value(player_id)
		result["listed_stock_value"] = ListedMarket.market_value(player_id)
		result["project_value"] = Startups.unresolved_value(player_id)
		result["enterprise_value"] = int(player.get("enterprise_valuation", 0))
		result["debt_after"] = int(player.get("debt", 0))
		result["risk_penalty"] = _risk_penalty(player)
		result["final_value"] = (
			int(result.cash_after)
			+ int(result.property_value)
			+ int(result.stock_value)
			+ int(result.listed_stock_value)
			+ int(result.project_value)
			+ int(result.enterprise_value)
			- int(result.debt_after)
			- int(result.risk_penalty)
		)
		player.asset_value = int(result.final_value)
		report.players[player_id] = result
	GameState.game_data.players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.asset_value) > int(b.asset_value))
	for index in range(GameState.game_data.players.size()):
		GameState.game_data.players[index].rank = index + 1
	GameState.game_data.final_settlement = report
	GameState.game_data.phase = "final"
	GameState._record("system", "final_settlement", report.duplicate(true))
	GameState.save_to_disk()
	return report


static func report_consistency(report: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var is_final: = report.has("property_recovery_rate")
	for player_id: Variant in report.get("players", {}).keys():
		var player_report: Dictionary = report.get("players", {}).get(player_id, {})
		if is_final:
			var expected_final: = (
				int(player_report.get("cash_after", 0))
				+ int(player_report.get("property_value", 0))
				+ int(player_report.get("stock_value", 0))
				+ int(player_report.get("listed_stock_value", 0))
				+ int(player_report.get("project_value", 0))
				+ int(player_report.get("enterprise_value", 0))
				- int(player_report.get("debt_after", player_report.get("residual_debt", 0)))
				- int(player_report.get("risk_penalty", 0))
			)
			if int(player_report.get("final_value", 0)) != expected_final:
				errors.append("%s final_value" % str(player_id))
			if int(player_report.get("debt_after", 0)) != int(player_report.get("residual_debt", 0)):
				errors.append("%s residual_debt" % str(player_id))
			continue
		var cash_before: = int(player_report.get("cash_before", 0))
		var cash_after: = int(player_report.get("cash_after", cash_before))
		if int(player_report.get("cash_change", cash_after - cash_before)) != cash_after - cash_before:
			errors.append("%s cash_change" % str(player_id))
		var cash_audit: Dictionary = player_report.get("cash_audit", {})
		if not cash_audit.is_empty():
			if not bool(cash_audit.get("balanced", false)):
				errors.append("%s cash_audit_balance" % str(player_id))
			if int(cash_audit.get("opening_cash", cash_before)) != cash_before or int(cash_audit.get("closing_cash", cash_after)) != cash_after:
				errors.append("%s cash_audit_endpoints" % str(player_id))
		var business_total: = 0
		for line: Dictionary in player_report.get("lines", []):
			business_total += int(line.get("value", 0))
		if business_total != int(player_report.get("business_income", business_total)):
			errors.append("%s business_income" % str(player_id))
		var expected_net: = (
			int(player_report.get("business_income", 0))
			+ int(player_report.get("traffic_income", 0))
			+ int(player_report.get("control_income", 0))
			- int(player_report.get("competition_cost", 0))
			- int(player_report.get("interest", 0))
		)
		if int(player_report.get("net", expected_net)) != expected_net:
			errors.append("%s net" % str(player_id))
		var stock_activity: Dictionary = player_report.get("stock_activity", {})
		if not stock_activity.is_empty():
			var expected_stock_pnl: = int(stock_activity.get("closing_market_value", 0)) - int(stock_activity.get("opening_market_value", 0)) - int(stock_activity.get("buy_cash", 0)) + int(stock_activity.get("sell_gross_cash", 0))
			if int(player_report.get("stock_pnl", expected_stock_pnl)) != expected_stock_pnl:
				errors.append("%s stock_pnl" % str(player_id))
	return {"ok": errors.is_empty(), "errors": errors}


static func _has_business_effect(business: Dictionary, kind: String) -> bool:
	return business.effects.any( func(effect: Dictionary) -> bool: return str(effect.kind) == kind)


static func _consume_business_effect(business: Dictionary, kind: String) -> bool:
	for effect: Dictionary in business.effects.duplicate():
		if str(effect.kind) == kind:
			business.effects.erase(effect)
			return true
	return false


static func _tick_business_effects(business: Dictionary) -> void :
	for effect: Dictionary in business.effects.duplicate():
		effect.duration = int(effect.duration) - 1
		if int(effect.duration) <= 0:
			business.effects.erase(effect)


static func _tick_player_effects(player: Dictionary) -> void :
	for effect: Dictionary in player.effects.duplicate():
		if str(effect.get("kind", "")) in ["cash_lock", "temporary_risk"]:
			continue
		if not effect.has("duration"):
			push_warning("跳过缺少 duration 的玩家状态：%s" % str(effect.get("kind", "unknown")))
			continue
		if str(effect.kind) == "repay_cash" and int(effect.duration) <= 1:
			GameState.settle_obligation(str(player.id), int(effect.value), "融资到期处理", "temporary_finance", 8)
		effect.duration = int(effect.duration) - 1
		if int(effect.duration) <= 0:
			if str(effect.kind) == "temporary_talent_capacity":
				player.talent_capacity_bonus = maxi(0, int(player.get("talent_capacity_bonus", 0)) - int(effect.get("value", 0)))
			player.effects.erase(effect)


static func _tick_player_guards(player: Dictionary) -> void :
	for guard: Dictionary in player.guards.duplicate():
		guard.duration = int(guard.duration) - 1
		if int(guard.duration) <= 0:
			player.guards.erase(guard)


static func _risk_penalty(player: Dictionary) -> int:
	return Risks.valuation_penalty(player)
