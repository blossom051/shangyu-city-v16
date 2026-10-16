extends Node

signal scene_requested(path: String)

const PauseOverlayScript = preload("res://scripts/PauseOverlay.gd")
const SceneTransitionLayerScript = preload("res://scripts/SceneTransitionLayer.gd")
const ModePolicy = preload("res://scripts/GameModePolicy.gd")

const SCENES: = {
	"menu": "res://scenes/MainMenu.tscn", 
	"collection": "res://scenes/CardCollectionGallery.tscn", 
	"mode": "res://scenes/ModeSelect.tscn", 
	"company": "res://scenes/CompanySelect.tscn", 
	"opening_cards": "res://scenes/CardDrawScene.tscn", 
	"city": "res://scenes/CityMap.tscn", 
	"summary": "res://scenes/TurnSummary.tscn", 
	"final": "res://scenes/FinalResult.tscn", 
}

var setup: = {"mode": "solo", "rounds": 12, "player_count": 1, "ai_difficulty": "standard", "selections": []}
var pause_overlay: CanvasLayer
var transition_layer: CanvasLayer
var prepared_scenes: Dictionary = {}
var prepared_scene_resources: Dictionary = {}
var suppress_background_preload_for_tests: = false
var transition_active: = false
var transition_key: = ""
var transition_state: = {
	"preload_requested": false, 
	"feedback_visible": false, 
	"staged_initialization": true, 
	"input_ready": false, 
}
var suspended_city: Node
var suspended_city_context: Dictionary = {}
var navigation_metrics: = {
	"city_instance_id": 0, 
	"last_return_msec": 0, 
	"resume_count": 0, 
	"reused_city": false, 
}


func _ready() -> void :
	pause_overlay = PauseOverlayScript.new()
	transition_layer = SceneTransitionLayerScript.new()
	transition_layer.name = "SceneTransitionLayer"
	call_deferred("_attach_global_overlays")


func _attach_global_overlays() -> void :
	if pause_overlay != null and pause_overlay.get_parent() == null:
		get_tree().root.add_child(pause_overlay)
	if transition_layer != null and transition_layer.get_parent() == null:
		get_tree().root.add_child(transition_layer)


func _unhandled_input(event: InputEvent) -> void :
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	var current: = get_tree().current_scene
	if current != null and current.scene_file_path.ends_with("MainMenu.tscn"):
		return
	if pause_overlay == null:
		return
	var tutorial_director: = get_node_or_null("/root/TutorialDirector")
	if tutorial_director != null and bool(tutorial_director.get("active")):
		tutorial_director.call("request_exit_confirmation")
		get_viewport().set_input_as_handled()
		return
	if pause_overlay.visible:
		pause_overlay.hide_menu()
	else:
		pause_overlay.show_menu()
	get_viewport().set_input_as_handled()

func go(key: String) -> void :
	var path: = str(SCENES.get(key, ""))
	if path.is_empty():
		return
	if key == "city" and is_instance_valid(suspended_city):
		return_to_city(false)
		return
	if key in ["menu", "collection", "mode", "company", "opening_cards", "final"]:
		_dispose_suspended_city()
	var music_snapshot: Dictionary = AudioManager.capture_music_continuity() if key in ["menu", "collection"] else {}
	scene_requested.emit(path)
	get_tree().change_scene_to_file(path)
	if not music_snapshot.is_empty():
		call_deferred("_restore_frontend_music", music_snapshot)


func _restore_frontend_music(snapshot: Dictionary) -> void :
	await get_tree().process_frame
	await get_tree().process_frame
	AudioManager.restore_music_continuity(snapshot)


func suspend_city_for_navigation(context: = {}) -> bool:
	if is_instance_valid(suspended_city):
		suspended_city_context.merge(context, true)
		return true
	var current: = get_tree().current_scene
	if current == null or not str(current.scene_file_path).ends_with("CityMap.tscn"):
		return false
	ModalManager.clear_all("city_navigation")
	if current.has_method("suspend_for_navigation"):
		current.call("suspend_for_navigation")
	suspended_city = current
	suspended_city_context = context.duplicate(true)
	navigation_metrics.city_instance_id = current.get_instance_id()
	get_tree().current_scene = null
	get_tree().root.remove_child(current)
	return true


func open_city_system(path: String, context: = {}) -> void :
	var packed := load(path) as PackedScene
	if packed == null:
		_navigation_failed("系统界面暂时无法打开", path)
		return
	var next := packed.instantiate()
	if next == null:
		_navigation_failed("系统界面初始化失败", path)
		return
	var next_context: Dictionary = context.duplicate(true)
	next_context["path"] = path
	next_context["kind"] = "system"
	if not suspend_city_for_navigation(next_context):
		next.free()
		_navigation_failed("当前城市状态无法切换", path)
		return
	_commit_transient_scene(next, path)


func open_round_summary() -> void :
	var path := str(SCENES.summary)
	var packed := load(path) as PackedScene
	if packed == null:
		_navigation_failed("经营战报暂时无法打开", path)
		return
	var next := packed.instantiate()
	if next == null:
		_navigation_failed("经营战报初始化失败", path)
		return
	if not suspend_city_for_navigation({"kind": "round_summary"}):
		next.free()
		_navigation_failed("当前城市状态无法切换", path)
		return
	_commit_transient_scene(next, path)


func return_to_city(begin_next_round: = false) -> void :
	if not is_instance_valid(suspended_city):
		if begin_next_round:
			GameState.begin_round()
		go("city")
		return
	var started: = Time.get_ticks_msec()
	ModalManager.clear_all("return_to_city")
	var current: = get_tree().current_scene
	if current != null and current != suspended_city:
		get_tree().current_scene = null
		if current.get_parent() != null:
			current.queue_free()
		else:
			current.free()
	if begin_next_round:
		GameState.begin_round()
	var city: = suspended_city
	suspended_city = null
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	scene_requested.emit(str(SCENES.city))
	var context: = suspended_city_context.duplicate(true)
	suspended_city_context.clear()
	if city.has_method("resume_from_navigation"):
		city.call("resume_from_navigation", context)
	navigation_metrics.last_return_msec = Time.get_ticks_msec() - started
	navigation_metrics.resume_count = int(navigation_metrics.get("resume_count", 0)) + 1
	navigation_metrics.reused_city = int(navigation_metrics.get("city_instance_id", 0)) == city.get_instance_id()


func city_lifecycle_profile() -> Dictionary:
	var profile: = navigation_metrics.duplicate(true)
	profile["suspended"] = is_instance_valid(suspended_city)
	return profile


func _replace_transient_scene(path: String) -> void :
	var packed: = load(path) as PackedScene
	if packed == null:
		_navigation_failed("界面资源加载失败", path)
		return
	var next := packed.instantiate()
	if next == null:
		_navigation_failed("界面初始化失败", path)
		return
	_commit_transient_scene(next, path)


func _commit_transient_scene(next: Node, path: String) -> void:
	var current: = get_tree().current_scene
	if current != null and current != suspended_city:
		get_tree().current_scene = null
		if current.get_parent() != null:
			current.queue_free()
		else:
			current.free()
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	scene_requested.emit(path)


func _navigation_failed(message: String, path: String) -> void:
	push_error("%s: %s" % [message, path])
	var current := get_tree().current_scene
	if current != null:
		var toast := current.get_node_or_null("UI/Toast") as Label
		if toast != null:
			toast.text = message


func _dispose_suspended_city() -> void :
	if not is_instance_valid(suspended_city):
		suspended_city = null
		suspended_city_context.clear()
		return
	if suspended_city.get_parent() != null:
		suspended_city.get_parent().remove_child(suspended_city)
	suspended_city.free()
	suspended_city = null
	suspended_city_context.clear()


func prepare_scene(key: String) -> void :
	if suppress_background_preload_for_tests:
		return
	var path: = str(SCENES.get(key, ""))
	if path.is_empty() or prepared_scenes.has(key) or prepared_scene_resources.has(key):
		return


	var error: = ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if error == OK or error == ERR_BUSY:
		prepared_scenes[key] = path
		if key == "city":
			transition_state.preload_requested = true


func transition_profile() -> Dictionary:
	return transition_state.duplicate(true)


func go_smooth(key: String, prepare_round: = false) -> void :
	if transition_active:
		return
	if transition_layer != null and transition_layer.get_parent() == null:
		get_tree().root.add_child(transition_layer)
	prepare_scene(key)
	transition_active = true
	transition_key = key
	transition_state.feedback_visible = true
	transition_state.input_ready = false
	transition_state.staged_initialization = key == "city"
	if transition_layer != null:
		transition_layer.call("begin", {
			"mode": "开启资本竞赛配置", 
			"company": "调取董事会签约档案", 
			"city": "驶入城市经营区", 
		}.get(key, "资本网络正在切换"))
	call_deferred("_complete_smooth_transition", key, prepare_round)


func _complete_smooth_transition(key: String, prepare_round: bool) -> void :
	var stages: Array[String] = []
	if key == "mode":
		stages.assign(["建立赛制档案", "载入董事席位", "开启竞赛配置", "界面准备就绪"])
	else:
		stages.assign(["生成首轮城市局势", "预载城市经营资源", "铺设经营地块", "点亮城市经营界面"])
	await get_tree().process_frame
	if transition_layer != null:
		transition_layer.call("set_stage", stages[0], 28.0)
	if prepare_round:
		GameState.begin_round()
	await get_tree().process_frame
	if transition_layer != null:
		transition_layer.call("set_stage", stages[1], 42.0)
	var packed: = await _prepared_scene(key)
	if packed == null:
		if transition_layer != null:
			transition_layer.call("force_hide")
		transition_active = false
		transition_key = ""
		transition_state.feedback_visible = false
		go(key)
		return
	if transition_layer != null:
		transition_layer.call("set_stage", stages[2], 74.0)
	await get_tree().process_frame
	if transition_layer != null:
		transition_layer.call("set_stage", stages[3], 88.0)
	get_tree().change_scene_to_packed(packed)
	if key != "city":
		notify_scene_input_ready(key)


func _prepared_scene(key: String) -> PackedScene:
	if prepared_scene_resources.has(key):
		return prepared_scene_resources[key] as PackedScene
	var path: = str(prepared_scenes.get(key, SCENES.get(key, "")))
	if path.is_empty():
		return null
	var progress: Array = []
	var status: = ResourceLoader.load_threaded_get_status(path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if transition_layer != null and not progress.is_empty():
			transition_layer.call("set_stage", "预载城市经营资源", 28.0 + float(progress[0]) * 38.0)
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path, progress)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	var packed: = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed != null:
		prepared_scene_resources[key] = packed
	return packed


func notify_scene_input_ready(key: String) -> void :
	if not transition_active or key != transition_key:
		return
	transition_state.input_ready = true
	if transition_layer != null:
		transition_layer.call("finish")
	transition_active = false
	transition_key = ""
	call_deferred("_mark_transition_feedback_hidden")


func _mark_transition_feedback_hidden() -> void :
	while transition_layer != null and transition_layer.visible:
		await get_tree().process_frame
	transition_state.feedback_visible = false


func resume_loaded_match() -> void :
	var phase: = str(GameState.game_data.get("phase", ""))
	match phase:
		"opening_cards":
			go("opening_cards")
		"settlement":
			go("summary")
		"finished":
			go("final")
		_:
			go("city")

func configure(mode: String, rounds: int, player_count: int, ai_difficulty: String = "standard") -> void :
	setup.mode = ModePolicy.normalize_mode(mode)
	setup.rounds = rounds
	setup.player_count = ModePolicy.normalized_player_count(str(setup.mode), player_count)
	setup.ai_difficulty = load("res://scripts/AIDifficultyPolicy.gd").normalize(ai_difficulty)
	setup.selections = []

func confirm_companies(selections: Array[Dictionary]) -> void :
	setup.selections = selections
	GameState.start_match(str(setup.mode), int(setup.rounds), selections, 6007, str(setup.ai_difficulty))
	go("opening_cards")

func finish_opening() -> void :
	go_smooth("city", true)
