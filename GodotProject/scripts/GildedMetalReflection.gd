class_name GildedMetalReflection
extends Control

const GOLD_DEEP: = Color("8d5f16")
const GOLD_WARM: = Color("ffd35e")
const GOLD_PALE: = Color("fff0a8")
const MIRROR_WHITE: = Color("fffdf2")
const REFRACTION_CYAN: = Color("8ff5ff")
const REFRACTION_LILAC: = Color("d8b4ff")
const REFRACTION_ROSE: = Color("ffb8dc")

var phase: = 0.0
var phase_offset: = 0.0
var hovered: = false
var selected: = false


func setup(card_id: String) -> void :
	name = "GildedMetalReflection"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = false
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_offset = float(abs(card_id.hash()) % 1000) / 1000.0 * TAU
	var additive: = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	queue_redraw()


func set_state(is_hovered: bool, is_selected: bool) -> void :
	hovered = is_hovered
	selected = is_selected
	queue_redraw()


func _process(delta: float) -> void :
	if GameSettings.reduce_motion:
		return
	phase += delta
	queue_redraw()


func _draw() -> void :
	if size.x <= 24.0 or size.y <= 24.0:
		return
	var frame: = Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0)
	var t: = phase + phase_offset
	var emphasis: = 1.12 if selected else 1.07 if hovered else 1.0
	_draw_ambient_halo(frame, t, emphasis)
	_draw_metal_frame(frame, emphasis)
	_draw_prismatic_edge_inlays(frame, t, emphasis)
	_draw_corner_facets(frame, emphasis)
	_draw_constellation_sparkles(frame, t, emphasis)
	if GameSettings.reduce_motion:
		_draw_diagonal_sheen(frame, 0.46, 0.58)
		return
	var cycle: = fposmod(t / (2.85 if selected else 3.35), 1.0)
	if cycle <= 0.64:
		_draw_diagonal_sheen(frame, smoothstep(0.0, 1.0, cycle / 0.64), 0.94 if selected else 0.78)


func _draw_ambient_halo(frame: Rect2, time: float, strength: float) -> void :

	var pulse: = 1.0 if GameSettings.reduce_motion else 0.82 + 0.18 * sin(time * 2.05)
	_draw_rounded_outline(frame.grow(5.5), Color(GOLD_WARM, 0.11 * pulse * strength), 7, 23)
	_draw_rounded_outline(frame.grow(3.5), Color(MIRROR_WHITE, 0.15 * pulse * strength), 4, 21)
	_draw_rounded_outline(frame.grow(1.8), Color(REFRACTION_CYAN, 0.12 * pulse * strength), 2, 20)
	_draw_rounded_outline(frame.grow(0.4), Color(REFRACTION_LILAC, 0.1 * pulse * strength), 2, 19)


func _draw_diagonal_sheen(frame: Rect2, progress: float, strength: float) -> void :

	var surface: = frame.grow(-3.0)
	var radius: = minf(16.0, minf(surface.size.x, surface.size.y) * 0.1)
	var travel_start: = surface.position.x - 62.0
	var travel_end: = surface.end.x + 62.0
	var center_at_middle: = lerpf(travel_start, travel_end, clampf(progress, 0.0, 1.0))
	var center_y: = surface.get_center().y
	var y: = surface.position.y
	while y <= surface.end.y:
		var bounds: = _rounded_x_bounds(surface, radius, y)
		var center_x: = center_at_middle + (y - center_y) * 0.34
		var readability: = _sheen_readability(surface, y)
		_draw_clipped_scanline(bounds, y, center_x, 31.0, Color(GOLD_PALE, 0.04 * readability * strength), 2.25)
		_draw_clipped_scanline(bounds, y, center_x, 8.0, Color(MIRROR_WHITE, 0.082 * readability * strength), 2.25)
		_draw_clipped_scanline(bounds, y, center_x - 13.0, 1.8, Color(REFRACTION_CYAN, 0.052 * readability * strength), 2.0)
		_draw_clipped_scanline(bounds, y, center_x + 13.0, 1.8, Color(REFRACTION_ROSE, 0.046 * readability * strength), 2.0)
		y += 2.0


func _draw_clipped_scanline(bounds: Vector2, y: float, center_x: float, half_width: float, color: Color, width: float) -> void :
	var x_start: = maxf(bounds.x, center_x - half_width)
	var x_end: = minf(bounds.y, center_x + half_width)
	if x_end > x_start:
		draw_line(Vector2(x_start, y), Vector2(x_end, y), color, width, true)


func _rounded_x_bounds(rect: Rect2, radius: float, y: float) -> Vector2:
	var local_y: = clampf(y - rect.position.y, 0.0, rect.size.y)
	var inset: = 0.0
	if local_y < radius:
		var dy_top: = radius - local_y
		inset = radius - sqrt(maxf(0.0, radius * radius - dy_top * dy_top))
	elif local_y > rect.size.y - radius:
		var dy_bottom: = local_y - (rect.size.y - radius)
		inset = radius - sqrt(maxf(0.0, radius * radius - dy_bottom * dy_bottom))
	return Vector2(rect.position.x + inset, rect.end.x - inset)


func _sheen_readability(surface: Rect2, y: float) -> float:
	var ratio: = clampf((y - surface.position.y) / maxf(1.0, surface.size.y), 0.0, 1.0)
	if ratio < 0.14:
		return 0.28
	if ratio < 0.52:
		return 1.0
	if ratio < 0.62:
		return 0.23
	if ratio < 0.9:
		return 0.12
	return 0.18


func _draw_metal_frame(frame: Rect2, strength: float) -> void :
	_draw_rounded_outline(frame, Color(GOLD_DEEP, 0.9 * strength), 5, 18)
	_draw_rounded_outline(frame.grow(-2.0), Color(GOLD_WARM, 0.95 * strength), 2, 17)
	_draw_rounded_outline(frame.grow(-4.0), Color(MIRROR_WHITE, 0.7 * strength), 1, 16)


func _draw_prismatic_edge_inlays(frame: Rect2, time: float, strength: float) -> void :
	var pulse: = 1.0 if GameSettings.reduce_motion else 0.78 + 0.22 * sin(time * 2.6)
	var inset: = frame.grow(-1.0)
	var segments: = [Vector2(0.1, 0.3), Vector2(0.38, 0.58), Vector2(0.66, 0.9)]
	var tones: = [REFRACTION_CYAN, REFRACTION_LILAC, REFRACTION_ROSE]
	for index in segments.size():
		var segment: Vector2 = segments[index]
		var tone: Color = tones[index]
		draw_line(Vector2(lerpf(inset.position.x, inset.end.x, segment.x), inset.position.y), Vector2(lerpf(inset.position.x, inset.end.x, segment.y), inset.position.y), Color(tone, 0.68 * pulse * strength), 2.2, true)
		draw_line(Vector2(lerpf(inset.position.x, inset.end.x, 1.0 - segment.y), inset.end.y), Vector2(lerpf(inset.position.x, inset.end.x, 1.0 - segment.x), inset.end.y), Color(tone, 0.58 * pulse * strength), 2.0, true)


func _draw_corner_facets(frame: Rect2, strength: float) -> void :
	var corners: = [frame.position + Vector2(9, 4), Vector2(frame.end.x - 9, frame.position.y + 4), frame.end - Vector2(9, 4), Vector2(frame.position.x + 9, frame.end.y - 4)]
	for index in corners.size():
		var center: Vector2 = corners[index]
		var cool: = REFRACTION_CYAN if index % 2 == 0 else REFRACTION_LILAC
		var diamond: = PackedVector2Array([center + Vector2(0, -4.5), center + Vector2(3.4, 0), center + Vector2(0, 4.5), center + Vector2(-3.4, 0)])
		draw_colored_polygon(diamond, Color(cool, 0.54 * strength))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(MIRROR_WHITE, 0.82 * strength), 1.0, true)


func _draw_constellation_sparkles(frame: Rect2, time: float, strength: float) -> void :

	var points: = [Vector2(0.08, 0.02), Vector2(0.3, 0.01), Vector2(0.72, 0.01), Vector2(0.94, 0.03), Vector2(0.985, 0.23), Vector2(0.99, 0.71), Vector2(0.91, 0.98), Vector2(0.61, 0.99), Vector2(0.25, 0.99), Vector2(0.02, 0.83), Vector2(0.01, 0.48)]
	for index in points.size():
		var point: Vector2 = points[index]
		var pulse: = 0.42 if GameSettings.reduce_motion else pow(maxf(0.0, sin(time * (2.2 + float(index % 3) * 0.36) + float(index) * 1.73)), 9.0)
		if pulse < 0.03:
			continue
		_draw_star_glint(frame.position + frame.size * point, pulse * strength, 12.0 if index % 3 == 0 else 8.5)


func _draw_star_glint(center: Vector2, strength: float, radius: float) -> void :
	if strength <= 0.01:
		return
	draw_circle(center, radius * 0.52, Color(GOLD_PALE, 0.075 * strength))
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(MIRROR_WHITE, 0.98 * strength), 1.65, true)
	draw_line(center - Vector2(0, radius * 0.8), center + Vector2(0, radius * 0.8), Color(GOLD_PALE, 0.98 * strength), 2.0, true)
	draw_line(center - Vector2(radius * 0.42, radius * 0.42), center + Vector2(radius * 0.42, radius * 0.42), Color(REFRACTION_CYAN, 0.78 * strength), 1.1, true)
	draw_line(center - Vector2(radius * 0.38, - radius * 0.38), center + Vector2(radius * 0.38, - radius * 0.38), Color(REFRACTION_LILAC, 0.74 * strength), 1.1, true)
	draw_circle(center, 1.8, Color(MIRROR_WHITE, 0.96 * strength))


func _draw_rounded_outline(rect: Rect2, color: Color, width: int, radius: int) -> void :
	var box: = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)
