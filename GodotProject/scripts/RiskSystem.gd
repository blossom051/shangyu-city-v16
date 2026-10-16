class_name RiskSystem
extends RefCounted

const CRITICAL_RISK_SCORE: = 100
const CRITICAL_RISK_DEADLINE: = 3

static func adjust(player_id: String, amount: int, reason: String, category: = "经营") -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	ensure_player(player)
	var before: = clampi(int(player.get("risk", 0)), 0, 100)
	var floor: = delinquency_floor(player_id) if amount < 0 else 0
	var after: = clampi(maxi(floor, before + amount), 0, 100)
	var applied: = after - before
	player.risk = after
	if applied != 0:
		var entry: = {
			"round": int(GameState.game_data.get("round", 0)), 
			"amount": applied, 
			"reason": reason, 
			"category": category, 
			"before": before, 
			"after": after, 
		}
		player.risk_history.append(entry)
		if player.risk_history.size() > 24:
			player.risk_history = player.risk_history.slice(player.risk_history.size() - 24)
		GameState._record(player_id, "risk_changed", entry.duplicate(true))
	return {"ok": true, "before": before, "after": after, "applied": applied}


static func ensure_player(player: Dictionary) -> void :
	player.risk = clampi(int(player.get("risk", 0)), 0, 100)
	player.get_or_add("risk_history", [])
	player.get_or_add("critical_risk_rounds", 0)
	player.get_or_add("critical_risk_processed_round", -1)


static func ensure_all_players() -> void :
	for player: Dictionary in GameState.game_data.get("players", []):
		ensure_player(player)


static func profile(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {}
	ensure_player(player)
	var score: = int(player.risk)
	var recent: Array = player.risk_history.slice(maxi(0, player.risk_history.size() - 4))
	recent.reverse()
	var round_change: = 0
	var current_round: = int(GameState.game_data.get("round", 0))
	for entry: Dictionary in player.risk_history:
		if int(entry.get("round", -1)) == current_round:
			round_change += int(entry.get("amount", 0))
	var threshold: = next_threshold(score)
	var valuation: = valuation_penalty(player)
	var credit: = credit_penalty(score)
	var rate_percent: = rate_surcharge(score) * 100.0
	var land_surcharge: = land_purchase_surcharge_rate(score) * 100.0
	var build_surcharge: = build_surcharge_rate(score) * 100.0
	var floor: = delinquency_floor(player_id)
	return {
		"player_id": player_id, 
		"score": score, 
		"tier": tier_name(score), 
		"tier_color": tier_color(score), 
		"round_change": round_change, 
		"range_text": tier_range_text(score), 
		"next_threshold": threshold, 
		"points_to_next": maxi(0, threshold - score) if threshold >= 0 else 0, 
		"valuation_penalty": valuation, 
		"credit_penalty": credit, 
		"rate_surcharge": rate_surcharge(score), 
		"land_surcharge_rate": land_purchase_surcharge_rate(score), 
		"build_surcharge_rate": build_surcharge_rate(score), 
		"delinquency_floor": floor, 
		"mitigation": mitigation_multiplier(player), 
		"recent": recent, 
		"next_tier": next_tier_text(score), 
		"impacts": [
			{"id": "valuation", "label": "资产估值", "amount": valuation, "unit": "万", "display": "-%d 万" % valuation, "note": "回合与终局净值扣减"}, 
			{"id": "credit", "label": "银行授信", "amount": credit, "unit": "万", "display": "-%d 万" % credit, "note": "每 1 风险减少 2 万授信"}, 
			{"id": "rate", "label": "贷款利率", "amount": rate_percent, "unit": "%", "display": "+%.2f%%" % rate_percent, "note": "新增贷款的风险加息"}, 
			{"id": "land", "label": "拿地成本", "amount": land_surcharge, "unit": "%", "display": "+%.0f%%" % land_surcharge, "note": "尽调与交易担保附加成本"}, 
			{"id": "build", "label": "建设成本", "amount": build_surcharge, "unit": "%", "display": "+%.0f%%" % build_surcharge, "note": "高风险企业合规附加成本"}, 
		], 
	}


static func tier_name(score: int) -> String:
	if score >= 80:
		return "危机"
	if score >= 60:
		return "危险"
	if score >= 40:
		return "高压"
	if score >= 20:
		return "关注"
	return "稳健"


static func tier_color(score: int) -> Color:
	if score >= 80:
		return Color("dc5664")
	if score >= 60:
		return Color("ea815e")
	if score >= 40:
		return Color("e6aa58")
	if score >= 20:
		return Color("d6c05a")
	return Color("64c89b")


static func tier_range_text(score: int) -> String:
	if score >= 80:
		return "80–100"
	if score >= 60:
		return "60–79"
	if score >= 40:
		return "40–59"
	if score >= 20:
		return "20–39"
	return "0–19"


static func next_threshold(score: int) -> int:
	for threshold: int in [20, 40, 60, 80]:
		if score < threshold:
			return threshold
	return -1


static func credit_penalty(score: int) -> int:
	return clampi(score, 0, 100) * 2


static func rate_surcharge(score: int) -> float:
	return float(clampi(score, 0, 80)) * 0.0005


static func land_purchase_surcharge_rate(score: int) -> float:
	if score >= 80:
		return 0.18
	if score >= 60:
		return 0.1
	if score >= 40:
		return 0.05
	return 0.0


static func build_surcharge_rate(score: int) -> float:
	if score >= 80:
		return 0.12
	if score >= 60:
		return 0.07
	if score >= 40:
		return 0.03
	return 0.0


static func delinquency_floor(player_id: String) -> int:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 0
	var max_overdue: = 0
	for loan: Dictionary in player.get("loans", []):
		if str(loan.get("kind", "")) == "judicial_residual":
			return mini(92, 64 + int(loan.get("residual_rounds", 0)) * 8)
		if int(loan.get("unpaid_interest", 0)) > 0 or int(loan.get("unpaid_principal", 0)) > 0 or int(loan.get("overdue_fee", 0)) > 0:
			max_overdue = maxi(max_overdue, int(loan.get("overdue", 0)))
	if max_overdue >= 3:
		return 64
	if max_overdue == 2:
		return 42
	if max_overdue == 1:
		return 24
	return 0


static func governance_options(player_id: String) -> Array[Dictionary]:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return []
	var used: = int(player.get("risk_governance_round", -1)) == int(GameState.game_data.get("round", 0))
	var floor: = delinquency_floor(player_id)
	var score: = int(player.get("risk", 0))
	var cash: = int(player.get("cash", 0))
	var options: Array[Dictionary] = [
		{"id": "internal_audit", "title": "内控审计", "cost": 30, "risk_reduction": 8, "used": used, "description": "梳理经营漏洞，本回合风险 -8"}, 
		{"id": "risk_reserve", "title": "风险准备金", "cost": 55, "risk_reduction": 15, "used": used, "description": "建立专项准备金，本回合风险 -15"}, 
	]
	for option: Dictionary in options:
		var reason: = ""
		if used:
			reason = "本回合已经执行过一次主动治理"
		elif score <= floor:
			reason = "逾期风险底线为 %d，请先处理欠款" % floor if floor > 0 else "当前风险为 0，无需治理"
		elif cash < int(option.cost):
			reason = "现金不足，需要 %d 万" % int(option.cost)
		option.disabled = not reason.is_empty()
		option.disabled_reason = reason
	var debt_reason: = "" if floor > 0 else "当前没有逾期账单"
	options.append({"id": "resolve_debt", "title": "处理贷款逾期", "cost": 0, "risk_reduction": 0, "used": false, "redirect": "bank", "description": "进入银行补齐账单，解除违约风险底线", "disabled": not debt_reason.is_empty(), "disabled_reason": debt_reason})
	return options


static func perform_governance(player_id: String, action_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	if action_id == "resolve_debt":
		return {"ok": true, "message": "请前往银行处理逾期账单", "redirect": "bank"}
	if int(player.get("risk_governance_round", -1)) == int(GameState.game_data.get("round", 0)):
		return {"ok": false, "message": "本回合已经执行过一次风险治理"}
	var selected: Dictionary = {}
	for option: Dictionary in governance_options(player_id):
		if str(option.get("id", "")) == action_id:
			selected = option
			break
	if selected.is_empty() or int(selected.get("risk_reduction", 0)) <= 0:
		return {"ok": false, "message": "无效治理行动"}
	var floor: = delinquency_floor(player_id)
	if int(player.get("risk", 0)) <= floor:
		return {"ok": false, "message": "当前风险受逾期底线限制，请先到银行处理欠款" if floor > 0 else "当前风险已经处于最低水平"}
	var cost: = int(selected.get("cost", 0))
	if int(player.get("cash", 0)) < cost:
		return {"ok": false, "message": "现金不足，需要 %d 万" % cost}
	if not GameState.apply_cash(player_id, - cost, str(selected.get("title", "风险治理"))):
		return {"ok": false, "message": "治理费用扣款失败"}
	var before: = int(player.get("risk", 0))
	var result: = adjust(player_id, - int(selected.get("risk_reduction", 0)), str(selected.get("title", "风险治理")), "主动治理")
	player.risk_governance_round = int(GameState.game_data.get("round", 0))
	GameState._record(player_id, "risk_governance", {
		"action_id": action_id, "cost": cost, "risk_before": before, 
		"risk_after": int(player.get("risk", 0)), "floor": floor, 
	})
	return {
		"ok": true, "message": "%s完成：现金 -%d 万，风险 %d → %d" % [str(selected.get("title", "风险治理")), cost, before, int(player.get("risk", 0))], 
		"cost": cost, "risk_before": before, "risk_after": int(player.get("risk", 0)), 
		"applied": int(result.get("applied", 0)), 
	}


static func apply_end_round_recovery(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "risk_reduced": 0}
	ensure_player(player)
	if int(player.get("risk", 0)) >= CRITICAL_RISK_SCORE:
		player.risk_quiet_rounds = 0
		return {"ok": true, "risk_reduced": 0, "reason": "critical_risk_requires_active_governance"}
	if delinquency_floor(player_id) > 0:
		player.risk_quiet_rounds = 0
		return {"ok": true, "risk_reduced": 0, "reason": "active_delinquency"}
	var round_number: = int(GameState.game_data.get("round", 0))
	var positive_change: = false
	for entry: Dictionary in player.get("risk_history", []):
		if int(entry.get("round", -1)) == round_number and int(entry.get("amount", 0)) > 0:
			positive_change = true
			break
	if positive_change:
		player.risk_quiet_rounds = 0
		return {"ok": true, "risk_reduced": 0, "reason": "new_risk"}
	player.risk_quiet_rounds = int(player.get("risk_quiet_rounds", 0)) + 1
	if int(player.risk_quiet_rounds) < 2 or int(player.get("risk", 0)) <= 0:
		return {"ok": true, "risk_reduced": 0, "quiet_rounds": int(player.risk_quiet_rounds)}
	var before: = int(player.risk)
	adjust(player_id, -3, "连续两轮稳定经营", "自然恢复")
	return {"ok": true, "risk_reduced": before - int(player.risk), "quiet_rounds": int(player.risk_quiet_rounds)}


static func process_critical_risk_round(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"ok": false, "message": "玩家不存在"}
	ensure_player(player)
	var round_number: = int(GameState.game_data.get("round", 0))
	if int(player.get("critical_risk_processed_round", -1)) == round_number:
		return _critical_risk_status(player)
	player.critical_risk_processed_round = round_number
	if int(player.get("risk", 0)) >= CRITICAL_RISK_SCORE:
		player.critical_risk_rounds = int(player.get("critical_risk_rounds", 0)) + 1
	else:
		player.critical_risk_rounds = 0
	var status: = _critical_risk_status(player)
	GameState._record(player_id, "critical_risk_round_processed", {
		"round": round_number, 
		"risk": int(player.get("risk", 0)), 
		"critical_rounds": int(status.critical_rounds), 
		"deadline": CRITICAL_RISK_DEADLINE, 
		"bankruptcy_pending": bool(status.bankruptcy_pending), 
	})
	return status


static func _critical_risk_status(player: Dictionary) -> Dictionary:
	var critical_rounds: = int(player.get("critical_risk_rounds", 0))
	return {
		"ok": true, 
		"risk": int(player.get("risk", 0)), 
		"critical_rounds": critical_rounds, 
		"deadline": CRITICAL_RISK_DEADLINE, 
		"bankruptcy_pending": int(player.get("risk", 0)) >= CRITICAL_RISK_SCORE and critical_rounds >= CRITICAL_RISK_DEADLINE, 
	}


static func mitigation_multiplier(player: Dictionary) -> float:
	var company: = GameConfig.by_id("investment_companies", str(player.get("company_id", "")))
	var multiplier: = float(company.get("abilities", {}).get("risk_loss_multiplier", 1.0))
	for guard: Dictionary in player.get("guards", []):
		if str(guard.get("effect", "")) == "risk_loss_multiplier":
			multiplier *= float(guard.get("value", 1.0))
	for effect: Dictionary in player.get("effects", []):
		if str(effect.get("kind", "")) == "risk_loss_multiplier":
			multiplier *= float(effect.get("value", 1.0))
	return maxf(0.0, multiplier)


static func valuation_penalty(player: Dictionary) -> int:
	return roundi(float(clampi(int(player.get("risk", 0)), 0, 100)) * mitigation_multiplier(player))


static func next_tier_text(score: int) -> String:
	for threshold: int in [20, 40, 60, 80]:
		if score < threshold:
			return "距下一档还差 %d 点" % (threshold - score)
	return "已处于最高风险档"
