class_name CapitalArcaneFX
extends Control

const SPECTRUM: = [
	Color("5de9ff"), Color("66a8ff"), Color("9d79ff"), 
	Color("ed73ff"), Color("ff7bb8"), Color("72ffd0"), 
]

var card_rect: = Rect2()
var accent: = Color("e8bd58")
var intensity: = 1.0
var progress: = 0.0
var running: = false


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1900


func play_rect(rect: Rect2, color: Color, strength: = 1.0) -> void :
	card_rect = rect
	accent = color
	intensity = clampf(strength, 0.45, 1.5)
	progress = 0.0
	running = true
	queue_redraw()
	var duration: = 0.24 if GameSettings.reduce_motion else 0.78
	var tween: = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish)


func lifecycle_profile() -> Dictionary:
	return {"running": running, "mouse_filter": mouse_filter, "progress": progress, "border_only": true}


func _set_progress(value: float) -> void :
	progress = value
	queue_redraw()


func _finish() -> void :
	running = false
	queue_free()


func _draw() -> void :
	if not running or card_rect.size.x <= 1.0 or card_rect.size.y <= 1.0:
		return
	var fade: = pow(1.0 - progress, 0.74)
	var pulse: = sin(progress * PI)
	var ring_count: = 2
	for ring_index in range(ring_count):
		var expansion: = (5.0 + float(ring_index) * 5.0 + progress * 14.0) * intensity
		var frame: = card_rect.grow(expansion)
		var color: = _spectral_color(ring_index, progress)
		color.a = (0.24 - float(ring_index) * 0.07) * fade
		_draw_outline(frame, color, maxf(1.0, 2.2 - ring_index * 0.35), 22.0 + expansion * 0.35)

	if GameSettings.reduce_motion:
		return
	var runner_rect: = card_rect.grow(7.0 + pulse * 5.0 * intensity)
	for runner_index in range(3):
		var head: = fposmod(progress * 1.25 + float(runner_index) / 3.0, 1.0)
		var previous: = _perimeter_point(runner_rect, head)
		for segment_index in range(1, 5):
			var t: = fposmod(head - float(segment_index) * 0.008, 1.0)
			var point: = _perimeter_point(runner_rect, t)
			var runner_color: Color = SPECTRUM[(runner_index + segment_index) % SPECTRUM.size()]
			runner_color.a = fade * (0.46 - float(segment_index) * 0.07)
			draw_line(previous, point, runner_color, 1.8 * intensity, true)
			previous = point

	var corners: = [runner_rect.position, Vector2(runner_rect.end.x, runner_rect.position.y), runner_rect.end, Vector2(runner_rect.position.x, runner_rect.end.y)]
	for corner_index in range(corners.size()):
		var sparkle: Vector2 = corners[corner_index]
		var sparkle_size: = (3.0 + float(corner_index % 2) * 1.5) * pulse * intensity
		var sparkle_color: Color = SPECTRUM[(corner_index * 2 + int(progress * 10.0)) % SPECTRUM.size()]
		sparkle_color.a = 0.42 * fade
		draw_line(sparkle - Vector2(sparkle_size, 0), sparkle + Vector2(sparkle_size, 0), sparkle_color, 1.8, true)
		draw_line(sparkle - Vector2(0, sparkle_size), sparkle + Vector2(0, sparkle_size), Color(1, 1, 1, 0.36 * fade), 1.2, true)


func _draw_outline(rect: Rect2, color: Color, width: float, radius: float) -> void :
	var box: = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(maxi(1, int(round(width))))
	box.set_corner_radius_all(maxi(1, int(round(radius))))
	draw_style_box(box, rect)


func _spectral_color(index: int, offset: float) -> Color:
	var spectral: Color = SPECTRUM[(index + int(floor(offset * 12.0))) % SPECTRUM.size()]
	return spectral.lerp(accent, 0.22)


func _perimeter_point(rect: Rect2, unit: float) -> Vector2:
	var perimeter: = 2.0 * (rect.size.x + rect.size.y)
	var distance: = fposmod(unit, 1.0) * perimeter
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
