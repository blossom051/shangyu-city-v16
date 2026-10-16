class_name EventOpeningFX
extends Control


const GOLD: = Color(0.94, 0.76, 0.34, 0.0)
const CYAN: = Color(0.34, 0.86, 0.92, 0.0)

var elapsed: = 0.0
var duration: = 1.2


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var additive: = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process( not GameSettings.reduce_motion)
	visible = not GameSettings.reduce_motion


func _process(delta: float) -> void :
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		visible = false
		set_process(false)


func _draw() -> void :
	if duration <= 0.0:
		return
	var progress: = clampf(elapsed / duration, 0.0, 1.0)
	var viewport_size: = size
	var sweep_x: = lerpf( - viewport_size.x * 0.22, viewport_size.x * 1.18, progress)
	var fade: = sin(progress * PI)
	var band_color: = Color(GOLD.r, GOLD.g, GOLD.b, 0.11 * fade)
	var edge_color: = Color(GOLD.r, GOLD.g, GOLD.b, 0.3 * fade)
	var skew: = viewport_size.y * 0.22
	draw_colored_polygon(PackedVector2Array([
		Vector2(sweep_x - 96.0, 0.0), 
		Vector2(sweep_x + 24.0, 0.0), 
		Vector2(sweep_x - skew + 24.0, viewport_size.y), 
		Vector2(sweep_x - skew - 96.0, viewport_size.y), 
	]), band_color)
	draw_line(Vector2(sweep_x + 24.0, 0.0), Vector2(sweep_x - skew + 24.0, viewport_size.y), edge_color, 2.0)
	for index in 26:
		var seed: = float(index + 1)
		var particle_progress: = fposmod(progress * (0.72 + fposmod(seed * 0.17, 0.34)) + seed * 0.071, 1.0)
		var x: = particle_progress * viewport_size.x
		var y: = fposmod(seed * 83.0 + sin(progress * 5.0 + seed) * 34.0, viewport_size.y)
		var pulse: = 0.35 + 0.65 * sin(PI * particle_progress)
		var color: = GOLD if index % 3 == 0 else CYAN
		color.a = 0.12 * fade * pulse
		draw_circle(Vector2(x, y), 1.2 + float(index % 3) * 0.7, color)
