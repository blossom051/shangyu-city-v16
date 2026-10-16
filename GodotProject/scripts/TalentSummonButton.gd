class_name TalentSummonButton
extends Button

var portal_title: = "人才召募"
var portal_cost: = ""
var accent: = Color("63c8ef")
var symbol_count: = 1


func _ready() -> void :
	text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func set_portal_label(title: String, cost: String, color: Color, count: int) -> void :
	portal_title = title
	portal_cost = cost
	accent = color
	symbol_count = count
	text = ""
	queue_redraw()


func _draw() -> void :
	var active: = not disabled
	var glow: = 1.0 if is_hovered() and active else 0.0
	var color: = accent.lightened(glow * 0.16) if active else Color("52616c")
	var cut: = 18.0
	var polygon: = PackedVector2Array([Vector2(cut, 2), Vector2(size.x - cut, 2), Vector2(size.x - 2, cut), Vector2(size.x - 2, size.y - cut), Vector2(size.x - cut, size.y - 2), Vector2(cut, size.y - 2), Vector2(2, size.y - cut), Vector2(2, cut)])
	draw_colored_polygon(polygon, Color(0.018, 0.045, 0.12, 0.94) if active else Color(0.025, 0.04, 0.06, 0.82))
	var outline: = PackedVector2Array(polygon)
	outline.append(polygon[0])
	draw_polyline(outline, Color(color, 0.92), 2.0 + glow * 1.5, true)
	var seal: = Vector2(40, size.y * 0.5)
	draw_circle(seal, 24.0, Color(color, 0.08 + glow * 0.08));draw_arc(seal, 21.0, 0, TAU, 40, Color(color, 0.78), 2.0, true);draw_arc(seal, 14.0, 0, TAU, 32, Color(color, 0.38), 1.0, true)
	if symbol_count >= 5:
		for index in range(5):
			draw_circle(seal + Vector2.from_angle(TAU * float(index) / 5.0 - PI * 0.5) * 9.0, 2.8, Color(color, 0.9))
	elif symbol_count == 3:
		var star: = PackedVector2Array()
		for index in range(6):
			star.append(seal + Vector2.from_angle( - PI * 0.5 + TAU * float(index) / 6.0) * (11.0 if index % 2 == 0 else 5.0))
		draw_colored_polygon(star, Color(color, 0.78))
	else:
		draw_colored_polygon(PackedVector2Array([seal + Vector2(0, -10), seal + Vector2(9, 0), seal + Vector2(0, 10), seal + Vector2(-9, 0)]), Color(color, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(72, 34), portal_title, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 82), 19, color)
	draw_string(ThemeDB.fallback_font, Vector2(72, 58), portal_cost, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 82), 13, Color("c8d8de") if active else Color("687984"))
