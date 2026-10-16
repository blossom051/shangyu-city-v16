class_name DistrictSystem
extends RefCounted


static func initialize() -> void :
	GameState.game_data.districts = {}
	recalculate()


static func recalculate() -> Array[Dictionary]:
	var previous: Dictionary = GameState.game_data.get("districts", {}).duplicate(true)
	var districts: Dictionary = {}
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		var district_id: = str(land.get("district", "unknown"))
		if not districts.has(district_id):
			var old_district: Dictionary = previous.get(district_id, {})
			var base_heat: = float(old_district.get("base_heat", old_district.get("heat", 100.0)))
			districts[district_id] = {
				"id": district_id, 
				"name": str(land.get("district_name", district_id)), 
				"base_heat": base_heat, 
				"heat": base_heat, 
				"total_weight": 0.0, 
				"influence": {}, 
				"control": {}, 
				"leader_id": "", 
				"dominant_id": "", 
			}
		var district: Dictionary = districts[district_id]
		var weight: = _land_weight(land)
		district.total_weight = float(district.total_weight) + weight
		var owner_id: = str(land.get("owner_id", ""))
		if not owner_id.is_empty():
			district.influence[owner_id] = float(district.influence.get(owner_id, 0.0)) + weight

	var events: Array[Dictionary] = []
	for district_id: String in districts:
		var district: Dictionary = districts[district_id]
		for effect: Dictionary in GameState.game_data.get("district_effects", []):
			if str(effect.get("district_id", "")) != district_id:
				continue
			if str(effect.get("kind", "")) == "heat_delta":
				district.heat = clampf(float(district.heat) + float(effect.get("value", 0.0)), 40.0, 160.0)
		var best_player: = ""
		var best_control: = 0.0
		for player_id: String in district.influence:
			var control: = 0.0
			if float(district.total_weight) > 0.0:
				control = clampf(float(district.influence[player_id]) / float(district.total_weight), 0.0, 1.0)
			district.control[player_id] = control
			if control > best_control:
				best_control = control
				best_player = player_id
		if best_control >= 0.4:
			district.leader_id = best_player
		if best_control >= 0.6:
			district.dominant_id = best_player
		var old: Dictionary = previous.get(district_id, {})
		if old.get("influence", {}) != district.influence or str(old.get("leader_id", "")) != str(district.leader_id) or str(old.get("dominant_id", "")) != str(district.dominant_id):
			events.append({
				"type": "district_control_changed", 
				"district_id": district_id, 
				"leader_id": str(district.leader_id), 
				"dominant_id": str(district.dominant_id), 
				"control": district.control.duplicate(true), 
			})
	GameState.game_data.districts = districts
	for player: Dictionary in GameState.game_data.get("players", []):
		player.district_influence = {}
		for district_id: String in districts:
			player.district_influence[district_id] = float(districts[district_id].control.get(str(player.id), 0.0))
	return events


static func business_modifiers(business_id: String) -> Dictionary:
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
	if business.is_empty():
		return {"income_multiplier": 1.0, "competition_rate": 0.0, "controller_id": ""}
	var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
	var district: Dictionary = GameState.game_data.get("districts", {}).get(str(land.get("district", "")), {})
	var owner_id: = str(business.get("owner_id", ""))
	var dominant_id: = str(district.get("dominant_id", ""))
	var income_multiplier: = 1.0
	var competition_rate: = 0.0
	if not dominant_id.is_empty():
		if dominant_id == owner_id:
			income_multiplier = 1.15
		else:
			income_multiplier = 0.88
			competition_rate = 0.12
	for effect: Dictionary in GameState.game_data.get("district_effects", []):
		if str(effect.get("district_id", "")) == str(land.get("district", "")) and str(effect.get("kind", "")) == "joint_operation" and str(effect.get("source_player_id", "")) == owner_id:
			income_multiplier *= float(effect.get("value", 1.0))
	return {"income_multiplier": income_multiplier, "competition_rate": competition_rate, "controller_id": dominant_id}


static func joint_operation_dividend(player_id: String) -> Dictionary:
	var total: = 0
	var lines: Array[Dictionary] = []
	for effect: Dictionary in GameState.game_data.get("district_effects", []):
		if str(effect.get("kind", "")) != "joint_operation" or str(effect.get("source_player_id", "")) != player_id:
			continue
		var district_id: = str(effect.get("district_id", ""))
		var rival_count: = 0
		for business: Dictionary in GameState.game_data.get("businesses", {}).values():
			if str(business.get("owner_id", "")) == player_id or str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
				continue
			var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
			if str(land.get("district", "")) == district_id:
				rival_count += 1
		var amount: = mini(int(effect.get("dividend_cap", 80)), rival_count * int(effect.get("per_rival_business", 20)))
		total += amount
		lines.append({"district_id": district_id, "rival_businesses": rival_count, "value": amount, "label": "核心商圈联营分成"})
	return {"total": total, "lines": lines}


static func _land_weight(land: Dictionary) -> float:
	match str(land.get("state", "available")):
		"constructing":
			return 1.1
		"operating", "loss_watch", "mortgaged":
			return 1.25
		_:
			return 1.0
