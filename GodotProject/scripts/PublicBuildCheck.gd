extends Node

var failures: int = 0
var output: String = ""

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--public-build-check"): call_deferred("run_checks")
	if OS.get_cmdline_user_args().has("--public-save-write") or OS.get_cmdline_user_args().has("--public-save-read"):
		call_deferred("run_save_check")

func run_save_check() -> void:
	var folder: String = OS.get_environment("SHANGYU_QA_OUTPUT")
	if folder.is_empty(): get_tree().quit(2); return
	var state: Node = get_tree().root.get_node("GameState")
	var slots: Node = get_tree().root.get_node("SaveSlots")
	state.suppress_disk_save = true
	get_tree().root.get_node("GameFlow").suppress_background_preload_for_tests = true
	slots.configure_paths_for_tests(folder.path_join("save-test"), folder.path_join("test-legacy.json"))
	if OS.get_cmdline_user_args().has("--public-save-write"):
		var players: Array[Dictionary] = [{"company_id": "hengyue", "human": true}]
		state.start_match("solo", 0, players, 16016)
		state.game_data.round = 7
		state.player("p1").cash = 1234
		check("cold save write", bool(slots.save_manual(8, "Public build test", state.snapshot()).get("ok", false)))
	else:
		check("cold save read", bool(state.load_from_slot("slot_08").get("ok", false)))
		check("cold save values", int(state.game_data.get("round", 0)) == 7 and int(state.player("p1").get("cash", 0)) == 1234)
	print("PUBLIC_SAVE failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func check(label: String, success: bool) -> void:
	print(("PASS " if success else "FAIL ") + label)
	if not success: failures += 1

func capture(label: String) -> void:
	for i in range(15): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(label + " screenshot", get_tree().root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func run_checks() -> void:
	output = OS.get_environment("SHANGYU_QA_OUTPUT")
	if output.is_empty(): get_tree().quit(2); return
	var audio: Node = get_tree().root.get_node("AudioManager")
	check("empty default playlist", audio.BGM_TRACKS.is_empty())
	audio.play_random_bgm()
	audio.sync_city_time(0.5)
	audio._switch_bgm_index(0)
	audio.set_music_enabled(false)
	audio.set_music_enabled(true)
	audio.set_muted(true)
	audio.set_muted(false)
	check("no music playing", not audio.audio_state_profile().music_playing)
	var gs: Node = get_tree().root.get_node("GameState")
	gs.suppress_disk_save = true
	get_tree().root.get_node("GameFlow").suppress_background_preload_for_tests = true
	await get_tree().create_timer(2.0).timeout
	await capture("main-menu")
	check("main menu loaded", get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("MainMenu.tscn"))
	get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
	await get_tree().create_timer(1.0).timeout
	await capture("mode-select")
	var companies: Array[Dictionary] = [{"company_id": "hengyue", "human": true}]
	gs.start_match("solo", 0, companies, 16016)
	gs.begin_round()
	get_tree().change_scene_to_file("res://scenes/CityMap.tscn")
	await get_tree().create_timer(8.0).timeout
	await capture("city")
	check("city HUD loaded", get_tree().current_scene != null and get_tree().current_scene.find_child("GameHUD", true, false) != null)
	var has_mp3: bool = false
	for file: String in DirAccess.get_files_at("res://assets/audio/generated"):
		if file.to_lower().contains("mp3"): has_mp3 = true
	check("no bundled MP3", not has_mp3)
	# External music uses a synthetic test tone; it is never included in the release.
	audio._load_custom_music(output.path_join("music-fixture"))
	check("external track loaded", audio.BGM_TRACKS.size() == 1)
	if audio.BGM_TRACKS.size() == 1:
		audio.select_bgm(str(audio.BGM_TRACKS[0].id))
		check("external track playing", audio.audio_state_profile().music_playing)
		audio.set_muted(true)
		check("mute stops external music", not audio.audio_state_profile().music_playing)
		audio.set_muted(false)
		check("unmute resumes external music", audio.audio_state_profile().music_playing)
	print("PUBLIC_RUNTIME failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
