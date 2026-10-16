class_name CardComboRules
extends RefCounted

const MAX_COMBOS_PER_ROUND: = 1


static func ensure_player(player: Dictionary) -> void :
	player.get_or_add("combo_memory", [])
	player.get_or_add("combo_count", 0)


static func reset_round(player: Dictionary) -> void :
	ensure_player(player)
	player.combo_memory = []
	player.combo_count = 0


static func preview(player: Dictionary, card: Dictionary) -> Dictionary:
	ensure_player(player)
	if int(player.combo_count) >= MAX_COMBOS_PER_ROUND:
		return {"triggered": false}
	var config: Node = Engine.get_main_loop().root.get_node("GameConfig")
	var current: = _family(card)
	for previous_id: String in player.combo_memory:
		var previous: Dictionary = config.by_id("cards", previous_id)
		var pair: = [_family(previous), current]
		pair.sort()
		match "|".join(pair):
			"district|finance": return {"triggered": true, "id": "capital_route", "name": "资本路线联动", "cash": 15, "message": "金融与商圈策略衔接，现金+15万"}
			"operation|talent": return {"triggered": true, "id": "board_synergy", "name": "董事会协同", "risk": -3, "message": "经营与人才策略衔接，风险-3"}
			"attack|public_opinion": return {"triggered": true, "id": "pressure_chain", "name": "舆情压制链", "target_risk": 3, "message": "连续施压命中，目标风险+3"}
			"construction|operation": return {"triggered": true, "id": "execution_cycle", "name": "执行闭环", "sp_refund": 1, "message": "建设与经营形成闭环，返还1 SP"}
	return {"triggered": false}


static func resolve(player: Dictionary, card: Dictionary, target_id: String) -> Dictionary:
	var result: = preview(player, card)
	player.combo_memory.append(str(card.get("id", "")))
	if not bool(result.get("triggered", false)):
		return result
	player.combo_count = int(player.combo_count) + 1
	var state: Node = Engine.get_main_loop().root.get_node("GameState")
	if int(result.get("cash", 0)) != 0:
		state.apply_cash(str(player.id), int(result.cash), str(result.name))
	if int(result.get("risk", 0)) != 0:
		load("res://scripts/RiskSystem.gd").adjust(str(player.id), int(result.risk), str(result.name), "策略连携")
	if int(result.get("target_risk", 0)) != 0:
		var target_owner: = target_id
		if state.game_data.get("businesses", {}).has(target_id):
			target_owner = str(state.game_data.businesses[target_id].get("owner_id", target_id))
		load("res://scripts/RiskSystem.gd").adjust(target_owner, int(result.target_risk), str(result.name), "策略连携")
	if int(result.get("sp_refund", 0)) != 0:
		player.strategy_points = mini(int(player.get("strategy_points_max", 3)), int(player.strategy_points) + int(result.sp_refund))
	return result


static func _family(card: Dictionary) -> String:
	var category: = str(card.get("category", ""))
	if category in ["construction", "talent", "public_opinion", "district", "finance"]:
		return category
	if str(card.get("type", "")) == "attack":
		return "attack"
	return str(card.get("type", "operation"))
