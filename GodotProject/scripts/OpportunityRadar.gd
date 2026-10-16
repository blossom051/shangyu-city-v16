class_name OpportunityRadar
extends RefCounted

static var GameState:
	get: return Engine.get_main_loop().root.get_node("/root/GameState")

const Regions = preload("res://scripts/RegionalEconomySystem.gd")


static func refresh() -> Array[Dictionary]:
	Regions.ensure_state()
	var candidates: Array[Dictionary] = []
	for district_id: String in GameState.game_data.regional_economy:
		var state: Dictionary = GameState.game_data.regional_economy[district_id]
		if float(state.get("commercial_heat", 100.0)) >= 106.0:
			candidates.append(_item(90.0 + float(state.commercial_heat), "🔥", "%s消费热度上升，消费与娱乐企业收益预期提高。" % str(state.name), district_id, "build"))
		if float(state.get("technology_activity", 100.0)) >= 107.0:
			candidates.append(_item(80.0 + float(state.technology_activity), "📈", "%s科技活跃，科技企业和相关证券获得预期支撑。" % str(state.name), district_id, "stocks"))
		if float(state.get("land_price_index", 100.0)) >= 106.0:
			candidates.append(_item(70.0 + float(state.land_price_index), "🏙", "%s地价指数升至 %.1f，待售地和拍卖底价正在变贵。" % [str(state.name), float(state.land_price_index)], district_id, "land"))
	var human: = _human_player()
	if not human.is_empty():
		var debt_ratio: = float(human.get("debt", 0)) / maxf(1.0, float(human.get("asset_value", human.get("cash", 1))))
		if debt_ratio >= 0.45:
			candidates.append(_item(260.0, "⚠", "当前负债率偏高，后续利息和融资压力将明显增加。", "", "bank"))
	for scheduled_round: Variant in GameState.game_data.get("auction_schedule", []):
		var auction: = {"round": int(scheduled_round), "land_id": "地块"}
		if int(auction.get("round", -1)) == int(GameState.game_data.get("round", 0)):
			candidates.append(_item(240.0, "🏦", "%s将在本轮进入城市拍卖。" % str(auction.get("land_id", "地块")), "", "auction"))
	candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a.priority) > float(b.priority))
	var result: = candidates.slice(0, mini(3, candidates.size()))
	GameState.game_data.opportunity_radar = result.duplicate(true)
	return result


static func current() -> Array:
	return GameState.game_data.get("opportunity_radar", []).duplicate(true)


static func _item(priority: float, icon: String, text: String, district_id: String, action: String) -> Dictionary:
	return {"priority": priority, "icon": icon, "text": text, "district_id": district_id, "action": action, "optional": true, "round": int(GameState.game_data.get("round", 0))}


static func _human_player() -> Dictionary:
	for player: Dictionary in GameState.game_data.get("players", []):
		if bool(player.get("human", false)):
			return player
	return {}
