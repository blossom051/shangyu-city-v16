extends Node

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15801)
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 100000
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	var panel: Control = load("res://scenes/BusinessBuildPanel.tscn").instantiate() as Control
	panel.land_id = "L29"
	add_child(panel)
	for _frame in range(10):
		await get_tree().process_frame
	var cards: Array[Node] = panel.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_script() == load("res://scripts/BusinessOfferCard.gd")
	)
	_assert("西岸六种企业均生成独立图像卡", cards.size() == 6)
	var frame: Image = null
	if DisplayServer.get_name() != "headless":
		frame = get_viewport().get_texture().get_image()
		if frame != null:
			frame.save_png("../Screenshots/V15.4-西岸企业卡图片修复.png")
	var all_rich := cards.size() == 6
	for card_value: Node in cards:
		var card := card_value as Control
		var texture := card.call("_business_art") as Texture2D
		print("WEST_BANK_CARD_TEXTURE name=%s class=%s size=%s" % [str(card.business.get("id", "")), texture.get_class() if texture else "null", texture.get_size() if texture else Vector2.ZERO])
		var variance := 0.0
		if frame != null:
			var art_rect := Rect2i(Vector2i(card.global_position + Vector2(17, 17)), Vector2i(card.size.x - 34, 150))
			variance = _luma_variance(frame, art_rect, 7)
			print("WEST_BANK_CARD_ART name=%s variance=%.6f rect=%s" % [str(card.business.get("id", "")), variance, art_rect])
		elif texture != null:
			var texture_image := texture.get_image()
			if texture_image != null:
				variance = _luma_variance(texture_image, Rect2i(Vector2i.ZERO, texture_image.get_size()), 11)
			print("WEST_BANK_CARD_SOURCE name=%s variance=%.6f" % [str(card.business.get("id", "")), variance])
		all_rich = all_rich and variance >= 0.008
	_assert("六张西岸企业卡的画面均有可辨识建筑细节而非纯色白屏", all_rich)
	print("V158_WEST_BANK_BUSINESS_ART passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _luma_variance(image: Image, rect: Rect2i, step: int) -> float:
	var values: Array[float] = []
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(clipped.position.y, clipped.end.y, step):
		for x in range(clipped.position.x, clipped.end.x, step):
			var color := image.get_pixel(x, y)
			values.append(color.get_luminance())
	if values.is_empty():
		return 0.0
	var mean := 0.0
	for value in values:
		mean += value
	mean /= values.size()
	var variance := 0.0
	for value in values:
		variance += pow(value - mean, 2.0)
	return variance / values.size()


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL %s" % label)
