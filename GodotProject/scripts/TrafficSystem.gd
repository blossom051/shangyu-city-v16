class_name TrafficSystem
extends RefCounted

const RandomEvents = preload("res://scripts/RandomEventSystem.gd")


static func generate_round(forced_route_ids: Array = []) -> Array:
	var routes: Array = GameConfig.list("traffic_routes").duplicate(true)
	var active: Array = []
	if not forced_route_ids.is_empty():
		for route_id: Variant in forced_route_ids:
			var route: = GameConfig.by_id("traffic_routes", str(route_id)).duplicate(true)
			if not route.is_empty():
				active.append(route)
	else:
		_shuffle_with_match_rng(routes)
		var count: = GameState.rng.randi_range(3, mini(5, routes.size()))
		active = routes.slice(0, count)
	for route: Dictionary in active:
		var from_heat: = _district_heat(str(route.from))
		var to_heat: = _district_heat(str(route.to))
		var event_multiplier: = RandomEvents.traffic_multiplier([str(route.from), str(route.to)])
		route["strength"] = snappedf(clampf((from_heat + to_heat) / 200.0 * event_multiplier, 0.6, 1.6), 0.01)
	GameState.game_data.traffic_routes = active
	return active.duplicate(true)


static func settle() -> Dictionary:
	var report: = {"routes": [], "players": {}}
	for player: Dictionary in GameState.game_data.players:
		report.players[str(player.id)] = {"traffic_income": 0, "control_income": 0, "competition_cost": 0, "routes": []}
	for route: Dictionary in GameState.game_data.get("traffic_routes", []):
		var route_businesses: = _eligible_businesses(route)
		var pool: = roundi(float(route.base_demand) * float(route.get("strength", 1.0)))
		var total_weight: = 0.0
		for item: Dictionary in route_businesses:
			total_weight += float(item.weight)
		var route_story: = {"route_id": str(route.id), "name": str(route.name), "pool": pool, "awards": []}
		if total_weight > 0.0:
			for item: Dictionary in route_businesses:
				var gross: = roundi(float(pool) * float(item.weight) / total_weight)
				var owner_id: = str(item.owner_id)
				var district: Dictionary = GameState.game_data.districts.get(str(item.district_id), {})
				var controller_id: = str(district.get("dominant_id", ""))
				var competition_cost: = 0
				if not controller_id.is_empty() and controller_id != owner_id:
					competition_cost = roundi(float(gross) * 0.15)
				var net: = maxi(0, gross - competition_cost)
				if net > 0:
					GameState.apply_cash(owner_id, net, "%s客流收益" % str(route.name))
				var owner_report: Dictionary = report.players[owner_id]
				owner_report.traffic_income = int(owner_report.traffic_income) + net
				owner_report.competition_cost = int(owner_report.competition_cost) + competition_cost
				owner_report.routes.append(str(route.id))
				if competition_cost > 0:
					GameState.apply_cash(controller_id, competition_cost, "%s竞争成本转入" % str(route.name))
					var controller_report: Dictionary = report.players[controller_id]
					controller_report.control_income = int(controller_report.control_income) + competition_cost
				route_story.awards.append({"player_id": owner_id, "business_id": str(item.business_id), "gross": gross, "net": net, "competition_cost": competition_cost, "controller_id": controller_id})
				if competition_cost > 0:
					GameState.game_data.battle_ledger.append({"round": int(GameState.game_data.round), "category": "district_toll", "player_id": controller_id, "title": "%s向%s收取%s商圈竞争费 %d 万" % [str(GameState.player(controller_id).name), str(GameState.player(owner_id).name), str(route.name), competition_cost], "details": {"route_id": str(route.id), "from_player_id": owner_id, "to_player_id": controller_id, "amount": competition_cost}})
		_settle_route_control(route, pool, report, route_story)
		report.routes.append(route_story)
	GameState.game_data.battle_ledger.append({
		"round": int(GameState.game_data.round), 
		"category": "traffic", 
		"player_id": "system", 
		"title": "城市客流完成分配", 
		"details": report.duplicate(true), 
	})
	GameState.game_data.last_traffic_report = report
	GameState.save_to_disk()
	GameState._emit_change()
	return report


static func _settle_route_control(route: Dictionary, pool: int, report: Dictionary, route_story: Dictionary) -> void :
	var handled: Dictionary = {}
	for district_id: String in [str(route.from), str(route.to)]:
		var district: Dictionary = GameState.game_data.districts.get(district_id, {})
		var controller_id: = str(district.get("dominant_id", ""))
		var rate: = 0.15
		if controller_id.is_empty():
			controller_id = str(district.get("leader_id", ""))
			rate = 0.08
		if controller_id.is_empty() or handled.has("%s:%s" % [district_id, controller_id]):
			continue
		handled["%s:%s" % [district_id, controller_id]] = true
		var control_income: = roundi(float(pool) * 0.5 * rate)
		if control_income <= 0:
			continue
		GameState.apply_cash(controller_id, control_income, "%s商圈控制收益" % str(route.name))
		var controller_report: Dictionary = report.players[controller_id]
		controller_report.control_income = int(controller_report.control_income) + control_income
		route_story.awards.append({"player_id": controller_id, "district_id": district_id, "control_income": control_income})


static func _eligible_businesses(route: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for business: Dictionary in GameState.game_data.businesses.values():
		if str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
			continue
		var land: Dictionary = GameState.game_data.lands.get(str(business.land_id), {})
		var district_id: = str(land.get("district", ""))
		if district_id not in [str(route.from), str(route.to)]:
			continue
		var business_type: = GameConfig.by_id("business_types", str(business.type_id))
		var weight: = 1.0
		for tag: Variant in business_type.get("tags", []):
			if route.get("preferred_tags", []).has(tag):
				weight += 0.25
		if business_type.get("fit", []).has(district_id):
			weight += 0.2
		result.append({"business_id": str(business.id), "owner_id": str(business.owner_id), "district_id": district_id, "weight": weight})
	return result


static func _district_heat(district_id: String) -> float:
	return float(GameState.game_data.get("districts", {}).get(district_id, {}).get("heat", 100.0))


static func _shuffle_with_match_rng(values: Array) -> void :
	for index in range(values.size() - 1, 0, -1):
		var other: = GameState.rng.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[other]
		values[other] = value
