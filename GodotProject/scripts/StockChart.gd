class_name StockChart
extends Control

signal point_selected(index: int, value: float, delta: float, rate: float)

var values: Array = []
var line_color: = Color("4384a4")
var selected_index: = -1


func _ready() -> void :
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func set_values(data: Array, color: Color) -> void :
	values = data.duplicate()
	line_color = color
	selected_index = values.size() - 1 if not values.is_empty() else -1
	queue_redraw()


func select_point(index: int) -> Dictionary:
	if values.is_empty():
		return {}
	selected_index = clampi(index, 0, values.size() - 1)
	var profile: = selection_profile()
	point_selected.emit(selected_index, float(profile.value), float(profile.delta), float(profile.rate))
	queue_redraw()
	return profile


func selection_profile() -> Dictionary:
	if selected_index < 0 or selected_index >= values.size():
		return {}
	var value: = float(values[selected_index])
	var previous: = float(values[selected_index - 1]) if selected_index > 0 else value
	var delta: = value - previous
	var rate: = delta / previous if absf(previous) > 0.0001 else 0.0
	return {"index": selected_index, "day": selected_index + 1, "value": value, "previous": previous, "delta": delta, "rate": rate}


func _on_gui_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and values.size() > 0:
		var points: = _chart_points()
		var nearest: = 0
		var distance: float = INF
		for index in range(points.size()):
			var current: float = event.position.distance_squared_to(points[index])
			if current < distance:
				distance = current
				nearest = index
		select_point(nearest)
		accept_event()


func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color("071827"), true)
	var plot: = Rect2(48, 32, maxf(1.0, size.x - 78), maxf(1.0, size.y - 72))
	for i in range(6):
		var y: = plot.position.y + plot.size.y * float(i) / 5.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.24, 0.52, 0.6, 0.18), 1)
	for i in range(1, 10):
		var x: = plot.position.x + plot.size.x * float(i) / 10.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(0.24, 0.52, 0.6, 0.11), 1)
	if values.size() < 2:
		draw_line(Vector2(plot.position.x, plot.get_center().y), Vector2(plot.end.x, plot.get_center().y), Color(line_color, 0.48), 3, true)
		return
	var points: = _chart_points()
	var area: = PackedVector2Array([Vector2(points[0].x, plot.end.y)])
	for point in points:
		area.append(point)
	area.append(Vector2(points[-1].x, plot.end.y))
	draw_colored_polygon(area, Color(line_color, 0.17))
	draw_polyline(points, Color(line_color.lightened(0.24), 0.28), 10.0, true)
	draw_polyline(points, line_color, 3.0, true)
	for index in range(points.size()):
		var up: = index == 0 or float(values[index]) >= float(values[index - 1])
		var color: = Color("55df9b") if up else Color("ff7180")
		if index == selected_index:
			draw_line(Vector2(points[index].x, plot.position.y), Vector2(points[index].x, plot.end.y), Color("f0c65c70"), 2)
			draw_circle(points[index], 13, Color("f0c65c30"))
			draw_circle(points[index], 8, Color("f4d776"), false, 3)
		draw_line(points[index] - Vector2(0, 10), points[index] + Vector2(0, 10), color, 2)
		draw_circle(points[index], 4.5, color)
	var font: = get_theme_default_font()
	draw_string(font, Vector2(14, 22), "最高  %.2f" % float(values.max()), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("85c7d2"))
	draw_string(font, Vector2(14, size.y - 10), "最低  %.2f" % float(values.min()), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("85c7d2"))
	_draw_selection_card(points)


func _draw_selection_card(points: PackedVector2Array) -> void :
	var profile: = selection_profile()
	if profile.is_empty():
		return
	var point: = points[selected_index]
	var card_size: = Vector2(214, 76)
	var card_x: = clampf(point.x - card_size.x * 0.5, 56.0, size.x - card_size.x - 16.0)
	var card_y: = 16.0 if point.y > 112.0 else size.y - card_size.y - 18.0
	var rect: = Rect2(card_x, card_y, card_size.x, card_size.y)
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.1, 0.14, 0.98)
	style.border_color = Color("e6bf58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	draw_style_box(style, rect)
	var font: = get_theme_default_font()
	draw_string(font, rect.position + Vector2(14, 23), "第 %d 个交易日" % int(profile.day), HORIZONTAL_ALIGNMENT_LEFT, 120, 13, Color("9bcbd3"))
	draw_string(font, rect.position + Vector2(14, 50), "闭市价  %.2f" % float(profile.value), HORIZONTAL_ALIGNMENT_LEFT, 150, 20, Color("f6df9d"))
	var delta_color: = Color("63dda0") if float(profile.delta) >= 0.0 else Color("ff7e87")
	draw_string(font, rect.position + Vector2(146, 24), "%+.2f" % float(profile.delta), HORIZONTAL_ALIGNMENT_LEFT, 62, 13, delta_color)
	draw_string(font, rect.position + Vector2(146, 49), "%+.2f%%" % (float(profile.rate) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 66, 13, delta_color)


func _chart_points() -> PackedVector2Array:
	var plot: = Rect2(48, 32, maxf(1.0, size.x - 78), maxf(1.0, size.y - 72))
	var min_v: float = values.min()
	var max_v: float = values.max()
	var padding: = maxf(8.0, (max_v - min_v) * 0.28)
	min_v -= padding
	max_v += padding
	var span: = maxf(1.0, max_v - min_v)
	var points: = PackedVector2Array()
	for index in range(values.size()):
		points.append(Vector2(plot.position.x + plot.size.x * float(index) / maxf(1.0, float(values.size() - 1)), plot.end.y - plot.size.y * (float(values[index]) - min_v) / span))
	return points
