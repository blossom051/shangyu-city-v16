class_name CompanyAbilityEngine
extends RefCounted

const ParcelGeometry = preload("res://scripts/LandParcelGeometry.gd")
const Risks = preload("res://scripts/RiskSystem.gd")

const KNOWN_ABILITY_KEYS: Array[String] = [
	"fixed_cost_multiplier", "risk_loss_multiplier", "event_guard_every", 
	"income_tags", "income_multiplier", "income_start_round", "public_opinion_penalty_multiplier", 
	"startup_hint", "loan_limit", "first_loan_interest_multiplier", "debt_penalty_multiplier", 
	"first_startup_success_bonus", 
	"build_cost_multiplier", "adjacency_income_multiplier", "stock_profit_multiplier", 
	"auction_rebate_rate", "auction_rebate_cap", "low_cash_threshold", "low_cash_risk", 
	"opening_red_ids", "extra_draw_every", 
]


static func definition(company_id: String) -> Dictionary:
	return GameConfig.by_id("investment_companies", company_id)


static func abilities(company_id: String) -> Dictionary:
	return definition(company_id).get("abilities", {})


static func numeric_ability(company_id: String, key: String, fallback: float) -> float:
	return float(abilities(company_id).get(key, fallback))


static func bool_ability(company_id: String, key: String, fallback: = false) -> bool:
	return bool(abilities(company_id).get(key, fallback))


static func array_ability(company_id: String, key: String) -> Array:
	var value: Variant = abilities(company_id).get(key, [])
	return value if value is Array else []


static func income_multiplier(company_id: String, business_type: Dictionary, round_number: = -1) -> float:
	var rule: = abilities(company_id)
	var eligible_tags: Array = rule.get("income_tags", [])
	if eligible_tags.is_empty():
		return 1.0
	var tags: Array = business_type.get("tags", [])
	if not tags.any( func(tag: Variant) -> bool: return eligible_tags.has(str(tag))):
		return 1.0
	var starts_at: = int(rule.get("income_start_round", 1))
	var current_round: = round_number
	if current_round < 0 and not GameState.game_data.is_empty():
		current_round = int(GameState.game_data.get("round", 1))
	if current_round < starts_at:
		return 1.0
	return float(rule.get("income_multiplier", 1.0))


static func fixed_cost_multiplier(company_id: String) -> float:
	return numeric_ability(company_id, "fixed_cost_multiplier", 1.0)


static func risk_loss_multiplier(company_id: String) -> float:
	return numeric_ability(company_id, "risk_loss_multiplier", 1.0)


static func build_cost_multiplier(company_id: String) -> float:
	return numeric_ability(company_id, "build_cost_multiplier", 1.0)


static func public_opinion_penalty_multiplier(company_id: String) -> float:
	return numeric_ability(company_id, "public_opinion_penalty_multiplier", 1.0)


static func stock_profit_multiplier(company_id: String) -> float:
	return numeric_ability(company_id, "stock_profit_multiplier", 1.0)


static func blocks_negative_event(player: Dictionary, event_id: String, round_number: int) -> bool:
	var every: = int(numeric_ability(str(player.get("company_id", "")), "event_guard_every", 0.0))
	if every <= 0 or round_number < every:
		return false
	var state: Dictionary = player.get("ability_state", {})
	_refresh_event_guard(player, round_number)
	state = player.get("ability_state", {})
	if not bool(state.get("event_guard_ready", false)):
		return false
	state.event_guard_ready = false
	state.blocked_event_id = event_id
	player.ability_state = state
	GameState._record(str(player.id), "company_ability_triggered", {"ability": "event_guard_shield_consumed", "event_id": event_id, "round": round_number})
	return true


static func _refresh_event_guard(player: Dictionary, round_number: int) -> void :
	var every: = int(numeric_ability(str(player.get("company_id", "")), "event_guard_every", 0.0))
	if every <= 0:
		return
	var cycle: = floori(float(round_number) / float(every))
	var state: Dictionary = player.get("ability_state", {})
	if cycle <= int(state.get("event_guard_cycle", 0)):
		return
	state.event_guard_cycle = cycle
	state.event_guard_ready = true
	player.ability_state = state
	GameState._record(str(player.id), "company_ability_ready", {"ability": "event_guard_shield", "round": round_number, "cycle": cycle})


static func adjacency_income_multiplier(player: Dictionary, business: Dictionary) -> float:
	var multiplier: = numeric_ability(str(player.get("company_id", "")), "adjacency_income_multiplier", 1.0)
	if multiplier <= 1.0:
		return 1.0
	var origin: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
	if origin.is_empty():
		return 1.0
	for land_id: String in player.get("land_ids", []):
		if land_id == str(origin.id):
			continue
		var neighbor: Dictionary = GameState.game_data.lands.get(land_id, {})
		if not neighbor.is_empty() and ParcelGeometry.are_adjacent(origin, neighbor):
			return multiplier
	return 1.0


static func apply_end_round(player: Dictionary) -> Dictionary:
	_refresh_event_guard(player, int(GameState.game_data.get("round", 0)))
	var threshold: = int(numeric_ability(str(player.get("company_id", "")), "low_cash_threshold", 0.0))
	var risk: = int(numeric_ability(str(player.get("company_id", "")), "low_cash_risk", 0.0))
	var state: Dictionary = player.get("ability_state", {})
	var round_number: = int(GameState.game_data.get("round", 0))
	if threshold <= 0 or risk <= 0 or GameState.available_cash(str(player.id)) >= threshold or int(state.get("low_cash_round", -1)) == round_number:
		return {"triggered": false}
	Risks.adjust(str(player.id), risk, "激进经营现金压力", "财团特性")
	state.low_cash_round = round_number
	player.ability_state = state
	GameState._record(str(player.id), "company_ability_triggered", {"ability": "low_cash_risk", "risk": risk, "round": round_number})
	return {"triggered": true, "risk": risk}


static func apply_auction_win_rebate(player_id: String, paid: int, asset_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {"triggered": false}
	var rate: = numeric_ability(str(player.company_id), "auction_rebate_rate", 0.0)
	var cap: = int(numeric_ability(str(player.company_id), "auction_rebate_cap", 0.0))
	var state: Dictionary = player.get("ability_state", {})
	if rate <= 0.0 or cap <= 0 or bool(state.get("auction_rebate_used", false)) or paid <= 0:
		return {"triggered": false}
	var rebate: = mini(cap, roundi(float(paid) * rate))
	if rebate <= 0 or not GameState.apply_cash(player_id, rebate, "赤焰强势成交返利"):
		return {"triggered": false}
	state.auction_rebate_used = true
	player.ability_state = state
	var receipt: = {"triggered": true, "ability": "auction_rebate", "asset_id": asset_id, "paid": paid, "rebate": rebate, "round": int(GameState.game_data.get("round", 0))}
	GameState._record(player_id, "company_ability_triggered", receipt)
	return receipt


static func first_startup_success_bonus(player: Dictionary) -> float:
	var bonus: = numeric_ability(str(player.get("company_id", "")), "first_startup_success_bonus", 0.0)
	var state: Dictionary = player.get("ability_state", {})
	if bonus <= 0.0 or bool(state.get("startup_bonus_used", false)):
		return 0.0
	state.startup_bonus_used = true
	player.ability_state = state
	GameState._record(str(player.id), "company_ability_triggered", {"ability": "first_startup_success_bonus", "bonus": bonus, "round": int(GameState.game_data.get("round", 0))})
	return bonus


static func should_award_regular_draw_bonus(player: Dictionary) -> bool:
	var every: = int(numeric_ability(str(player.get("company_id", "")), "extra_draw_every", 0.0))
	if every <= 0:
		return false
	var state: Dictionary = player.get("ability_state", {})
	var count: = int(state.get("regular_draw_count", 0)) + 1
	state.regular_draw_count = count
	player.ability_state = state
	if count % every != 0:
		return false
	GameState._record(str(player.id), "company_ability_triggered", {"ability": "deterministic_extra_draw", "draw_count": count, "round": int(GameState.game_data.get("round", 0))})
	return true


static func validate_registry() -> Dictionary:
	var errors: Array[String] = []
	var companies: Array = GameConfig.list("investment_companies")
	if companies.size() != 8:
		errors.append("investment company registry must contain eight companies")
	for company: Dictionary in companies:
		var company_id: = str(company.get("id", ""))
		var company_abilities: Dictionary = company.get("abilities", {})
		if company_abilities.is_empty():
			errors.append("%s has no executable abilities" % company_id)
		for key: Variant in company_abilities.keys():
			if not KNOWN_ABILITY_KEYS.has(str(key)):
				errors.append("%s uses unknown ability key %s" % [company_id, str(key)])
	return {"ok": errors.is_empty(), "errors": errors}
