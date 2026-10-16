class_name CardEffectBurst
extends Control

var animation_key: = "card_settlement"
var accent: = Color("d6ad54")
var progress: = 0.0


func setup(next_key: String, next_accent: Color) -> void :
	animation_key = next_key
	accent = next_accent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void :
	progress = fmod(progress + delta * 0.72, 1.0)
	queue_redraw()


func _draw() -> void :
	var center: = size * 0.5
	var fade: = sin(progress * PI)
	for radius in [82.0, 132.0, 188.0]:
		draw_arc(center, radius + progress * 18.0, 0.0, TAU, 72, Color(accent, (1.0 - progress) * 0.14), 2.0, true)
	match animation_key:
		"stock_ticker_pulse":
			_draw_stock(center, fade)
		"bank_stamp_transfer":
			_draw_bank(center, fade)
		"auction_hammer_bid":
			_draw_auction(center, fade)
		"parcel_title_deed":
			_draw_parcel(center, fade)
		"talent_spotlight":
			_draw_talent(center, fade)
		"innovation_timeline":
			_draw_innovation(center, fade)
		"construction_crane_progress":
			_draw_construction(center, fade)
		"district_route_pulse":
			_draw_district(center, fade)
		"newspaper_headline":
			_draw_news(center, fade)
		"shield_counter":
			_draw_shield(center, fade)
		_:
			_draw_cashflow(center, fade)


func _draw_stock(c: Vector2, fade: float) -> void :
	var points: = PackedVector2Array([c + Vector2(-190, 80), c + Vector2(-105, 20), c + Vector2(-30, 42), c + Vector2(55, -48), c + Vector2(170, -100)])
	draw_polyline(points, Color(accent, 0.55 + fade * 0.35), 8.0, true)
	for point: Vector2 in points:
		draw_circle(point, 9.0 + fade * 4.0, Color(accent, 0.78))


func _draw_bank(c: Vector2, fade: float) -> void :
	draw_rect(Rect2(c - Vector2(180, 95), Vector2(360, 190)), Color(accent, 0.08), true)
	draw_polyline(PackedVector2Array([c + Vector2(-170, -65), c + Vector2(0, -130), c + Vector2(170, -65)]), Color(accent, 0.72), 8.0, true)
	for x in [-120.0, -40.0, 40.0, 120.0]:
		draw_line(c + Vector2(x, -55), c + Vector2(x, 70), Color(accent, 0.62), 12.0)
	draw_circle(c, 48.0 + fade * 8.0, Color(accent, 0.18), true)


func _draw_auction(c: Vector2, fade: float) -> void :
	var angle: = lerpf(-0.85, 0.15, progress)
	var handle_end: = c + Vector2(cos(angle), sin(angle)) * 150.0
	draw_line(c, handle_end, Color(accent, 0.82), 18.0, true)
	draw_line(handle_end + Vector2(-34, -24), handle_end + Vector2(34, 24), Color(accent, 0.9), 34.0, true)
	draw_line(c + Vector2(-155, 105), c + Vector2(155, 105), Color(accent, 0.58 + fade * 0.25), 14.0)


func _draw_parcel(c: Vector2, fade: float) -> void :
	var polygon: = PackedVector2Array([c + Vector2(-160, -95), c + Vector2(115, -120), c + Vector2(180, -15), c + Vector2(100, 120), c + Vector2(-130, 100), c + Vector2(-185, 0)])
	draw_colored_polygon(polygon, Color(accent, 0.1 + fade * 0.08))
	draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[3], polygon[4], polygon[5], polygon[0]]), Color(accent, 0.82), 8.0, true)
	draw_line(c + Vector2(-40, 15), c + Vector2(90, 70), Color(accent, 0.58), 5.0)


func _draw_talent(c: Vector2, fade: float) -> void :
	draw_circle(c + Vector2(0, -72), 54.0, Color(accent, 0.22 + fade * 0.16), true)
	draw_arc(c + Vector2(0, 90), 120.0, PI, TAU, 48, Color(accent, 0.82), 16.0, true)
	draw_arc(c, 190.0 + progress * 18.0, 0.0, TAU, 72, Color(accent, (1.0 - progress) * 0.46), 6.0, true)


func _draw_innovation(c: Vector2, fade: float) -> void :
	for index in range(8):
		var angle: = TAU * float(index) / 8.0 + progress * 0.5
		var point: = c + Vector2(cos(angle), sin(angle)) * 165.0
		draw_line(c, point, Color(accent, 0.22 + fade * 0.16), 3.0)
		draw_circle(point, 12.0 + fade * 5.0, Color(accent, 0.76))
	draw_circle(c, 34.0, Color(accent, 0.88))


func _draw_construction(c: Vector2, fade: float) -> void :
	draw_line(c + Vector2(-135, 120), c + Vector2(-135, -125), Color(accent, 0.84), 14.0)
	draw_line(c + Vector2(-135, -115), c + Vector2(135, -115), Color(accent, 0.84), 12.0)
	draw_line(c + Vector2(85, -115), c + Vector2(85, 20 + progress * 50.0), Color(accent, 0.6), 5.0)
	draw_rect(Rect2(c + Vector2(-70, 10), Vector2(170, 110)), Color(accent, 0.1 + fade * 0.08), true)
	draw_rect(Rect2(c + Vector2(-70, 10), Vector2(170, 110)), Color(accent, 0.68), false, 7.0)


func _draw_district(c: Vector2, fade: float) -> void :
	var nodes: = [Vector2(-155, -70), Vector2(-20, -125), Vector2(135, -55), Vector2(150, 90), Vector2(-5, 125), Vector2(-145, 65)]
	var path: = PackedVector2Array()
	for value: Vector2 in nodes:
		path.append(c + value)
	path.append(c + nodes[0])
	draw_polyline(path, Color(accent, 0.68), 7.0, true)
	for point: Vector2 in path:
		draw_circle(point, 10.0 + fade * 5.0, Color(accent, 0.82))


func _draw_news(c: Vector2, fade: float) -> void :
	var rect: = Rect2(c - Vector2(165, 120), Vector2(330, 240))
	draw_rect(rect, Color(0.96, 0.91, 0.79, 0.2 + fade * 0.1), true)
	draw_rect(rect, Color(accent, 0.74), false, 6.0)
	draw_line(c + Vector2(-130, -70), c + Vector2(130, -70), Color(accent, 0.82), 12.0)
	for y in [-25.0, 15.0, 55.0]:
		draw_line(c + Vector2(-130, y), c + Vector2(130, y), Color(accent, 0.42), 5.0)


func _draw_shield(c: Vector2, fade: float) -> void :
	var shield: = PackedVector2Array([c + Vector2(0, -150), c + Vector2(135, -95), c + Vector2(105, 60), c + Vector2(0, 150), c + Vector2(-105, 60), c + Vector2(-135, -95), c + Vector2(0, -150)])
	draw_colored_polygon(shield, Color(accent, 0.1 + fade * 0.12))
	draw_polyline(shield, Color(accent, 0.88), 9.0, true)
	draw_arc(c, 190.0 + progress * 18.0, 0.0, TAU, 72, Color(accent, (1.0 - progress) * 0.55), 8.0, true)


func _draw_cashflow(c: Vector2, fade: float) -> void :
	for y in [-90.0, 0.0, 90.0]:
		var shift: = progress * 80.0
		draw_line(c + Vector2(-175 + shift, y), c + Vector2(105 + shift, y), Color(accent, 0.62), 8.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(105 + shift, y - 22), c + Vector2(160 + shift, y), c + Vector2(105 + shift, y + 22)]), Color(accent, 0.8))
