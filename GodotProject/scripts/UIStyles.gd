class_name UIStyles
extends RefCounted

const V7: = preload("res://scripts/V7Theme.gd")

const TOY_INK: = V7.WHITE
const TOY_MUTED: = V7.MUTED
const TOY_CREAM: = V7.PANEL
const TOY_SKY: = V7.BLUE
const TOY_TABLE: = V7.BG_2
const TOY_BORDER: = V7.BLUE
const TOY_YELLOW: = V7.GOLD
const TOY_PINK: = V7.RED
const TOY_GREEN: = V7.GREEN
const TOY_BLUE: = V7.BLUE
const INK: = V7.WHITE
const MUTED: = V7.MUTED
const PANEL_DARK: = V7.PANEL

static func screen() -> Color:
	return V7.screen()

static func panel(fill: = V7.PANEL, border: = V7.BLUE, radius: = 18, depth: = 10) -> StyleBoxFlat:
	return V7.panel(fill, border, radius, depth)

static func button(primary: = false, accent: = V7.BLUE) -> StyleBoxFlat:
	return V7.button(primary, accent)

static func card(accent: = V7.BLUE, selected: = false) -> StyleBoxFlat:
	return V7.card(accent, selected)

static func badge(accent: = V7.GOLD) -> StyleBoxFlat:
	return V7.badge(accent)

static func section_title(target: Label, accent: = V7.GOLD) -> void :
	V7.section_title(target, accent)

static func apply_button(ctrl: Button, primary: = false, accent: = V7.BLUE, font_size: = 18) -> void :
	V7.apply_button(ctrl, primary, accent, font_size)

static func apply_labels(root: Node, color: = V7.WHITE) -> void :
	V7.apply_labels(root, color)

static func apply_option_button(ctrl: OptionButton) -> void :
	V7.apply_option_button(ctrl)

static func apply_slider(slider: HSlider) -> void :
	V7.apply_slider(slider)

static func label(text: String, size: int, color: = V7.WHITE) -> Label:
	return V7.label(text, size, color)

static func money(value: int) -> String:
	return V7.money(value)

static func toy_screen() -> Color:
	return screen()

static func toy_panel(fill: = V7.PANEL, border: = V7.BLUE, radius: = 18, depth: = 10) -> StyleBoxFlat:

	var safe_fill: Color = V7.PANEL if fill.get_luminance() > 0.58 else fill
	return panel(safe_fill, border, radius, depth)

static func toy_button(primary: = false, accent: = V7.BLUE) -> StyleBoxFlat:
	return button(primary, accent)

static func toy_card(accent: = V7.BLUE, selected: = false) -> StyleBoxFlat:
	return card(accent, selected)

static func toy_badge(accent: = V7.GOLD) -> StyleBoxFlat:
	return badge(accent)

static func toy_section_title(target: Label, accent: = V7.GOLD) -> void :
	section_title(target, accent)

static func apply_toy_button(ctrl: Button, primary: = false, accent: = V7.BLUE, font_size: = 18) -> void :
	apply_button(ctrl, primary, accent, font_size)

static func apply_toy_labels(root: Node, color: = V7.WHITE) -> void :
	apply_labels(root, color)

static func apply_toy_option_button(ctrl: OptionButton) -> void :
	apply_option_button(ctrl)

static func apply_toy_slider(slider: HSlider) -> void :
	apply_slider(slider)
