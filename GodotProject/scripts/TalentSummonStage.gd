class_name TalentSummonStage
extends Control

signal finished

var elapsed: = 0.0
var duration: = 1.35
var accent: = Color("63c8ef")
var card_count: = 1


func play(count: int, color: Color) -> void :
	card_count = clampi(count, 1, 5)
	accent = color
	duration = 0.22 if GameSettings.reduce_motion else 1.35
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void :
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		set_process(false)
		finished.emit()
		queue_free()


func _draw() -> void :
	var t: = clampf(elapsed / duration, 0.0, 1.0)
	var center: = size * Vector2(0.5, 0.53)
	var veil_alpha: = sin(t * PI) * 0.72
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.012, 0.055, veil_alpha))
	var energy: = sin(minf(1.0, t * 1.25) * PI * 0.5)
	for ring in range(5):
		var radius: = 46.0 + float(ring) * 38.0 + sin(elapsed * 4.0 + ring) * 6.0
		var ring_color: = Color(accent, (0.42 - float(ring) * 0.055) * energy)
		draw_arc(center, radius, elapsed * (0.5 + ring * 0.08), TAU + elapsed * (0.5 + ring * 0.08), 96, ring_color, 2.0, true)
	for ray in range(12):
		var angle: = TAU * float(ray) / 12.0 + elapsed * 0.35
		var inner: = center + Vector2.from_angle(angle) * 78.0
		var outer: = center + Vector2.from_angle(angle) * (150.0 + 30.0 * energy)
		draw_line(inner, outer, Color(accent, 0.08 + 0.16 * energy), 2.0)
	var card_size: = Vector2(104, 156) if card_count == 1 else Vector2(68, 106)
	var spacing: = 82.0
	for index in range(card_count):
		var offset: = (float(index) - float(card_count - 1) * 0.5) * spacing
		var rise: = lerpf(90.0, -22.0, smoothstep(0.1, 0.82, t))
		var card_center: = center + Vector2(offset, rise)
		var card_rect: = Rect2(card_center - card_size * 0.5, card_size)
		draw_style_box(_card_back(accent, energy), card_rect)
		draw_circle(card_center, card_size.x * 0.72, Color(accent, 0.06 * energy))
		draw_arc(card_center, card_size.x * 0.28, 0, TAU, 32, Color(accent, 0.75 * energy), 2.0)
		draw_colored_polygon(PackedVector2Array([card_center + Vector2(0, -16), card_center + Vector2(14, 0), card_center + Vector2(0, 16), card_center + Vector2(-14, 0)]), Color(accent, 0.42 * energy))
	if t > 0.72:
		var flash: = sin(inverse_lerp(0.72, 1.0, t) * PI)
		draw_circle(center, 240.0 * flash, Color(accent, 0.16 * flash))


func _card_back(color: Color, energy: float) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.04, 0.12, 0.97)
	style.border_color = Color(color, 0.55 + energy * 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(color, 0.35 * energy)
	style.shadow_size = 10
	return style
