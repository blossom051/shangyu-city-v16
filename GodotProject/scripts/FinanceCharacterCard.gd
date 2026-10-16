class_name FinanceCharacterCard
extends PanelContainer

const ATLAS = preload("res://assets/ui/characters/financial_character_triptych_v8.png")


func setup(role: String, title: String, caption: String, compact: = false) -> void :
	name = "FinanceCharacter_%s" % role
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(292, 252) if compact else Vector2(360, 420)
	var accent: Color = {"bank": Color("d6ad54"), "startup": Color("62c89b"), "market": Color("47a9d0")}.get(role, Color("d6ad54"))
	var frame: = StyleBoxFlat.new()
	frame.bg_color = Color(0.02, 0.075, 0.1, 0.97)
	frame.border_color = Color(accent, 0.82)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(14)
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_top = 10
	frame.content_margin_bottom = 12
	frame.shadow_color = Color(0, 0, 0, 0.34)
	frame.shadow_size = 12
	add_theme_stylebox_override("panel", frame)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	add_child(stack)
	var portrait: = TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = _portrait(role)
	portrait.custom_minimum_size = Vector2(0, 172) if compact else Vector2(0, 296)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stack.add_child(portrait)
	var copy: = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	stack.add_child(copy)
	var role_label: = Label.new()
	role_label.text = title
	role_label.name = "CharacterTitle"
	role_label.add_theme_font_size_override("font_size", 17 if compact else 23)
	role_label.add_theme_color_override("font_color", Color("edf4f5"))
	role_label.clip_text = true
	role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(role_label)
	var caption_label: = Label.new()
	caption_label.name = "CharacterTags"
	caption_label.text = caption
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.max_lines_visible = 3
	caption_label.add_theme_font_size_override("font_size", 13 if compact else 15)
	caption_label.add_theme_color_override("font_color", Color("9fb6bf"))
	copy.add_child(caption_label)


func debug_presentation_profile() -> Dictionary:
	var portrait: = find_child("Portrait", true, false) as TextureRect
	var title: = find_child("CharacterTitle", true, false) as Label
	var detail: = find_child("CharacterTags", true, false) as Label
	return {
		"portrait_height_ratio": 0.0 if portrait == null or custom_minimum_size.y <= 0.0 else portrait.custom_minimum_size.y / custom_minimum_size.y, 
		"keeps_aspect": portrait != null and portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 
		"single_line_title": title != null and title.autowrap_mode == TextServer.AUTOWRAP_OFF, 
		"detail_line_limit": detail.max_lines_visible if detail != null else 99, 
	}


func _portrait(role: String) -> Texture2D:
	var index: int = int({"bank": 0, "startup": 1, "market": 2}.get(role, 0))
	var cell_width: = float(ATLAS.get_width()) / 3.0
	var atlas: = AtlasTexture.new()
	atlas.atlas = ATLAS
	atlas.region = Rect2(cell_width * index, 0, cell_width, ATLAS.get_height())
	return atlas
