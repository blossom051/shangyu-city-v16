class_name CardUseGlow
extends Control

var accent: = Color("63d6d0")
var progress: = 0.0
var card_size: = Vector2(220, 316)


func setup(value: Color, visual_card_size: = Vector2(220, 316)) -> void :
	accent = value
	card_size = visual_card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void :
	progress = minf(1.0, progress + delta * 1.65)
	queue_redraw()
	if progress >= 1.0:
		set_process(false)


func _draw() -> void :
	var fade: = pow(1.0 - progress, 0.72)
	var pulse: = sin(progress * PI)
	var base_rect: = Rect2((size - card_size) * 0.5, card_size)
	for frame_index in range(4):
		var expansion: = 5.0 + float(frame_index) * 6.0 + progress * 12.0
		var frame_color: = accent.lightened(float(frame_index) * 0.08)
		frame_color.a = fade * (0.58 - float(frame_index) * 0.095)
		_draw_outline(base_rect.grow(expansion), frame_color, 4 - frame_index, 24 + int(expansion * 0.3))

	if GameSettings.reduce_motion:
		return
	var runner_rect: = base_rect.grow(8.0 + pulse * 5.0)
	for runner_index in range(4):
		var head: = fposmod(progress * 1.35 + float(runner_index) * 0.25, 1.0)
		var previous: = _perimeter_point(runner_rect, head)
		for segment_index in range(1, 8):
			var point: = _perimeter_point(runner_rect, head - float(segment_index) * 0.008)
			var trail: = accent.lightened(0.1 + float(segment_index % 3) * 0.07)
			trail.a = fade * (0.92 - float(segment_index) * 0.1)
			draw_line(previous, point, trail, 2.6, true)
			previous = point


func _draw_outline(rect: Rect2, color: Color, width: int, radius: int) -> void :
	var box: = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(maxi(1, width))
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)


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
