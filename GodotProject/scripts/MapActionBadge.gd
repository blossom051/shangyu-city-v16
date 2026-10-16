class_name MapActionBadge
extends Control

const Assets = preload("res://scripts/CityActionAssetRegistry.gd")

var kind: = "Cards"
var accent: = Color("5bbad0")


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: = TextureRect.new()
	icon.name = "Artwork"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.texture = Assets.icon(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	queue_redraw()


func setup(next_kind: String, next_accent: Color) -> void :
	kind = next_kind
	accent = next_accent
	var icon: = get_node_or_null("Artwork") as TextureRect
	if icon != null:
		icon.texture = Assets.icon(kind)
	queue_redraw()


func _draw() -> void :
	draw_circle(size * 0.5, minf(size.x, size.y) * 0.46, Color(accent, 0.13))
