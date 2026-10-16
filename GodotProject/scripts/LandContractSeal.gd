class_name LandContractSeal
extends Control


func _draw() -> void :
	var center: = size * 0.5
	var gold: = Color("f0d47c")
	var cyan: = Color("73d7dc")
	var radius: = minf(size.x, size.y) * 0.43
	draw_circle(center, radius, Color("071d29"))
	draw_circle(center, radius, Color("8f6d27"), false, maxf(1.4, radius * 0.075))
	draw_circle(center, radius * 0.82, Color("153745"))
	draw_arc(center, radius * 0.82, -2.75, -0.18, 24, cyan, maxf(1.0, radius * 0.045), true)
	draw_arc(center, radius * 0.82, 0.35, 2.15, 20, gold, maxf(1.0, radius * 0.045), true)
	var scale_factor: = radius / 34.0
	var plot: = PackedVector2Array([
		center + Vector2(0, -22) * scale_factor, center + Vector2(23, -7) * scale_factor, 
		center + Vector2(16, 20) * scale_factor, center + Vector2(-20, 17) * scale_factor, 
		center + Vector2(-24, -8) * scale_factor, 
	])
	draw_colored_polygon(plot, Color("0b2633"))
	draw_polyline(PackedVector2Array([plot[0], plot[1], plot[2], plot[3], plot[4], plot[0]]), gold, maxf(1.2, 2.4 * scale_factor), true)
	for offset in [-8.0, 0.0, 8.0]:
		draw_line(center + Vector2(offset, -13) * scale_factor, center + Vector2(offset, 12) * scale_factor, Color(cyan, 0.72), maxf(0.8, scale_factor))
	for offset in [-7.0, 2.0, 11.0]:
		draw_line(center + Vector2(-13, offset) * scale_factor, center + Vector2(12, offset) * scale_factor, Color(cyan, 0.72), maxf(0.8, scale_factor))
	var seal_center: = center + Vector2(12, 10) * scale_factor
	draw_circle(seal_center, 7.0 * scale_factor, Color("9c7127"))
	draw_circle(seal_center, 7.0 * scale_factor, gold, false, maxf(1.0, 1.8 * scale_factor))
	draw_line(seal_center + Vector2(0, 6) * scale_factor, seal_center + Vector2(0, 14) * scale_factor, gold, maxf(1.0, 1.8 * scale_factor))
