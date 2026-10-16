class_name CityWorldBounds
extends RefCounted

static var GameState:
	get: return Engine.get_main_loop().root.get_node("/root/GameState")

const Mobility = preload("res://scripts/CityMobilityRoutes.gd")
const Geometry = preload("res://scripts/LandParcelGeometry.gd")
const WORLD_BOUNDS: = Rect2(-130.0, -26.0, 169.0, 52.0)
const EAST_LAKE: = Rect2(32.2, -25.5, 6.8, 51.0)
const WEST_RIVER: = Rect2(-55.0, -25.5, 17.0, 51.0)
const CAPITAL_BRIDGE: = Rect2(-55.4, -1.35, 17.8, 3.6)
const AURORA_BRIDGE: = Rect2(-55.4, 12.8, 17.8, 3.6)
const BUILD_CLEARANCE: = 1.15
const EFFECT_CLEARANCE: = 0.35


static func classify(position: Vector3) -> String:
	var point: = Vector2(position.x, position.z)
	if not WORLD_BOUNDS.has_point(point):
		return "outside"
	if EAST_LAKE.has_point(point):
		return "water"
	if is_valid_vehicle_position(position):
		return "road"
	if WEST_RIVER.has_point(point):
		return "water"
	if is_valid_pedestrian_position(position):
		return "walkway"
	return "land"


static func is_valid_land_position(position: Vector3) -> bool:
	var point: = Vector2(position.x, position.z)
	return WORLD_BOUNDS.has_point(point) and not EAST_LAKE.has_point(point) and not WEST_RIVER.has_point(point)


static func is_valid_build_position(position: Vector3, land_id: = "", radius: = BUILD_CLEARANCE) -> bool:
	if not is_valid_land_position(position):
		return false
	var point: = Vector2(position.x, position.z)
	var target_land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if not target_land.is_empty() and not Geometry.contains(Geometry.world_polygon(target_land), point):
		return false
	if target_land.is_empty():
		var inside_any: = false
		for land: Dictionary in GameState.game_data.get("lands", {}).values():
			if Geometry.contains(Geometry.world_polygon(land), point):
				inside_any = true
				land_id = str(land.get("id", ""))
				break
		if not inside_any:
			return false
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		if str(business.get("land_id", "")) == land_id:
			continue
		var other_land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		if other_land.is_empty():
			continue
		var anchor: Array = other_land.get("anchor", [INF, INF])
		if point.distance_to(Vector2(float(anchor[0]), float(anchor[1]))) < radius * 2.0:
			return false
	return true


static func is_valid_pedestrian_position(position: Vector3) -> bool:
	return is_valid_land_position(position) and Mobility.pedestrian_position_is_valid(position)


static func is_valid_vehicle_position(position: Vector3) -> bool:
	var point := Vector2(position.x, position.z)
	var on_bridge := CAPITAL_BRIDGE.has_point(point) or AURORA_BRIDGE.has_point(point)
	if not on_bridge and not is_valid_land_position(position):
		return false
	return _near_route(position, Mobility.load_routes().get("vehicles", []), 1.45)


static func is_valid_effect_position(position: Vector3, allow_road: = true) -> bool:
	if not is_valid_land_position(position):
		return false
	if not allow_road and is_valid_vehicle_position(position):
		return false
	return not _inside_occupied_building(position, EFFECT_CLEARANCE)


static func nearest_valid_position(position: Vector3, kind: String, max_radius: = 8.0) -> Vector3:
	if _valid_for_kind(position, kind):
		return position
	for ring in range(1, ceili(max_radius / 0.5) + 1):
		var radius: = float(ring) * 0.5
		for step in range(16):
			var angle: = TAU * float(step) / 16.0
			var candidate: = Vector3(position.x + cos(angle) * radius, position.y, position.z + sin(angle) * radius)
			if _valid_for_kind(candidate, kind):
				return candidate
	return Vector3(INF, position.y, INF)


static func validate_world() -> Dictionary:
	var errors: Array[String] = []
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		var anchor: Array = land.get("anchor", [INF, INF])
		var position: = Vector3(float(anchor[0]), 0.0, float(anchor[1]))
		if not is_valid_land_position(position):
			errors.append("%s anchor outside legal land" % str(land.get("id", "")))
	for route_value: Variant in Mobility.load_routes().get("pedestrians", []):
		var route: = route_value as Dictionary
		for node: Dictionary in route.get("nodes", []):
			if not is_valid_pedestrian_position(Mobility.node_position(node, 0.1)):
				errors.append("%s pedestrian node is illegal" % str(route.get("id", "")))
	for route_value: Variant in Mobility.load_routes().get("vehicles", []):
		var route: = route_value as Dictionary
		for node: Dictionary in route.get("nodes", []):
			if not is_valid_vehicle_position(Mobility.node_position(node, 0.02)):
				errors.append("%s vehicle node is illegal" % str(route.get("id", "")))
	return {"ok": errors.is_empty(), "errors": errors, "world_bounds": WORLD_BOUNDS, "water_zones": 2}


static func _valid_for_kind(position: Vector3, kind: String) -> bool:
	match kind:
		"build": return is_valid_build_position(position)
		"pedestrian", "npc": return is_valid_pedestrian_position(position)
		"vehicle": return is_valid_vehicle_position(position)
		"effect", "particle", "decoration": return is_valid_effect_position(position)
	return is_valid_land_position(position)


static func _inside_occupied_building(position: Vector3, clearance: float) -> bool:
	var point: = Vector2(position.x, position.z)
	for business: Dictionary in GameState.game_data.get("businesses", {}).values():
		if str(business.get("state", "")) in ["closed", "acquired"]:
			continue
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		if land.is_empty():
			continue
		var anchor: Array = land.get("anchor", [INF, INF])
		if point.distance_to(Vector2(float(anchor[0]), float(anchor[1]))) < BUILD_CLEARANCE + clearance:
			return true
	return false


static func _near_route(position: Vector3, routes: Array, half_width: float) -> bool:
	var point: = Vector2(position.x, position.z)
	for route_value: Variant in routes:
		var route: = route_value as Dictionary
		var nodes: Array = route.get("nodes", [])
		var segment_count: = nodes.size() if bool(route.get("closed", false)) else maxi(0, nodes.size() - 1)
		for index in range(segment_count):
			var a: = Vector2(float(nodes[index].get("x", 0.0)), float(nodes[index].get("z", 0.0)))
			var b_node: Dictionary = nodes[(index + 1) % nodes.size()]
			var b: = Vector2(float(b_node.get("x", 0.0)), float(b_node.get("z", 0.0)))
			if _distance_to_segment(point, a, b) <= half_width:
				return true
	return false


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: = b - a
	if ab.length_squared() <= 0.0001:
		return point.distance_to(a)
	var t: = clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)
