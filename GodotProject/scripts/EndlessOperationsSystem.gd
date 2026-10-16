class_name EndlessOperationsSystem
extends RefCounted

const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")

const PLANNING_HORIZON := 12
const IPO_MIN_ROUND := 15
const IPO_MIN_ASSET := 4000
const IPO_MIN_OPERATING := 6
const IPO_MIN_PREMIUM_LANDS := 2
const IPO_MAX_RISK := 35
const IPO_REVIEW_ROUNDS := 3
const IPO_INTEGRATION_INCOME_PER_LEVEL := 32
const IPO_INNOVATION_INCOME_PER_LEVEL := 24
const IPO_MAX_INNOVATION_LEVEL := 3
const IPO_RESTRICTION_ROUNDS := 3
const CYCLE_PHASES := [
	{"id": "recovery", "name": "复苏", "build_delta": 0, "startup_rate": 0.04, "fraud_rate": 0.04},
	{"id": "boom", "name": "上行", "build_delta": -1, "startup_rate": 0.08, "fraud_rate": 0.1},
	{"id": "overheat", "name": "过热", "build_delta": 0, "startup_rate": -0.08, "fraud_rate": 0.24},
	{"id": "adjustment", "name": "调整", "build_delta": 1, "startup_rate": -0.04, "fraud_rate": 0.08},
]


static func initialize_match(enabled: bool) -> void:
	GameState.game_data.endless = enabled
	GameState.game_data.economic_cycle = {}
	GameState.game_data.ipo_records = {}
	GameState.game_data.ipo_audit_history = []
	if not enabled:
		return
	GameState.game_data.economic_cycle = {
		"index": 0,
		"phase": str(CYCLE_PHASES[0].id),
		"name": str(CYCLE_PHASES[0].name),
		"started_round": 1,
		"ends_round": GameState.rng.randi_range(4, 7),
	}
	GameState.game_data.next_endless_startup_round = 2


static func is_enabled() -> bool:
	return bool(GameState.game_data.get("endless", false))


static func is_final_round() -> bool:
	return not is_enabled() and int(GameState.game_data.get("round", 0)) >= int(GameState.game_data.get("round_limit", 0))


static func planning_rounds_left() -> int:
	if is_enabled():
		return PLANNING_HORIZON
	return maxi(0, int(GameState.game_data.get("round_limit", 0)) - int(GameState.game_data.get("round", 0)) + 1)


static func begin_round() -> void:
	if not is_enabled():
		return
	var round_number := int(GameState.game_data.get("round", 0))
	var cycle: Dictionary = GameState.game_data.get("economic_cycle", {})
	if cycle.is_empty():
		initialize_match(true)
		cycle = GameState.game_data.economic_cycle
	if round_number > int(cycle.get("ends_round", 0)):
		var next_index := (int(cycle.get("index", 0)) + 1) % CYCLE_PHASES.size()
		var profile: Dictionary = CYCLE_PHASES[next_index]
		GameState.game_data.economic_cycle = {
			"index": next_index,
			"phase": str(profile.id),
			"name": str(profile.name),
			"started_round": round_number,
			"ends_round": round_number + GameState.rng.randi_range(3, 6),
		}
		GameState.game_data.battle_ledger.append({"round": round_number, "category": "economic_cycle", "player_id": "system", "title": "经济进入%s期" % str(profile.name), "details": GameState.game_data.economic_cycle.duplicate(true)})
	var next_offer := int(GameState.game_data.get("next_endless_startup_round", 2))
	if round_number >= next_offer:
		var schedule: Array = GameState.game_data.get("startup_schedule", [])
		if not schedule.has(round_number):
			schedule.append(round_number)
			GameState.game_data.startup_schedule = schedule
		var phase := str(GameState.game_data.get("economic_cycle", {}).get("phase", "recovery"))
		var gap := GameState.rng.randi_range(2, 3) if phase in ["boom", "overheat"] else GameState.rng.randi_range(3, 4)
		GameState.game_data.next_endless_startup_round = round_number + gap
	_process_ipo_applications(round_number)
	_process_market_commitments(round_number)
	ListedMarket.price_all(round_number)


static func current_cycle() -> Dictionary:
	if not is_enabled():
		return {"phase": "standard", "name": "常态", "build_delta": 0, "startup_rate": 0.0, "fraud_rate": 0.0}
	var cycle: Dictionary = GameState.game_data.get("economic_cycle", {})
	var index := clampi(int(cycle.get("index", 0)), 0, CYCLE_PHASES.size() - 1)
	var profile: Dictionary = CYCLE_PHASES[index].duplicate(true)
	profile.merge(cycle, true)
	return profile


static func economic_cycle_rule_profile() -> Dictionary:
	return {
		"rotation": ["recovery", "boom", "overheat", "adjustment"],
		"phase_order_random": false,
		"duration_random": true,
		"duration_rounds": Vector2i(4, 7),
		"display_rule": "固定轮动，每阶段持续 4–7 回合",
	}


static func construction_round_delta() -> int:
	return int(current_cycle().get("build_delta", 0))


static func startup_success_modifier() -> float:
	return float(current_cycle().get("startup_rate", 0.0))


static func startup_fraud_rate() -> float:
	return float(current_cycle().get("fraud_rate", 0.0))


static func finance_cluster_bonus(player_id: String) -> Dictionary:
	if not is_enabled():
		return {"count": 0, "cash": 0, "financing_rate": 0.0}
	var count := 0
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		if str(business.get("owner_id", "")) != player_id or str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
			continue
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		var business_type := GameConfig.by_id("business_types", str(business.get("type_id", "")))
		if str(land.get("district", "")) == "finance" or str(business_type.get("sector", "")) == "finance":
			count += 1
	var cash := 0
	if count >= 3:
		cash = 12 + (count - 3) * 4
	return {"count": count, "cash": cash, "financing_rate": 0.04 if count >= 3 else 0.0}


static func settle_player(player_id: String) -> Dictionary:
	if not is_enabled():
		return {"cash": 0, "finance_cash": 0, "listed_synergy": 0, "finance_count": 0, "audit": {}}
	var cluster := finance_cluster_bonus(player_id)
	var finance_cash := int(cluster.cash)
	var listed_synergy := 0
	var records: Dictionary = GameState.game_data.get("ipo_records", {})
	if records.has(player_id) and str((records[player_id] as Dictionary).get("status", "listed")) == "listed":
		var integration_level := int((records[player_id] as Dictionary).get("integration_level", 0))
		listed_synergy = integration_level * IPO_INTEGRATION_INCOME_PER_LEVEL
		listed_synergy += int((records[player_id] as Dictionary).get("innovation_income", 0))
	var audit := _audit_ipo(player_id)
	return {"cash": finance_cash + listed_synergy, "finance_cash": finance_cash, "listed_synergy": listed_synergy, "finance_count": int(cluster.count), "audit": audit}


static func ipo_eligibility(player_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	if not is_enabled():
		return {"ok": false, "message": "仅永续经营模式开放"}
	if player.is_empty() or bool(player.get("eliminated", false)):
		return {"ok": false, "message": "当前财团不可申请"}
	var existing: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
	if str(existing.get("status", "")) == "preparing":
		return {"ok": false, "message": "上市申请正在审核，第 %d 回合公布结果" % int(existing.get("approval_round", 0))}
	if str(existing.get("status", "")) == "listed":
		return {"ok": false, "message": "本财团已完成上市"}
	if bool(player.get("endless_cheat", false)):
		return {
			"ok": true,
			"message": "无限权限已满足全部上市条件",
			"checks": {"round": true, "operating": true, "asset": true, "premium_lands": true, "risk": true},
			"operating": maxi(IPO_MIN_OPERATING, player.get("business_ids", []).size()),
			"premium_lands": IPO_MIN_PREMIUM_LANDS,
			"cheat": true,
		}
	if str(existing.get("status", "")) == "rejected" and int(GameState.game_data.get("round", 0)) < int(existing.get("retry_round", 0)):
		return {"ok": false, "message": "整改期至第 %d 回合" % int(existing.get("retry_round", 0))}
	var operating := 0
	for business_id: String in player.get("business_ids", []):
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
		if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
			operating += 1
	var premium_lands := 0
	for land_id: String in player.get("land_ids", []):
		if bool(GameState.game_data.get("lands", {}).get(land_id, {}).get("premium_zone", false)):
			premium_lands += 1
	var round_number := int(GameState.game_data.get("round", 0))
	var asset := int(player.get("asset_value", 0))
	var risk := int(player.get("risk", 0))
	var checks := {
		"round": round_number >= IPO_MIN_ROUND,
		"operating": operating >= IPO_MIN_OPERATING,
		"asset": asset >= IPO_MIN_ASSET,
		"premium_lands": premium_lands >= IPO_MIN_PREMIUM_LANDS,
		"risk": risk <= IPO_MAX_RISK,
	}
	if not bool(checks.round): return {"ok": false, "message": "第 %d 回合开放上市申请" % IPO_MIN_ROUND, "checks": checks, "operating": operating, "premium_lands": premium_lands}
	if not bool(checks.operating): return {"ok": false, "message": "需至少 %d 家营业企业" % IPO_MIN_OPERATING, "checks": checks, "operating": operating, "premium_lands": premium_lands}
	if not bool(checks.asset): return {"ok": false, "message": "净资产需达到 %d 万" % IPO_MIN_ASSET, "checks": checks, "operating": operating, "premium_lands": premium_lands}
	if not bool(checks.premium_lands): return {"ok": false, "message": "需持有至少 %d 块西岸核心区土地" % IPO_MIN_PREMIUM_LANDS, "checks": checks, "operating": operating, "premium_lands": premium_lands}
	if not bool(checks.risk): return {"ok": false, "message": "上市前风险需降至 %d 以下" % IPO_MAX_RISK, "checks": checks, "operating": operating, "premium_lands": premium_lands}
	return {"ok": true, "message": "符合上市申请条件", "checks": checks, "operating": operating, "premium_lands": premium_lands}


static func request_ipo(player_id: String, aggressive: bool = false) -> Dictionary:
	var eligibility := ipo_eligibility(player_id)
	if not bool(eligibility.get("ok", false)):
		return eligibility
	var player := GameState.player(player_id)
	var quote := listing_route_quote(player_id, aggressive)
	var application_cost := int(quote.get("application_cost", 0))
	if int(player.get("cash", 0)) < application_cost + 150:
		return {"ok": false, "message": "提交申请后需保留至少 150 万经营现金"}
	GameState.apply_cash(player_id, -application_cost, "上市申请与审计")
	var funding := int(quote.get("funding", 0))
	var round_number := int(GameState.game_data.get("round", 0))
	var roadshow_bonus := clampf(float(player.get("ipo_roadshow_bonus", 0.0)), 0.0, 0.06)
	var audit_gap_relief := 0.08 if bool(player.get("ipo_audit_prepared", false)) else 0.0
	var placement_confidence_bonus := clampi(int(player.get("ipo_placement_confidence_bonus", 0)), 0, 12)
	var record := {
		"player_id": player_id,
		"round": round_number,
		"status": "preparing",
		"approval_round": round_number + IPO_REVIEW_ROUNDS,
		"approval_chance": minf(0.95, float(quote.get("approval_chance", 0.8)) + roadshow_bonus),
		"application_cost": application_cost,
		"aggressive": aggressive,
		"funding": funding,
		"route_id": str(quote.get("route_id", "stable")),
		"route_name": str(quote.get("route_name", "稳健上市")),
		"valuation_multiple": float(quote.get("valuation_multiple", 1.0)),
		"target_market_cap": int(quote.get("target_market_cap", 0)),
		"issue_price": float(quote.get("issue_price", 0.0)),
		"shares_outstanding": int(quote.get("shares_outstanding", 0)),
		"offered_shares": int(quote.get("offered_shares", 0)),
		"float_ratio": float(quote.get("float_ratio", 0.25)),
		"dilution_ratio": float(quote.get("dilution_ratio", 0.2)),
		"volatility_factor": float(quote.get("volatility_factor", 1.0)),
		"disclosure_gap": maxf(0.0, float(quote.get("disclosure_gap", 0.1)) - audit_gap_relief),
		"next_audit_round": int(GameState.game_data.round) + 4,
		"exposed": false,
		"market_confidence": mini(100, int(quote.get("market_confidence", 60)) + placement_confidence_bonus),
		"last_disclosure_round": -99,
		"last_dividend_round": -99,
		"last_issuance_round": round_number,
		"last_buyback_round": -99,
		"last_acquisition_round": -99,
		"last_guidance_round": -99,
		"integration_level": 0,
		"innovation_level": 0,
		"innovation_income": 0,
		"audit_strikes": 0,
		"capital_restriction_until_round": 0,
	}
	player.erase("ipo_roadshow_bonus")
	player.erase("ipo_audit_prepared")
	player.erase("ipo_placement_confidence_bonus")
	GameState.game_data.ipo_records[player_id] = record
	GameState._record(player_id, "ipo_application", record.duplicate(true))
	return {"ok": true, "message": "申请已受理，%d 回合后公布审核结果" % IPO_REVIEW_ROUNDS, "funding": funding, "quote": quote.duplicate(true), "status": "preparing", "approval_round": int(record.approval_round)}


static func listing_route_quote(player_id: String, aggressive: bool = false) -> Dictionary:
	var player := GameState.player(player_id)
	var asset := maxi(1, int(player.get("asset_value", 0)))
	var route_id := "growth" if aggressive else "stable"
	var valuation_multiple := 1.32 if aggressive else 1.18
	var dilution_ratio := 0.27 if aggressive else 0.19
	var float_ratio := 0.36 if aggressive else 0.26
	var target_market_cap := maxi(720, roundi(float(asset) * valuation_multiple))
	var issue_price := snappedf(clampf(float(asset) / 82.0 * (1.10 if aggressive else 1.0), 18.0, 98.0), 0.01)
	var shares_outstanding := maxi(100000, roundi(float(target_market_cap) * 10000.0 / issue_price / 10000.0) * 10000)
	var offered_shares := maxi(10000, roundi(float(shares_outstanding) * dilution_ratio / 10000.0) * 10000)
	var funding := maxi(520 if aggressive else 420, roundi(float(offered_shares) * issue_price / 10000.0))
	return {
		"route_id": route_id,
		"route_name": "成长上市" if aggressive else "稳健上市",
		"asset": asset,
		"valuation_multiple": valuation_multiple,
		"target_market_cap": target_market_cap,
		"issue_price": issue_price,
		"shares_outstanding": shares_outstanding,
		"offered_shares": offered_shares,
		"float_ratio": float_ratio,
		"dilution_ratio": dilution_ratio,
		"funding": funding,
		"application_cost": 120 if aggressive else 80,
		"approval_chance": 0.72 if aggressive else 0.90,
		"disclosure_gap": 0.34 if aggressive else 0.06,
		"market_confidence": 55 if aggressive else 68,
		"volatility_factor": 1.28 if aggressive else 0.78,
		"review_rounds": IPO_REVIEW_ROUNDS,
	}


static func capital_market_profile(player_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var records: Dictionary = GameState.game_data.get("ipo_records", {})
	var eligibility := ipo_eligibility(player_id)
	var operating := int(eligibility.get("operating", 0))
	if not bool(eligibility.get("ok", false)) and not player.is_empty():
		operating = 0
		for business_id: String in player.get("business_ids", []):
			var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
			if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
				operating += 1
	var listed := records.has(player_id) and str((records[player_id] as Dictionary).get("status", "listed")) == "listed"
	var preparing := records.has(player_id) and str((records[player_id] as Dictionary).get("status", "")) == "preparing"
	var record: Dictionary = records.get(player_id, {}).duplicate(true)
	return {"listed": listed, "preparing": preparing, "eligibility": eligibility, "operating": operating, "required_operating": IPO_MIN_OPERATING, "asset": int(player.get("asset_value", 0)) if not player.is_empty() else 0, "required_asset": IPO_MIN_ASSET, "required_round": IPO_MIN_ROUND, "required_premium_lands": IPO_MIN_PREMIUM_LANDS, "required_max_risk": IPO_MAX_RISK, "record": record, "round": int(GameState.game_data.get("round", 0))}


static func capital_market_action(player_id: String, action: String) -> Dictionary:
	var records: Dictionary = GameState.game_data.get("ipo_records", {})
	if not records.has(player_id) or str((records[player_id] as Dictionary).get("status", "")) != "listed":
		return {"ok": false, "message": "财团尚未上市"}
	var player := GameState.player(player_id)
	var record: Dictionary = records[player_id]
	var round_number := int(GameState.game_data.get("round", 0))
	var confidence := int(record.get("market_confidence", 60))
	var restricted_until := int(record.get("capital_restriction_until_round", 0))
	if action in ["issuance", "buyback", "acquisition"] and round_number < restricted_until:
		return {"ok": false, "message": "监管整改至第 %d 回合，暂不可进行资本运作" % restricted_until}
	match action:
		"disclose":
			if round_number - int(record.get("last_disclosure_round", -99)) < 2:
				return {"ok": false, "message": "经营披露每 2 回合可执行一次"}
			if int(player.get("cash", 0)) < 20:
				return {"ok": false, "message": "披露审计需要 20 万现金"}
			GameState.apply_cash(player_id, -20, "上市公司经营披露")
			record.last_disclosure_round = round_number
			record.market_confidence = mini(100, confidence + 7)
			record.disclosure_gap = maxf(0.0, float(record.get("disclosure_gap", 0.0)) - 0.04)
			player.risk = maxi(0, int(player.get("risk", 0)) - 3)
			return _capital_result(player_id, action, "完成经营披露，市场信心上升", {"cash_change": -20, "confidence_change": 7, "risk_change": -3})
		"dividend":
			if round_number - int(record.get("last_dividend_round", -99)) < 3:
				return {"ok": false, "message": "现金分红每 3 回合可执行一次"}
			var dividend := maxi(20, roundi(float(player.get("cash", 0)) * 0.08))
			if int(player.get("cash", 0)) < dividend + 50:
				return {"ok": false, "message": "需保留至少 50 万经营现金"}
			GameState.apply_cash(player_id, -dividend, "上市公司现金分红")
			var shareholder_distribution := ListedMarket.distribute_dividend(player_id, dividend)
			record.last_dividend_round = round_number
			record.market_confidence = mini(100, confidence + 10)
			player.risk = maxi(0, int(player.get("risk", 0)) - 4)
			return _capital_result(player_id, action, "完成 %d 万分红" % dividend, {"cash_change": -dividend, "confidence_change": 10, "risk_change": -4, "shareholder_paid": int(shareholder_distribution.get("paid", 0)), "shareholder_count": int(shareholder_distribution.get("recipients", 0))})
		"issuance":
			if round_number - int(record.get("last_issuance_round", -99)) < 6:
				return {"ok": false, "message": "增发融资每 6 回合可执行一次"}
			if confidence < 35:
				return {"ok": false, "message": "市场信心低于 35，增发无法获得认购"}
			var funding := maxi(80, roundi(float(player.get("asset_value", 0)) * 0.12))
			GameState.apply_cash(player_id, funding, "上市公司增发融资")
			record.last_issuance_round = round_number
			record.market_confidence = maxi(0, confidence - 12)
			player.risk = mini(100, int(player.get("risk", 0)) + 6)
			return _capital_result(player_id, action, "增发融资到账 %d 万" % funding, {"cash_change": funding, "confidence_change": -12, "risk_change": 6})
		"buyback":
			if round_number - int(record.get("last_buyback_round", -99)) < 5:
				return {"ok": false, "message": "股份回购每 5 回合可执行一次"}
			var cost := maxi(60, roundi(float(player.get("cash", 0)) * 0.10))
			if int(player.get("cash", 0)) < cost + 80:
				return {"ok": false, "message": "回购后需保留至少 80 万经营现金"}
			GameState.apply_cash(player_id, -cost, "上市公司股份回购")
			record.last_buyback_round = round_number
			var overvalued := str(current_cycle().get("phase", "")) in ["boom", "overheat"] and GameState.rng.randf() < 0.34
			record.market_confidence = maxi(0, confidence - 8) if overvalued else mini(100, confidence + 15)
			record.disclosure_gap = maxf(0.0, float(record.get("disclosure_gap", 0.0)) - 0.02)
			player.risk = maxi(0, int(player.get("risk", 0)) - 2)
			return _capital_result(player_id, action, "回购时点偏贵，市场信心下降" if overvalued else "投入 %d 万完成股份回购" % cost, {"cash_change": -cost, "confidence_change": -8 if overvalued else 15, "risk_change": -2, "overvalued": overvalued})
		"acquisition":
			if round_number - int(record.get("last_acquisition_round", -99)) < 7:
				return {"ok": false, "message": "并购整合每 7 回合可执行一次"}
			var integration_level := int(record.get("integration_level", 0))
			if integration_level >= 3:
				return {"ok": false, "message": "并购协同已达最高 3 级"}
			var operating := int(capital_market_profile(player_id).get("operating", 0))
			if operating < 4:
				return {"ok": false, "message": "至少经营 4 家企业后可进行并购整合"}
			player.erase("acquisition_cost_discount")
			player.erase("acquisition_success_bonus")
			var acquisition_cost := maxi(160, roundi(float(player.get("asset_value", 0)) * 0.08))
			if int(player.get("cash", 0)) < acquisition_cost + 100:
				return {"ok": false, "message": "并购后需保留至少 100 万经营现金"}
			GameState.apply_cash(player_id, -acquisition_cost, "上市公司并购整合")
			record.last_acquisition_round = round_number
			var success_chance := clampf(0.72 - float(player.get("risk", 0)) * 0.004 - float(integration_level) * 0.04, 0.35, 0.9)
			var success := GameState.rng.randf() < success_chance
			record.market_confidence = maxi(0, confidence - (4 if success else 16))
			player.risk = mini(100, int(player.get("risk", 0)) + (5 if success else 14))
			if success:
				record.integration_level = integration_level + 1
				return _capital_result(player_id, action, "并购整合成功，每回合协同收益提高", {"cash_change": -acquisition_cost, "confidence_change": -4, "risk_change": 5, "success": true, "success_chance": success_chance, "integration_level": int(record.integration_level), "income_per_round": int(record.integration_level) * IPO_INTEGRATION_INCOME_PER_LEVEL})
			return _capital_result(player_id, action, "并购整合失败，投入已损失并触发市场质疑", {"cash_change": -acquisition_cost, "confidence_change": -16, "risk_change": 14, "success": false, "success_chance": success_chance})
		"guidance":
			if record.has("guidance_due_round"):
				return {"ok": false, "message": "上一份业绩指引尚未到验证期"}
			if round_number - int(record.get("last_guidance_round", -99)) < 4:
				return {"ok": false, "message": "业绩指引每 4 回合最多发布一次"}
			if int(player.get("cash", 0)) < 125:
				return {"ok": false, "message": "发布指引需 25 万顾问费并保留 100 万现金"}
			GameState.apply_cash(player_id, -25, "上市公司业绩指引")
			record.last_guidance_round = round_number
			record.guidance_due_round = round_number + 2
			record.guidance_target = guidance_target(player)
			record.market_confidence = mini(100, confidence + 5)
			return _capital_result(player_id, action, "已发布两回合业绩指引，兑现承诺才能继续增信", {"cash_change": -25, "confidence_change": 5, "due_round": int(record.guidance_due_round), "target": int(record.guidance_target)})
		"innovation":
			if record.has("innovation_due_round"):
				return {"ok": false, "message": "战略研发项目仍在推进"}
			var innovation_level := int(record.get("innovation_level", 0))
			if innovation_level >= IPO_MAX_INNOVATION_LEVEL:
				return {"ok": false, "message": "战略研发已达最高 3 级"}
			var innovation_cost := maxi(180, roundi(float(player.get("asset_value", 0)) * 0.05) + innovation_level * 60)
			if int(player.get("cash", 0)) < innovation_cost + 120:
				return {"ok": false, "message": "研发投入后需保留至少 120 万现金"}
			GameState.apply_cash(player_id, -innovation_cost, "上市公司战略研发")
			record.innovation_due_round = round_number + 3
			record.innovation_cost = innovation_cost
			record.innovation_success_chance = clampf(0.72 - startup_fraud_rate() * 0.4 - float(player.get("risk", 0)) * 0.002 - float(innovation_level) * 0.07, 0.35, 0.78)
			return _capital_result(player_id, action, "战略研发已立项，三回合后验证成果", {"cash_change": -innovation_cost, "due_round": int(record.innovation_due_round), "success_chance": float(record.innovation_success_chance), "next_level": innovation_level + 1})
	return {"ok": false, "message": "未知资本市场操作"}


static func guidance_target(player: Dictionary) -> int:
	var asset_target := roundi(float(player.get("asset_value", 0)) * 0.045)
	var growth_target := roundi(float(player.get("last_round_income", 0)) * 1.18)
	return maxi(120, maxi(asset_target, growth_target))


static func _process_ipo_applications(round_number: int) -> void:
	for player_id: String in GameState.game_data.get("ipo_records", {}).keys():
		var record: Dictionary = GameState.game_data.ipo_records[player_id]
		if str(record.get("status", "")) != "preparing" or round_number < int(record.get("approval_round", 999999)):
			continue
		var player := GameState.player(player_id)
		var compliance_penalty := float(player.get("risk", 0)) * 0.004
		var passed := GameState.rng.randf() < clampf(float(record.get("approval_chance", 0.8)) - compliance_penalty, 0.35, 0.94)
		if passed:
			record.status = "listed"
			record.listed_round = round_number
			ListedMarket.initialize_listing(player_id, record)
			GameState.apply_cash(player_id, int(record.get("funding", 0)), "上市融资到账")
			GameState._record(player_id, "ipo_approved", record.duplicate(true))
		else:
			record.status = "rejected"
			record.retry_round = round_number + 4
			player.risk = mini(100, int(player.get("risk", 0)) + (12 if bool(record.get("aggressive", false)) else 7))
			GameState._record(player_id, "ipo_rejected", record.duplicate(true))


static func _process_market_commitments(round_number: int) -> void:
	for player_id: String in GameState.game_data.get("ipo_records", {}).keys():
		var record: Dictionary = GameState.game_data.ipo_records[player_id]
		if str(record.get("status", "")) != "listed":
			continue
		var player := GameState.player(player_id)
		if int(record.get("guidance_due_round", 999999)) <= round_number:
			var met := int(player.get("last_round_income", 0)) >= int(record.get("guidance_target", 0))
			record.market_confidence = clampi(int(record.get("market_confidence", 60)) + (12 if met else -20), 0, 100)
			if not met: player.risk = mini(100, int(player.get("risk", 0)) + 10)
			record.erase("guidance_due_round")
			_record_market_resolution(player_id, "业绩指引兑现" if met else "业绩指引落空", {"met": met, "target": int(record.get("guidance_target", 0)), "actual": int(player.get("last_round_income", 0))})
		if int(record.get("innovation_due_round", 999999)) <= round_number:
			var success_chance := float(record.get("innovation_success_chance", 0.5))
			var success := GameState.rng.randf() < success_chance
			if success:
				record.innovation_level = mini(IPO_MAX_INNOVATION_LEVEL, int(record.get("innovation_level", 0)) + 1)
				record.innovation_income = int(record.innovation_level) * IPO_INNOVATION_INCOME_PER_LEVEL
			record.market_confidence = clampi(int(record.get("market_confidence", 60)) + (10 if success else -10), 0, 100)
			if not success: player.risk = mini(100, int(player.get("risk", 0)) + 7)
			record.erase("innovation_due_round")
			_record_market_resolution(player_id, "战略研发转化成功" if success else "战略研发未达预期", {"success": success, "success_chance": success_chance, "innovation_level": int(record.get("innovation_level", 0)), "income_per_round": int(record.get("innovation_income", 0))})


static func _capital_result(player_id: String, action: String, message: String, changes: Dictionary) -> Dictionary:
	var record: Dictionary = GameState.game_data.ipo_records[player_id]
	var impulse: float = float({"disclose": 0.025, "dividend": 0.035, "issuance": -0.04, "guidance": 0.018, "innovation": -0.012}.get(action, 0.0))
	if action == "buyback":
		impulse = -0.045 if bool(changes.get("overvalued", false)) else 0.055
	elif action == "acquisition":
		impulse = 0.075 if bool(changes.get("success", false)) else -0.105
	ListedMarket.queue_impulse(player_id, float(impulse), message)
	var details := {"action": action, "message": message, "market_confidence": int(record.get("market_confidence", 0)), "changes": changes.duplicate(true)}
	GameState._record(player_id, "capital_market_action", details.duplicate(true))
	GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.get("round", 0)), "category": "capital_market", "player_id": player_id, "title": message, "details": details.duplicate(true)})
	return {"ok": true, "message": message, "details": details}


static func _record_market_resolution(player_id: String, title: String, details: Dictionary) -> void:
	var success := bool(details.get("success", details.get("met", false)))
	ListedMarket.queue_impulse(player_id, 0.07 if success else -0.10, title)
	GameState._record(player_id, "capital_market_resolution", details.duplicate(true))
	GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.get("round", 0)), "category": "capital_market", "player_id": player_id, "title": title, "details": details.duplicate(true)})


static func _audit_ipo(player_id: String) -> Dictionary:
	var records: Dictionary = GameState.game_data.get("ipo_records", {})
	if not records.has(player_id):
		return {}
	var record: Dictionary = records[player_id]
	var current_round := int(GameState.game_data.round)
	if current_round < int(record.get("next_audit_round", 999999)):
		return {}
	record.next_audit_round = current_round + 4
	var confidence_relief := float(record.get("market_confidence", 60)) / 100.0 * 0.08
	var chance := clampf(float(record.get("disclosure_gap", 0.0)) + startup_fraud_rate() * 0.35 - confidence_relief, 0.01, 0.85)
	var exposed := GameState.rng.randf() < chance
	var result := {"round": current_round, "player_id": player_id, "exposed": exposed, "chance": chance}
	if exposed:
		var player := GameState.player(player_id)
		var fine := mini(int(player.get("cash", 0)), maxi(60, roundi(float(record.get("funding", 0)) * 0.35)))
		GameState.apply_cash(player_id, -fine, "信息披露处罚")
		player.risk = mini(100, int(player.get("risk", 0)) + 18)
		record.exposed = true
		record.audit_strikes = int(record.get("audit_strikes", 0)) + 1
		record.market_confidence = maxi(0, int(record.get("market_confidence", 60)) - 18)
		record.disclosure_gap = maxf(0.08, float(record.get("disclosure_gap", 0.0)) * 0.55)
		record.capital_restriction_until_round = current_round + IPO_RESTRICTION_ROUNDS
		ListedMarket.queue_impulse(player_id, -0.16, "披露违规被调查")
		result.fine = fine
		result.audit_strikes = int(record.audit_strikes)
		result.restriction_until_round = int(record.capital_restriction_until_round)
		GameState.game_data.event_news.append({"id": "ipo_audit_%s_%d" % [player_id, current_round], "title": "%s披露违规被调查" % str(player.get("name", player_id)), "tags": ["金融", "监管"], "credibility": "high", "is_event": true})
	GameState.game_data.ipo_audit_history.append(result.duplicate(true))
	return result
