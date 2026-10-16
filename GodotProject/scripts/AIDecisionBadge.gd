class_name AIDecisionBadge
extends Control


const PROFILES: = {
	"decision": {"symbol": "compass", "accent": Color("d6ad54")}, 
	"round_card": {"symbol": "cards", "accent": Color("9d8be8")}, 
	"buy_land": {"symbol": "pin", "accent": Color("61c8d8")}, 
	"build": {"symbol": "building", "accent": Color("f0b85b")}, 
	"talent": {"symbol": "person", "accent": Color("e887b8")}, 
	"discard": {"symbol": "checklist", "accent": Color("94b8c4")}, 
	"card": {"symbol": "spark_card", "accent": Color("b19aef")}, 
	"stock": {"symbol": "chart", "accent": Color("5fd6a0")}, 
	"loan": {"symbol": "bank", "accent": Color("e2bd68")}, 
	"startup": {"symbol": "rocket", "accent": Color("ef8d67")}, 
	"recovery": {"symbol": "cycle", "accent": Color("72c5a8")}, 
}

var action: = "decision"
var symbol: = "compass"
var accent: = Color("d6ad54")


func _ready() -> void :
	name = "ActionBadge"
	custom_minimum_size = Vector2(68, 68)
	size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_action(next_action: String) -> void :
	action = next_action if PROFILES.has(next_action) else "decision"
	var profile: Dictionary = PROFILES[action]
	symbol = str(profile.symbol)
	accent = Color(profile.accent)
	queue_redraw()


func presentation_profile() -> Dictionary:
	return {
		"action": action, 
		"symbol": symbol, 
		"accent": accent, 
		"uses_text": false, 
	}


func _draw() -> void :
	var center: = size * 0.5
	var radius: = minf(size.x, size.y) * 0.42
	draw_circle(center + Vector2(0, 3), radius + 3.0, Color(0, 0, 0, 0.34))
	draw_circle(center, radius + 3.0, Color("d6ad54"))
	draw_circle(center, radius + 1.2, accent)
	draw_circle(center, radius - 1.8, Color("092733"))
	draw_arc(center, radius - 5.0, -2.35, 0.78, 32, Color(accent, 0.52), 2.0, true)
	match symbol:
		"cards": _draw_cards(center)
		"pin": _draw_pin(center)
		"building": _draw_building(center)
		"person": _draw_person(center)
		"checklist": _draw_checklist(center)
		"spark_card": _draw_spark_card(center)
		"chart": _draw_chart(center)
		"bank": _draw_bank(center)
		"rocket": _draw_rocket(center)
		"cycle": _draw_cycle(center)
		_: _draw_compass(center)


func _draw_cards(c: Vector2) -> void :
	draw_rect(Rect2(c + Vector2(-15, -10), Vector2(23, 27)), Color.TRANSPARENT, false, 3.0)
	draw_rect(Rect2(c + Vector2(-8, -17), Vector2(23, 27)), accent, false, 3.0)
	draw_line(c + Vector2(-3, -9), c + Vector2(9, -9), accent, 2.0, true)
	draw_line(c + Vector2(-3, -3), c + Vector2(6, -3), accent, 2.0, true)


func _draw_pin(c: Vector2) -> void :
	draw_circle(c + Vector2(0, -7), 10.0, accent, false, 3.0, true)
	draw_circle(c + Vector2(0, -7), 3.0, accent)
	draw_polyline(PackedVector2Array([c + Vector2(-8, -1), c + Vector2(0, 16), c + Vector2(8, -1)]), accent, 3.0, true)


func _draw_building(c: Vector2) -> void :
	draw_rect(Rect2(c + Vector2(-15, -15), Vector2(30, 31)), accent, false, 3.0)
	for x in [-8.0, 0.0, 8.0]:
		for y in [-8.0, 0.0]:
			draw_rect(Rect2(c + Vector2(x - 2, y - 2), Vector2(4, 4)), accent)
	draw_line(c + Vector2(0, 9), c + Vector2(0, 16), accent, 3.0, true)


func _draw_person(c: Vector2) -> void :
	draw_circle(c + Vector2(0, -10), 7.0, accent, false, 3.0, true)
	draw_arc(c + Vector2(0, 12), 16.0, PI, TAU, 24, accent, 3.0, true)
	draw_line(c + Vector2(-16, 12), c + Vector2(-16, 18), accent, 3.0, true)
	draw_line(c + Vector2(16, 12), c + Vector2(16, 18), accent, 3.0, true)


func _draw_checklist(c: Vector2) -> void :
	for y in [-11.0, 0.0, 11.0]:
		draw_line(c + Vector2(-3, y), c + Vector2(15, y), accent, 3.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(-16, y - 1), c + Vector2(-12, y + 3), c + Vector2(-7, y - 4)]), accent, 2.5, true)


func _draw_spark_card(c: Vector2) -> void :
	draw_rect(Rect2(c + Vector2(-13, -16), Vector2(26, 32)), accent, false, 3.0)
	draw_line(c + Vector2(18, -15), c + Vector2(18, -5), accent, 2.0, true)
	draw_line(c + Vector2(13, -10), c + Vector2(23, -10), accent, 2.0, true)
	draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), accent, 2.0, true)


func _draw_chart(c: Vector2) -> void :
	draw_line(c + Vector2(-17, 16), c + Vector2(-17, -15), Color(accent, 0.55), 2.0, true)
	draw_line(c + Vector2(-17, 16), c + Vector2(18, 16), Color(accent, 0.55), 2.0, true)
	var points: = PackedVector2Array([
		c + Vector2(-14, 8), c + Vector2(-5, 1), c + Vector2(2, 5), 
		c + Vector2(10, -8), c + Vector2(18, -13), 
	])
	draw_polyline(points, accent, 3.5, true)
	draw_circle(points[points.size() - 1], 3.0, accent)


func _draw_bank(c: Vector2) -> void :
	draw_polyline(PackedVector2Array([c + Vector2(-19, -8), c + Vector2(0, -18), c + Vector2(19, -8)]), accent, 3.0, true)
	draw_line(c + Vector2(-19, 16), c + Vector2(19, 16), accent, 3.0, true)
	for x in [-12.0, -4.0, 4.0, 12.0]:
		draw_line(c + Vector2(x, -6), c + Vector2(x, 12), accent, 3.0, true)


func _draw_rocket(c: Vector2) -> void :
	draw_polyline(PackedVector2Array([
		c + Vector2(-7, 9), c + Vector2(-9, -3), c + Vector2(0, -17), 
		c + Vector2(9, -3), c + Vector2(7, 9), c + Vector2(-7, 9), 
	]), accent, 3.0, true)
	draw_circle(c + Vector2(0, -5), 3.0, accent, false, 2.0, true)
	draw_line(c + Vector2(-4, 12), c + Vector2(-8, 19), accent, 2.5, true)
	draw_line(c + Vector2(4, 12), c + Vector2(8, 19), accent, 2.5, true)


func _draw_cycle(c: Vector2) -> void :
	draw_arc(c, 15.0, -2.7, 0.25, 28, accent, 3.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(14, -9), c + Vector2(17, 0), c + Vector2(8, -1)]), accent, 3.0, true)
	draw_arc(c, 15.0, 0.45, 3.35, 28, accent, 3.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(-14, 9), c + Vector2(-17, 0), c + Vector2(-8, 1)]), accent, 3.0, true)


func _draw_compass(c: Vector2) -> void :
	draw_circle(c, 16.0, accent, false, 2.5, true)
	draw_polyline(PackedVector2Array([
		c + Vector2(-5, 7), c + Vector2(4, -11), c + Vector2(8, -7), c + Vector2(-5, 7), 
	]), accent, 3.0, true)
