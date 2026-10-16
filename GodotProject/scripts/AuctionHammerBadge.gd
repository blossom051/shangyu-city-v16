class_name AuctionHammerBadge
extends Control


func _ready() -> void :
	custom_minimum_size = Vector2(66, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void :
	var center: = size * 0.5
	draw_circle(center + Vector2(0, 2), 26.0, Color(0, 0, 0, 0.3))
	draw_circle(center, 25.0, Color("d6ad54"))
	draw_circle(center, 22.0, Color("102d38"))
	var gold: = Color("efca72")
	draw_set_transform(center + Vector2(-2, -2), -0.58)
	draw_rect(Rect2(Vector2(-12, -12), Vector2(25, 12)), gold, true)
	draw_rect(Rect2(Vector2(-16, -10), Vector2(5, 8)), gold, true)
	draw_rect(Rect2(Vector2(12, -10), Vector2(5, 8)), gold, true)
	draw_rect(Rect2(Vector2(-2, -1), Vector2(5, 27)), gold, true)
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_line(center + Vector2(-13, 17), center + Vector2(15, 17), gold, 3.0, true)


func presentation_profile() -> Dictionary:
	return {"symbol": "auction_hammer", "uses_text": false}
