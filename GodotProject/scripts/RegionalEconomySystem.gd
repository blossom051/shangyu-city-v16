class_name RegionalEconomySystem
extends RefCounted

static var GameState:
	get: return Engine.get_main_loop().root.get_node("/root/GameState")
static var GameConfig:
	get: return Engine.get_main_loop().root.get_node("/root/GameConfig")

const METRICS: = ["commercial_heat", "industry_concentration", "technology_activity", "finance_activity", "residential_prosperity", "traffic_access", "risk", "land_price_index", "market_attention"]
const DEFAULT_VALUE: = 100.0
const RISK_DEFAULT: = 18.0
const DISTRICT_BIASES: = {
	"education": {"technology_activity": 8.0, "residential_prosperity": 3.0}, 
	"medical": {"residential_prosperity": 7.0, "risk": -3.0}, 
	"finance": {"finance_activity": 12.0, "market_attention": 7.0}, 
	"commercial": {"commercial_heat": 12.0, "market_attention": 6.0}, 
	"residential": {"residential_prosperity": 12.0, "risk": -2.0}, 
	"entertainment": {"commercial_heat": 8.0, "market_attention": 9.0}, 
	"waterfront": {"traffic_access": 8.0, "industry_concentration": 5.0}, 
}


static func initialize() -> void :
	var regions: = {}
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		var district_id: = str(land.get("district", "unknown"))
		if regions.has(district_id):
			continue
		var state: = {"id": district_id, "name": str(land.get("district_name", district_id)), "pending": {}, "trend": {}, "reasons": []}
		for metric: String in METRICS:
			state[metric] = RISK_DEFAULT if metric == "risk" else DEFAULT_VALUE
			state.pending[metric] = 0.0
			state.trend[metric] = 0.0
		for metric: String in DISTRICT_BIASES.get(district_id, {}):
			state[metric] = float(state[metric]) + float(DISTRICT_BIASES[district_id][metric])
		regions[district_id] = state
	GameState.game_data.regional_economy = regions


static func ensure_state() -> void :
	if not GameState.game_data.has("regional_economy") or GameState.game_data.regional_economy.is_empty():
		initialize()


static func observe_action(player_id: String, kind: String, data: Dictionary) -> void :
	ensure_state()
	var district_id: = _district_from_action(data)
	if district_id.is_empty() or not GameState.game_data.regional_economy.has(district_id):
		return
	match kind:
		"buy_land", "auction_won":
			_queue(district_id, {"land_price_index": 1.2, "market_attention": 2.0}, "%s完成土地交易" % _player_name(player_id))
		"build_business":
			var type: Dictionary = GameConfig.by_id("business_types", str(data.get("type_id", "")))
			_queue(district_id, _business_delta(type), "%s启动%s建设" % [_player_name(player_id), str(type.get("name", "企业"))])
		"assign_talent":
			_queue(district_id, {"technology_activity": 0.8, "market_attention": 0.4}, "%s配置关键人才" % _player_name(player_id))
		"play_card":
			_queue(district_id, {"risk": 2.0, "market_attention": 1.4}, "%s发动区域策略" % _player_name(player_id))
		"stock_trade":
			_queue(district_id, {"finance_activity": 0.5, "market_attention": 0.7}, "资本流向发生变化")


static func advance_round() -> Array[Dictionary]:
	ensure_state()
	var changes: Array[Dictionary] = []
	for district_id: String in GameState.game_data.regional_economy:
		var state: Dictionary = GameState.game_data.regional_economy[district_id]
		for metric: String in METRICS:
			var before: = float(state.get(metric, RISK_DEFAULT if metric == "risk" else DEFAULT_VALUE))
			var neutral: = RISK_DEFAULT if metric == "risk" else DEFAULT_VALUE
			var pending: = float(state.pending.get(metric, 0.0))
			var next: = before + pending * 0.62 + (neutral - before) * (0.035 if metric != "risk" else 0.06)
			var minimum: = 0.0 if metric == "risk" else 65.0
			var maximum: = 100.0 if metric == "risk" else 145.0
			next = clampf(next, minimum, maximum)
			state.trend[metric] = next - before
			state[metric] = snappedf(next, 0.1)
			state.pending[metric] = 0.0
		if absf(float(state.trend.market_attention)) >= 0.4 or absf(float(state.trend.land_price_index)) >= 0.4:
			changes.append({"district_id": district_id, "name": str(state.name), "attention_change": float(state.trend.market_attention), "land_change": float(state.trend.land_price_index), "reason": str(state.reasons[-1]) if not state.reasons.is_empty() else "区域经营累积"})
		state.reasons = state.reasons.slice(maxi(0, state.reasons.size() - 5))
	return changes


static func business_income_multiplier(business: Dictionary, land: Dictionary) -> float:
	ensure_state()
	var state: Dictionary = GameState.game_data.regional_economy.get(str(land.get("district", "")), {})
	if state.is_empty():
		return 1.0
	var type: Dictionary = GameConfig.by_id("business_types", str(business.get("type_id", "")))
	var sector: = str(type.get("sector", "consumer"))
	var driver: = _sector_metric(sector)
	var activity: = float(state.get(driver, 100.0))
	var traffic: = float(state.get("traffic_access", 100.0))
	var risk: = float(state.get("risk", RISK_DEFAULT))
	return clampf(1.0 + (activity - 100.0) * 0.004 + (traffic - 100.0) * 0.0015 - maxf(0.0, risk - 25.0) * 0.0025, 0.78, 1.24)


static func land_price_multiplier(district_id: String) -> float:
	ensure_state()
	var state: Dictionary = GameState.game_data.regional_economy.get(district_id, {})
	return clampf(float(state.get("land_price_index", 100.0)) / 100.0, 0.75, 1.35)


static func auction_price_multiplier(district_id: String) -> float:
	ensure_state()
	var state: Dictionary = GameState.game_data.regional_economy.get(district_id, {})
	var attention: = float(state.get("market_attention", 100.0))
	return clampf(land_price_multiplier(district_id) * (0.92 + attention / 1250.0), 0.78, 1.38)


static func talent_fit_multiplier(talent: Dictionary, district_id: String) -> float:
	ensure_state()
	var state: Dictionary = GameState.game_data.regional_economy.get(district_id, {})
	var role: = str(talent.get("role", talent.get("type", "operation"))).to_lower()
	var metric: = "technology_activity" if "tech" in role else "finance_activity" if "finance" in role else "commercial_heat"
	return clampf(0.9 + float(state.get(metric, 100.0)) / 1000.0, 0.92, 1.08)


static func stock_expectation(stock_id: String) -> float:
	ensure_state()
	var metric: = _sector_metric(stock_id)
	var total: = 0.0
	var count: = 0
	for state: Dictionary in GameState.game_data.regional_economy.values():
		total += float(state.get(metric, 100.0)) - 100.0
		count += 1
	return clampf(total / float(maxi(1, count)) * 0.0012, -0.035, 0.035)


static func ai_opportunity(land: Dictionary, player: Dictionary) -> float:
	ensure_state()
	var state: Dictionary = GameState.game_data.regional_economy.get(str(land.get("district", "")), {})
	if state.is_empty():
		return 0.0
	var score: = (float(state.get("land_price_index", 100.0)) - 100.0) * 0.9 + (float(state.get("market_attention", 100.0)) - 100.0) * 0.6
	var company_type: = str(GameConfig.by_id("investment_companies", str(player.get("company_id", ""))).get("type", ""))
	if "地产" in company_type or "流量" in company_type:
		score += maxf(0.0, float(state.get("commercial_heat", 100.0)) - 100.0) * 0.5
	return score


static func state_for(district_id: String) -> Dictionary:
	ensure_state()
	return GameState.game_data.regional_economy.get(district_id, {}).duplicate(true)


static func validate() -> Dictionary:
	ensure_state()
	var errors: Array[String] = []
	for district_id: String in GameState.game_data.regional_economy:
		var state: Dictionary = GameState.game_data.regional_economy[district_id]
		for metric: String in METRICS:
			if not state.has(metric) or not is_finite(float(state[metric])):
				errors.append("%s missing %s" % [district_id, metric])
	return {"ok": errors.is_empty(), "errors": errors, "districts": GameState.game_data.regional_economy.size(), "metrics": METRICS.size()}


static func _queue(district_id: String, values: Dictionary, reason: String) -> void :
	var state: Dictionary = GameState.game_data.regional_economy[district_id]
	for metric: String in values:
		state.pending[metric] = float(state.pending.get(metric, 0.0)) + float(values[metric])
	state.reasons.append(reason)


static func _district_from_action(data: Dictionary) -> String:
	var land_id: = str(data.get("land_id", ""))
	if land_id.is_empty() and not str(data.get("business_id", "")).is_empty():
		land_id = str(GameState.game_data.get("businesses", {}).get(str(data.business_id), {}).get("land_id", ""))
	return str(GameState.game_data.get("lands", {}).get(land_id, {}).get("district", data.get("district_id", "")))


static func _business_delta(type: Dictionary) -> Dictionary:
	match str(type.get("sector", "consumer")):
		"technology": return {"technology_activity": 4.0, "industry_concentration": 1.5, "land_price_index": 1.0, "market_attention": 1.2}
		"finance": return {"finance_activity": 4.0, "land_price_index": 1.4, "market_attention": 1.6}
		"logistics": return {"industry_concentration": 3.5, "traffic_access": 2.0, "risk": 0.5}
		"medical": return {"residential_prosperity": 3.0, "risk": -0.5, "land_price_index": 0.6}
		"entertainment": return {"commercial_heat": 4.0, "market_attention": 2.4, "risk": 1.2}
		"property": return {"commercial_heat": 2.4, "land_price_index": 2.0, "market_attention": 1.2}
	return {"commercial_heat": 3.0, "residential_prosperity": 1.0, "land_price_index": 0.8, "market_attention": 1.0}


static func _sector_metric(sector: String) -> String:
	if sector in ["technology", "tech"]: return "technology_activity"
	if sector in ["finance", "financial"]: return "finance_activity"
	if sector in ["logistics", "industry", "industrial"]: return "industry_concentration"
	if sector in ["medical", "health"]: return "residential_prosperity"
	if sector in ["property", "real_estate"]: return "land_price_index"
	return "commercial_heat"


static func _player_name(player_id: String) -> String:
	var player: Dictionary = GameState.player(player_id)
	return str(player.get("name", "城市资本"))
