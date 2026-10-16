extends Node

signal visual_changed(brightness: float, contrast: float)
signal motion_changed(reduce_motion: bool)
signal display_changed(size: Vector2i, fullscreen: bool)

const SAVE_PATH: = "user://v60d_settings.json"
const RESOLUTIONS: = [
	Vector2i(1280, 720), 
	Vector2i(1366, 768), 
	Vector2i(1600, 900), 
	Vector2i(1920, 1080), 
	Vector2i(2560, 1440), 
]
const WINDOW_MODES: = ["windowed", "borderless", "fullscreen"]
const WINDOW_MODE_LABELS: = ["窗口模式", "无边框窗口", "全屏模式"]
const UI_SCALES: = [0.85, 1.0, 1.1, 1.25]
const UI_SCALE_LABELS: = ["85%（紧凑）", "100%（推荐）", "110%（较大）", "125%（大字）"]
const FRAME_RATE_LIMITS: = [30, 60, 0]
const FRAME_RATE_LABELS: = ["30 FPS（低配推荐）", "60 FPS", "无限制"]
const DISPLAY_PROFILE_VERSION: = 2
const VISUAL_PROFILE_VERSION: = 3
const AUDIO_PROFILE_VERSION: = 4
const MOTION_PROFILE_VERSION: = 2
const DEFAULT_BRIGHTNESS: = 0.94
const DEFAULT_CONTRAST: = 0.98
const DEFAULT_RESOLUTION_INDEX: = 3
const DEFAULT_WINDOW_MODE: = "windowed"
const DEFAULT_UI_SCALE_INDEX: = 1
const DEFAULT_FRAME_RATE_INDEX: = 2
const DEFAULT_BGM_VOLUME: = 0.24
const DEFAULT_SFX_VOLUME: = 0.18

var resolution_index: = 3
var window_mode: = "windowed"
var ui_scale_index: = 1
var frame_rate_index: = DEFAULT_FRAME_RATE_INDEX
var fullscreen: = false
var bgm_volume: = DEFAULT_BGM_VOLUME
var sfx_volume: = DEFAULT_SFX_VOLUME
var muted: = false
var music_enabled: = true
var sfx_enabled: = true
var brightness: = DEFAULT_BRIGHTNESS
var contrast: = DEFAULT_CONTRAST
var visual_profile_version: = VISUAL_PROFILE_VERSION
var motion_profile_version: = MOTION_PROFILE_VERSION
var reduce_motion: = false
var tutorial_completed: = false


func _ready() -> void :
	load_from_disk()
	call_deferred("apply")


func apply() -> void :
	AudioManager.set_bgm_volume(bgm_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	AudioManager.set_muted(muted)
	AudioManager.set_music_enabled(music_enabled)
	AudioManager.set_sfx_enabled(sfx_enabled)
	_apply_window_mode()
	_apply_ui_scale()
	_apply_frame_rate()
	visual_changed.emit(brightness, contrast)
	motion_changed.emit(reduce_motion)
	display_changed.emit(applied_resolution(), fullscreen)


func display_options_profile() -> Dictionary:
	return {
		"resolution_count": RESOLUTIONS.size(), 
		"window_mode_count": WINDOW_MODES.size(), 
		"ui_scale_count": UI_SCALES.size(), 
		"frame_rate_count": FRAME_RATE_LIMITS.size(),
	}


func set_resolution_index(index: int) -> void :
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)

	if window_mode != "windowed":
		window_mode = "windowed"
		fullscreen = false
	_apply_window_mode()
	display_changed.emit(applied_resolution(), fullscreen)
	save_now()


func set_window_mode(index: int) -> void :
	window_mode = WINDOW_MODES[clampi(index, 0, WINDOW_MODES.size() - 1)]
	fullscreen = window_mode == "fullscreen"
	_apply_window_mode()
	display_changed.emit(applied_resolution(), fullscreen)
	save_now()


func set_fullscreen(value: bool) -> void :

	set_window_mode(2 if value else 0)


func set_ui_scale_index(index: int) -> void :
	ui_scale_index = clampi(index, 0, UI_SCALES.size() - 1)
	_apply_ui_scale()
	display_changed.emit(applied_resolution(), fullscreen)
	save_now()


func set_frame_rate_index(index: int) -> void:
	frame_rate_index = clampi(index, 0, FRAME_RATE_LIMITS.size() - 1)
	_apply_frame_rate()
	save_now()


func set_audio(bgm: float, sfx: float, is_muted: bool) -> void :
	bgm_volume = clampf(bgm, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	muted = is_muted
	AudioManager.set_bgm_volume(bgm_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	AudioManager.set_muted(muted)
	save_now()


func set_audio_switches(enable_music: bool, enable_sfx: bool) -> void :
	music_enabled = enable_music
	sfx_enabled = enable_sfx
	AudioManager.set_music_enabled(music_enabled)
	AudioManager.set_sfx_enabled(sfx_enabled)
	save_now()


func set_visual(next_brightness: float, next_contrast: float) -> void :
	brightness = clampf(next_brightness, 0.62, 1.0)
	contrast = clampf(next_contrast, 0.78, 1.08)
	visual_changed.emit(brightness, contrast)
	save_now()


func visual_profile() -> Dictionary:
	return {"version": VISUAL_PROFILE_VERSION, "default_brightness": DEFAULT_BRIGHTNESS, "default_contrast": DEFAULT_CONTRAST}


func recommended_defaults_profile() -> Dictionary:
	return {
		"bgm_volume": DEFAULT_BGM_VOLUME, 
		"sfx_volume": DEFAULT_SFX_VOLUME, 
		"reduce_motion": false, 
		"brightness": DEFAULT_BRIGHTNESS, 
		"contrast": DEFAULT_CONTRAST, 
		"frame_rate_index": DEFAULT_FRAME_RATE_INDEX,
	}


func restore_recommended_defaults() -> Dictionary:
	var keep_tutorial_completed: = tutorial_completed
	resolution_index = DEFAULT_RESOLUTION_INDEX
	window_mode = DEFAULT_WINDOW_MODE
	ui_scale_index = DEFAULT_UI_SCALE_INDEX
	frame_rate_index = DEFAULT_FRAME_RATE_INDEX
	fullscreen = false
	bgm_volume = DEFAULT_BGM_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	muted = false
	music_enabled = true
	sfx_enabled = true
	brightness = DEFAULT_BRIGHTNESS
	contrast = DEFAULT_CONTRAST
	reduce_motion = false
	visual_profile_version = VISUAL_PROFILE_VERSION
	tutorial_completed = keep_tutorial_completed
	apply()
	save_now()
	return {
		"resolution_index": resolution_index, 
		"window_mode": window_mode, 
		"ui_scale_index": ui_scale_index, 
		"frame_rate_index": frame_rate_index,
		"brightness": brightness, 
		"contrast": contrast, 
		"bgm_volume": bgm_volume, 
		"sfx_volume": sfx_volume, 
	}


func set_reduce_motion(value: bool) -> void :
	reduce_motion = value
	motion_changed.emit(reduce_motion)
	save_now()


func set_tutorial_completed(value: bool) -> void :
	tutorial_completed = value
	save_now()


func applied_resolution() -> Vector2i:
	return DisplayServer.window_get_size()


func resolution_label() -> String:
	var size: = applied_resolution()
	var mode_index: = WINDOW_MODES.find(window_mode)
	var mode_label: String = str(WINDOW_MODE_LABELS[maxi(0, mode_index)])
	return "%d × %d  %s  UI %d%%" % [size.x, size.y, mode_label, roundi(UI_SCALES[ui_scale_index] * 100.0)]


func _apply_window_mode() -> void :
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen: = DisplayServer.window_get_current_screen()
			var rect: = DisplayServer.screen_get_usable_rect(screen)
			DisplayServer.window_set_position(rect.position)
			DisplayServer.window_set_size(rect.size)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
			call_deferred("_center_window")


func _apply_ui_scale() -> void :
	if get_tree() != null and get_tree().root != null:
		get_tree().root.content_scale_factor = UI_SCALES[ui_scale_index]


func _apply_frame_rate() -> void:
	Engine.max_fps = int(FRAME_RATE_LIMITS[frame_rate_index])


func _center_window() -> void :
	if window_mode != "windowed" or DisplayServer.get_name() == "headless":
		return
	var screen: = DisplayServer.window_get_current_screen()
	var screen_position: = DisplayServer.screen_get_position(screen)
	var screen_size: = DisplayServer.screen_get_usable_rect(screen).size
	var window_size: = DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_position + (screen_size - window_size) / 2)


func save_now() -> void :
	var file: = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"display_profile_version": DISPLAY_PROFILE_VERSION, 
			"audio_profile_version": AUDIO_PROFILE_VERSION, 
			"resolution_index": resolution_index, 
			"window_mode": window_mode, 
			"ui_scale_index": ui_scale_index, 
			"frame_rate_index": frame_rate_index,
			"fullscreen": fullscreen, 
			"bgm_volume": bgm_volume, 
			"sfx_volume": sfx_volume, 
			"muted": muted, 
			"music_enabled": music_enabled, 
			"sfx_enabled": sfx_enabled, 
			"brightness": brightness, 
			"contrast": contrast, 
			"visual_profile_version": visual_profile_version, 
			"motion_profile_version": MOTION_PROFILE_VERSION, 
			"reduce_motion": reduce_motion, 
			"tutorial_completed": tutorial_completed, 
		}))


func load_from_disk() -> void :
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var saved_resolution_index: = int(parsed.get("resolution_index", resolution_index))
	if int(parsed.get("display_profile_version", 0)) < DISPLAY_PROFILE_VERSION:

		saved_resolution_index = int({0: 1, 1: 3, 2: 4}.get(saved_resolution_index, 3))
	resolution_index = clampi(saved_resolution_index, 0, RESOLUTIONS.size() - 1)
	if parsed.has("window_mode"):
		window_mode = str(parsed.get("window_mode", window_mode))
	else:
		window_mode = "fullscreen" if bool(parsed.get("fullscreen", false)) else "windowed"
	if not window_mode in WINDOW_MODES:
		window_mode = "windowed"
	fullscreen = window_mode == "fullscreen"
	ui_scale_index = clampi(int(parsed.get("ui_scale_index", ui_scale_index)), 0, UI_SCALES.size() - 1)
	frame_rate_index = clampi(int(parsed.get("frame_rate_index", DEFAULT_FRAME_RATE_INDEX)), 0, FRAME_RATE_LIMITS.size() - 1)
	bgm_volume = clampf(float(parsed.get("bgm_volume", bgm_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	if int(parsed.get("audio_profile_version", 0)) < AUDIO_PROFILE_VERSION:

		bgm_volume = DEFAULT_BGM_VOLUME
		sfx_volume = DEFAULT_SFX_VOLUME
	muted = bool(parsed.get("muted", muted))
	music_enabled = bool(parsed.get("music_enabled", music_enabled))
	sfx_enabled = bool(parsed.get("sfx_enabled", sfx_enabled))
	var saved_visual_version: = int(parsed.get("visual_profile_version", 0))
	brightness = clampf(float(parsed.get("brightness", brightness)), 0.62, 1.0)
	contrast = clampf(float(parsed.get("contrast", contrast)), 0.78, 1.08)
	if saved_visual_version < VISUAL_PROFILE_VERSION:
		brightness = maxf(brightness, 0.92)
		contrast = maxf(contrast, 0.96)
	visual_profile_version = VISUAL_PROFILE_VERSION
	var saved_motion_version: = int(parsed.get("motion_profile_version", 0))
	reduce_motion = bool(parsed.get("reduce_motion", reduce_motion))
	if saved_motion_version < MOTION_PROFILE_VERSION:


		reduce_motion = false
	motion_profile_version = MOTION_PROFILE_VERSION
	tutorial_completed = bool(parsed.get("tutorial_completed", tutorial_completed))
	if saved_motion_version < MOTION_PROFILE_VERSION:
		save_now()
