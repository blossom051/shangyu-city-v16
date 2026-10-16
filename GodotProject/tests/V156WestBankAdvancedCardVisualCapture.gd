extends Node

const CardScene = preload("res://scenes/CardView.tscn")


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().size = Vector2i(1920, 1080)
	var background := ColorRect.new()
	background.color = Color("020b15")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 90
	layout.offset_right = -90
	layout.offset_top = 52
	layout.offset_bottom = -52
	layout.add_theme_constant_override("separation", 26)
	background.add_child(layout)
	var title := Label.new()
	title.text = "西岸高级卡 · AI 独立卡面 × Unreal Engine 5.8 动态光效"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("ffe6a8"))
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "NO.001–003  每张卡独立构图、独立光效；卡牌库内其余 39 张普通卡同样一牌一图"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("9edfea"))
	layout.add_child(subtitle)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 54)
	layout.add_child(row)
	for card_id in ["wb40", "wb41", "wb42"]:
		var card := CardScene.instantiate() as CardView
		card.setup(GameConfig.by_id("cards", card_id))
		card.custom_minimum_size = Vector2(360, 520)
		card.size = card.custom_minimum_size
		row.add_child(card)
	for _frame in range(90):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../Screenshots/V15.5-西岸三张高级卡-AI卡面与UE58光效.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result := image.save_png(output)
	print("V156_WEST_ADVANCED_VISUAL result=%d path=%s" % [result, output])
	get_tree().quit(0 if result == OK else 1)
