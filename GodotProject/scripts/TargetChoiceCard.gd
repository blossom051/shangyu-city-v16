class_name TargetChoiceCard
extends Button

const StockAssets = preload("res://scripts/StockAssetRegistry.gd")

var data: Dictionary = {}
var selected: = false


func setup(value: Dictionary) -> void :
	data = value
	text = ""
	custom_minimum_size = Vector2(272, 118)
	queue_redraw()


func set_selected(value: bool) -> void :
	selected = value
	queue_redraw()


func _draw() -> void :
	var id: = str(data.get("id", ""))
	var owner_id: = str(data.get("owner_id", ""))
	var is_business: bool = str(data.get("kind", "")) == "business" or GameState.game_data.businesses.has(id)
	var is_stock: = str(data.get("kind", "")) == "stock"
	var accent: = Color(str(data.get("owner_color", "#cf9d48"))) if is_business else Color("cf9d48") if selected else Color("6c9cad")
	var box: = UIStyles.toy_card(accent, selected)
	draw_style_box(box, Rect2(3, 3, size.x - 6, size.y - 6))
	var c: = Vector2(46, size.y * 0.5)
	var label: = str(data.get("label", "目标"))
	if is_stock:
		var texture: = StockAssets.icon(id)
		if texture != null:
			draw_texture_rect(texture, Rect2(14, 24, 64, 64), false)
		var owned: = int(data.get("shares", 0)) > 0
		var holding: = "未持有  仍可作为合法目标"
		if owned:
			holding = "我的持仓 %d股  均价 %.2f\n市值 %d万  浮盈亏 %s%d万" % [int(data.get("shares", 0)), float(data.get("avg_cost", 0.0)), int(data.get("market_value", 0)), "+" if int(data.get("pnl", 0)) >= 0 else "", int(data.get("pnl", 0))]
		label = "%s  %s   %.2f  %+.1f%%\n%s" % [str(data.get("label", id)), str(data.get("sector", "")), float(data.get("price", 0.0)), float(data.get("change", 0.0)) * 100.0, holding]
	elif is_business:
		var business: Dictionary = GameState.game_data.businesses.get(id, {})
		if owner_id.is_empty(): owner_id = str(business.get("owner_id", ""))
		var owner: = GameState.player(owner_id)
		var owner_name: = str(data.get("owner_name", owner.get("name", "未知财团")))
		var owner_color: = Color(str(data.get("owner_color", owner.get("color", "#5aa9d6"))))
		var land: Dictionary = GameState.game_data.lands.get(str(business.get("land_id", "")), {})
		var district_name: = str(data.get("district_name", land.get("district_name", "城市商圈")))
		var business_name: = str(data.get("business_name", business.get("name", id)))
		draw_rect(Rect2(12, 12, 9, size.y - 24), owner_color, true)
		draw_circle(c, 24, owner_color)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 12), c + Vector2(-16, -4), c + Vector2(-5, -15), c + Vector2(5, -5), c + Vector2(16, -12), c + Vector2(16, 12)]), Color.WHITE)
		label = "%s\n所属：%s\n%s  %s" % [business_name, owner_name, district_name, _state_name(str(data.get("state", business.get("state", "operating"))))]
	elif GameState.game_data.players.any( func(p: Dictionary) -> bool: return str(p.id) == id):
		var player: Dictionary = GameState.player(id)
		draw_circle(c, 24, Color(str(player.color)))
		label = "%s  排名 #%d\n现金 %d 万" % [player.name, int(player.rank), int(player.cash)]
	elif GameState.game_data.lands.has(id):
		var land: Dictionary = GameState.game_data.lands[id]
		draw_rect(Rect2(c - Vector2(25, 20), Vector2(50, 40)), Color("d5c49f"), true)
		draw_rect(Rect2(c - Vector2(25, 20), Vector2(50, 40)), accent, false, 3)
		var owner: = GameState.player(str(land.get("owner_id", "")))
		label = "%s  %s\n所属：%s" % [id, land.get("district_name", "城市地块"), "城市" if owner.is_empty() else str(owner.name)]
	else:
		draw_circle(c, 25, accent)
		draw_string(ThemeDB.fallback_font, c + Vector2(-16, 7), "◆", HORIZONTAL_ALIGNMENT_CENTER, 32, 20, Color("fff4d4"))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(82, 30), label, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 94), 16, 18, UIStyles.TOY_INK)


func _state_name(value: String) -> String:
	return {"constructing": "建设中", "operating": "运营中", "loss_watch": "亏损观察", "mortgaged": "已抵押", "auction": "拍卖中"}.get(value, value)
