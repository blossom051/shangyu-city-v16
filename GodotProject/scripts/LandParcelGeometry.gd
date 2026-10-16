class_name LandParcelGeometry
extends RefCounted

const ALLOWED_SITE_TYPES: Array[String] = [
	"parking_redevelopment", 
	"brownfield", 
	"unused_hardstand", 
	"courtyard_renewal", 
	"waterfront_reserve", 
]


static func point_from_array(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(INF, INF)


static func points_from_data(values: Variant) -> PackedVector2Array:
	var points: = PackedVector2Array()
	if not values is Array:
		return points
	for value: Variant in values:
		var point: = point_from_array(value)
		if is_finite(point.x) and is_finite(point.y):
			points.append(point)
	return points


static func world_polygon(land: Dictionary) -> PackedVector2Array:
	var anchor: = anchor_of(land)
	var result: = PackedVector2Array()
	for point: Vector2 in points_from_data(land.get("polygon", [])):
		result.append(anchor + point)
	return result


static func anchor_of(land: Dictionary) -> Vector2:
	return point_from_array(land.get("anchor", []))


static func are_adjacent(first: Dictionary, second: Dictionary, maximum_gap: = 6.0) -> bool:
	if str(first.get("district", "")) != str(second.get("district", "")):
		return false
	var first_polygon: = world_polygon(first)
	var second_polygon: = world_polygon(second)
	if not is_valid_polygon(first_polygon) or not is_valid_polygon(second_polygon):
		return false
	if polygons_overlap(first_polygon, second_polygon):
		return true
	var minimum_gap: = INF
	for first_index in range(first_polygon.size()):
		var first_start: = first_polygon[first_index]
		var first_end: = first_polygon[(first_index + 1) % first_polygon.size()]
		for second_index in range(second_polygon.size()):
			var second_start: = second_polygon[second_index]
			var second_end: = second_polygon[(second_index + 1) % second_polygon.size()]
			var closest: = Geometry2D.get_closest_points_between_segments(first_start, first_end, second_start, second_end)
			if closest.size() >= 2:
				minimum_gap = minf(minimum_gap, closest[0].distance_to(closest[1]))
	return minimum_gap <= maximum_gap


static func is_valid_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3 or absf(signed_area(points)) < 0.35:
		return false
	return Geometry2D.triangulate_polygon(points).size() >= 3


static func signed_area(points: PackedVector2Array) -> float:
	var area: = 0.0
	for index in range(points.size()):
		var current: = points[index]
		var next: = points[(index + 1) % points.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


static func contains(points: PackedVector2Array, point: Vector2) -> bool:
	if not is_finite(point.x) or not is_finite(point.y):
		return false
	for index in range(points.size()):
		if _point_on_segment(point, points[index], points[(index + 1) % points.size()]):
			return true
	return Geometry2D.is_point_in_polygon(point, points)


static func polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	for a_index in range(a.size()):
		var a_start: = a[a_index]
		var a_end: = a[(a_index + 1) % a.size()]
		for b_index in range(b.size()):
			var b_start: = b[b_index]
			var b_end: = b[(b_index + 1) % b.size()]
			var intersection: Variant = Geometry2D.segment_intersects_segment(a_start, a_end, b_start, b_end)
			if intersection != null:
				return true
	return contains(a, b[0]) or contains(b, a[0])


static func bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum: = points[0]
	var maximum: = points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func mesh_for_polygon(points: PackedVector2Array, height: = 0.0) -> ArrayMesh:
	var mesh: = ArrayMesh.new()
	var indices: = Geometry2D.triangulate_polygon(points)
	if indices.size() < 3:
		return mesh
	var vertices: = PackedVector3Array()
	var normals: = PackedVector3Array()
	var uvs: = PackedVector2Array()
	var parcel_bounds: = bounds(points)
	for point: Vector2 in points:
		vertices.append(Vector3(point.x, height, point.y))
		normals.append(Vector3.UP)
		var relative: = point - parcel_bounds.position
		uvs.append(Vector2(
			relative.x / maxf(parcel_bounds.size.x, 0.01), 
			relative.y / maxf(parcel_bounds.size.y, 0.01)
		))
	var arrays: = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
	var segment: = end - start
	if segment.length_squared() <= 1e-06:
		return point.distance_squared_to(start) <= 1e-06
	var t: = clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_squared_to(start + segment * t) <= 1e-06
