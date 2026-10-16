class_name V7Theme
extends RefCounted

const BG: = Color("143542")
const BG_2: = Color("1b4350")
const NAVY: = Color("1d4658")
const PANEL: = Color(0.09, 0.245, 0.29, 0.94)
const PANEL_2: = Color(0.12, 0.31, 0.36, 0.95)
const BLUE: = Color("43a8c7")
const BLUE_DARK: = Color("2f7892")
const GOLD: = Color("dfb85f")
const GOLD_2: = Color("aa8138")
const WHITE: = Color("f2f5f3")
const MUTED: = Color("b4c9ce")
const GREEN: = Color("58dba1")
const RED: = Color("f47b85")
const PURPLE: = Color("a77dff")

static func screen() -> Color:
	return BG


static func palette_profile() -> Dictionary:
	return {"background": BG, "secondary": BG_2, "panel": PANEL, "blue": BLUE, "gold": GOLD}

static func panel(fill: = PANEL, border: = BLUE, radius: = 12, depth: = 8) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = depth
	style.shadow_offset = Vector2(0, depth * 0.45)
	style.anti_aliasing = true
	return style

static func button(primary: = false, accent: = BLUE) -> StyleBoxFlat:
	var fill: = Color(0.08, 0.24, 0.4, 0.96)
	if primary:
		fill = Color(accent.r, accent.g, accent.b, 0.88).darkened(0.2)
	var style: = panel(fill, accent, 10, 6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	return style

static func card(accent: = BLUE, selected: = false) -> StyleBoxFlat:
	var style: = panel(Color(0.06, 0.18, 0.235, 0.96), accent, 14, 12 if selected else 7)
	style.set_border_width_all(3 if selected else 1)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.34 if selected else 0.16)
	return style

static func badge(accent: = GOLD) -> StyleBoxFlat:
	var style: = panel(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.95), accent, 12, 4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

static func section_title(target: Label, accent: = GOLD) -> void :
	target.add_theme_color_override("font_color", WHITE)
	target.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	target.add_theme_constant_override("outline_size", 4)
	target.add_theme_font_size_override("font_size", 24)
	target.add_theme_stylebox_override("normal", badge(accent))

static func apply_button(ctrl: Button, primary: = false, accent: = BLUE, font_size: = 18) -> void :
	ctrl.add_theme_font_size_override("font_size", font_size)
	ctrl.add_theme_color_override("font_color", WHITE if not primary else Color("fff7d6"))
	ctrl.add_theme_color_override("font_hover_color", Color("ffffff"))
	ctrl.add_theme_color_override("font_pressed_color", Color("fff0ad"))
	ctrl.add_theme_color_override("font_disabled_color", Color("607789"))
	ctrl.add_theme_stylebox_override("normal", button(primary, accent))
	ctrl.add_theme_stylebox_override("hover", button(true, accent.lightened(0.12)))
	ctrl.add_theme_stylebox_override("pressed", button(true, accent.darkened(0.08)))
	ctrl.add_theme_stylebox_override("disabled", panel(Color(0.04, 0.08, 0.12, 0.82), Color("34495e"), 16, 2))

static func apply_labels(root: Node, color: = WHITE) -> void :
	if root is Label:
		var label: = root as Label
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		label.add_theme_constant_override("outline_size", 3)
	for child in root.get_children():
		apply_labels(child, color)

static func apply_option_button(ctrl: OptionButton) -> void :
	apply_button(ctrl, false, BLUE, 18)

static func apply_slider(slider: HSlider) -> void :
	slider.custom_minimum_size = Vector2(260, 34)
	var base: = StyleBoxFlat.new()
	base.bg_color = Color(0.03, 0.1, 0.16, 0.92)
	base.border_color = BLUE_DARK
	base.set_border_width_all(1)
	base.set_corner_radius_all(10)
	var active: = StyleBoxFlat.new()
	active.bg_color = BLUE
	active.border_color = GOLD
	active.set_border_width_all(1)
	active.set_corner_radius_all(10)
	slider.add_theme_stylebox_override("slider", base)
	slider.add_theme_stylebox_override("grabber_area", active)
	slider.add_theme_stylebox_override("grabber_area_highlight", active)

static func label(text: String, size: int, color: = WHITE) -> Label:
	var result: = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color.BLACK)
	result.add_theme_constant_override("outline_size", 3)
	return result

static func money(value: int) -> String:
	var prefix: = "-" if value < 0 else ""
	var n: = absi(value)
	return "%s%.1f万" % [prefix, float(n) / 10000.0] if n >= 10000 else "%s%d万" % [prefix, n]
