class_name GameUIFactory
extends RefCounted

static func create_game_panel(title: String) -> Control:
	var panel: = PanelContainer.new()
	var box: = VBoxContainer.new()
	panel.add_child(box)
	if not title.is_empty():
		var label: = Label.new();label.text = title;label.add_theme_font_size_override("font_size", 24);box.add_child(label)
	apply_game_window_style(panel)
	return panel

static func create_game_button(text: String, style: String = "primary") -> Button:
	var button: = Button.new();button.text = text;apply_button_style(button, style);return button

static func create_stat_badge(icon_key: String, value_text: String) -> Control:
	var row: = HBoxContainer.new()
	var icon: = TextureRect.new();icon.custom_minimum_size = Vector2(24, 24);icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;icon.texture = VisualAssets.get_icon(icon_key);row.add_child(icon)
	var label: = Label.new();label.text = value_text if icon.texture else "%s %s" % [VisualAssets.get_icon_fallback(icon_key), value_text];row.add_child(label)
	return row

static func create_status_tag(status_key: String, text: String) -> Control:
	return create_stat_badge(status_key, text)

static func create_card_container() -> Control:
	var panel: = PanelContainer.new();apply_game_window_style(panel);return panel

static func apply_game_window_style(control: Control) -> void :
	var skin: = VisualAssets.get_ui_skin("default")
	var fallback: Theme = skin.get("fallback_theme_resource")
	if fallback: control.theme = fallback
	var texture: Texture2D = skin.get("window_bg_resource")
	if texture and (control is Panel or control is PanelContainer):
		var box: = StyleBoxTexture.new();box.texture = texture;control.add_theme_stylebox_override("panel", box)

static func apply_button_style(button: Button, style: String = "primary") -> void :
	var skin: = VisualAssets.get_ui_skin("default")
	var fallback: Theme = skin.get("fallback_theme_resource")
	if fallback: button.theme = fallback
	for state in ["normal", "hover", "pressed", "disabled"]:
		var texture: Texture2D = skin.get("button_%s_resource" % state)
		if texture:
			var box: = StyleBoxTexture.new();box.texture = texture;button.add_theme_stylebox_override(state, box)
	button.modulate = Color.WHITE if style == "primary" else Color(0.84, 0.92, 0.94)
