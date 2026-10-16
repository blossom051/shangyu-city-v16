class_name FinalMedalBadge
extends Control

var rank: = 1


func setup(next_rank: int) -> void :
	rank = next_rank
	queue_redraw()


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(92, 92)
	queue_redraw()


func _draw() -> void :
	var colors: = _palette()
	var c: = size * 0.5
	var radius: = minf(size.x, size.y) * 0.36
	draw_circle(c, radius + 14.0, Color(colors.glow, 0.2 if rank == 1 else 0.12))
	for index in range(16):
		var angle: = TAU * float(index) / 16.0
		draw_line(c + Vector2(cos(angle), sin(angle)) * (radius + 3.0), c + Vector2(cos(angle), sin(angle)) * (radius + 12.0), Color(colors.glow, 0.32), 3.0)
	draw_circle(c, radius + 6.0, colors.outer)
	draw_circle(c, radius + 1.0, colors.inner)
	draw_circle(c, radius - 10.0, Color(0.02, 0.065, 0.085, 0.34))
	draw_arc(c, radius - 4.0, -0.92, 3.84, 64, Color(1, 1, 1, 0.24), 4.0, true)
	var font: = ThemeDB.fallback_font
	var label: = "G" if rank == 1 else "S" if rank == 2 else "B"
	draw_string(font, c + Vector2(-12, 10), label, HORIZONTAL_ALIGNMENT_CENTER, 24, 26, Color("fff8df") if rank == 1 else Color("f3f6f7"))
	draw_string(font, c + Vector2(-10, 31), "#%d" % rank, HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color("102a34"))


func _palette() -> Dictionary:
	match rank:
		1:
			return {"outer": Color("ffe07b"), "inner": Color("c78f2c"), "glow": Color("ffdc65")}
		2:
			return {"outer": Color("f2f6f8"), "inner": Color("8fa8b5"), "glow": Color("e4f3ff")}
		_:
			return {"outer": Color("e6a168"), "inner": Color("995d35"), "glow": Color("ffb06e")}
