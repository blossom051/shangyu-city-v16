class_name TalentCardBack
extends Button

var quality: = "blue"
var clock: = 0.0


func setup(value: String) -> void :
	quality = value
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void :
	clock += delta
	queue_redraw()


func _draw() -> void :
	var accent: = _quality_color(quality)
	var hover_gain: = 1.0 if is_hovered() else 0.0
	var rect: = Rect2(4, 4, size.x - 8, size.y - 8)
	draw_style_box(_outer_frame(accent, hover_gain), rect)
	draw_style_box(_inner_frame(accent), rect.grow(-10))
	var center: = rect.get_center() - Vector2(0, 8)
	for radius in [38.0, 60.0, 82.0]:
		draw_arc(center, radius, clock * 0.22, TAU + clock * 0.22, 72, Color(accent, 0.16 + hover_gain * 0.08), 1.5, true)
	for index in range(8):
		var angle: = TAU * float(index) / 8.0 - clock * 0.18
		var point: = center + Vector2.from_angle(angle) * 70.0
		draw_circle(point, 2.5 + hover_gain, Color(accent, 0.58))
	var diamond: = PackedVector2Array([center + Vector2(0, -43), center + Vector2(34, 0), center + Vector2(0, 43), center + Vector2(-34, 0)])
	draw_colored_polygon(diamond, Color(accent, 0.12 + hover_gain * 0.06))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(accent, 0.86), 2.5, true)
	draw_circle(center, 22.0, Color(0.015, 0.035, 0.09, 0.96))
	draw_arc(center, 18.0, 0, TAU, 40, Color(accent, 0.92), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -10), center + Vector2(9, 0), center + Vector2(0, 10), center + Vector2(-9, 0)]), Color(accent, 0.72))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 47), "人才契约", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 17, Color("f2ead6"))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 23), "触碰以开启档案", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 12, Color("9fc5d3"))


func _outer_frame(accent: Color, hover_gain: float) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new();style.bg_color = Color("07142e");style.border_color = accent.lightened(hover_gain * 0.18);style.set_border_width_all(3);style.set_corner_radius_all(16);style.shadow_color = Color(accent, 0.26 + hover_gain * 0.22);style.shadow_size = 14 + int(hover_gain * 5.0);return style


func _inner_frame(accent: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new();style.bg_color = Color(0.02, 0.065, 0.14, 0.9);style.border_color = Color(accent, 0.38);style.set_border_width_all(1);style.set_corner_radius_all(11);return style


func _quality_color(value: String) -> Color:
	return {"blue": Color("54b9e8"), "platinum": Color("d0e4eb"), "gold": Color("efc653"), "red": Color("ef5865")}.get(value, Color("54b9e8"))
