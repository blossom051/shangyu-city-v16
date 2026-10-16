extends Node

var passed := 0
var failed := 0


func _ready() -> void:
	var had_settings_file := FileAccess.file_exists(GameSettings.SAVE_PATH)
	var original_settings_text := FileAccess.get_file_as_string(GameSettings.SAVE_PATH) if had_settings_file else ""
	var original_max_fps := Engine.max_fps
	_assert("提供帧率锁定公共接口", GameSettings.has_method("set_frame_rate_index"))
	if GameSettings.has_method("set_frame_rate_index"):
		GameSettings.call("set_frame_rate_index", 0)
		_assert("30 FPS 档真实限制引擎帧率", Engine.max_fps == 30)
		GameSettings.call("set_frame_rate_index", 1)
		_assert("60 FPS 档真实限制引擎帧率", Engine.max_fps == 60)
		GameSettings.call("set_frame_rate_index", 2)
		_assert("无限制档真实取消引擎上限", Engine.max_fps == 0)
		GameSettings.call("set_frame_rate_index", 1)
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameSettings.SAVE_PATH))
		_assert("帧率档位写入设置存档", saved is Dictionary and int(saved.get("frame_rate_index", -1)) == 1)
		var legacy_file := FileAccess.open(GameSettings.SAVE_PATH, FileAccess.WRITE)
		legacy_file.store_string(JSON.stringify({
			"display_profile_version": GameSettings.DISPLAY_PROFILE_VERSION,
			"audio_profile_version": GameSettings.AUDIO_PROFILE_VERSION,
			"visual_profile_version": GameSettings.VISUAL_PROFILE_VERSION,
			"motion_profile_version": GameSettings.MOTION_PROFILE_VERSION,
			"resolution_index": 1,
			"window_mode": "borderless",
			"ui_scale_index": 2,
			"brightness": 0.91,
			"contrast": 0.97,
		}))
		legacy_file = null
		GameSettings.frame_rate_index = 0
		GameSettings.load_from_disk()
		_assert("旧设置无帧率字段时保持无限制", GameSettings.frame_rate_index == GameSettings.DEFAULT_FRAME_RATE_INDEX)
		_assert("读取旧设置不改变原分辨率和窗口模式", GameSettings.resolution_index == 1 and GameSettings.window_mode == "borderless")
		GameSettings.set_frame_rate_index(0)
		GameSettings.restore_recommended_defaults()
		_assert("恢复推荐设置采用无限制", GameSettings.frame_rate_index == 2 and Engine.max_fps == 0)
	var main_menu: Node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(main_menu)
	await get_tree().process_frame
	var settings_box: Node = main_menu.get_node_or_null("UI/Settings/Margin/Box")
	var menu_frame_rate := settings_box.get_node_or_null("FrameRate") as OptionButton if settings_box != null else null
	_assert("主菜单提供三档帧率选项", menu_frame_rate != null and menu_frame_rate.item_count == 3)
	_assert("主菜单未加入垂直同步控件", settings_box != null and settings_box.get_node_or_null("VSync") == null)
	_assert("主菜单保留旧分辨率状态说明", settings_box != null and "当前已应用" in str((settings_box.get_node("DisplayStatus") as Label).text))
	main_menu.queue_free()
	var pause_overlay := CanvasLayer.new()
	pause_overlay.set_script(load("res://scripts/PauseOverlay.gd"))
	add_child(pause_overlay)
	await get_tree().process_frame
	var pause_frame_rate := pause_overlay.find_child("FrameRate", true, false) as OptionButton
	_assert("暂停菜单提供三档帧率选项", pause_frame_rate != null and pause_frame_rate.item_count == 3)
	_assert("暂停菜单未加入垂直同步控件", pause_overlay.find_child("VSync", true, false) == null)
	pause_overlay.queue_free()
	Engine.max_fps = original_max_fps
	_restore_settings_file(had_settings_file, original_settings_text)
	print("V155_MINIMAL_FRAME_CAP passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)


func _restore_settings_file(had_file: bool, contents: String) -> void:
	if had_file:
		var file := FileAccess.open(GameSettings.SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(contents)
	elif FileAccess.file_exists(GameSettings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.SAVE_PATH))
