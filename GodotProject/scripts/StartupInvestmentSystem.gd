class_name StartupInvestmentSystem
extends RefCounted

const Bank = preload("res://scripts/BankSystem.gd")
const MarketImpacts = preload("res://scripts/MarketImpactSystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const ConditionalCatalog = preload("res://scripts/ConditionalEventCatalog.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")


static func initialize_match(round_limit: int) -> void :
	var event_count: = 1 if round_limit <= 10 else 2 if round_limit <= 16 else 3
	var schedule: Array[int] = []
	for index in range(event_count):
		var center: = roundi(float(index + 1) * float(round_limit) / float(event_count + 1))
		var event_round: = clampi(center + GameState.rng.randi_range(-1, 1), 2, maxi(2, round_limit - 2))
		while schedule.has(event_round) and event_round < round_limit - 2:
			event_round += 1
		while schedule.has(event_round) and event_round > 2:
			event_round -= 1
		schedule.append(event_round)
	schedule.sort()
	GameState.game_data.startup_schedule = schedule
	GameState.game_data.startup_offers = {}
	GameState.game_data.startup_offer_history = []
	GameState.game_data.startup_result_notices = []


static func event_rounds() -> Array:
	return GameState.game_data.get("startup_schedule", []).duplicate()


static func is_event_round(round_number: int = -1) -> bool:
	var current: = int(GameState.game_data.get("round", 0)) if round_number < 0 else round_number
	return GameState.game_data.get("startup_schedule", []).has(current)


static func next_event_round(after_round: int = -1) -> int:
	var current: = int(GameState.game_data.get("round", 0)) if after_round < 0 else after_round
	for value: Variant in GameState.game_data.get("startup_schedule", []):
		if int(value) > current:
			return int(value)
	return -1


static func projects_for_round(round_number: int = -1) -> Array:
	var current: = int(GameState.game_data.get("round", 0)) if round_number < 0 else round_number
	if not is_event_round(current):
		return []
	var key: = str(current)
	var offers: Dictionary = GameState.game_data.get("startup_offers", {})
	if not offers.has(key):
		var pool: Array = GameConfig.list("startup_projects").duplicate(true)
		pool.append_array(ConditionalCatalog.startup_projects().filter( func(project: Dictionary) -> bool: return ConditionalCatalog.eligible(project)))
		var history: Array = GameState.game_data.get("startup_offer_history", [])
		var unseen: Array = pool.filter(func(project: Dictionary) -> bool: return not history.has(str(project.get("id", ""))))
		if unseen.size() >= 3:
			pool = unseen
		else:
			history.clear()
		_shuffle_with_match_rng(pool)
		var cycle_phase := str(EndlessOperationsSystem.current_cycle().get("phase", "standard"))
		var offer_count := 4 if EndlessOperationsSystem.is_enabled() and cycle_phase == "boom" else 3
		offers[key] = pool.slice(0, mini(offer_count, pool.size())).map( func(project: Dictionary) -> String: return str(project.id))
		for offered_id: String in offers[key]:
			if not history.has(offered_id):
				history.append(offered_id)
		GameState.game_data.startup_offers = offers
		GameState.game_data.startup_offer_history = history
	var projects: Array = []
	for project_id: Variant in offers[key]:
		projects.append(_project_by_id(str(project_id)).duplicate(true))
	return projects


static func project_by_id(project_id: String) -> Dictionary:
	return _project_by_id(project_id).duplicate(true)


static func investment_preview(player_id: String, project_id: String) -> Dictionary:
	var player := GameState.player(player_id)
	var project := _project_by_id(project_id)
	if player.is_empty() or project.is_empty():
		return _fail("项目无效")
	var breakdown := _success_breakdown(player_id, project)
	var cycle := EndlessOperationsSystem.current_cycle()
	return _ok("尽调摘要已生成", {
		"project": project.duplicate(true),
		"cost": int(project.get("cost", 0)),
		"cash_after": int(player.get("cash", 0)) - int(project.get("cost", 0)),
		"expected_financing": roundi(float(project.get("cost", 0)) * float(project.get("financing_multiplier", 1.8))),
		"duration": clampi(int(project.get("delay", 1)), 1, 2),
		"base_success": float(project.get("base_success", 0.52)),
		"success_rate": float(breakdown.get("total", 0.0)),
		"success_breakdown": breakdown,
		"cycle": cycle,
		"fraud_rate": EndlessOperationsSystem.startup_fraud_rate(),
	})


static func invest(player_id: String, project_id: String) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("startup_invest", {"player_id": player_id, "project_id": project_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var project: = _project_by_id(project_id)
	if player.is_empty() or project.is_empty():
		return _fail("项目无效")
	if not is_event_round() or not projects_for_round().any( func(offer: Dictionary) -> bool: return str(offer.id) == project_id):
		return _fail("本回合没有该创投项目")
	if player.active_projects.any( func(item: Dictionary) -> bool: return str(item.project_id) == project_id):
		return _fail("本局已投资过该项目")
	if int(player.cash) < int(project.cost):
		return _fail("投资资金不足")
	GameState.apply_cash(player_id, - int(project.cost), "创业项目首轮投资")
	var success_rate: = _success_rate(player_id, project)
	var duration: = clampi(int(project.get("delay", 1)), 1, 2)
	var expected_financing: = roundi(float(project.cost) * float(project.get("financing_multiplier", 1.8)))
	var active_project: = {
		"project_id": project_id, 
		"founder": str(project.founder), 
		"sector": str(project.get("sector", "consumer")), 
		"cost": int(project.cost), 
		"status": "active", 
		"remaining_rounds": duration, 
		"success_rate": success_rate, 
		"expected_financing": expected_financing, 
		"current_valuation": roundi(float(project.cost) * 0.55), 
		"resolved": false, 
		"fraudulent": EndlessOperationsSystem.is_enabled() and GameState.rng.randf() < EndlessOperationsSystem.startup_fraud_rate(),
	}
	player.active_projects.append(active_project)
	GameState._record(player_id, "startup_invest", {"project_id": project_id, "founder": str(project.founder), "cost": int(project.cost), "success_rate": success_rate})
	_append_ledger(player_id, "%s完成投资决策" % str(project.name), {"project_id": project_id, "founder": str(project.founder), "cost": int(project.cost), "remaining_rounds": duration})
	return _ok("已投资，%d 回合后揭晓" % duration, {"project": active_project.duplicate(true), "invested": int(project.cost), "cash_after": int(player.cash), "success_rate": success_rate, "remaining_rounds": duration, "expected_financing": expected_financing})


static func settle(player_id: String) -> Array:
	var player: = GameState.player(player_id)
	var stories: Array = []
	for item: Dictionary in player.get("active_projects", []):
		if bool(item.get("resolved", false)) or str(item.get("status", "")) != "active":
			continue
		item.remaining_rounds = int(item.remaining_rounds) - 1
		if int(item.remaining_rounds) > 0:
			continue
		var project: = _project_by_id(str(item.project_id))
		var succeeded: = not bool(item.get("fraudulent", false)) and GameState.rng.randf() <= float(item.success_rate)
		item.resolved = true
		if succeeded:
			_resolve_success(player, item, project)
			var success_story: = _result_story(player_id, item, project, "success")
			stories.append(success_story)
			_queue_result_notice(success_story)
			GameState._record(player_id, "startup_resolved", {"project_id": str(item.project_id), "outcome": "success", "cost": int(item.cost), "cash_return": int(item.expected_financing), "valuation": int(item.current_valuation)})
		else:
			_resolve_failure(player, item, project)
			var failure_story: = _result_story(player_id, item, project, "failure")
			stories.append(failure_story)
			_queue_result_notice(failure_story)
			GameState._record(player_id, "startup_resolved", {"project_id": str(item.project_id), "outcome": "failure", "cost": int(item.cost), "cash_return": 0, "valuation": 0})
	return stories


static func pop_result_notice(player_id: String) -> Dictionary:
	var notices: Array = GameState.game_data.get("startup_result_notices", [])
	for index in range(notices.size()):
		var notice: Dictionary = notices[index]
		if str(notice.get("player_id", "")) == player_id:
			notices.remove_at(index)
			GameState.game_data.startup_result_notices = notices
			return notice.duplicate(true)
	return {}


static func pending_result_count(player_id: String) -> int:
	return GameState.game_data.get("startup_result_notices", []).filter( func(notice: Dictionary) -> bool: return str(notice.get("player_id", "")) == player_id).size()


static func _result_story(player_id: String, item: Dictionary, project: Dictionary, outcome: String) -> Dictionary:
	return {
		"player_id": player_id, 
		"project_id": str(item.get("project_id", "")), 
		"project_name": str(project.get("name", item.get("project_id", "创业项目"))), 
		"founder": str(item.get("founder", "创始人")), 
		"sector": str(item.get("sector", "consumer")), 
		"outcome": outcome, 
		"cost": int(item.get("cost", 0)), 
		"cash_return": int(item.get("expected_financing", 0)) if outcome == "success" else 0, 
		"valuation_gain": int(item.get("current_valuation", 0)) if outcome == "success" else 0, 
		"profit_loss": (int(item.get("expected_financing", 0)) - int(item.get("cost", 0))) if outcome == "success" else - int(item.get("cost", 0)), 
		"risk_change": 0 if outcome == "success" else 8, 
		"resolved_round": int(GameState.game_data.get("round", 0)), 
	}


static func _queue_result_notice(story: Dictionary) -> void :
	var notices: Array = GameState.game_data.get("startup_result_notices", [])
	notices.append(story.duplicate(true))
	GameState.game_data.startup_result_notices = notices


static func unresolved_value(player_id: String) -> int:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 0
	var total: = 0
	for item: Dictionary in player.get("active_projects", []):
		if str(item.get("status", "")) == "active" and not bool(item.get("resolved", false)):
			total += int(item.get("current_valuation", 0))
	return total


static func _resolve_success(player: Dictionary, item: Dictionary, project: Dictionary) -> void :
	item.status = "success"
	item.current_valuation = roundi(float(item.cost) * 1.5)
	GameState.apply_cash(str(player.id), int(item.expected_financing), "创业项目融资到账")
	player.investment_track_record = int(player.get("investment_track_record", 0)) + 1
	player.enterprise_valuation = int(player.get("enterprise_valuation", 0)) + int(item.current_valuation)
	player.next_project_bonus = 0.0
	MarketImpacts.add(str(item.sector), 0.06, "project_success", str(player.id), {"project_id": str(item.project_id), "founder": str(item.founder)})
	_append_ledger(str(player.id), "%s投资退出成功" % str(project.name), {"outcome": "success", "founder": str(item.founder), "cash_return": int(item.expected_financing), "valuation_gain": int(item.current_valuation), "sector": str(item.sector)})


static func _resolve_failure(player: Dictionary, item: Dictionary, project: Dictionary) -> void :
	item.status = "failed"
	item.current_valuation = 0
	Risks.adjust(str(player.id), 8, "创投项目失败", "创投")
	player.investment_experience = int(player.get("investment_experience", 0)) + 1
	player.next_project_bonus = minf(0.15, float(player.get("next_project_bonus", 0.0)) + 0.05)
	MarketImpacts.add(str(item.sector), -0.03, "project_failure", str(player.id), {"project_id": str(item.project_id), "founder": str(item.founder)})
	_append_ledger(str(player.id), "%s投资失败" % str(project.name), {"outcome": "failure", "founder": str(item.founder), "risk_gain": 8, "next_project_bonus": float(player.next_project_bonus), "sector": str(item.sector)})


static func _success_rate(player_id: String, project: Dictionary) -> float:
	return float(_success_breakdown(player_id, project).get("total", 0.15))


static func _success_breakdown(player_id: String, project: Dictionary) -> Dictionary:
	var player: = GameState.player(player_id)
	var base := float(project.get("base_success", 0.52))
	var cycle := EndlessOperationsSystem.startup_success_modifier()
	var company := CompanyRules.first_startup_success_bonus(player)
	var bank := Bank.project_success_modifier(player_id)
	var experience := float(player.get("next_project_bonus", 0.0))
	var max_control: = 0.0
	for control: Variant in player.get("district_influence", {}).values():
		max_control = maxf(max_control, float(control))
	var control_bonus := minf(0.08, max_control * 0.1)
	var talent_bonus := 0.0
	for talent_id: String in player.get("talent_ids", []):
		var talent: = GameConfig.by_id("talents", talent_id)
		if str(talent.get("stat", "")) == "invest":
			talent_bonus += float(talent.get("value", 0.0)) * 0.25
	var total := clampf(base + cycle + company + bank + experience + control_bonus + talent_bonus, 0.15, 0.9)
	return {"base": base, "cycle": cycle, "company": company, "bank": bank, "experience": experience, "control": control_bonus, "talent": talent_bonus, "total": total}


static func _append_ledger(player_id: String, title: String, details: Dictionary) -> void :
	GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.get("round", 0)), "category": "project_investment", "player_id": player_id, "title": title, "details": details.duplicate(true)})


static func _shuffle_with_match_rng(values: Array) -> void :
	for index in range(values.size() - 1, 0, -1):
		var other: = GameState.rng.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[other]
		values[other] = value


static func _project_by_id(project_id: String) -> Dictionary:
	var project: = GameConfig.by_id("startup_projects", project_id)
	if not project.is_empty(): return project
	for candidate: Dictionary in ConditionalCatalog.startup_projects():
		if str(candidate.id) == project_id: return candidate
	return {}


static func _ok(message: String, details: = {}) -> Dictionary:
	var result: = {"ok": true, "message": message, "details": details}
	result.merge(details, true)
	return result


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
