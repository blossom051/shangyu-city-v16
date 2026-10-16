class_name CapitalMetricEmblem
extends Control

var accent: = Color("e1b955")
var ratio: = 0.5


func setup(color: Color, value_ratio: float) -> void :
	accent = color
	ratio = clampf(value_ratio, 0.04, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void :
	var center: = size * 0.5
	var radius: = minf(size.x, size.y) * 0.32
	draw_circle(center, radius * 0.72, Color(accent, 0.065))
	draw_arc(center, radius, - PI * 0.75, PI * 0.75, 64, Color(accent, 0.18), 8.0, true)
	draw_arc(center, radius, - PI * 0.75, lerpf( - PI * 0.75, PI * 0.75, ratio), 64, Color(accent, 0.92), 8.0, true)
	draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(accent, 0.38), 2.0, true)
	for index in range(8):
		var angle: = TAU * float(index) / 8.0 - PI * 0.5
		var point: = center + Vector2.from_angle(angle) * radius * 1.18
		draw_circle(point, 2.5 if index % 2 == 0 else 1.6, Color(accent.lightened(0.25), 0.72))
	draw_line(center + Vector2( - radius * 0.3, 0), center + Vector2(radius * 0.3, 0), Color(accent, 0.55), 2.0, true)
	draw_line(center + Vector2(0, - radius * 0.3), center + Vector2(0, radius * 0.3), Color(accent, 0.55), 2.0, true)
