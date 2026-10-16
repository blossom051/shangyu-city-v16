class_name NewspaperCityPulse
extends Control


var districts: Array[Dictionary] = []


func setup(values: Array) -> void :
	districts.clear()
	for value: Variant in values:
		if value is Dictionary:
			districts.append((value as Dictionary).duplicate(true))
	queue_redraw()


func _draw() -> void :
	var frame: = Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color("e5ddc8"), true)
	draw_rect(frame.grow(-1.0), Color("81745b"), false, 1.0)
	var sky: = Rect2(18, 16, size.x - 36, size.y - 34)
	draw_rect(sky, Color("eee7d5"), true)
	_draw_city_silhouette(sky)
	_draw_heat_line(sky)


func _draw_city_silhouette(area: Rect2) -> void :
	var ink: = Color(0.11, 0.14, 0.14, 0.82)
	var baseline: = area.end.y - 12.0
	var widths: = [0.08, 0.055, 0.1, 0.07, 0.12, 0.065, 0.09, 0.055, 0.11]
	var heights: = [0.3, 0.52, 0.39, 0.68, 0.46, 0.77, 0.4, 0.58, 0.34]
	var x: = area.position.x
	for index in widths.size():
		var width: = area.size.x * float(widths[index])
		var height: = area.size.y * float(heights[index])
		var building: = Rect2(Vector2(x, baseline - height), Vector2(width - 3.0, height))
		draw_rect(building, ink, true)
		for row in range(2, int(height / 16.0)):
			for column in range(1, maxi(2, int(width / 14.0))):
				var window: = Vector2(building.position.x + column * 11.0, building.position.y + row * 13.0)
				draw_rect(Rect2(window, Vector2(3.0, 4.0)), Color(0.9, 0.79, 0.48, 0.42), true)
		x += width
	draw_line(Vector2(area.position.x, baseline), Vector2(area.end.x, baseline), Color("7f2d2b"), 2.0)


func _draw_heat_line(area: Rect2) -> void :
	if districts.is_empty():
		return
	var graph: = Rect2(area.position + Vector2(12, 10), Vector2(area.size.x - 24, area.size.y * 0.38))
	var values: Array[float] = []
	for district: Dictionary in districts:
		values.append(float(district.get("heat", 100.0)))
	var low: float = float(values.min())
	var high: float = float(values.max())
	var span: float = maxf(1.0, high - low)
	var points: = PackedVector2Array()
	for index in values.size():
		var ratio: float = (values[index] - low) / span
		var x: float = graph.position.x + graph.size.x * float(index) / float(maxi(1, values.size() - 1))
		var y: float = graph.end.y - graph.size.y * ratio
		points.append(Vector2(x, y))
	if points.size() > 1:
		draw_polyline(points, Color("8d302c"), 3.0, true)
	for index in points.size():
		var ratio: float = (values[index] - low) / span
		var accent: Color = Color("2f7e96").lerp(Color("b74135"), ratio)
		draw_circle(points[index], 5.0, Color("f5eedc"))
		draw_circle(points[index], 3.2, accent)
