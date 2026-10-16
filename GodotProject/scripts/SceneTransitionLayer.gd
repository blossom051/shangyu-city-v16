class_name SceneTransitionLayer
extends CanvasLayer


signal transition_hidden

const MINIMUM_VISIBLE_SECONDS: = 0.82

var veil: Control
var city_fx: Control
var title_label: Label
var stage_label: Label
var percent_label: Label
var progress_bar: ProgressBar
var stage_nodes: Array[Label] = []
var _elapsed: = 0.0
var _displayed_progress: = 0.0
var _target_progress: = 0.0
var _begun: = false
var _finish_requested: = false
var _hiding: = false


class CityBootAnimation:
	extends Control

	var phase: = 0.0
	var loading_progress: = 0.0
	var moving: = true
	var animation_frames: = 0

	func _ready() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func set_loading_progress(value: float) -> void :
		loading_progress = clampf(value, 0.0, 100.0)
		queue_redraw()

	func reset_motion() -> void :
		phase = 0.0
		animation_frames = 0
		queue_redraw()

	func _process(delta: float) -> void :
		if moving:
			phase += delta
			animation_frames += 1
			queue_redraw()

	func _draw() -> void :
		var viewport: = size
		if viewport.x <= 1.0 or viewport.y <= 1.0:
			return
		_draw_atmosphere(viewport)
		_draw_skyline(viewport)
		_draw_capital_routes(viewport)
		_draw_stage_horizon(viewport)

	func _draw_atmosphere(viewport: Vector2) -> void :
		draw_rect(Rect2(Vector2.ZERO, viewport), Color("061925"))
		for band in range(9):
			var ratio: = float(band) / 9.0
			var color: = Color(0.025 + ratio * 0.018, 0.12 + ratio * 0.055, 0.17 + ratio * 0.07, 1.0)
			draw_rect(Rect2(0.0, viewport.y * ratio, viewport.x, viewport.y / 9.0 + 2.0), color)
		var core: = Vector2(viewport.x * 0.63, viewport.y * 0.39)
		for radius_index in range(7, 0, -1):
			var radius: = viewport.y * (0.055 + float(radius_index) * 0.045)
			var alpha: = 0.012 + (8.0 - float(radius_index)) * 0.006
			draw_circle(core, radius, Color(0.22, 0.78, 0.82, alpha))
		var sweep_x: = fposmod(phase * viewport.x * 0.055, viewport.x * 1.35) - viewport.x * 0.18 if moving else viewport.x * 0.48
		var sweep: = PackedVector2Array([
			Vector2(sweep_x, 0), Vector2(sweep_x + viewport.x * 0.1, 0), 
			Vector2(sweep_x + viewport.x * 0.3, viewport.y), Vector2(sweep_x + viewport.x * 0.18, viewport.y), 
		])
		draw_colored_polygon(sweep, Color(0.19, 0.75, 0.78, 0.026))

	func _draw_skyline(viewport: Vector2) -> void :
		var ground_y: = viewport.y * 0.76
		draw_rect(Rect2(0, ground_y, viewport.x, viewport.y - ground_y), Color("06141d"))
		var lit_ratio: = clampf(loading_progress / 100.0, 0.0, 1.0)
		for index in range(19):
			var x: = viewport.x * (0.012 + float(index) * 0.053)
			var width: = viewport.x * (0.038 + float(index % 4) * 0.004)
			var height: = viewport.y * (0.18 + float((index * 7) % 9) * 0.025)
			if index in [5, 11, 15]:
				height += viewport.y * 0.13
			var top: = ground_y - height
			var fill: = Color(0.035 + float(index % 3) * 0.01, 0.13, 0.17 + float(index % 4) * 0.008, 1.0)
			draw_rect(Rect2(x, top, width, height), fill)
			draw_line(Vector2(x, top), Vector2(x + width, top), Color(0.27, 0.7, 0.72, 0.24), 2.0)
			if index in [5, 11, 15]:
				draw_line(Vector2(x + width * 0.5, top), Vector2(x + width * 0.5, top - viewport.y * 0.055), Color(0.8, 0.68, 0.35, 0.72), 2.0)
			for row in range(6):
				for column in range(3):
					var order: = fposmod(float(index * 17 + row * 5 + column * 11), 57.0) / 57.0
					var is_lit: = order <= lit_ratio
					var pulse: = 0.78 + sin(phase * 2.1 + float(index + row)) * 0.18 if moving else 0.88
					var window_color: = Color(0.96, 0.76, 0.34, (0.42 + pulse * 0.42) if is_lit else 0.075)
					var window_pos: = Vector2(x + width * (0.18 + float(column) * 0.28), top + height * (0.13 + float(row) * 0.125))
					draw_rect(Rect2(window_pos, Vector2(maxf(3.0, width * 0.075), maxf(3.0, viewport.y * 0.008))), window_color)

	func _draw_capital_routes(viewport: Vector2) -> void :
		var route_progress: = clampf(loading_progress / 100.0, 0.0, 1.0)
		var center: = Vector2(viewport.x * 0.63, viewport.y * 0.43)
		var starts: = [
			Vector2(viewport.x * 0.07, viewport.y * 0.67), 
			Vector2(viewport.x * 0.19, viewport.y * 0.28), 
			Vector2(viewport.x * 0.39, viewport.y * 0.71), 
			Vector2(viewport.x * 0.91, viewport.y * 0.29), 
			Vector2(viewport.x * 0.94, viewport.y * 0.66), 
		]
		for route_index in range(starts.size()):
			var start: Vector2 = starts[route_index]
			var elbow: = Vector2(lerpf(start.x, center.x, 0.56), start.y)
			var path: = PackedVector2Array([start, elbow, center])
			draw_polyline(path, Color(0.25, 0.75, 0.78, 0.2), 3.0, true)
			var active_length: = clampf(route_progress * 1.25 - float(route_index) * 0.08, 0.0, 1.0)
			var active_point: = _path_point(start, elbow, center, active_length)
			if active_length > 0.0:
				draw_line(start, _path_point(start, elbow, center, minf(active_length, 0.5) * 2.0 * 0.5), Color(0.29, 0.86, 0.85, 0.54), 4.0)
				draw_circle(active_point, 5.0, Color(0.98, 0.78, 0.34, 0.92))
			if moving and active_length >= 0.99:
				var flow: = fposmod(phase * (0.24 + float(route_index) * 0.018) + float(route_index) * 0.17, 1.0)
				var flow_point: = _path_point(start, elbow, center, flow)
				draw_circle(flow_point, 4.0, Color(0.45, 0.95, 0.91, 0.88))
		var core_pulse: = 1.0 + sin(phase * 2.4) * 0.06 if moving else 1.0
		for ring in range(4):
			draw_arc(center, (18.0 + float(ring) * 12.0) * core_pulse, 0.0, TAU, 40, Color(0.96, 0.77, 0.34, 0.6 - float(ring) * 0.11), 3.0, true)
		draw_circle(center, 8.0, Color("f4ce6a"))

	func _path_point(start: Vector2, elbow: Vector2, finish: Vector2, ratio: float) -> Vector2:
		if ratio <= 0.5:
			return start.lerp(elbow, ratio * 2.0)
		return elbow.lerp(finish, (ratio - 0.5) * 2.0)

	func _draw_stage_horizon(viewport: Vector2) -> void :
		var y: = viewport.y * 0.815
		draw_line(Vector2(viewport.x * 0.06, y), Vector2(viewport.x * 0.94, y), Color(0.25, 0.64, 0.67, 0.22), 2.0)
		var streak_offset: = fposmod(phase * 180.0, 180.0) if moving else 64.0
		for streak in range(12):
			var x: = float(streak) * viewport.x / 10.0 + streak_offset - viewport.x * 0.12
			draw_line(Vector2(x, y), Vector2(x + viewport.x * 0.035, y), Color(0.96, 0.77, 0.34, 0.4), 3.0)


func _ready() -> void :
	layer = 2800
	_build()
	visible = false
	set_process(false)


func begin(title: String) -> void :
	if veil == null:
		_build()
	_kill_loading_tweens()
	_begun = true
	_finish_requested = false
	_hiding = false
	_elapsed = 0.0
	_displayed_progress = 4.0
	_target_progress = 4.0
	veil.modulate.a = 1.0
	visible = true
	title_label.text = title
	stage_label.text = "校准首轮经营数据"
	(city_fx as CityBootAnimation).moving = not bool(GameSettings.reduce_motion)
	(city_fx as CityBootAnimation).reset_motion()
	(city_fx as CityBootAnimation).set_loading_progress(_displayed_progress)
	_update_progress_visual()
	set_process(true)


func set_stage(text: String, progress: float) -> void :
	if not _begun:
		return
	stage_label.text = text
	_target_progress = maxf(_target_progress, clampf(progress, 0.0, 100.0))
	if bool(GameSettings.reduce_motion):
		_displayed_progress = _target_progress
		_update_progress_visual()


func finish() -> void :
	if not _begun:
		return
	set_stage("城市经营界面已就绪", 100.0)
	_finish_requested = true


func force_hide() -> void :
	if not _begun:
		return
	_complete_hide(true)


func presentation_profile() -> Dictionary:
	return {
		"procedural_city": city_fx != null, 
		"first_frame_opaque": visible and veil != null and veil.modulate.a >= 0.999, 
		"image_asset_count": 0, 
		"moving_picture": false, 
		"continuous_motion": _begun and not bool(GameSettings.reduce_motion), 
		"animation_frames": int((city_fx as CityBootAnimation).animation_frames) if city_fx != null else 0, 
		"stage_nodes": stage_nodes.size(), 
		"minimum_body_font": 18, 
		"progress": _displayed_progress, 
		"target_progress": _target_progress, 
		"minimum_visible_seconds": MINIMUM_VISIBLE_SECONDS, 
		"elapsed": _elapsed, 
		"finish_requested": _finish_requested, 
		"visible": visible, 
	}


func _process(delta: float) -> void :
	if not _begun:
		return
	_elapsed += delta
	if _displayed_progress < _target_progress:
		_displayed_progress = minf(_target_progress, _displayed_progress + delta * 84.0)
		_update_progress_visual()
	if _finish_requested and _displayed_progress >= 99.95 and _elapsed >= MINIMUM_VISIBLE_SECONDS and not _hiding:
		_complete_hide(bool(GameSettings.reduce_motion))


func _update_progress_visual() -> void :
	progress_bar.value = _displayed_progress
	percent_label.text = "%d%%" % roundi(_displayed_progress)
	(city_fx as CityBootAnimation).set_loading_progress(_displayed_progress)
	var thresholds: Array[float] = [28.0, 55.0, 82.0, 99.5]
	for index in range(stage_nodes.size()):
		var active: bool = _displayed_progress >= thresholds[index]
		stage_nodes[index].add_theme_color_override("font_color", Color("f2cc69") if active else Color("668994"))
		stage_nodes[index].text = ("● " if active else "○ ") + ["市场", "资源", "城市", "就绪"][index]


func _complete_hide(immediate: bool) -> void :
	if _hiding:
		return
	_hiding = true
	if immediate:
		_reset_hidden()
		return
	var tween: = create_tween()
	tween.set_meta("city_boot_loading", true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(veil, "modulate:a", 0.0, 0.18)
	tween.finished.connect(_reset_hidden)


func _reset_hidden() -> void :
	visible = false
	veil.modulate.a = 1.0
	_begun = false
	_finish_requested = false
	_hiding = false
	set_process(false)
	transition_hidden.emit()


func _kill_loading_tweens() -> void :
	if not is_inside_tree():
		return
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.get_meta("city_boot_loading", false):
			tween.kill()


func _build() -> void :
	veil = Control.new()
	veil.name = "ProceduralCityLoading"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)

	var opaque_base: = ColorRect.new()
	opaque_base.name = "OpaqueFirstFrame"
	opaque_base.color = Color("061925")
	opaque_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opaque_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(opaque_base)

	city_fx = CityBootAnimation.new()
	city_fx.name = "CityBootAnimation"
	city_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(city_fx)

	var heading: = VBoxContainer.new()
	heading.position = Vector2(58, 44)
	heading.size = Vector2(820, 150)
	heading.add_theme_constant_override("separation", 7)
	veil.add_child(heading)
	var eyebrow: = Label.new()
	eyebrow.text = "CITY CAPITAL NETWORK  INITIALIZING"
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color("70d4dd"))
	heading.add_child(eyebrow)
	title_label = Label.new()
	title_label.text = "城市资本网络正在启航"
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color("f5dc95"))
	title_label.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.035, 0.94))
	title_label.add_theme_constant_override("outline_size", 7)
	heading.add_child(title_label)
	var subtitle: = Label.new()
	subtitle.text = "城市将随真实加载进度逐区点亮"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("e9f4f4"))
	heading.add_child(subtitle)

	var progress_panel: = PanelContainer.new()
	progress_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	progress_panel.offset_left = -430
	progress_panel.offset_right = 430
	progress_panel.offset_top = -190
	progress_panel.offset_bottom = -28
	var panel_style: = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.008, 0.035, 0.055, 0.94)
	panel_style.border_color = Color(0.86, 0.69, 0.3, 0.84)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(22)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 17
	panel_style.shadow_color = Color(0, 0, 0, 0.58)
	panel_style.shadow_size = 20
	progress_panel.add_theme_stylebox_override("panel", panel_style)
	veil.add_child(progress_panel)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	progress_panel.add_child(stack)
	var stage_row: = HBoxContainer.new()
	stack.add_child(stage_row)
	stage_label = Label.new()
	stage_label.text = "校准首轮经营数据"
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_label.add_theme_font_size_override("font_size", 19)
	stage_label.add_theme_color_override("font_color", Color("f3f7f6"))
	stage_row.add_child(stage_label)
	percent_label = Label.new()
	percent_label.text = "4%"
	percent_label.add_theme_font_size_override("font_size", 22)
	percent_label.add_theme_color_override("font_color", Color("f2cb69"))
	stage_row.add_child(percent_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 15)
	progress_bar.show_percentage = false
	var progress_bg: = StyleBoxFlat.new()
	progress_bg.bg_color = Color("0c2c37")
	progress_bg.set_corner_radius_all(8)
	var progress_fill: = StyleBoxFlat.new()
	progress_fill.bg_color = Color("e0b757")
	progress_fill.set_corner_radius_all(8)
	progress_fill.shadow_color = Color(0.95, 0.76, 0.29, 0.34)
	progress_fill.shadow_size = 7
	progress_bar.add_theme_stylebox_override("background", progress_bg)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	stack.add_child(progress_bar)
	var milestones: = HBoxContainer.new()
	milestones.alignment = BoxContainer.ALIGNMENT_CENTER
	milestones.add_theme_constant_override("separation", 44)
	stack.add_child(milestones)
	for text_value in ["○ 市场", "○ 资源", "○ 城市", "○ 就绪"]:
		var node: = Label.new()
		node.text = text_value
		node.add_theme_font_size_override("font_size", 16)
		node.add_theme_color_override("font_color", Color("668994"))
		milestones.add_child(node)
		stage_nodes.append(node)
	var note: = Label.new()
	note.text = "后台资源与城市交互状态同步加载  无需点击"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("90b8be"))
	stack.add_child(note)
