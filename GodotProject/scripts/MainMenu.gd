extends Node3D

const Styles = preload("res://scripts/UIStyles.gd")
const SaveSlotDialogScene = preload("res://scripts/SaveSlotDialog.gd")
const BODY_FONT: Font = preload("res://Themes/V9141BodyMediumFont.tres")
const REGULAR_FONT: Font = preload("res://Themes/V9141BodyFont.tres")

@onready var error_label: Label = $UI / Safe / Menu / DataError
@onready var settings_panel: PanelContainer = $UI / Settings
@onready var menu: Control = $UI / Safe / Menu
@onready var atmosphere: ColorRect = $UI / Atmosphere
@onready var logo: Label = $UI / Safe / Menu / Logo
@onready var subtitle: Label = $UI / Safe / Menu / Subtitle
@onready var tagline: Label = $UI / Safe / Menu / Tagline
@onready var new_game_button: Button = $UI / Safe / Menu / NewGame
@onready var tutorial_button: Button = $UI / Safe / Menu / Tutorial
@onready var continue_button: Button = $UI / Safe / Menu / Continue
@onready var collection_button: Button = $UI / Safe / Menu / Collection
@onready var settings_button: Button = $UI / Safe / Menu / Settings
@onready var quit_button: Button = $UI / Safe / Menu / Quit

var settings_backdrop: ColorRect

func _ready() -> void :
	if OS.get_cmdline_user_args().has("--self-test") or OS.get_cmdline_args().has("--self-test"):
		var smoke: = Node.new()
		smoke.set_script(load("res://scripts/ReleaseSelfTest.gd"))
		add_child(smoke)
		return

	_configure_text()
	_configure_visual_environment()
	_configure_menu_composition()
	get_viewport().size_changed.connect(_apply_main_menu_layout)
	_configure_settings_modal()
	var companies: = GameConfig.list("investment_companies")
	if not companies.is_empty() and $UI / CityBackground.has_method("show_company"):
		$UI / CityBackground.call("show_company", companies[3])
	error_label.visible = not GameConfig.validation_errors.is_empty()
	error_label.text = "数据校验失败：\n" + "\n".join(GameConfig.validation_errors)

	new_game_button.pressed.connect(_start_new_game)
	tutorial_button.pressed.connect(_start_standalone_tutorial)
	continue_button.pressed.connect(_continue_game)
	collection_button.pressed.connect( func() -> void : AudioManager.click();GameFlow.go("collection"))
	settings_button.pressed.connect(_toggle_settings)
	quit_button.pressed.connect( func() -> void : AudioManager.click();get_tree().quit())
	$UI / Settings / Margin / Box / Close.pressed.connect(_toggle_settings)
	$UI / Settings / Margin / Box / BgmSlider.value_changed.connect(_set_bgm_volume)
	$UI / Settings / Margin / Box / SfxSlider.value_changed.connect(_set_sfx_volume)
	$UI / Settings / Margin / Box / BrightnessSlider.value_changed.connect(_set_brightness)
	$UI / Settings / Margin / Box / ContrastSlider.value_changed.connect(_set_contrast)
	$UI / Settings / Margin / Box / AudioSwitches / MusicEnabled.toggled.connect(_set_music_enabled)
	$UI / Settings / Margin / Box / AudioSwitches / SfxEnabled.toggled.connect(_set_sfx_enabled)
	$UI / Settings / Margin / Box / AudioSwitches / AllMute.toggled.connect(_set_muted)
	$UI / Settings / Margin / Box / Fullscreen.toggled.connect(_set_fullscreen)
	$UI / Settings / Margin / Box / ReduceMotion.toggled.connect(_set_reduce_motion)
	$UI / Settings / Margin / Box / RecommendedDefaults.pressed.connect(_restore_recommended_defaults)
	GameSettings.display_changed.connect(_refresh_display_status)
	_setup_resolution()
	_setup_frame_rate()
	$UI / Settings / Margin / Box / BgmSlider.value = GameSettings.bgm_volume
	$UI / Settings / Margin / Box / SfxSlider.value = GameSettings.sfx_volume
	$UI / Settings / Margin / Box / BrightnessSlider.value = GameSettings.brightness
	$UI / Settings / Margin / Box / ContrastSlider.value = GameSettings.contrast
	$UI / Settings / Margin / Box / AudioSwitches / MusicEnabled.button_pressed = GameSettings.music_enabled
	$UI / Settings / Margin / Box / AudioSwitches / SfxEnabled.button_pressed = GameSettings.sfx_enabled
	$UI / Settings / Margin / Box / AudioSwitches / AllMute.button_pressed = GameSettings.muted
	$UI / Settings / Margin / Box / Fullscreen.button_pressed = GameSettings.fullscreen
	$UI / Settings / Margin / Box / ReduceMotion.button_pressed = GameSettings.reduce_motion
	_refresh_display_status(GameSettings.applied_resolution(), GameSettings.fullscreen)
	settings_panel.add_theme_stylebox_override("panel", Styles.panel(Color(0.055, 0.15, 0.19, 0.98), Styles.TOY_YELLOW, 14, 14))
	_style_settings_controls()
	call_deferred("_apply_settings_scale")

	for button: Button in _home_buttons():
		_style_home_menu_button(button, button == new_game_button)

	var has_save: = GameState.has_save_file()
	continue_button.disabled = not has_save
	continue_button.text = "读取存档" if has_save else "暂无存档"
	call_deferred("_apply_main_menu_layout")


func _configure_text() -> void :
	logo.text = "商域之城"
	subtitle.text = "资本版图"
	tagline.text = "城市经营  资本竞逐"
	new_game_button.text = "开始游戏"
	tutorial_button.text = "新手教程"
	continue_button.text = "读取存档"
	collection_button.text = "资本典藏馆"
	settings_button.text = "设置"
	quit_button.text = "退出"
	$UI / Version.text = "%s  资本版图" % GameConfig.PRODUCT_VERSION
	$UI / Settings / Margin / Box / Title.text = "音频与画面"
	$UI / Settings / Margin / Box / BgmLabel.text = "背景音乐  %d%%" % roundi(GameSettings.bgm_volume * 100.0)
	$UI / Settings / Margin / Box / SfxLabel.text = "操作音效  %d%%" % roundi(GameSettings.sfx_volume * 100.0)
	$UI / Settings / Margin / Box / BrightnessLabel.text = "画面亮度"
	$UI / Settings / Margin / Box / ContrastLabel.text = "画面对比度"
	$UI / Settings / Margin / Box / AudioSwitches / MusicEnabled.text = "背景音乐：开"
	$UI / Settings / Margin / Box / AudioSwitches / SfxEnabled.text = "操作音效：开"
	$UI / Settings / Margin / Box / AudioSwitches / AllMute.text = "全部静音：关"
	$UI / Settings / Margin / Box / Fullscreen.text = "全屏：关"
	$UI / Settings / Margin / Box / FrameRateLabel.text = "帧率上限"
	$UI / Settings / Margin / Box / ReduceMotion.text = "减少动态效果：关"
	$UI / Settings / Margin / Box / Close.text = "返回主菜单"


func _configure_menu_composition() -> void :
	logo.add_theme_font_override("font", BODY_FONT)
	subtitle.add_theme_font_override("font", BODY_FONT)
	tagline.add_theme_font_override("font", REGULAR_FONT)
	logo.add_theme_color_override("font_color", Color("f4f1e8"))
	logo.add_theme_color_override("font_outline_color", Color(0.005, 0.02, 0.028, 0.98))
	logo.add_theme_constant_override("outline_size", 4)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.48))
	logo.add_theme_constant_override("shadow_offset_x", 1)
	logo.add_theme_constant_override("shadow_offset_y", 3)
	subtitle.add_theme_color_override("font_color", Color("e2bb63"))
	subtitle.add_theme_color_override("font_outline_color", Color(0.01, 0.035, 0.045, 0.95))
	subtitle.add_theme_constant_override("outline_size", 2)
	tagline.add_theme_color_override("font_color", Color("b7cbd0"))
	tagline.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.05, 0.88))
	tagline.add_theme_constant_override("outline_size", 2)
	$UI / Version.add_theme_color_override("font_color", Color("dbe7e9"))
	$UI / Version.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.84))
	$UI / Version.add_theme_constant_override("outline_size", 3)


func _apply_main_menu_layout() -> void :
	var viewport: = get_viewport().get_visible_rect().size
	var compact_height: = viewport.y < 760.0
	var portrait: = viewport.y > viewport.x * 1.1
	var content_width: = minf(360.0, viewport.x - 56.0)
	var button_width: = minf(content_width, 320.0)
	var button_height: = 48.0 if compact_height else 52.0
	var button_gap: = 5.0 if compact_height else 7.0
	var buttons_y: = 158.0 if compact_height else 176.0
	var error_height: = 44.0 if error_label.visible else 0.0
	var buttons_end: = buttons_y + button_height * 6.0 + button_gap * 5.0
	var content_end: = buttons_end + (12.0 + error_height if error_label.visible else 0.0)

	var menu_x: = (viewport.x - content_width) * 0.5 if portrait else clampf(viewport.x * 0.055, 42.0, 96.0)
	var menu_y: = maxf(34.0, (viewport.y - content_end) * (0.38 if portrait else 0.46))
	menu_y = minf(menu_y, maxf(28.0, viewport.y - content_end - 28.0))
	menu.position = Vector2(menu_x, menu_y)
	menu.size = Vector2(content_width, content_end)
	if atmosphere.has_method("configure_focus"):
		atmosphere.call("configure_focus", (menu_x + content_width * 0.46) / maxf(1.0, viewport.x), (content_width + 180.0) / maxf(1.0, viewport.x), portrait)

	logo.position = Vector2.ZERO
	logo.size = Vector2(content_width, 62.0 if compact_height else 70.0)
	logo.add_theme_font_size_override("font_size", 46 if compact_height else 52)
	subtitle.position = Vector2(0.0, 65.0 if compact_height else 75.0)
	subtitle.size = Vector2(content_width, 34.0)
	subtitle.add_theme_font_size_override("font_size", 22 if compact_height else 24)
	tagline.position = Vector2(0.0, 105.0 if compact_height else 116.0)
	tagline.size = Vector2(content_width, 27.0)
	tagline.add_theme_font_size_override("font_size", 15 if compact_height else 16)
	$UI / Safe / Menu / Spacer.position = Vector2(0.0, 139.0 if compact_height else 155.0)
	$UI / Safe / Menu / Spacer.size = Vector2(72.0, 2.0)

	var all_buttons: = _home_buttons()
	for index in all_buttons.size():
		var button: Button = all_buttons[index]
		button.position = Vector2.ZERO + Vector2(0.0, buttons_y + index * (button_height + button_gap))
		button.size = Vector2(button_width, button_height)
		button.custom_minimum_size = button.size
		button.add_theme_font_size_override("font_size", 21 if compact_height else 23)
		button.pivot_offset = button.size * 0.5
		button.set_meta("home_base_x", button.position.x)

	error_label.position = Vector2(0.0, buttons_end + 10.0)
	error_label.size = Vector2(content_width, error_height)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _configure_visual_environment() -> void :
	RenderingServer.set_default_clear_color(Color("78d5ee"))
	var environment: = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("78d5ee")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d4")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.glow_enabled = true
	environment.glow_intensity = 0.58
	environment.glow_strength = 0.72
	environment.glow_bloom = 0.035
	environment.glow_hdr_threshold = 1.22
	var world_environment: = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _configure_settings_modal() -> void :
	settings_backdrop = ColorRect.new()
	settings_backdrop.name = "SettingsBackdrop"
	settings_backdrop.visible = false
	settings_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_backdrop.color = Color(0.01, 0.035, 0.05, 0.68)
	settings_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	settings_backdrop.z_index = 20
	$UI.add_child(settings_backdrop)
	$UI.move_child(settings_backdrop, $UI / Settings.get_index())
	settings_panel.z_index = 30
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.offset_left = -360.0
	settings_panel.offset_top = -360.0
	settings_panel.offset_right = 360.0
	settings_panel.offset_bottom = 360.0


func _start_new_game() -> void :
	AudioManager.enter_game()
	TutorialDirector.cancel("formal_new_game")
	_button_pulse(new_game_button)
	GameFlow.go_smooth("mode")


func _start_standalone_tutorial() -> void :
	AudioManager.enter_game()
	_button_pulse(tutorial_button)
	TutorialDirector.start_standalone_tutorial()


func _continue_game() -> void :
	if has_node("SaveSlotDialog"):
		return
	var dialog := SaveSlotDialogScene.new()
	dialog.name = "SaveSlotDialog"
	dialog.open("load")
	dialog.slot_loaded.connect(func(_slot_id: String) -> void:
		AudioManager.enter_game()
		TutorialDirector.cancel("load_other_save")
		GameFlow.resume_loaded_match())
	add_child(dialog)


func _toggle_settings() -> void :
	AudioManager.click()
	var next_visible: = not settings_panel.visible
	settings_panel.visible = next_visible
	settings_backdrop.visible = next_visible


func _setup_resolution() -> void :
	var box: OptionButton = $UI / Settings / Margin / Box / Resolution
	box.clear()
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		box.add_item("%d x %d" % [resolution.x, resolution.y])
	box.select(GameSettings.resolution_index)
	box.item_selected.connect( func(index: int) -> void :
		GameSettings.set_resolution_index(index)
		$UI / Settings / Margin / Box / Fullscreen.button_pressed = false
		AudioManager.click())


func _setup_frame_rate() -> void:
	var box: OptionButton = $UI / Settings / Margin / Box / FrameRate
	box.clear()
	for label: String in GameSettings.FRAME_RATE_LABELS:
		box.add_item(label)
	box.select(GameSettings.frame_rate_index)
	box.item_selected.connect(func(index: int) -> void:
		GameSettings.set_frame_rate_index(index)
		AudioManager.click())


func _set_fullscreen(value: bool) -> void :
	$UI / Settings / Margin / Box / Fullscreen.text = "全屏：开" if value else "全屏：关"
	GameSettings.set_fullscreen(value)


func _set_bgm_volume(value: float) -> void :
	GameSettings.set_audio(value, GameSettings.sfx_volume, GameSettings.muted)
	$UI / Settings / Margin / Box / BgmLabel.text = "背景音乐  %d%%" % roundi(value * 100.0)


func _set_sfx_volume(value: float) -> void :
	GameSettings.set_audio(GameSettings.bgm_volume, value, GameSettings.muted)
	$UI / Settings / Margin / Box / SfxLabel.text = "操作音效  %d%%" % roundi(value * 100.0)
	AudioManager.click()

func _set_brightness(value: float) -> void :
	GameSettings.set_visual(value, GameSettings.contrast)
	$UI / Settings / Margin / Box / BrightnessLabel.text = "画面亮度  %d%%" % roundi(value * 100.0)

func _set_contrast(value: float) -> void :
	GameSettings.set_visual(GameSettings.brightness, value)
	$UI / Settings / Margin / Box / ContrastLabel.text = "画面对比度  %d%%" % roundi(value * 100.0)


func _set_reduce_motion(value: bool) -> void :
	GameSettings.set_reduce_motion(value)
	$UI / Settings / Margin / Box / ReduceMotion.text = "减少动态效果：开" if value else "减少动态效果：关"


func _restore_recommended_defaults() -> void :
	GameSettings.restore_recommended_defaults()
	$UI / Settings / Margin / Box / BgmSlider.value = GameSettings.bgm_volume
	$UI / Settings / Margin / Box / SfxSlider.value = GameSettings.sfx_volume
	$UI / Settings / Margin / Box / BrightnessSlider.value = GameSettings.brightness
	$UI / Settings / Margin / Box / ContrastSlider.value = GameSettings.contrast
	$UI / Settings / Margin / Box / AudioSwitches / MusicEnabled.button_pressed = GameSettings.music_enabled
	$UI / Settings / Margin / Box / AudioSwitches / SfxEnabled.button_pressed = GameSettings.sfx_enabled
	$UI / Settings / Margin / Box / AudioSwitches / AllMute.button_pressed = GameSettings.muted
	$UI / Settings / Margin / Box / Fullscreen.button_pressed = GameSettings.fullscreen
	$UI / Settings / Margin / Box / ReduceMotion.button_pressed = GameSettings.reduce_motion
	$UI / Settings / Margin / Box / Resolution.select(GameSettings.resolution_index)
	$UI / Settings / Margin / Box / FrameRate.select(GameSettings.frame_rate_index)
	_refresh_display_status(GameSettings.applied_resolution(), GameSettings.fullscreen)
	$UI / Settings / Margin / Box / RecommendedDefaults.text = "已恢复推荐设置"
	AudioManager.success()


func _refresh_display_status(_size: Vector2i, _fullscreen: bool) -> void :
	$UI / Settings / Margin / Box / DisplayStatus.text = "当前已应用：%s" % GameSettings.resolution_label()
	call_deferred("_apply_settings_scale")


func _apply_settings_scale() -> void :
	var viewport_size: = get_viewport().get_visible_rect().size
	var panel_size: = settings_panel.size
	var height_factor: = (viewport_size.y - 24.0) / maxf(1.0, panel_size.y)
	var width_factor: = (viewport_size.x - 24.0) / maxf(1.0, panel_size.x)
	var factor: = clampf(minf(height_factor, width_factor), 0.7, 1.0)
	settings_panel.pivot_offset = settings_panel.size * 0.5
	settings_panel.scale = Vector2.ONE * factor
	settings_panel.global_position = (viewport_size - settings_panel.size * factor) * 0.5


func _set_muted(value: bool) -> void :
	GameSettings.set_audio(GameSettings.bgm_volume, GameSettings.sfx_volume, value)
	$UI / Settings / Margin / Box / AudioSwitches / AllMute.text = "全部静音：开" if value else "全部静音：关"


func _set_music_enabled(value: bool) -> void :
	GameSettings.set_audio_switches(value, GameSettings.sfx_enabled)
	$UI / Settings / Margin / Box / AudioSwitches / MusicEnabled.text = "背景音乐：开" if value else "背景音乐：关"
	AudioManager.click()


func _set_sfx_enabled(value: bool) -> void :
	if not value:
		AudioManager.click()
	GameSettings.set_audio_switches(GameSettings.music_enabled, value)
	$UI / Settings / Margin / Box / AudioSwitches / SfxEnabled.text = "操作音效：开" if value else "操作音效：关"
	if value:
		AudioManager.success()


func _home_buttons() -> Array[Button]:
	return [new_game_button, tutorial_button, continue_button, collection_button, settings_button, quit_button]


func _style_home_menu_button(button: Button, primary: = false) -> void :
	button.add_theme_font_override("font", BODY_FONT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var accent: = Color("e5bd62") if primary else Color("8fc5cf")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		if state in ["hover", "focus"]:
			style.bg_color = Color(0.035, 0.15, 0.19, 0.78)
			style.border_width_left = 5
			style.border_color = accent
		elif state == "pressed":
			style.bg_color = Color(0.03, 0.11, 0.15, 0.9)
			style.border_width_left = 5
			style.border_color = accent.darkened(0.12)
		elif primary:
			style.bg_color = Color(0.15, 0.12, 0.035, 0.46)
			style.border_width_left = 5
			style.border_color = Color(accent, 0.92)
		if state == "disabled":
			style.bg_color = Color.TRANSPARENT
			style.border_width_left = 0
		style.set_corner_radius_all(4)
		style.content_margin_left = 22.0
		style.content_margin_right = 12.0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("ffe39a") if primary else Color("f4f8f7"))
	button.add_theme_color_override("font_hover_color", Color("fff0b8"))
	button.add_theme_color_override("font_focus_color", Color("fff0b8"))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.03, 0.86))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_disabled_color", Color("6e8290"))
	button.mouse_entered.connect( func() -> void :
		AudioManager.hover()
		_tween_home_button_offset(button, 7.0))
	button.mouse_exited.connect( func() -> void :
		_tween_home_button_offset(button, 0.0))
	button.button_down.connect( func() -> void :
		_tween_home_button_offset(button, 3.0))
	button.button_up.connect( func() -> void :
		_tween_home_button_offset(button, 7.0))


func _tween_home_button_offset(button: Button, offset: float) -> void :
	var base_x: = float(button.get_meta("home_base_x", 0.0))
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", base_x + offset, 0.12)


func _button_pulse(button: Button) -> void :
	_tween_scale(button, Vector2(1.08, 1.08))


func _tween_scale(button: Button, target: Vector2) -> void :
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target, 0.1)


func _style_settings_controls() -> void :
	$UI / Settings / Margin / Box.add_theme_constant_override("separation", 8)
	Styles.apply_labels($UI / Settings)
	$UI / Settings / Margin / Box / Title.add_theme_font_size_override("font_size", 32)
	$UI / Settings / Margin / Box / Title.add_theme_color_override("font_color", Styles.TOY_YELLOW)
	Styles.apply_slider($UI / Settings / Margin / Box / BgmSlider)
	Styles.apply_slider($UI / Settings / Margin / Box / SfxSlider)
	Styles.apply_slider($UI / Settings / Margin / Box / BrightnessSlider)
	Styles.apply_slider($UI / Settings / Margin / Box / ContrastSlider)
	Styles.apply_option_button($UI / Settings / Margin / Box / Resolution)
	Styles.apply_option_button($UI / Settings / Margin / Box / FrameRate)
	$UI / Settings / Margin / Box / DisplayStatus.add_theme_color_override("font_color", Color("9fb8c1"))
	for button in [
		$UI / Settings / Margin / Box / AudioSwitches / MusicEnabled, 
		$UI / Settings / Margin / Box / AudioSwitches / SfxEnabled, 
		$UI / Settings / Margin / Box / AudioSwitches / AllMute, 
		$UI / Settings / Margin / Box / Fullscreen, 
		$UI / Settings / Margin / Box / ReduceMotion, 
		$UI / Settings / Margin / Box / RecommendedDefaults, 
		$UI / Settings / Margin / Box / Close, 
	]:
		Styles.apply_button(button, button == $UI / Settings / Margin / Box / Close, Styles.TOY_YELLOW if button == $UI / Settings / Margin / Box / Close else Styles.TOY_BLUE, 19)
		button.custom_minimum_size = Vector2(0, 50)
		button.mouse_entered.connect(AudioManager.hover)
	$UI / Settings / Margin / Box / BgmSlider.value_changed.connect( func(value: float) -> void :
		$UI / Settings / Margin / Box / BgmLabel.text = "背景音乐  %d%%" % roundi(value * 100.0))
	$UI / Settings / Margin / Box / SfxSlider.value_changed.connect( func(value: float) -> void :
		$UI / Settings / Margin / Box / SfxLabel.text = "操作音效  %d%%" % roundi(value * 100.0))
