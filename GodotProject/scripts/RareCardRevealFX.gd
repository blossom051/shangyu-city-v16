class_name RareCardRevealFX
extends Control

signal finished

const REFRACTION: = [
	Color("fff8ca"), Color("ffffff"), Color("8ff5ff"), 
	Color("a7b9ff"), Color("e9b6ff"), Color("ffb9d8"), Color("8dffd6"), 
]

var card_rect: = Rect2()
var progress: = 0.0
var strength: = 1.0


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0


func play_rect(target_rect: Rect2, effect_strength: = 1.0, duration: = 1.35) -> void :
	card_rect = target_rect
	strength = clampf(effect_strength, 0.35, 1.35)
	progress = 0.0
	queue_redraw()
	var actual_duration: = 0.24 if GameSettings.reduce_motion else duration
	var tween: = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, actual_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_callback( func() -> void :
		finished.emit()
		queue_free())


func set_review_progress(value: float) -> void :
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_progress(value: float) -> void :
	progress = value
	queue_redraw()


func _draw() -> void :
	if card_rect.size.x < 40.0 or card_rect.size.y < 60.0:
		return
	var centre: = card_rect.get_center()
	var attack: = smoothstep(0.0, 0.16, progress)
	var release: = 1.0 - smoothstep(0.62, 1.0, progress)
	var energy: = attack * release * strength
	_draw_contained_halo(energy)
	_draw_perimeter_sweep(energy)
	_draw_edge_sparkles(energy)


func _draw_contained_halo(energy: float) -> void :


	var pulse: = 0.88 + sin(progress * PI * 4.0) * 0.12
	var frame: = card_rect.grow(5.0)
	var layers: = [
		{"grow": 24.0, "width": 20, "color": Color("ffb2ef"), "alpha": 0.07}, 
		{"grow": 17.0, "width": 15, "color": Color("8ff5ff"), "alpha": 0.11}, 
		{"grow": 11.0, "width": 10, "color": Color("ffe36f"), "alpha": 0.18}, 
		{"grow": 6.0, "width": 6, "color": Color("ffffff"), "alpha": 0.42}, 
	]
	for layer: Dictionary in layers:
		draw_style_box(_frame_box(Color(layer.color, float(layer.alpha) * energy * pulse), int(layer.width)), frame.grow(float(layer.grow)))
	draw_style_box(_frame_box(Color("fff3a3", 0.92 * energy), 3), frame)
	draw_style_box(_frame_box(Color("8ff5ff", 0.62 * energy), 2), frame.grow(4.0))
	draw_style_box(_frame_box(Color("e9b6ff", 0.48 * energy), 2), frame.grow(8.0))


func _draw_perimeter_sweep(energy: float) -> void :
	var frame: = card_rect.grow(9.0)
	var head: = fposmod(progress * 1.65, 1.0)
	for index in range(30):
		var tail: = float(index) / 29.0
		var point: = _edge_sample(frame, head - tail * 0.22)
		var envelope: = pow(1.0 - tail, 2.1) * energy
		var color: Color = REFRACTION[(index / 4) % REFRACTION.size()]
		draw_circle(point, 2.0 + envelope * 3.2, Color(color, envelope * 0.22))
		draw_circle(point, 0.9 + envelope * 1.2, Color("ffffff", envelope * 0.82))


func _draw_edge_sparkles(energy: float) -> void :
	var frame: = card_rect.grow(12.0)
	var ratios: = [0.03, 0.21, 0.46, 0.69, 0.88]
	for index in ratios.size():
		var phase: = fposmod(progress * 2.6 + float(index) * 0.23, 1.0)
		var pulse: = sin(phase * PI) if phase < 1.0 else 0.0
		if pulse < 0.42:
			continue
		var point: = _edge_sample(frame, float(ratios[index]))
		var radius: = (7.0 + float(index % 2) * 3.0) * pulse
		_draw_star(point, radius, REFRACTION[(index + 1) % REFRACTION.size()], energy * pulse)


func _draw_star(point: Vector2, radius: float, color: Color, alpha: float) -> void :
	if alpha <= 0.01:
		return
	draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), Color(color, 0.2 * alpha), 7.0, true)
	draw_line(point - Vector2(0, radius * 1.55), point + Vector2(0, radius * 1.55), Color(color, 0.24 * alpha), 8.0, true)
	draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), Color("ffffff", 0.98 * alpha), 1.8, true)
	draw_line(point - Vector2(0, radius * 1.55), point + Vector2(0, radius * 1.55), Color(color, 1.0 * alpha), 2.2, true)
	draw_line(point - Vector2(radius * 0.48, radius * 0.48), point + Vector2(radius * 0.48, radius * 0.48), Color("ffffff", 0.62 * alpha), 1.0, true)
	draw_line(point + Vector2( - radius * 0.48, radius * 0.48), point + Vector2(radius * 0.48, - radius * 0.48), Color(color, 0.58 * alpha), 1.0, true)
	draw_circle(point, 6.0, Color(color, 0.16 * alpha))
	draw_circle(point, 2.5, Color("ffffff", alpha))


func _edge_sample(rect: Rect2, ratio: float) -> Vector2:
	var perimeter: = rect.size.x * 2.0 + rect.size.y * 2.0
	var distance: = fposmod(ratio, 1.0) * perimeter
	if distance <= rect.size.x:
		return rect.position + Vector2(distance, 0)
	distance -= rect.size.x
	if distance <= rect.size.y:
		return Vector2(rect.end.x, rect.position.y + distance)
	distance -= rect.size.y
	if distance <= rect.size.x:
		return Vector2(rect.end.x - distance, rect.end.y)
	distance -= rect.size.x
	return Vector2(rect.position.x, rect.end.y - distance)


func _frame_box(color: Color, width: int) -> StyleBoxFlat:
	var box: = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(width)
	box.set_corner_radius_all(24)
	return box
