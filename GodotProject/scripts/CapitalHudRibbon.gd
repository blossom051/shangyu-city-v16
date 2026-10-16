class_name CapitalHudRibbon
extends Control


var phase: = 0.0


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process( not GameSettings.reduce_motion)
	queue_redraw()


func _process(delta: float) -> void :
	phase = fposmod(phase + delta, TAU)
	queue_redraw()


func _draw() -> void :
	if size.x < 80.0 or size.y < 44.0:
		return
	var w: = size.x
	var h: = size.y
	var shell: = PackedVector2Array([
		Vector2(28, 3), Vector2(w - 28, 3), Vector2(w - 5, 19), 
		Vector2(w - 5, h - 14), Vector2(w - 20, h - 4), 
		Vector2(20, h - 4), Vector2(5, h - 14), Vector2(5, 19), Vector2(28, 3), 
	])


	draw_polygon(shell, PackedColorArray([Color(0.015, 0.055, 0.082, 0.91)]))
	var lower_glass: = PackedVector2Array([
		Vector2(10, h * 0.48), Vector2(w - 10, h * 0.48), 
		Vector2(w - 10, h - 14), Vector2(w - 20, h - 7), 
		Vector2(20, h - 7), Vector2(10, h - 14), 
	])
	draw_polygon(lower_glass, PackedColorArray([Color(0.035, 0.12, 0.16, 0.24)]))


	var centre: = w * 0.5
	for bloom_index in range(4):
		var bloom_width: = 235.0 + float(bloom_index) * 54.0
		var alpha: = 0.055 - float(bloom_index) * 0.01
		draw_rect(Rect2(centre - bloom_width * 0.5, 8 + bloom_index * 2, bloom_width, h - 18 - bloom_index * 4), Color(0.24, 0.25, 0.14, alpha), true)

	draw_polyline(shell, Color("65bac8", 0.62), 1.25, true)
	draw_line(Vector2(30, 8), Vector2(centre - 94, 8), Color("76d4dd", 0.52), 1.35, true)
	draw_line(Vector2(centre + 94, 8), Vector2(w - 30, 8), Color("76d4dd", 0.52), 1.35, true)
	draw_line(Vector2(22, h - 8), Vector2(centre - 78, h - 8), Color("bc9748", 0.36), 1.1, true)
	draw_line(Vector2(centre + 78, h - 8), Vector2(w - 22, h - 8), Color("bc9748", 0.36), 1.1, true)

	var shimmer: = 0.72 + sin(phase * 1.2) * 0.08
	draw_line(Vector2(centre - 58, 7), Vector2(centre + 58, 7), Color("f2cf71", shimmer), 2.1, true)
	draw_line(Vector2(centre - 42, h - 7), Vector2(centre + 42, h - 7), Color("e4bd5e", 0.64), 1.6, true)
	draw_circle(Vector2(centre, 7), 2.2, Color("fff0b2", 0.86))
