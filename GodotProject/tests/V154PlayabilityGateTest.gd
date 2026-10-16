extends Node

const Settlement = preload("res://scripts/TurnSettlement.gd")
const SYSTEMS: Array[Dictionary] = [
	{"name": "创投", "path": "res://scenes/StartupPitchEvent.tscn"},
	{"name": "人才", "path": "res://scenes/TalentMarket.tscn"},
	{"name": "证券", "path": "res://scenes/StockMarket.tscn"},
	{"name": "新闻", "path": "res://scenes/NewsCenter.tscn"},
	{"name": "银行", "path": "res://scenes/BankPanel.tscn"},
	{"name": "拍卖", "path": "res://scenes/AuctionPanel.tscn"},
	{"name": "资本市场", "path": "res://scenes/CapitalMarket.tscn"},
]

var passed := 0
var failed := 0


func _ready() -> void:
	GameFlow.suppress_background_preload_for_tests = true
	GameState.suppress_disk_save = true
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15499)
	GameState.begin_round()
	GameState.game_data.round = 2
	GameState.game_data.startup_schedule = [2]
	GameState.game_data.startup_offers = {}
	GameState.active_player().active_projects = ["legacy_project_id", null, 154, {"status": "active", "project_id": "legacy_valid", "remaining_rounds": 2}]
	GameState.normalize_compatible_state()
	_assert("旧存档创投数组会在进入城市前完成兼容清洗", GameState.active_player().active_projects.size() == 1 and GameState.active_player().active_projects[0] is Dictionary)
	await _frames(2)

	var packed := load("res://scenes/CityMap.tscn") as PackedScene
	var city := packed.instantiate() if packed != null else null
	if city != null:
		get_tree().root.add_child(city)
		get_tree().current_scene = city
	for _frame in range(300):
		await get_tree().process_frame
		if city != null and city.find_child("GameHUD", true, false) != null:
			break
	_assert("城市成熟界面完成初始化", city != null and city.find_child("GameHUD", true, false) != null)
	var original_city_id := city.get_instance_id() if city != null else 0
	var city_map := city.find_child("CommercialCityMap", true, false) if city != null else null
	var exchange_hit := city.find_child("CapitalExchangeHitArea", true, false) if city != null else null
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	# Reproduce the real navigation edge: the landmark opens on mouse-down, so
	# the city never receives the matching release event before it is suspended.
	if city != null:
		city.left_drag_candidate = true
		city.dragging = true
		city.last_mouse = Vector2(640, 360)
	if exchange_hit != null:
		exchange_hit.emit_signal("input_event", city.get_node("CameraRig/Camera3D"), click, Vector3.ZERO, Vector3.UP, 0)
	await _frames(5)
	var clicked_capital := get_tree().current_scene
	var clicked_opened := clicked_capital != null and str(clicked_capital.scene_file_path) == "res://scenes/CapitalMarket.tscn"
	_assert("点击资本交易中心可延迟打开资本市场", clicked_opened)
	_assert("点击资本交易中心后不是空白屏", clicked_opened and _visible_content_count(clicked_capital) >= 3)
	if clicked_opened:
		GameFlow.return_to_city(false)
		await _frames(5)
	_assert("资本市场返回后城市仍可复用", get_tree().current_scene == city and city.get_instance_id() == original_city_id)
	if city != null:
		var rig := city.get_node("CameraRig") as Node3D
		var position_before_motion := rig.position
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(710, 420)
		city.call("_unhandled_input", motion)
		_assert("资本市场返回后鼠标移动不会继续拖拽地图", rig.position.is_equal_approx(position_before_motion) and not city.dragging and not city.left_drag_candidate)
		rig.position.x = -500.0
		city.call("_clamp_camera_rig")
		_assert("拖向西岸后镜头限制保持有限且合法", is_finite(rig.position.x) and is_equal_approx(rig.position.x, -120.0))

	for cycle in range(3):
		for system: Dictionary in SYSTEMS:
			GameFlow.open_city_system(str(system.path), {"system": str(system.name), "gate_cycle": cycle})
			await _frames(5)
			var current := get_tree().current_scene
			var opened := current != null and str(current.scene_file_path) == str(system.path)
			_assert("循环%d %s场景可打开" % [cycle + 1, str(system.name)], opened)
			_assert("循环%d %s场景不是空白屏" % [cycle + 1, str(system.name)], opened and _visible_content_count(current) >= 3)
			if opened:
				GameFlow.return_to_city(false)
				await _frames(5)
			_assert("循环%d %s返回后复用城市" % [cycle + 1, str(system.name)], get_tree().current_scene == city and city != null and city.get_instance_id() == original_city_id)

	var modal_surface := Control.new()
	modal_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	city.add_child(modal_surface)
	var modal_token := ModalManager.open_modal("playability_gate", modal_surface, modal_surface)
	_assert("弹窗打开后正确阻止背景输入", modal_token > 0 and ModalManager.is_blocked())
	ModalManager.close_modal(modal_token, "gate_close")
	_assert("弹窗关闭后解除输入锁", not ModalManager.is_blocked() and ModalManager.active_id().is_empty())
	modal_surface.queue_free()
	await _frames(2)

	var settled_round := int(GameState.game_data.round)
	GameState.game_data.phase = "settlement"
	var report := Settlement.settle_round()
	var consistency := Settlement.report_consistency(report)
	_assert("回合结算账本保持一致", bool(consistency.get("ok", false)))
	GameFlow.open_round_summary()
	await _frames(8)
	var summary := get_tree().current_scene
	var summary_opened := summary != null and str(summary.scene_file_path).ends_with("TurnSummary.tscn")
	_assert("结算后经营战报可正常打开", summary_opened)
	_assert("经营战报不是空白屏", summary_opened and _visible_content_count(summary) >= 5)
	if summary_opened:
		GameFlow.return_to_city(true)
		await _frames(8)
	_assert("关闭战报后进入下一回合", get_tree().current_scene == city and int(GameState.game_data.round) == settled_round + 1 and str(GameState.game_data.phase) == "player_turn")
	var active_modal_id := ModalManager.active_id()
	var visible_modal_surface := false
	for value: Variant in get_tree().get_nodes_in_group("managed_modal_surface"):
		var surface := value as Control
		if surface != null and surface.is_inside_tree() and surface.is_visible_in_tree():
			visible_modal_surface = true
			break
	_assert("下一回合弹窗为可见可操作界面", not ModalManager.is_blocked() or (active_modal_id in ["event_card", "round_decision", "round_card_draft"] and visible_modal_surface))
	ModalManager.clear_all("playability_gate_cleanup")
	await _frames(2)
	_assert("关闭下一回合弹窗后无输入锁", not ModalManager.is_blocked())

	GameState.suppress_disk_save = false
	print("V154_PLAYABILITY_GATE passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _visible_content_count(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	for candidate: Node in root.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is Label and not (control as Label).text.strip_edges().is_empty():
			count += 1
		elif control is Button and not (control as Button).text.strip_edges().is_empty():
			count += 1
	return count


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
