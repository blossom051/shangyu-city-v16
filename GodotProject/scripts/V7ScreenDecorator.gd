class_name V7ScreenDecorator
extends RefCounted

const Styles = preload("res://scripts/UIStyles.gd")
const Art = preload("res://scripts/PremiumWorkspaceBackdrop.gd")

static func decorate(screen: Control, variant: String) -> void :
	for child in screen.get_children():
		if child is ColorRect:
			(child as ColorRect).color = Styles.screen()
	var art: = Control.new()
	art.name = "PremiumWorkspaceBackdrop"
	art.set_script(Art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.call("setup", variant)
	screen.add_child(art)
	screen.move_child(art, 0)
	if screen.get_child_count() > 1 and screen.get_child(1) is ColorRect:
		screen.move_child(art, 1)
	Styles.apply_labels(screen)
	_style_tree(screen)

static func _style_tree(node: Node) -> void :
	if node is PanelContainer:
		(node as PanelContainer).add_theme_stylebox_override("panel", Styles.panel())
	elif node is Panel:
		(node as Panel).add_theme_stylebox_override("panel", Styles.panel(Color(0.04, 0.13, 0.18, 0.96), Styles.TOY_BLUE, 12, 6))
	elif node is Button:
		Styles.apply_button(node as Button, false, Styles.TOY_BLUE, 17)
	elif node is OptionButton:
		Styles.apply_option_button(node as OptionButton)
	for child in node.get_children():
		_style_tree(child)
