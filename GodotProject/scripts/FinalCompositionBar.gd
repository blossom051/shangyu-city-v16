class_name FinalCompositionBar
extends Control

var segments: Array[Dictionary] = []


func set_segments(value: Array[Dictionary]) -> void :
	segments = value.duplicate(true)
	queue_redraw()


func _ready() -> void :
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void :
	var total: = 0.0
	for segment: Dictionary in segments:
		total += maxf(0.0, float(segment.get("value", 0)))
	draw_rect(Rect2(Vector2.ZERO, size), Color("17323d"), true)
	if total <= 0.0:
		return
	var cursor: = 0.0
	for segment: Dictionary in segments:
		var width: = size.x * maxf(0.0, float(segment.get("value", 0))) / total
		if width <= 0.0:
			continue
		draw_rect(Rect2(Vector2(cursor, 0), Vector2(width, size.y)), Color(segment.get("color", Color.WHITE)), true)
		cursor += width
