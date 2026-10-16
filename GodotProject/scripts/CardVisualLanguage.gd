class_name CardVisualLanguage
extends RefCounted

const ArtRegistry = preload("res://scripts/CardArtRegistry.gd")
const BODY_FONT: Font = preload("res://Themes/V9141BodyFont.tres")
const MEDIUM_FONT: Font = preload("res://Themes/V9141BodyMediumFont.tres")
const DISPLAY_FONT: Font = preload("res://Themes/V9141DisplayFont.tres")
const STRATEGY_CARD_BACK: Texture2D = preload("res://assets/images/v136/cards/premium_capital_card_back.png")
const WEST_BANK_CARD_BACK: Texture2D = preload("res://assets/ui/west_bank/cards/west_bank_card_back.png")

const INK: = Color("e9edf0")
const MUTED: = Color("aebbc2")
const PAPER: = Color("f4ead5")
const DARK: = Color("08151f")
const DARK_2: = Color("102633")
const GOLD: = Color("d6ad54")
const BLUE: = Color("3d86bd")
const GREEN: = Color("3f9670")
const RED: = Color("bf4d57")
const PURPLE: = Color("7557a2")
const TEAL: = Color("3f918d")
const SMOKED_DIAMOND_BASE: = Color("0b151c")
const SMOKED_DIAMOND_INNER: = Color(0.07, 0.13, 0.16, 0.96)
const SMOKED_DIAMOND_HEADER: = Color(0.025, 0.07, 0.09, 0.98)
static func type_color(value: String) -> Color:
	return {
		"attack": RED, 
		"defense": BLUE, 
		"counter": PURPLE, 
		"operation": GREEN, 
		"finance": GOLD, 
		"district": TEAL, 
	}.get(value, PURPLE)


static func type_name(value: String) -> String:
	return {
		"attack": "进攻策略", 
		"defense": "防御部署", 
		"counter": "反制预案", 
		"operation": "经营方案", 
		"finance": "资本工具", 
		"district": "商圈行动", 
	}.get(value, "董事会策略")


static func rarity(value: String) -> String:
	return {"blue": "BLUE", "gold": "GOLD", "platinum": "PLATINUM", "red": "RED TRUMP", "gilded": "曜金典藏", "west_bank": "西岸普通", "west_bank_advanced": "西岸高级"}.get(value, "STANDARD")


static func rarity_color(value: String) -> Color:
	return {
		"blue": Color("4f9bc8"), 
		"gold": Color("d8ad50"), 
		"platinum": Color("b8d2dc"), 
		"red": Color("e15b62"), 
		"gilded": Color("f5dfa1"), 
		"west_bank": Color("68e1e8"),
		"west_bank_advanced": Color("f06bdc"),
	}.get(value, Color("4f9bc8"))


static func rarity_material(value: String) -> Dictionary:
	return {
		"blue": {"base": Color("0b263b"), "inner": Color("123b55"), "header": Color("0a1d2c"), "ink": Color("f2f7f8"), "muted": Color("c4d7df")}, 
		"gold": {"base": Color("241b10"), "inner": Color("493416"), "header": Color("1c160d"), "ink": Color("fff3d7"), "muted": Color("e2cfaa")}, 
		"platinum": {"base": Color("18242b"), "inner": Color("354650"), "header": Color("101a20"), "ink": Color("f7fbff"), "muted": Color("d0dde2")}, 
		"red": {"base": Color("2c0d16"), "inner": Color("591a29"), "header": Color("210a11"), "ink": Color("fff1e8"), "muted": Color("e8c8c6")}, 
		"gilded": {"base": SMOKED_DIAMOND_BASE, "inner": SMOKED_DIAMOND_INNER, "header": SMOKED_DIAMOND_HEADER, "ink": Color("fff9ea"), "muted": Color("d7e5e7")}, 
		"west_bank": {"base": Color("041b2c"), "inner": Color("092f42"), "header": Color("041522"), "ink": Color("fff0bd"), "muted": Color("b9dfe3")},
		"west_bank_advanced": {"base": Color("120822"), "inner": Color("281044"), "header": Color("090514"), "ink": Color("fff2ce"), "muted": Color("ebc9ee")},
	}.get(value, {"base": Color("0b263b"), "inner": Color("123b55"), "header": Color("0a1d2c"), "ink": Color("f2f7f8"), "muted": Color("c4d7df")})


static func collection_surface(value: String) -> Color:
	return Color(rarity_material(value).base).darkened(0.12)


static func uses_premium_atlas() -> bool:
	return ArtRegistry.composition_count() >= 30


static func draw_back(canvas: CanvasItem, size: Vector2, selected: = false, phase: = 0.0) -> void :
	var r: = Rect2(5, 5, size.x - 10, size.y - 10)
	_box(canvas, Rect2(r.position + Vector2(0, 6), r.size), Color(0.015, 0.1, 0.14, 0.34), Color.TRANSPARENT, 0, 18)
	_box(canvas, r, Color("071b35"), Color("80e9ff") if selected else Color("698da9"), 4 if selected else 2, 18)
	canvas.draw_texture_rect(STRATEGY_CARD_BACK, r.grow(-5), false)
	canvas.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y * 0.13)), Color(0.01, 0.025, 0.04, 0.28), true)
	canvas.draw_rect(Rect2(r.position + Vector2(5, r.size.y * 0.84), Vector2(r.size.x - 10, r.size.y * 0.13)), Color(0.01, 0.025, 0.04, 0.32), true)
	_box(canvas, r.grow(-8), Color.TRANSPARENT, Color(GOLD, 0.64), 1, 13)
	if selected:
		_selection_glow(canvas, r, Color("78dcff"), phase)


static func draw_west_bank_back(canvas: CanvasItem, size: Vector2, selected: = false, phase: = 0.0) -> void:
	var r := Rect2(5, 5, size.x - 10, size.y - 10)
	_box(canvas, Rect2(r.position + Vector2(0, 7), r.size), Color(0.0, 0.05, 0.09, 0.46), Color.TRANSPARENT, 0, 20)
	_box(canvas, r, Color("031624"), Color("76e1e8") if selected else Color("d4b55a"), 5 if selected else 3, 20)
	canvas.draw_texture_rect(WEST_BANK_CARD_BACK, r.grow(-5), false)
	canvas.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y * 0.115)), Color(0.005, 0.02, 0.035, 0.34), true)
	canvas.draw_rect(Rect2(r.position + Vector2(5, r.size.y * 0.865), Vector2(r.size.x - 10, r.size.y * 0.10)), Color(0.005, 0.02, 0.035, 0.38), true)
	_box(canvas, r.grow(-9), Color.TRANSPARENT, Color("78dce2", 0.72), 1, 14)
	if selected:
		_selection_glow(canvas, r, Color("76e1e8"), phase)


static func draw_face(canvas: CanvasItem, size: Vector2, data: Dictionary, selected: = false, phase: = 0.0) -> void :
	if str(data.get("series", "")) == "west_bank":
		_draw_west_bank_face(canvas, size, data, selected, phase)
		return
	var type: = str(data.get("type", "operation"))
	var accent: = type_color(type)
	var rarity_key: = str(data.get("rarity", "blue"))
	var metal: = rarity_color(rarity_key)
	var material: = rarity_material(rarity_key)
	var r: = Rect2(5, 5, size.x - 10, size.y - 10)
	if selected:
		_selection_glow(canvas, r, accent, phase)
	_box(canvas, Rect2(r.position + Vector2(0, 7), r.size), Color(0.015, 0.1, 0.14, 0.36), Color.TRANSPARENT, 0, 19)
	_box(canvas, r, Color(material.base), metal, 5 if selected else 3, 19)
	if rarity_key == "gilded":
		var shimmer: = 0.68 + sin(phase * 1.8) * 0.1
		_box(canvas, r.grow(-3), Color(0.04, 0.11, 0.14, 0.18), Color(1.0, 0.9, 0.64, shimmer), 3, 17)
	_box(canvas, r.grow(-7), Color(material.inner), Color(accent, 0.74), 1, 13)
	if rarity_key == "gilded":


		canvas.draw_line(r.position + Vector2(9, 21), Vector2(r.position.x + 9, r.end.y - 21), Color("8ff5ff", 0.16), 1.2, true)
		canvas.draw_line(Vector2(r.end.x - 9, r.position.y + 21), r.end - Vector2(9, 21), Color("d8b4ff", 0.13), 1.2, true)
	canvas.draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x * 0.18, r.size.y - 16)), Color(metal, 0.035), true)
	canvas.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.72, 8), Vector2(r.size.x * 0.2, r.size.y - 16)), Color(0, 0, 0, 0.08), true)
	var regions: = layout_regions(size)
	var header: Rect2 = regions.header
	var art: Rect2 = regions.art
	var name_rect: Rect2 = regions.name
	var effect_rect: Rect2 = regions.effect
	var footer: Rect2 = regions.keyword
	var font: = BODY_FONT

	_box(canvas, header, Color(material.header), Color(accent, 0.72), 1, 8)
	var crest: = Rect2(header.position + Vector2(5, 4), Vector2(24, 24))
	canvas.draw_circle(crest.get_center(), 12, Color(accent, 0.92))
	canvas.draw_string(font, crest.position + Vector2(0, 18), _type_glyph(type), HORIZONTAL_ALIGNMENT_CENTER, int(crest.size.x), 13, Color("f6edd6"))
	canvas.draw_string(MEDIUM_FONT, header.position + Vector2(36, 21), type_name(type), HORIZONTAL_ALIGNMENT_LEFT, int(header.size.x * 0.62), 12, Color(material.ink))
	canvas.draw_string(MEDIUM_FONT, header.position + Vector2(0, 21), rarity(rarity_key), HORIZONTAL_ALIGNMENT_RIGHT, int(header.size.x - 8), 9, metal)

	_box(canvas, art, Color("06111a"), Color(metal, 0.88), 2, 10)
	if rarity_key == "gilded":
		_box(canvas, art.grow(3), Color.TRANSPARENT, Color("f3d98a"), 2, 12)
	var art_inner: = art.grow(-3)
	var art_asset: = ArtRegistry.resolve(data)


	canvas.draw_texture_rect(art_asset.display_texture, art_inner, false)
	canvas.draw_rect(Rect2(art_inner.position, Vector2(art_inner.size.x, art_inner.size.y * 0.18)), Color(0.02, 0.05, 0.08, 0.26), true)
	canvas.draw_rect(Rect2(Vector2(art_inner.position.x, art_inner.end.y - art_inner.size.y * 0.24), Vector2(art_inner.size.x, art_inner.size.y * 0.24)), Color(0.01, 0.03, 0.05, 0.58), true)
	canvas.draw_line(art_inner.position + Vector2(4, 4), art_inner.position + Vector2(30, 4), Color(metal, 0.9), 2.0)
	canvas.draw_line(art_inner.position + Vector2(4, 4), art_inner.position + Vector2(4, 30), Color(metal, 0.9), 2.0)
	canvas.draw_line(art_inner.end - Vector2(4, 4), art_inner.end - Vector2(30, 4), Color(metal, 0.9), 2.0)
	canvas.draw_line(art_inner.end - Vector2(4, 4), art_inner.end - Vector2(4, 30), Color(metal, 0.9), 2.0)
	var cost_rect: = Rect2(art.position + Vector2(8, 8), Vector2(32, 32))
	_box(canvas, cost_rect, Color("071722"), metal, 2, 16)
	canvas.draw_string(font, cost_rect.position + Vector2(0, 23), str(int(data.get("cost", 1))), HORIZONTAL_ALIGNMENT_CENTER, int(cost_rect.size.x), 16, Color("fff0c2"))
	canvas.draw_string(font, art.position + Vector2(0, art.size.y - 9), category_name(str(data.get("category", "operation"))), HORIZONTAL_ALIGNMENT_RIGHT, int(art.size.x - 9), 10, Color("f2dfad"))

	canvas.draw_string(DISPLAY_FONT, name_rect.position + Vector2(1, 23), str(data.get("name", "策略卡")), HORIZONTAL_ALIGNMENT_LEFT, int(name_rect.size.x), 20, Color(0.01, 0.02, 0.025, 0.82))
	canvas.draw_string(DISPLAY_FONT, name_rect.position + Vector2(0, 22), str(data.get("name", "策略卡")), HORIZONTAL_ALIGNMENT_LEFT, int(name_rect.size.x), 20, Color(material.ink))
	canvas.draw_line(Vector2(name_rect.position.x, name_rect.end.y + 1), Vector2(name_rect.end.x, name_rect.end.y + 1), Color(metal, 0.62), 1.0)
	var max_lines: = maxi(2, int(effect_rect.size.y / 17.0))
	var effect_lines: = _wrapped_lines(effect_name(data), maxi(9, int(effect_rect.size.x / 13.5)), max_lines)
	for index in range(effect_lines.size()):
		var text_pos: = effect_rect.position + Vector2(0, 16 + index * 18)
		canvas.draw_string(font, text_pos + Vector2(1, 1), effect_lines[index], HORIZONTAL_ALIGNMENT_LEFT, int(effect_rect.size.x), 14, Color(0.005, 0.012, 0.018, 0.8))
		canvas.draw_string(font, text_pos, effect_lines[index], HORIZONTAL_ALIGNMENT_LEFT, int(effect_rect.size.x), 14, Color(material.muted))

	_box(canvas, footer, Color(accent, 0.14), Color(accent, 0.72), 1, 7)
	var timing: = "立即结算" if int(data.get("duration", 0)) <= 0 else "持续 %d 回合" % int(data.duration)
	var keywords: Array = data.get("keywords", [])
	var keyword_text: = " / ".join(keywords.slice(0, 2))
	canvas.draw_string(MEDIUM_FONT, footer.position + Vector2(7, 18), "%s  %s  %s" % [_target_short(str(data.get("target", "self"))), timing, keyword_text], HORIZONTAL_ALIGNMENT_LEFT, int(footer.size.x - 14), 11, Color(material.ink))


static func _draw_west_bank_face(canvas: CanvasItem, size: Vector2, data: Dictionary, selected: bool, phase: float) -> void:
	var r := Rect2(5, 5, size.x - 10, size.y - 10)
	var advanced := str(data.get("rarity", "")) == "west_bank_advanced"
	var cyan := Color("f06bdc") if advanced else Color("73e1e8")
	var gold := Color("ffd477") if advanced else Color("e0bd62")
	var base := Color("10071e") if advanced else Color("031826")
	var inner := Color("2b1045") if advanced else Color("082d3e")
	if selected:
		_selection_glow(canvas, r, cyan, phase)
	_box(canvas, Rect2(r.position + Vector2(0, 8), r.size), Color(0.0, 0.05, 0.09, 0.48), Color.TRANSPARENT, 0, 21)
	_box(canvas, r, base, gold, 5 if advanced or selected else 3, 21)
	_box(canvas, r.grow(-7), inner, cyan, 2 if advanced else 1, 15)
	if advanced:
		var breathe := 0.68 + sin(phase * 2.4) * 0.18
		_box(canvas, r.grow(2), Color.TRANSPARENT, Color(cyan, 0.16 + breathe * 0.16), 3, 23)
		_box(canvas, r.grow(-3), Color.TRANSPARENT, Color(gold, 0.38 + breathe * 0.30), 2, 18)
		_box(canvas, r.grow(-10), Color.TRANSPARENT, Color(cyan, 0.30 + breathe * 0.25), 1, 13)
		var orbit_center := Vector2(r.end.x - 29, r.position.y + 30)
		canvas.draw_circle(orbit_center, 14.0, Color(cyan, 0.18), false, 3.0, true)
		canvas.draw_circle(orbit_center, 8.0, Color(gold, 0.82), false, 2.0, true)
		for particle in range(10):
			var travel := fposmod(phase * (0.16 + particle * 0.011) + particle * 0.097, 1.0)
			var perimeter := (r.size.x + r.size.y) * 2.0
			var distance := travel * perimeter
			var point := r.position
			if distance < r.size.x:
				point += Vector2(distance, 0)
			elif distance < r.size.x + r.size.y:
				point += Vector2(r.size.x, distance - r.size.x)
			elif distance < r.size.x * 2.0 + r.size.y:
				point += Vector2(r.size.x - (distance - r.size.x - r.size.y), r.size.y)
			else:
				point += Vector2(0, r.size.y - (distance - r.size.x * 2.0 - r.size.y))
			var sparkle := 1.4 + float(particle % 3) * 0.8
			canvas.draw_circle(point, sparkle * 2.3, Color(cyan if particle % 2 else gold, 0.10), true)
			canvas.draw_circle(point, sparkle, Color("fff7d0"), true)
	var regions := layout_regions(size)
	var header: Rect2 = regions.header
	var art: Rect2 = regions.art
	var name_rect: Rect2 = regions.name
	var effect_rect: Rect2 = regions.effect
	var footer: Rect2 = regions.keyword
	_box(canvas, header, Color("090514") if advanced else Color("041522"), Color(gold, 0.82), 1, 9)
	canvas.draw_string(MEDIUM_FONT, header.position + Vector2(9, 21), "WEST BANK ADVANCED  ·  西岸高级" if advanced else "WEST BANK  ·  西岸普通", HORIZONTAL_ALIGNMENT_LEFT, int(header.size.x * 0.76), 11 if advanced else 12, Color("fff0bd"))
	canvas.draw_string(MEDIUM_FONT, header.position + Vector2(0, 21), "%d SP" % int(data.get("cost", 3)), HORIZONTAL_ALIGNMENT_RIGHT, int(header.size.x - 9), 12, cyan)
	_box(canvas, art, Color("020d16"), Color(cyan, 0.92), 2, 11)
	var art_asset := ArtRegistry.resolve(data)
	canvas.draw_texture_rect(art_asset.display_texture, art.grow(-3), false)
	canvas.draw_rect(Rect2(Vector2(art.position.x + 3, art.end.y - art.size.y * 0.23), Vector2(art.size.x - 6, art.size.y * 0.20)), Color(0.005, 0.025, 0.04, 0.68), true)
	canvas.draw_string(MEDIUM_FONT, art.position + Vector2(0, art.size.y - 10), category_name(str(data.get("category", "finance"))), HORIZONTAL_ALIGNMENT_RIGHT, int(art.size.x - 9), 11, Color("fff0bd"))
	canvas.draw_string(DISPLAY_FONT, name_rect.position + Vector2(0, 22), str(data.get("name", "西岸策略")), HORIZONTAL_ALIGNMENT_LEFT, int(name_rect.size.x), 20, Color("fff3c6"))
	canvas.draw_line(Vector2(name_rect.position.x, name_rect.end.y + 1), Vector2(name_rect.end.x, name_rect.end.y + 1), Color(cyan, 0.64), 1.0)
	var max_lines := maxi(2, int(effect_rect.size.y / 17.0))
	var effect_lines := _wrapped_lines(effect_name(data), maxi(9, int(effect_rect.size.x / 13.5)), max_lines)
	for index in range(effect_lines.size()):
		canvas.draw_string(BODY_FONT, effect_rect.position + Vector2(0, 16 + index * 18), effect_lines[index], HORIZONTAL_ALIGNMENT_LEFT, int(effect_rect.size.x), 14, Color("c6e4e6"))
	_box(canvas, footer, Color("50134e", 0.76) if advanced else Color("0a4050", 0.76), Color(gold, 0.78), 1, 8)
	var keywords: Array = data.get("keywords", [])
	canvas.draw_string(MEDIUM_FONT, footer.position + Vector2(7, 18), "%s  %s" % [_target_short(str(data.get("target", "self"))), " / ".join(keywords.slice(0, 2))], HORIZONTAL_ALIGNMENT_LEFT, int(footer.size.x - 14), 11, Color("fff0bd"))
static func layout_regions(size: Vector2) -> Dictionary:
	var margin: = 15.0
	var header: = Rect2(margin, 14, size.x - margin * 2.0, 32)
	var art_height: = clampf(size.y * 0.43, 92.0, 142.0)
	var art: = Rect2(margin, header.end.y + 7.0, size.x - margin * 2.0, art_height)
	var name_rect: = Rect2(margin, art.end.y + 7.0, size.x - margin * 2.0, 25)
	var footer: = Rect2(margin, size.y - 34.0, size.x - margin * 2.0, 25)
	var effect_top: = name_rect.end.y + 5.0
	var effect: = Rect2(margin, effect_top, size.x - margin * 2.0, maxf(32.0, footer.position.y - effect_top - 5.0))
	return {"header": header, "art": art, "name": name_rect, "effect": effect, "keyword": footer}


static func effect_name(card: Dictionary) -> String:
	if not str(card.get("description", "")).is_empty():
		return str(card.description)
	return "效果说明缺失"


static func category_name(value: String) -> String:
	return {
		"construction": "施工", 
		"finance": "金融", 
		"operation": "经营", 
		"district": "商圈", 
		"talent": "人才", 
		"public_opinion": "舆情", 
		"bank": "银行", 
		"auction": "拍卖", 
		"startup": "创投", 
		"land": "土地", 
		"stock": "证券", 
		"news": "新闻", 
	}.get(value, "策略")


static func _selection_glow(canvas: CanvasItem, rect: Rect2, accent: Color, phase: float) -> void :
	var breathe: = 0.76 + sin(phase * 2.0) * 0.06
	_box(canvas, rect.grow(5), Color.TRANSPARENT, Color(accent, 0.24 * breathe), 2, 22)
	_box(canvas, rect.grow(9), Color.TRANSPARENT, Color(accent, 0.1 * breathe), 1, 25)


static func _type_glyph(type: String) -> String:
	return {"attack": "⚡", "defense": "盾", "counter": "↺", "operation": "◆", "finance": "￥", "district": "城"}.get(type, "策")


static func _target_short(target: String) -> String:
	return {
		"self": "目标：己方", 
		"own_business": "目标：己方企业", 
		"own_construction": "目标：己方项目", 
		"enemy": "目标：对手", 
		"enemy_business": "目标：对手企业", 
		"enemy_construction": "目标：对手项目", 
		"stock": "目标：证券", 
		"district": "目标：商圈", 
		"available_land": "目标：待售土地", 
	}.get(target, "目标：合法对象")


static func _wrapped_lines(value: String, limit: int, max_lines: int) -> Array[String]:
	var result: Array[String] = []
	var cursor: = 0
	while cursor < value.length() and result.size() < max_lines:
		var line: = value.substr(cursor, limit)
		cursor += line.length()
		if result.size() == max_lines - 1 and cursor < value.length():
			line = line.left(maxi(1, limit - 1)) + "…"
			cursor = value.length()
		result.append(line)
	return result


static func _box(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, width: int, radius: int) -> void :
	var box: = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	canvas.draw_style_box(box, rect)
