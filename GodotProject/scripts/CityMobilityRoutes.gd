class_name CityMobilityRoutes
extends RefCounted

const DATA_PATH: = "res://data/city_mobility_routes.json"
const VEHICLE_ACTIONS: Array[String] = ["cruise", "turn", "stop_line"]
const PEDESTRIAN_ACTIONS: Array[String] = ["walk", "wait_crossing", "crosswalk", "interact"]
static var _cached_routes: Dictionary = {}


static func load_routes() -> Dictionary:
	if not _cached_routes.is_empty():
		return _cached_routes
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_cached_routes = parsed if parsed is Dictionary else {"vehicles": [], "pedestrians": [], "signals": {}}
	return _cached_routes


static func validate_route(route: Dictionary, kind: String) -> Dictionary:
	var domain: = str(route.get("domain", ""))
	if kind == "vehicle" and domain != "road_lane":
		return {"ok": false, "message": "%s 不在机动车道" % str(route.get("id", ""))}
	if kind == "pedestrian" and not domain in ["sidewalk", "waterfront_walkway"]:
		return {"ok": false, "message": "%s 不在人行区域" % str(route.get("id", ""))}
	var nodes: Array = route.get("nodes", [])
	if nodes.size() < 4:
		return {"ok": false, "message": "%s 路线节点不足" % str(route.get("id", ""))}
	var actions: = VEHICLE_ACTIONS if kind == "vehicle" else PEDESTRIAN_ACTIONS
	for node: Dictionary in nodes:
		if not str(node.get("action", "")) in actions:
			return {"ok": false, "message": "%s 含有非法动作" % str(route.get("id", ""))}
		if not is_finite(float(node.get("x", INF))) or not is_finite(float(node.get("z", INF))):
			return {"ok": false, "message": "%s 含有非法坐标" % str(route.get("id", ""))}
		if kind == "pedestrian" and bool(node.get("crossing", false)) and str(node.get("action", "")) != "crosswalk":
			return {"ok": false, "message": "%s 只能在斑马线节点穿越车道" % str(route.get("id", ""))}
	return {"ok": true}


static func node_position(node: Dictionary, y: float) -> Vector3:
	return Vector3(float(node.get("x", 0.0)), y, float(node.get("z", 0.0)))


static func rotated_nodes(route: Dictionary, offset: int) -> Array:
	var nodes: Array = route.get("nodes", [])
	if nodes.is_empty():
		return []
	var result: Array = []
	for index in range(nodes.size()):
		result.append(nodes[(index + offset) % nodes.size()].duplicate(true))
	return result


static func validate_network() -> Dictionary:
	var data: = load_routes()
	var errors: Array[String] = []
	for route_value: Variant in data.get("vehicles", []):
		var route: = route_value as Dictionary
		var result: = validate_route(route, "vehicle")
		if not bool(result.get("ok", false)):
			errors.append(str(result.get("message", "invalid vehicle route")))
	for route_value: Variant in data.get("pedestrians", []):
		var route: = route_value as Dictionary
		var result: = validate_route(route, "pedestrian")
		if not bool(result.get("ok", false)):
			errors.append(str(result.get("message", "invalid pedestrian route")))
			continue
		var nodes: Array = route.get("nodes", [])
		var segment_count: = nodes.size() if bool(route.get("closed", false)) else maxi(0, nodes.size() - 1)
		for index in range(segment_count):
			var start: = node_position(nodes[index], 0.1)
			var finish: = node_position(nodes[(index + 1) % nodes.size()], 0.1)
			for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
				if not pedestrian_position_is_valid(start.lerp(finish, float(fraction))):
					errors.append("%s leaves the pedestrian domain at segment %d" % [str(route.get("id", "")), index])
					break
	return {
		"ok": errors.is_empty(), 
		"errors": errors, 
		"vehicle_routes": data.get("vehicles", []).size(), 
		"pedestrian_routes": data.get("pedestrians", []).size(), 
		"water_zones": (data.get("pedestrian_domain", {}) as Dictionary).get("water_zones", []).size(), 
	}


static func pedestrian_position_is_valid(position: Vector3) -> bool:
	var data: = load_routes()
	var domain: Dictionary = data.get("pedestrian_domain", {})
	var bounds: Dictionary = domain.get("bounds", {})
	if position.x < float(bounds.get("min_x", - INF)) or position.x > float(bounds.get("max_x", INF)):
		return false
	if position.z < float(bounds.get("min_z", - INF)) or position.z > float(bounds.get("max_z", INF)):
		return false
	for zone_value: Variant in domain.get("water_zones", []):
		var zone: = zone_value as Dictionary
		var body_clearance: = float(domain.get("rendered_body_clearance", 0.0))
		if position.x >= float(zone.get("min_x", INF)) - body_clearance and position.x <= float(zone.get("max_x", - INF)) + body_clearance\
		and position.z >= float(zone.get("min_z", INF)) - body_clearance and position.z <= float(zone.get("max_z", - INF)) + body_clearance:
			return false
	var point: = Vector2(position.x, position.z)
	var corridor_half_width: = float(domain.get("corridor_half_width", 1.55))
	for route_value: Variant in data.get("pedestrians", []):
		var route: = route_value as Dictionary
		var nodes: Array = route.get("nodes", [])
		var segment_count: = nodes.size() if bool(route.get("closed", false)) else maxi(0, nodes.size() - 1)
		for index in range(segment_count):
			var a: = Vector2(float(nodes[index].get("x", 0.0)), float(nodes[index].get("z", 0.0)))
			var b_node: Dictionary = nodes[(index + 1) % nodes.size()]
			var b: = Vector2(float(b_node.get("x", 0.0)), float(b_node.get("z", 0.0)))
			if _distance_to_segment(point, a, b) <= corridor_half_width:
				return true
	return false


static func pedestrian_travel_is_valid(start: Vector3, finish: Vector3) -> bool:
	var distance: = start.distance_to(finish)
	var sample_count: = maxi(1, ceili(distance / 0.18))
	for index in range(sample_count + 1):
		if not pedestrian_position_is_valid(start.lerp(finish, float(index) / float(sample_count))):
			return false
	return true


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: = b - a
	if ab.length_squared() <= 0.0001:
		return point.distance_to(a)
	var t: = clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)
