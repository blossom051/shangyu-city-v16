extends Node

const InstitutionDialog = preload("res://scripts/WestBankInstitutionDialog.gd")
const OfferCardScript = preload("res://scripts/BusinessOfferCard.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	get_window().size = Vector2i(2048, 1152)
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15901)
	GameState.game_data.endless = true
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 100000
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	await _check_institution_cards(player)
	await _check_district_business_art()
	print("V159_CARD_LAYOUT_DISTRICT_ART passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check_institution_cards(player: Dictionary) -> void:
	var dialog := InstitutionDialog.new()
	dialog.open("TerraceHQ", str(player.id))
	add_child(dialog)
	for _frame in range(5):
		await get_tree().process_frame
	var cards: Array[Control] = []
	for child in dialog.options_host.get_children():
		if child is Control:
			cards.append(child as Control)
	_assert("机构方案区生成三张可见方案卡", cards.size() == 3)
	var all_inside := cards.size() == 3
	for card in cards:
		var card_rect := card.get_global_rect()
		for label_node in card.find_children("*", "Label", true, false):
			var label := label_node as Label
			if not label.visible or label.text.strip_edges().is_empty():
				continue
			var label_rect := label.get_global_rect()
			all_inside = all_inside and card_rect.grow(1.0).encloses(label_rect)
			var font := label.get_theme_font("font")
			var font_size := label.get_theme_font_size("font_size")
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var required_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
				all_inside = all_inside and (required_width <= label.size.x + 2.0 or label.clip_text)
			else:
				var required_size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, font_size)
				all_inside = all_inside and required_size.y <= label.size.y + 2.0
	_assert("机构卡标题、费用与说明的实际绘制范围全部留在卡内", all_inside)
	_save_current_frame("../Screenshots/V15.5-机构方案卡排版.png")
	dialog.queue_free()
	await get_tree().process_frame


func _check_district_business_art() -> void:
	var panel: Control = load("res://scenes/BusinessBuildPanel.tscn").instantiate() as Control
	panel.land_id = "L13"
	add_child(panel)
	for _frame in range(8):
		await get_tree().process_frame
	var cards: Array[Node] = panel.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_script() == OfferCardScript
	)
	_assert("原城区建设列表生成多个企业卡", cards.size() >= 4)
	var single_scene_art := cards.size() >= 4
	var regions := {}
	for card_node in cards:
		var texture := card_node.call("_business_art") as Texture2D
		single_scene_art = single_scene_art and texture is AtlasTexture
		if texture is AtlasTexture:
			var region := (texture as AtlasTexture).region
			regions[str(region)] = true
			single_scene_art = single_scene_art and region.size.x > region.size.y
	_assert("原城区企业卡均使用横向单幅裁切图而非完整拼图", single_scene_art)
	_assert("同一建设列表中的企业画面彼此区分", regions.size() == cards.size())
	_save_current_frame("../Screenshots/V15.5-城区企业卡单幅图片.png")
	panel.queue_free()
	await get_tree().process_frame


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		push_error("FAIL  %s" % label)


func _save_current_frame(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image != null:
		image.save_png(path)
