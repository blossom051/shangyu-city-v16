class_name CityUrbanFabric
extends RefCounted

const DATA_PATH: = "res://data/city_urban_fabric_v918.json"
const LAND_PATH: = "res://data/land_tiles.json"
const ROUTE_PATH: = "res://data/city_mobility_routes.json"
const MAP_HALF_EXTENT: = Vector2(90.0, 25.3)


static func placements() -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Array:
		return []
	var result: Array[Dictionary] = []
	for item: Variant in parsed:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


static func validate() -> Dictionary:
	var items: = placements()
	var errors: Array[String] = []
	var tiers: = {"low": 0, "mid": 0, "high": 0}
	var districts: Dictionary = {}
	var land_items: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAND_PATH))
	var route_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	for item: Dictionary in items:
		var item_id: = str(item.get("id", ""))
		var center: = Vector2(float(item.get("x", 0.0)), float(item.get("z", 0.0)))
		var radius: = float(item.get("width", 1.0)) * 0.55
		var tier: = str(item.get("tier", ""))
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		var district: = str(item.get("district", ""))
		districts[district] = int(districts.get(district, 0)) + 1
		if absf(center.x) + radius > MAP_HALF_EXTENT.x or absf(center.y - 0.4) + radius > MAP_HALF_EXTENT.y:
			errors.append("%s exceeds the metropolitan ground" % item_id)
		for land_value: Variant in land_items if land_items is Array else []:
			var land: = land_value as Dictionary
			var anchor: Array = land.get("anchor", [0.0, 0.0])
			var land_center: = Vector2(float(anchor[0]), float(anchor[1]))
			var land_radius: = _polygon_radius(land.get("polygon", []))
			if center.distance_to(land_center) < radius + land_radius + 0.62:
				errors.append("%s intersects land %s" % [item_id, str(land.get("id", ""))])
		if route_data is Dictionary:
			for domain in ["vehicles", "pedestrians"]:
				for route_value: Variant in (route_data as Dictionary).get(domain, []):
					var route: = route_value as Dictionary
					var nodes: Array = route.get("nodes", [])
					var segment_count: = nodes.size() if bool(route.get("closed", false)) else maxi(0, nodes.size() - 1)
					for index in range(segment_count):
						var a: = _route_point(nodes[index])
						var b: = _route_point(nodes[(index + 1) % nodes.size()])
						if _distance_to_segment(center, a, b) < radius + 0.72:
							errors.append("%s intersects %s route %s" % [item_id, domain, str(route.get("id", ""))])
							break
	for first_index in range(items.size()):
		var first: Dictionary = items[first_index]
		var first_center: = Vector2(float(first.x), float(first.z))
		var first_radius: = float(first.width) * 0.55
		for second_index in range(first_index + 1, items.size()):
			var second: Dictionary = items[second_index]
			var second_center: = Vector2(float(second.x), float(second.z))
			var second_radius: = float(second.width) * 0.55
			if first_center.distance_to(second_center) < first_radius + second_radius + 0.42:
				errors.append("%s overlaps %s" % [str(first.id), str(second.id)])
	return {
		"ok": errors.is_empty(), 
		"errors": errors, 
		"count": items.size(), 
		"tiers": tiers, 
		"districts": districts, 
		"clearance": 0.62, 
		"route_clearance": 0.72, 
	}


static func _polygon_radius(points: Array) -> float:
	var radius: = 0.0
	for point_value: Variant in points:
		var point: = point_value as Array
		if point.size() >= 2:
			radius = maxf(radius, Vector2(float(point[0]), float(point[1])).length())
	return radius


static func _route_point(node: Dictionary) -> Vector2:
	return Vector2(float(node.get("x", 0.0)), float(node.get("z", 0.0)))


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: = b - a
	if ab.length_squared() <= 0.0001:
		return point.distance_to(a)
	var t: = clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)
