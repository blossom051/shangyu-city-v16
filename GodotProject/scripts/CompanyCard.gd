class_name CompanyCard
extends Button

const DISPLAY_FONT = preload("res://assets/fonts/v9141/SmileySans-Oblique.ttf")
const BODY_FONT = preload("res://assets/fonts/v9141/SourceHanSansCN-Medium.otf")

var company: Dictionary = {}
var selected: = false
var hovered: = false


func setup(value: Dictionary, compact_layout: = false) -> void :
	company = value
	text = ""
	custom_minimum_size = Vector2(286, 132) if compact_layout else Vector2(312, 140)
	pivot_offset = custom_minimum_size * 0.5
	tooltip_text = "%s\n%s\n%s" % [company.name, company.ability_text, company.playstyle]
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	queue_redraw()


func set_selected(value: bool) -> void :
	selected = value
	z_index = 10 if value else 5 if hovered else 0
	var target: = Vector2(1.035, 1.035) if value else Vector2(1.018, 1.018) if hovered else Vector2.ONE
	if GameSettings.reduce_motion:
		scale = target
	else:
		var tween: = create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", target, 0.14)
	queue_redraw()


func _hover(value: bool) -> void :
	hovered = value
	set_selected(selected)
	if value:
		AudioManager.hover()


func _draw() -> void :
	var accent: = Color(str(company.get("color", "#56a7b4")))
	var r: = Rect2(4, 4, size.x - 8, size.y - 8)
	if selected:
		_draw_round(r.grow(7), Color("f1cb68"), Color(accent, 0.12), 2, 20)
		_draw_round(r.grow(4), Color(accent, 0.55), Color.TRANSPARENT, 5, 18)
	_draw_round(Rect2(r.position + Vector2(0, 7), r.size), Color.TRANSPARENT, Color(0, 0, 0, 0.3), 0, 14)
	_draw_round(r, Color("e3bd5c") if selected else Color(accent, 0.8 if hovered else 0.58), Color(0.018, 0.075, 0.105, 0.98), 3 if selected else 2, 14)
	_draw_round(r.grow(-7), Color(accent, 0.22), Color.TRANSPARENT, 1, 10)
	draw_rect(Rect2(r.position, Vector2(7, r.size.y)), accent, true)
	var emblem: = Vector2(44, size.y * 0.5)
	draw_circle(emblem, 25, Color(accent, 0.16))
	draw_circle(emblem, 19, accent, false, 3)
	_draw_emblem(emblem, accent)
	draw_string(DISPLAY_FONT, Vector2(78, 34), str(company.get("name", "投资公司")), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 92), 22, Color("f7f1e4"))
	draw_string(BODY_FONT, Vector2(78, 57), "%s  %s 万" % [company.get("type", "资本集团"), company.get("capital", 0)], HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 92), 12, Color("b9ccd1"))
	draw_rect(Rect2(74, 69, size.x - 90, 1), Color(accent, 0.42), true)
	var info_x: = 78.0
	draw_string(BODY_FONT, Vector2(info_x, 92), "优势  %s" % _short(str(company.get("strength", "专属经营能力")).split("，")[0], 16), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - info_x - 14), 12, Color("dff2e8"))
	draw_string(BODY_FONT, Vector2(info_x, 116), "代价  %s" % _short(str(company.get("weakness", "需要审慎经营")).split("，")[0], 16), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - info_x - 14), 12, Color("e4a4a3"))
	if selected:
		draw_circle(Vector2(size.x - 20, 20), 12, Color("d6ad54"))
		draw_circle(Vector2(size.x - 20, 20), 4, Color("132a32"))


func _draw_emblem(center: Vector2, accent: Color) -> void :
	var id: = str(company.get("id", ""))
	var ink: = accent.lightened(0.48)
	match id:
		"hengyue":

			draw_polyline(PackedVector2Array([center + Vector2(-16, 11), center + Vector2(-7, -5), center + Vector2(0, 3), center + Vector2(8, -15), center + Vector2(17, 11)]), ink, 4, true)
			draw_line(center + Vector2(-17, 13), center + Vector2(17, 13), ink, 3)
		"xingchao":

			draw_arc(center, 16, -2.8, 0.8, 22, ink, 4, true)
			draw_arc(center + Vector2(4, 3), 9, -2.5, 1.2, 18, ink, 3, true)
			draw_circle(center + Vector2(12, -10), 3, ink)
		"qiming":

			for angle in range(0, 360, 45):
				var direction: = Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				draw_line(center + direction * 9, center + direction * 16, ink, 3)
			draw_circle(center, 6, ink)
		"jinding":

			for i in range(3):
				draw_rect(Rect2(center + Vector2(-14 + i * 11, 7 - i * 9), Vector2(7, 8 + i * 9)), ink)
			draw_line(center + Vector2(-17, 14), center + Vector2(17, 14), ink, 3)
		"wangang":

			draw_polyline(PackedVector2Array([center + Vector2(-16, 10), center + Vector2(-16, -10), center + Vector2(3, -10), center + Vector2(13, -2)]), ink, 4, true)
			draw_line(center + Vector2(3, -10), center + Vector2(3, 12), ink, 3)
			draw_line(center + Vector2(-18, 13), center + Vector2(18, 13), ink, 3)
		"qinghe":

			draw_arc(center + Vector2(-5, 1), 12, -1.7, 1.5, 18, ink, 4, true)
			draw_arc(center + Vector2(5, 1), 12, 1.7, 4.9, 18, ink, 4, true)
			draw_circle(center, 4, ink)
		"chiyan":

			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -18), center + Vector2(12, 0), center + Vector2(5, 16), center + Vector2(-4, 7), center + Vector2(-13, 13), center + Vector2(-10, -2)]), ink)
			draw_colored_polygon(PackedVector2Array([center + Vector2(1, -7), center + Vector2(6, 5), center + Vector2(0, 12), center + Vector2(-5, 4)]), Color("132a32"))
		"yunshan":

			for offset in [Vector2(-9, -6), Vector2(-2, -2), Vector2(5, 2)]:
				draw_rect(Rect2(center + offset - Vector2(7, 10), Vector2(14, 20)), ink, false, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)]), ink)
		_:
			draw_circle(center, 13, ink, false, 4)


func _short(value: String, count: int) -> String:
	return value if value.length() <= count else value.left(count) + "…"


func _timing_short() -> String:
	var abilities: Dictionary = company.get("abilities", {})
	if abilities.has("event_guard_every"): return "每4回合补盾"
	if abilities.has("income_start_round"): return "第3回合起结算"
	if abilities.has("first_loan_interest_multiplier"): return "首次融资"
	if abilities.has("adjacency_income_multiplier"): return "相邻资产结算"
	if abilities.has("stock_profit_multiplier"): return "证券正收益结算"
	if abilities.has("auction_rebate_rate"): return "首次正常中标后"
	if abilities.has("extra_draw_every"): return "每两次普通抽牌"
	return "每轮经营结算"


func _draw_round(rect: Rect2, border: Color, fill: Color, width: int, radius: int) -> void :
	var box: = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)
