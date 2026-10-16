class_name TalentRedGlow
extends Control

var phase: = 0.0
var accent: = Color("ef5d5d")


func setup(value: = Color("ef5d5d")) -> void :
	accent = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void :
	if not GameSettings.reduce_motion:
		phase += delta
	queue_redraw()


func _draw() -> void :
	var center: = size * 0.5
	for index in range(7, 0, -1):
		var radius: = 82.0 + float(index) * 18.0
		draw_circle(center, radius, Color(accent, 0.012 + float(7 - index) * 0.006))
	for ring in range(3):
		var radius: = 126.0 + float(ring) * 34.0 + sin(phase * 2.2 + ring) * 4.0
		var color: = Color("f2c968") if ring == 1 else accent
		draw_arc(center, radius, phase * (0.28 + ring * 0.08), TAU + phase * (0.28 + ring * 0.08), 96, Color(color, 0.62 - ring * 0.12), 3.0 if ring == 1 else 2.0, true)
	for ray in range(18):
		var angle: = TAU * float(ray) / 18.0 + phase * 0.12
		var inner: = center + Vector2.from_angle(angle) * 154.0
		var outer: = center + Vector2.from_angle(angle) * (184.0 + float(ray % 4) * 10.0)
		draw_line(inner, outer, Color("f4d982", 0.3), 2.0)
	for spark in range(24):
		var angle: = TAU * float((spark * 7) % 24) / 24.0 + phase * (0.18 + float(spark % 3) * 0.04)
		var radius: = 118.0 + float((spark * 23) % 102)
		var point: = center + Vector2.from_angle(angle) * radius
		draw_circle(point, 2.0 + float(spark % 3), Color("ffe49a", 0.48 + 0.18 * sin(phase * 3.0 + spark)))
