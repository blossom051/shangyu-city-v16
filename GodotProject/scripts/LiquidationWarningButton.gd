class_name LiquidationWarningButton
extends Button


func _ready() -> void:
	text = ""
	flat = true
	custom_minimum_size = Vector2(58, 58)
	size = Vector2(58, 58)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "申请破产清算并主动结束当前财团经营"
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var hovered := is_hovered()
	var c := Color("ff626b") if hovered else Color("dd4854")
	var centre := size * 0.5
	# Q版警示徽章：柔和圆角外轮廓、微笑腮红与清晰叹号，避免旧版
	# 巨大三角形压住旁边的 HUD。
	draw_circle(centre + Vector2(0, 2), 25.0, Color(0.02, 0.08, 0.12, 0.82))
	draw_circle(centre, 24.0, Color(c, 0.20 if not hovered else 0.34))
	draw_arc(centre, 23.0, 0, TAU, 48, c, 3.2, true)
	var shield := PackedVector2Array([centre + Vector2(0, -16), centre + Vector2(14, -9), centre + Vector2(11, 10), centre + Vector2(0, 18), centre + Vector2(-11, 10), centre + Vector2(-14, -9)])
	draw_colored_polygon(shield, Color(c, 0.72))
	draw_line(centre + Vector2(0, -9), centre + Vector2(0, 5), Color("fff0e8"), 4.0, true)
	draw_circle(centre + Vector2(0, 11), 2.6, Color("fff0e8"))
	draw_circle(centre + Vector2(-9, 6), 2.2, Color("ff9ca2"))
	draw_circle(centre + Vector2(9, 6), 2.2, Color("ff9ca2"))
	draw_line(centre + Vector2(17, -16), centre + Vector2(21, -20), Color("ffe18a"), 2.0, true)
	draw_line(centre + Vector2(19, -14), centre + Vector2(23, -14), Color("ffe18a"), 2.0, true)
