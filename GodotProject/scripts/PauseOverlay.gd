class_name PauseOverlay
extends CanvasLayer

const Styles = preload("res://scripts/UIStyles.gd")
const SaveSlotDialogScene = preload("res://scripts/SaveSlotDialog.gd")

var shade: ColorRect
var panel: PanelContainer
var settings: VBoxContainer
var resolution_option: OptionButton
var window_mode_option: OptionButton
var ui_scale_option: OptionButton
var frame_rate_option: OptionButton
var display_status: Label
var bgm_slider: HSlider
var sfx_slider: HSlider
var brightness_slider: HSlider
var contrast_slider: HSlider
var reduce_motion_toggle: CheckButton
var endless_status: Label
var ipo_button: Button
var end_session_button: Button


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build()
	GameSettings.display_changed.connect(_refresh_display_status)
	call_deferred("_resize_panel")
	hide_menu()


func show_menu() -> void :
	visible = true
	get_tree().paused = true
	_sync_display_controls()
	_refresh_endless_actions()
	AudioManager.click()


func hide_menu() -> void :
	visible = false
	get_tree().paused = false


func _build() -> void :
	shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.005, 0.02, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.resized.connect(_resize_panel)
	add_child(shade)
	get_viewport().size_changed.connect(_resize_panel)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var panel_style: StyleBox = Styles.toy_panel()
	panel_style = panel_style.duplicate()
	panel_style.set_content_margin(SIDE_RIGHT, 0.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	shade.add_child(panel)

	var body: = ScrollContainer.new()
	body.name = "Body"
	body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(body)

	var margin: = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(margin)


	settings = VBoxContainer.new()
	settings.name = "Settings"
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 10)
	margin.add_child(settings)

	var title: = Styles.label("沙盘已暂停", 32, Color("f4d37a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_child(title)
	var note: = Styles.label("显示设置会立即应用；保存后可返回首页继续经营。", 16, Styles.TOY_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_child(note)
	_add_action(settings, "继续游戏", true, hide_menu)

	var settings_title: = Styles.label("游戏设置", 21, Styles.TOY_INK)
	settings.add_child(settings_title)
	var switches: = HBoxContainer.new()
	switches.add_theme_constant_override("separation", 16)
	settings.add_child(switches)
	var music_toggle: = CheckButton.new()
	music_toggle.name = "Music"
	music_toggle.text = "音乐"
	music_toggle.button_pressed = GameSettings.music_enabled
	music_toggle.toggled.connect( func(value: bool) -> void :
		GameSettings.set_audio_switches(value, GameSettings.sfx_enabled)
		music_toggle.text = "背景音乐：开" if value else "背景音乐：关"
		AudioManager.click())
	switches.add_child(music_toggle)
	var sfx_toggle: = CheckButton.new()
	sfx_toggle.name = "SFX"
	sfx_toggle.text = "音效"
	sfx_toggle.button_pressed = GameSettings.sfx_enabled
	sfx_toggle.toggled.connect( func(value: bool) -> void :
		if not value:
			AudioManager.click()
		GameSettings.set_audio_switches(GameSettings.music_enabled, value)
		sfx_toggle.text = "操作音效：开" if value else "操作音效：关"
		if value:
			AudioManager.success())
	switches.add_child(sfx_toggle)
	reduce_motion_toggle = CheckButton.new()
	reduce_motion_toggle.name = "ReduceMotion"
	reduce_motion_toggle.text = "减少动态效果：关"
	reduce_motion_toggle.button_pressed = GameSettings.reduce_motion
	reduce_motion_toggle.toggled.connect( func(value: bool) -> void :
		GameSettings.set_reduce_motion(value)
		reduce_motion_toggle.text = "减少动态效果：开" if value else "减少动态效果：关"
		AudioManager.click())
	switches.add_child(reduce_motion_toggle)

	bgm_slider = _value_row("MusicVolume", "音乐音量", GameSettings.bgm_volume, 0.0, 1.0, 0.05, func(value: float) -> void : GameSettings.set_audio(value, GameSettings.sfx_volume, GameSettings.muted))
	sfx_slider = _value_row("SfxVolume", "音效音量", GameSettings.sfx_volume, 0.0, 1.0, 0.05, func(value: float) -> void : GameSettings.set_audio(GameSettings.bgm_volume, value, GameSettings.muted))
	settings.add_child(bgm_slider.get_parent())
	settings.add_child(sfx_slider.get_parent())
	brightness_slider = _value_row("Brightness", "画面亮度", GameSettings.brightness, 0.62, 1.0, 0.02, func(value: float) -> void : GameSettings.set_visual(value, GameSettings.contrast))
	contrast_slider = _value_row("Contrast", "画面对比度", GameSettings.contrast, 0.78, 1.08, 0.02, func(value: float) -> void : GameSettings.set_visual(GameSettings.brightness, value))
	settings.add_child(brightness_slider.get_parent())
	settings.add_child(contrast_slider.get_parent())

	settings.add_child(Styles.label("分辨率（窗口模式下生效）", 15, Styles.TOY_MUTED))
	resolution_option = OptionButton.new()
	resolution_option.name = "Resolution"
	resolution_option.custom_minimum_size = Vector2(0, 44)
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	Styles.apply_toy_option_button(resolution_option)
	resolution_option.item_selected.connect(_set_resolution)
	settings.add_child(resolution_option)

	settings.add_child(Styles.label("帧率上限", 15, Styles.TOY_MUTED))
	frame_rate_option = OptionButton.new()
	frame_rate_option.name = "FrameRate"
	frame_rate_option.custom_minimum_size = Vector2(0, 44)
	for label: String in GameSettings.FRAME_RATE_LABELS:
		frame_rate_option.add_item(label)
	Styles.apply_toy_option_button(frame_rate_option)
	frame_rate_option.item_selected.connect(_set_frame_rate)
	settings.add_child(frame_rate_option)

	settings.add_child(Styles.label("显示模式", 15, Styles.TOY_MUTED))
	window_mode_option = OptionButton.new()
	window_mode_option.name = "WindowMode"
	window_mode_option.custom_minimum_size = Vector2(0, 44)
	for label: String in GameSettings.WINDOW_MODE_LABELS:
		window_mode_option.add_item(label)
	Styles.apply_toy_option_button(window_mode_option)
	window_mode_option.item_selected.connect(_set_window_mode)
	settings.add_child(window_mode_option)

	settings.add_child(Styles.label("界面缩放", 15, Styles.TOY_MUTED))
	ui_scale_option = OptionButton.new()
	ui_scale_option.name = "UIScale"
	ui_scale_option.custom_minimum_size = Vector2(0, 44)
	for label: String in GameSettings.UI_SCALE_LABELS:
		ui_scale_option.add_item(label)
	Styles.apply_toy_option_button(ui_scale_option)
	ui_scale_option.item_selected.connect( func(index: int) -> void : GameSettings.set_ui_scale_index(index))
	settings.add_child(ui_scale_option)

	display_status = Styles.label("", 15, Color("72c7d9"))
	display_status.name = "DisplayStatus"
	display_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(display_status)
	var defaults_button: = _add_action(settings, "恢复推荐设置", false, _restore_recommended_defaults)
	defaults_button.name = "RecommendedDefaults"

	_add_action(settings, "保存到存档位", false, _open_save_slots)
	_add_action(settings, "读取存档", false, _open_load_slots)
	endless_status = Styles.label("", 15, Color("7bd8c7"))
	endless_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_child(endless_status)
	ipo_button = _add_action(settings, "申请稳健上市融资", false, _request_ipo)
	end_session_button = _add_action(settings, "主动结束永续经营", false, _end_endless_session)
	_add_action(settings, "保存并返回首页", false, _save_and_return)
	_add_action(settings, "退出游戏", false, _quit_game)
	_sync_display_controls()
	_refresh_endless_actions()


func _refresh_endless_actions() -> void:
	if endless_status == null:
		return
	var enabled := EndlessOperationsSystem.is_enabled()
	endless_status.visible = enabled
	ipo_button.visible = enabled
	end_session_button.visible = enabled
	if not enabled:
		return
	var cycle := EndlessOperationsSystem.current_cycle()
	var active := GameState.active_player()
	var eligibility := EndlessOperationsSystem.ipo_eligibility(str(active.get("id", "")))
	endless_status.text = "第%d回合  %s期  %s" % [int(GameState.game_data.get("round", 0)), str(cycle.get("name", "常态")), str(eligibility.get("message", ""))]
	ipo_button.disabled = not bool(eligibility.get("ok", false))


func _request_ipo() -> void:
	var result := EndlessOperationsSystem.request_ipo(str(GameState.active_player().get("id", "")), false)
	endless_status.text = str(result.get("message", ""))
	_refresh_endless_actions()


func _end_endless_session() -> void:
	hide_menu()
	load("res://scripts/TurnSettlement.gd").finalize_match()
	GameFlow.go("final")


func _resize_panel() -> void :
	if panel == null or shade == null:
		return
	var available: = get_viewport().get_visible_rect().size
	shade.position = Vector2.ZERO
	shade.size = available
	var target: = Vector2(minf(680.0, maxf(420.0, available.x - 40.0)), minf(900.0, maxf(520.0, available.y - 40.0)))
	panel.size = target
	panel.position = (available - target) * 0.5


func _sync_display_controls() -> void :
	if resolution_option == null:
		return
	resolution_option.select(GameSettings.resolution_index)
	window_mode_option.select(maxi(0, GameSettings.WINDOW_MODES.find(GameSettings.window_mode)))
	ui_scale_option.select(GameSettings.ui_scale_index)
	frame_rate_option.select(GameSettings.frame_rate_index)
	if bgm_slider != null:
		bgm_slider.set_value_no_signal(GameSettings.bgm_volume)
		sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
		brightness_slider.set_value_no_signal(GameSettings.brightness)
		contrast_slider.set_value_no_signal(GameSettings.contrast)
	var music_toggle: = settings.find_child("Music", true, false) as CheckButton
	var sfx_toggle: = settings.find_child("SFX", true, false) as CheckButton
	if music_toggle != null:
		music_toggle.set_pressed_no_signal(GameSettings.music_enabled)
	if sfx_toggle != null:
		sfx_toggle.set_pressed_no_signal(GameSettings.sfx_enabled)
	if reduce_motion_toggle != null:
		reduce_motion_toggle.set_pressed_no_signal(GameSettings.reduce_motion)
		reduce_motion_toggle.text = "减少动态效果：开" if GameSettings.reduce_motion else "减少动态效果：关"
	_refresh_display_status(GameSettings.applied_resolution(), GameSettings.fullscreen)


func _set_resolution(index: int) -> void :
	GameSettings.set_resolution_index(index)
	_sync_display_controls()


func _set_window_mode(index: int) -> void :
	GameSettings.set_window_mode(index)
	_sync_display_controls()


func _set_frame_rate(index: int) -> void:
	GameSettings.set_frame_rate_index(index)
	_sync_display_controls()


func _refresh_display_status(_size: Vector2i, _fullscreen: bool) -> void :
	if display_status != null:
		display_status.text = "当前已应用：%s" % GameSettings.resolution_label()


func _value_row(node_name: String, title: String, value: float, minimum: float, maximum: float, increment: float, changed: Callable) -> HSlider:
	var row: = HBoxContainer.new()
	var label: = Styles.label(title, 16, Styles.TOY_INK)
	label.custom_minimum_size = Vector2(108, 0)
	row.add_child(label)
	var slider: = HSlider.new()
	slider.name = node_name
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(changed)
	row.add_child(slider)
	return slider


func _add_action(parent: VBoxContainer, title: String, primary: bool, action: Callable) -> Button:
	var button: = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 52)
	Styles.apply_toy_button(button, primary, Styles.TOY_YELLOW, 19)
	button.pressed.connect(action)
	button.mouse_entered.connect(AudioManager.hover)
	parent.add_child(button)
	return button


func _restore_recommended_defaults() -> void :
	GameSettings.restore_recommended_defaults()
	_sync_display_controls()
	var button: = settings.find_child("RecommendedDefaults", true, false) as Button
	if button != null:
		button.text = "已恢复推荐设置"
	AudioManager.success()


func _save_game() -> void :
	GameState.save_to_disk()
	GameSettings.save_now()
	AudioManager.success()
	if display_status != null:
		display_status.text = "已保存  %s" % GameSettings.resolution_label()


func _open_save_slots() -> void:
	_open_save_slot_dialog("save")


func _open_load_slots() -> void:
	_open_save_slot_dialog("load")


func _open_save_slot_dialog(mode: String) -> void:
	if get_tree().root.has_node("SaveSlotDialog"):
		return
	var dialog := SaveSlotDialogScene.new()
	dialog.name = "SaveSlotDialog"
	dialog.open(mode)
	dialog.slot_saved.connect(func(_slot_id: String) -> void:
		if display_status != null:
			display_status.text = "手动存档已保存")
	dialog.slot_loaded.connect(func(_slot_id: String) -> void:
		hide_menu()
		GameFlow.resume_loaded_match())
	get_tree().root.add_child(dialog)


func _save_and_return() -> void :
	var tutorial_director: = get_node_or_null("/root/TutorialDirector")
	if tutorial_director != null and (bool(tutorial_director.get("active")) or bool(tutorial_director.get("sandbox").get("active"))):
		tutorial_director.call("cancel", "pause_return_to_menu")
	_save_game()
	hide_menu()
	GameFlow.go("menu")


func _quit_game() -> void :
	var tutorial_director: = get_node_or_null("/root/TutorialDirector")
	if tutorial_director != null and (bool(tutorial_director.get("active")) or bool(tutorial_director.get("sandbox").get("active"))):
		tutorial_director.call("cancel", "pause_quit")
	_save_game()
	get_tree().quit()
