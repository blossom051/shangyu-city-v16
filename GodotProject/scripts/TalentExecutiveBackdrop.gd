class_name TalentExecutiveBackdrop
extends Control


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color("071d27"), true)
	var skyline_base: = size.y * 0.68
	for i in range(18):
		var w: = 50.0 + float((i * 19) % 44)
		var h: = 80.0 + float((i * 47) % 160)
		var x: = float(i) * size.x / 17.0 - 26.0
		draw_rect(Rect2(x, skyline_base - h, w, h), Color(0.08, 0.2, 0.25, 0.34), true)
		for row in range(3):
			draw_line(Vector2(x + 10, skyline_base - h + 18 + row * 22), Vector2(x + w - 10, skyline_base - h + 18 + row * 22), Color(0.74, 0.63, 0.32, 0.08), 2)
	draw_rect(Rect2(0, skyline_base, size.x, size.y - skyline_base), Color("0b2832"), true)
	draw_line(Vector2(0, skyline_base), Vector2(size.x, skyline_base), Color("b8964d"), 2)
	for i in range(5):
		var y: = skyline_base + 30 + i * 44
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.45, 0.67, 0.7, 0.045), 1)
	draw_string(ThemeDB.fallback_font, Vector2(30, size.y - 28), "EXECUTIVE SEARCH  /  BOARD TALENT OFFICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.81, 0.8, 0.34))
