class_name MarketImpactSystem
extends RefCounted


static func add(stock_id: String, magnitude: float, source: String, player_id: = "system", details: = {}) -> Dictionary:
	if not GameState.game_data.get("stocks", {}).has(stock_id):
		return {"ok": false, "message": "关联股票不存在"}
	var impact: = {
		"id": "MI%04d" % (GameState.game_data.get("market_impacts", []).size() + 1), 
		"round": int(GameState.game_data.get("round", 0)), 
		"stock_id": stock_id, 
		"magnitude": clampf(magnitude, -0.18, 0.18), 
		"source": source, 
		"player_id": player_id, 
		"details": details.duplicate(true), 
	}
	GameState.game_data.market_impacts.append(impact)
	GameState.game_data.domain_events.append({
		"event_id": "R%02d-MI%04d" % [int(GameState.game_data.get("round", 0)), GameState.game_data.domain_events.size() + 1], 
		"round": int(GameState.game_data.get("round", 0)), 
		"type": "market_impact_added", 
		"data": impact.duplicate(true), 
	})
	return {"ok": true, "impact": impact}


static func total_for(stock_id: String) -> float:
	var total: = 0.0
	for impact: Dictionary in GameState.game_data.get("market_impacts", []):
		if str(impact.get("stock_id", "")) == stock_id:
			total += float(impact.get("magnitude", 0.0))
	return clampf(total, -0.3, 0.3)


static func consume_all() -> Array:
	var consumed: Array = GameState.game_data.get("market_impacts", []).duplicate(true)
	GameState.game_data.market_impacts = []
	return consumed
