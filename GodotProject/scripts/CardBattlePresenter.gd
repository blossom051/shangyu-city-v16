class_name CardBattlePresenter
extends RefCounted

const TYPE_FX: = {
	"attack": "hostile_route_strike", 
	"defense": "secret_shield_reveal", 
	"counter": "counter_chain_reversal", 
	"operation": "enterprise_cashflow", 
	"finance": "capital_ticker_surge", 
	"district": "city_district_activation", 
}


static func profile_for(card: Dictionary, result: = {}) -> Dictionary:
	var card_type: = str(card.get("type", "operation"))
	var reduced_motion: = false
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("GameSettings")
	if settings != null:
		reduced_motion = bool(settings.get("reduce_motion"))
	var phases: Array[Dictionary] = [
		{"id": "commit", "duration": 0.08 if reduced_motion else 0.24}, 
		{"id": "travel", "duration": 0.08 if reduced_motion else 0.32}, 
		{"id": "impact", "duration": 0.1 if reduced_motion else 0.38}, 
		{"id": "receipt", "duration": 0.1 if reduced_motion else 0.52}, 
	]
	if bool(result.get("guarded", false)):
		phases.insert(2, {"id": "secret_reveal", "duration": 0.1 if reduced_motion else 0.34})
	return {
		"card_type": card_type, 
		"fx": TYPE_FX.get(card_type, "enterprise_cashflow"), 
		"headline": _headline(card_type, result), 
		"phases": phases, 
		"total_duration": phases.reduce( func(sum: float, phase: Dictionary) -> float: return sum + float(phase.duration), 0.0), 
		"chain_depth": int(result.get("chain", {}).get("depth", 1)), 
		"must_cleanup": true, 
	}


static func _headline(card_type: String, result: Dictionary) -> String:
	if bool(result.get("guarded", false)):
		return "秘策揭晓  攻防链已结算"
	return {
		"attack": "资本攻势命中", 
		"defense": "董事会秘策已部署", 
		"counter": "反制预案已部署", 
		"operation": "经营方案生效", 
		"finance": "资本工具完成交割", 
		"district": "商圈行动落地", 
	}.get(card_type, "策略已经结算")
