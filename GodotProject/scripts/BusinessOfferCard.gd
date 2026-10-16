class_name BusinessOfferCard
extends Button

const VENUE_ATLAS = preload("res://assets/ui/business/business_venue_atlas_v82.png")
const VENUE_INDEX: = {
	"convenience": 0, 
	"restaurant": 1, 
	"supermarket": 2, 
	"entertainment": 3, 
	"ecommerce": 4, 
	"logistics": 5, 
	"research": 6, 
	"incubator": 7, 
	"mall": 8, 
	"financial_office": 9, 
	"training": 10, 
	"clinic": 11, 
}
const WEST_BANK_ART: Dictionary = {
	"investment_bank_hq": preload("res://assets/ui/business/west_bank/investment_bank_hq.png"),
	"asset_management_center": preload("res://assets/ui/business/west_bank/asset_management_center.png"),
	"fintech_lab": preload("res://assets/ui/business/west_bank/fintech_lab.png"),
	"data_exchange": preload("res://assets/ui/business/west_bank/data_exchange.png"),
	"cross_border_clearing": preload("res://assets/ui/business/west_bank/cross_border_clearing.png"),
	"international_convention": preload("res://assets/ui/business/west_bank/international_convention.png"),
}

var business: Dictionary = {}
var land: Dictionary = {}
var recommended: = false
var recommendation: Dictionary = {}


func setup(value: Dictionary, land_value: Dictionary = {}, recommendation_value: Dictionary = {}) -> void :
	business = value
	land = land_value
	recommendation = recommendation_value
	if recommendation.is_empty():
		recommendation = preload("res://scripts/BusinessRecommendationEngine.gd").result_for(business, land)
	recommended = bool(recommendation.get("recommended", false))
	text = ""
	custom_minimum_size = Vector2(304, 334)
	tooltip_text = investment_summary()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_ensure_art_layer()
	queue_redraw()


func venue_region() -> Rect2:
	var index: = int(VENUE_INDEX.get(str(business.get("id", "convenience")), 0))
	var cell: = Vector2(float(VENUE_ATLAS.get_width()) / 4.0, float(VENUE_ATLAS.get_height()) / 3.0)
	var cell_origin: = Vector2(float(index % 4) * cell.x, float(index / 4) * cell.y)
	return Rect2(cell_origin + Vector2(6, 70), Vector2(cell.x - 12, cell.y - 140))


func _business_art() -> Texture2D:
	var west_texture := WEST_BANK_ART.get(str(business.get("id", ""))) as Texture2D
	if west_texture != null:
		return west_texture
	var texture := AtlasTexture.new()
	texture.atlas = VENUE_ATLAS
	texture.region = venue_region()
	return texture


func _ensure_art_layer() -> void:
	var art := get_node_or_null("BusinessArt") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = "BusinessArt"
		art.position = Vector2(19, 19)
		art.size = Vector2(266, 146)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	art.texture = _business_art()
	var tint := get_node_or_null("BusinessArtTint") as ColorRect
	if tint == null:
		tint = ColorRect.new()
		tint.name = "BusinessArtTint"
		tint.position = Vector2(19, 19)
		tint.size = Vector2(266, 146)
		tint.color = Color(0.02, 0.08, 0.1, 0.13)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tint)
	var badge := get_node_or_null("RecommendationBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "RecommendationBadge"
		badge.position = Vector2(25, 25)
		badge.size = Vector2(92, 27)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 13)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
	badge.text = str(recommendation.get("badge", "街区推荐"))
	badge.visible = recommended
	if recommended:
		badge.add_theme_color_override("font_color", Color("10242d"))
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(_accent(), 0.94)
		badge_style.set_corner_radius_all(8)
		badge.add_theme_stylebox_override("normal", badge_style)


func investment_summary() -> String:
	var net: = maxi(1, int(recommendation.get("adjusted_net", int(business.get("income", 0)) - int(business.get("fixed_cost", 0)))))
	var display_cost: = int(business.get("display_cost", business.get("cost", 0)))
	var payback: = ceili(float(display_cost) / float(net))
	return "%s\n定位　%s\n预计净收益　%d 万/回合\n实际投资　%d 万（风险附加 %d 万）\n静态回本　约 %d 回合\n主要风险　%s" % [
		str(business.get("name", "企业方案")), 
		str(recommendation.get("reason", _fit_name())), 
		net, 
		display_cost, 
		int(business.get("risk_surcharge", 0)), 
		payback, 
		_risk_name(int(business.get("risk", 0)))
	]


func _make_custom_tooltip(for_text: String) -> Object:
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 162)
	var accent: = _accent()
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.1, 0.985)
	style.border_color = Color(accent, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var label: = Label.new()
	label.text = for_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("edf4f5"))
	label.add_theme_constant_override("line_spacing", 5)
	panel.add_child(label)
	return panel


func _draw() -> void :
	var accent: = _accent()
	var r: = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var card: = StyleBoxFlat.new()
	card.bg_color = Color(0.025, 0.095, 0.12, 0.98)
	card.border_color = Color(accent, 1.0 if is_hovered() else 0.74)
	card.set_border_width_all(3 if is_hovered() else 2)
	card.set_corner_radius_all(15)
	draw_style_box(card, r)
	if recommended:
		draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), accent, true)
	var art: = Rect2(17, 17, size.x - 34, 150)
	draw_rect(art, Color(accent, 0.78), false, 2)
	var font: = ThemeDB.fallback_font
	draw_string(font, Vector2(22, 198), str(business.get("name", "企业方案")), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 44), 22, Color("edf4f5"))
	draw_string(font, Vector2(22, 222), str(recommendation.get("reason", "按基础收益测算")).left(19), HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 44), 13, Color("d8c27a") if recommended else Color("8fa7ae"))
	draw_string(font, Vector2(22, 244), "投资 %d 万　 　%d 回合建成" % [int(business.get("display_cost", business.get("cost", 0))), int(business.get("build_rounds", 0))], HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 44), 14, Color("a9bdc4"))
	var net: = int(recommendation.get("adjusted_net", int(business.get("income", 0)) - int(business.get("fixed_cost", 0))))
	_draw_metric(font, Rect2(20, 258, 78, 52), "街区净收益", "+%d" % net, Color("66d39b"))
	_draw_metric(font, Rect2(112, 258, 72, 52), "风险", _risk_name(int(business.get("risk", 0))), accent)
	_draw_metric(font, Rect2(198, 258, 86, 52), "回本", "%d 回合" % ceili(float(business.get("display_cost", business.get("cost", 0))) / float(maxi(1, net))), Color("e4c56d"))
	if disabled:
		draw_rect(r, Color(0.015, 0.025, 0.03, 0.58), true)
		draw_string(font, Vector2(0, size.y * 0.53), "资金不足", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 20, Color("ef8b81"))


func _draw_badge(font: Font, pos: Vector2, text_value: String, accent: Color) -> void :
	var box: = StyleBoxFlat.new()
	box.bg_color = Color(accent, 0.92)
	box.set_corner_radius_all(8)
	draw_style_box(box, Rect2(pos.x - 7, pos.y - 22, 84, 26))
	draw_string(font, pos, text_value, HORIZONTAL_ALIGNMENT_CENTER, 70, 13, Color("10242d"))


func _draw_metric(font: Font, rect: Rect2, label: String, value: String, color: Color) -> void :
	draw_string(font, rect.position + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x), 12, Color("839da7"))
	draw_string(font, rect.position + Vector2(0, 40), value, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x), 17, color)


func _accent() -> Color:
	var risk: = int(business.get("risk", 0))
	return Color("65c9a4") if risk < 15 else Color("e1bd5c") if risk < 30 else Color("df736f")


func _risk_name(risk: int) -> String:
	return "低" if risk < 15 else "中" if risk < 30 else "高"


func _fit_score() -> int:
	var tags: Array = land.get("environment", []).duplicate()
	tags.append(str(land.get("district", "")))
	var score: = 0
	for fit_tag in business.get("fit", []):
		if tags.has(fit_tag):
			score += 1
	return score


func _fit_name() -> String:
	var fit_names: Array[String] = []
	var labels: = {"residential": "住宅", "education": "教育", "commercial": "商业", "finance": "金融", "technology": "科技", "logistics": "物流", "entertainment": "文娱", "newtown": "新区", "oldtown": "老城"}
	for value in business.get("fit", []):
		fit_names.append(str(labels.get(str(value), str(value))))
	return "适合%s区" % " / ".join(fit_names)
