class_name MusicMascotButton
extends Button

var active: = true


func _ready() -> void :
	text = ""
	custom_minimum_size = Vector2(66, 66)
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	queue_redraw()


func set_active(value: bool) -> void :
	active = value
	queue_redraw()


func _draw() -> void :
	var center: = size * 0.5
	var accent: = Color("f0c85f") if active else Color("81949a")
	draw_circle(center, 30, Color(0.015, 0.07, 0.095, 0.96))
	draw_circle(center, 29, accent, false, 3)
	draw_circle(center, 20, Color(accent, 0.16))
	draw_circle(center, 12, Color("173f51"))
	draw_circle(center, 4, accent)

	draw_arc(center, 24, PI + 0.18, TAU - 0.18, 24, Color("f3e2ae") if active else Color("9aabad"), 5, true)
	draw_rect(Rect2(center + Vector2(-29, -2), Vector2(8, 20)), accent, true)
	draw_rect(Rect2(center + Vector2(21, -2), Vector2(8, 20)), accent, true)
	if active:
		draw_string(ThemeDB.fallback_font, center + Vector2(7, -5), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff0b6"))
