class_name FinalCelebrationCanvas
extends Control

var elapsed: = 0.0


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process( not GameSettings.reduce_motion)
	queue_redraw()


func _process(delta: float) -> void :
	elapsed += delta
	queue_redraw()


func _draw() -> void :
	var center: = Vector2(size.x * 0.5, size.y * 0.22)
	var breath: = 1.0 if GameSettings.reduce_motion else 1.0 + sin(elapsed * 1.4) * 0.035
	for index in range(22):
		var angle: = TAU * float(index) / 22.0 + elapsed * 0.025
		var inner: = center + Vector2(cos(angle), sin(angle)) * 92.0
		var outer: = center + Vector2(cos(angle), sin(angle)) * (185.0 + float(index % 4) * 24.0) * breath
		draw_line(inner, outer, Color(0.96, 0.76, 0.3, 0.055), 4.0)
	for radius in [76.0, 105.0, 142.0]:
		draw_arc(center, radius * breath, 0.0, TAU, 96, Color(0.96, 0.76, 0.3, 0.11), 2.0, true)
	for index in range(18):
		var phase: = float(index) * 1.73 + elapsed * (0.18 + float(index % 3) * 0.04)
		var point: = Vector2(fmod(110.0 + float(index) * 127.0, maxf(1.0, size.x - 100.0)), 58.0 + fmod(float(index * 83), maxf(1.0, size.y * 0.52)))
		var glow: = 0.28 + (sin(phase) + 1.0) * 0.18
		draw_circle(point, 2.5 + float(index % 2), Color(0.98, 0.86, 0.48, glow))
	_draw_fireworks()
	_draw_confetti_streams()
	_draw_cannons()


func _draw_fireworks() -> void :
	var bursts: = [
		Vector2(size.x * 0.2, size.y * 0.15), 
		Vector2(size.x * 0.78, size.y * 0.18), 
		Vector2(size.x * 0.5, size.y * 0.09), 
	]
	var colors: = [Color("ffd76a"), Color("76d8f2"), Color("ef7d86")]
	for i in bursts.size():
		var origin: Vector2 = bursts[i]
		var phase: = 0.65 if GameSettings.reduce_motion else fmod(elapsed * (0.55 + float(i) * 0.13) + float(i) * 0.28, 1.0)
		var radius: = 22.0 + phase * 58.0
		var alpha: = 0.62 * (1.0 - phase)
		for spoke in range(18):
			var angle: = TAU * float(spoke) / 18.0
			var start: = origin + Vector2(cos(angle), sin(angle)) * (radius * 0.32)
			var end: = origin + Vector2(cos(angle), sin(angle)) * radius
			draw_line(start, end, Color(colors[(i + spoke) % colors.size()], alpha), 3.0)
		draw_circle(origin, 5.0 + phase * 4.0, Color(colors[i % colors.size()], alpha))


func _draw_confetti_streams() -> void :
	var colors: = [Color("ffd76a"), Color("61d2cc"), Color("74a8ff"), Color("ef7d86"), Color("ffffff")]
	for index in range(42):
		var speed: = 42.0 + float(index % 7) * 18.0
		var y: = fmod(float(index * 53) + elapsed * speed, maxf(1.0, size.y + 120.0)) - 80.0
		var x: = fmod(float(index * 149) + sin(elapsed + float(index)) * 18.0, maxf(1.0, size.x))
		var rect: = Rect2(Vector2(x, y), Vector2(5.0 + float(index % 3) * 3.0, 13.0 + float(index % 4) * 2.0))
		draw_set_transform(rect.position + rect.size * 0.5, elapsed * (0.8 + float(index % 5) * 0.12), Vector2.ONE)
		draw_rect(Rect2( - rect.size * 0.5, rect.size), Color(colors[index % colors.size()], 0.72), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cannons() -> void :
	var base_y: = size.y - 70.0
	for side in [-1, 1]:
		var base: = Vector2(size.x * (0.16 if side < 0 else 0.84), base_y)
		var muzzle: = base + Vector2(42.0 * side, -38.0)
		draw_line(base, muzzle, Color("d9b557"), 16.0)
		draw_line(base + Vector2(-18.0 * side, 18.0), base + Vector2(22.0 * side, 18.0), Color("73552f"), 12.0)
		draw_circle(muzzle, 10.0, Color("f2d37a"))
		for spark in range(7):
			var angle: = (-0.85 if side < 0 else -2.3) + float(spark) * 0.18
			draw_line(muzzle, muzzle + Vector2(cos(angle), sin(angle)) * (34.0 + float(spark % 3) * 12.0), Color(1.0, 0.89, 0.54, 0.48), 3.0)
