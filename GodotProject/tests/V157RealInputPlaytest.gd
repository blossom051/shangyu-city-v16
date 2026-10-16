extends Node

const Cards = preload("res://scripts/CardSystem.gd")
const CardDraftDialog = preload("res://scripts/RoundCardDraftDialog.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const Authority = preload("res://scripts/HumanTurnAuthority.gd")
const RoundDecisions = preload("res://scripts/RoundDecisionSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameFlow.suppress_background_preload_for_tests = true
	GameState.suppress_disk_save = true
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().size = Vector2i(1920, 1080)
	await _frames(3)
	_prepare_game()
	ModalManager.clear_all("real_input_playtest_setup")
	var city := await _spawn_city()
	_assert("真实输入试玩：城市完整加载", city != null and city.find_child("GameHUD", true, false) != null)
	if city == null:
		_finish()
		return

	var startup_button := _button_with_text(city, "创投")
	print("[REAL-INPUT] pre-startup event_round=%s round=%s schedule=%s authority=%s pending=%s modal=%s" % [Startups.is_event_round(), GameState.game_data.round, GameState.game_data.startup_schedule, Authority.check(GameState.game_data, bool(city.get("ai_sequence_running"))), RoundDecisions.pending(str(GameState.active_player().get("id", ""))), ModalManager.is_blocked()])
	await _real_click(startup_button)
	print("[REAL-INPUT] post-startup scene=%s toast=%s" % [str(get_tree().current_scene.scene_file_path) if get_tree().current_scene != null else "none", str(city.get_node("UI/Toast").text)])
	await _wait_for_scene("res://scenes/StartupPitchEvent.tscn", 120)
	var startup := get_tree().current_scene
	var startup_opened := startup != null and str(startup.scene_file_path) == "res://scenes/StartupPitchEvent.tscn" and _visible_content_count(startup) >= 3
	_assert("真实鼠标点击创投后打开项目页且不是蓝屏", startup_opened)
	var project_card: Button = null
	if startup != null:
		for candidate: Button in startup.find_children("*", "Button", true, false):
			if candidate.get_script() == load("res://scripts/StartupProjectCard.gd") and candidate.is_visible_in_tree():
				project_card = candidate
				break
	await _real_click(project_card)
	await _frames(5)
	var decline := _button_with_text(startup, "暂不投资") if startup_opened else null
	var confirmation_opened := startup_opened and decline != null and decline.is_visible_in_tree()
	_assert("真实鼠标点击项目后出现二次确认", confirmation_opened)
	await _real_click(decline)
	await _frames(5)
	_assert("真实鼠标点击暂不投资后项目页仍可见", confirmation_opened and get_tree().current_scene == startup and startup.is_visible_in_tree() and _visible_content_count(startup) >= 3)
	await _real_click(_button_with_text(startup, "返回城市"))
	await _wait_for_scene("res://scenes/CityMap.tscn", 120)
	_assert("真实鼠标点击返回后复用城市", get_tree().current_scene == city and city.is_visible_in_tree())

	city.call("_on_district_legend_pressed", "west_finance")
	await _frames(120)
	var hit := city.find_child("CapitalExchangeHitArea", true, false) as Area3D
	var camera := city.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var hit_shape := hit.get_child(0) as CollisionShape3D if hit != null and hit.get_child_count() > 0 else null
	print("[REAL-INPUT] capital hit=%s shape=%s camera=%s" % [str(hit), str(hit_shape), str(camera)])
	var exchange_screen := camera.unproject_position(hit_shape.global_position) if camera != null and hit_shape != null else Vector2(-1, -1)
	await _real_pointer_click(exchange_screen)
	await _wait_for_scene("res://scenes/CapitalMarket.tscn", 180)
	var capital := get_tree().current_scene
	_assert("真实3D点击资本中心后打开市场且不是空屏", capital != null and str(capital.scene_file_path) == "res://scenes/CapitalMarket.tscn" and _visible_content_count(capital) >= 3)
	await _real_click(_button_with_text(capital, "返回城市"))
	await _wait_for_scene("res://scenes/CityMap.tscn", 120)
	_assert("真实点击资本市场返回后城市可继续操作", get_tree().current_scene == city and not bool(city.get("dragging")) and not bool(city.get("left_drag_candidate")))

	var rig := city.get_node_or_null("CameraRig") as Node3D
	var drag_start := Vector2(960, 560)
	var drag_end := Vector2(1500, 560)
	await _real_drag(drag_start, drag_end)
	await _frames(6)
	_assert("真实鼠标拖动西岸不会闪退且镜头保持有限", get_tree().current_scene == city and rig != null and is_finite(rig.position.x) and rig.position.x >= -120.0 and rig.position.x <= 24.0)

	var player := GameState.active_player()
	var initial_hand: int = player.get("hand", []).size()
	Cards.create_round_offer(str(player.id), 5)
	var old_ok := await _play_draft_with_real_clicks(city, "old_city")
	var west_ok := await _play_draft_with_real_clicks(city, "west_bank")
	_assert("真实点击完成原城区五选一与西岸五选一", old_ok and west_ok and player.get("hand", []).size() == initial_hand + 2 and Cards.round_offer(str(player.id)).is_empty())

	var settlement_ok := true
	for index in range(5):
		GameState.game_data.phase = "settlement"
		var report := Settlement.settle_round()
		var audit := Settlement.report_consistency(report)
		settlement_ok = settlement_ok and bool(audit.get("ok", false))
		GameState.game_data.round = int(GameState.game_data.round) + 1
	_assert("连续5轮结算账本无计算错误或中断", settlement_ok)
	_finish()


func _prepare_game() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15701)
	var player := GameState.game_data.players[0] as Dictionary
	GameState.game_data.turn_order = [str(player.get("id", "p1"))]
	GameState.game_data.active_order_index = 0
	player.cash = 12000
	player.asset_value = 6000
	player.risk = 20
	GameState.game_data.round = 16
	GameState.game_data.phase = "player_turn"
	GameState.game_data.startup_schedule = [16]
	GameState.game_data.startup_offers = {}
	GameState.game_data.round_card_offers = {}
	GameState.game_data.west_round_card_offers = {}
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "REAL-CLICK-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.get("id", "p1"))
		land.asset_state = "OWNED"
		land.state = "operating"
		land.acquired_round = 1
		land.business_id = business_id
		player.land_ids.append(land_id)
		player.business_ids.append(business_id)
		var type_id := "investment_bank_hq" if land_id in ["L29", "L30"] else "financial_office"
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.get("id", "p1")), "land_id": land_id, "name": "真实试玩企业%d" % index, "type_id": type_id, "state": "operating", "operating_since_round": 1, "value": 900, "employees": ["", ""], "mortgaged": false, "effects": []}


func _spawn_city() -> Node:
	var packed := load("res://scenes/CityMap.tscn") as PackedScene
	var city := packed.instantiate() if packed != null else null
	if city != null:
		get_tree().root.call_deferred("add_child", city)
		await get_tree().process_frame
		get_tree().current_scene = city
	for _frame in range(600):
		await get_tree().process_frame
		var startup := city.get_node_or_null("UI/Bottom/Actions/Startup") as Button if city != null else null
		if city != null and city.find_child("GameHUD", true, false) != null and bool(city.get("city_visuals_initialized")) and bool(city.get("city_intro_complete")) and startup != null and startup.pressed.get_connections().size() > 0:
			break
	return city


func _play_draft_with_real_clicks(city: Node, expected_kind: String) -> bool:
	if Cards.round_offer_kind(str(GameState.active_player().id)) != expected_kind:
		return false
	var dialog := CardDraftDialog.new()
	dialog.open_for_player(str(GameState.active_player().id))
	city.add_child(dialog)
	await _frames(5)
	var offer: Array = Cards.round_offer(str(GameState.active_player().id))
	if offer.is_empty():
		dialog.queue_free()
		return false
	var choice := dialog.choice_buttons.get(str(offer[0])) as Button
	await _real_click(choice)
	await _real_click(dialog.confirm_button)
	for _frame in range(120):
		await get_tree().process_frame
		if dialog != null and is_instance_valid(dialog) and str(dialog.phase) == "ready_to_return":
			break
	if dialog == null or not is_instance_valid(dialog) or str(dialog.phase) != "ready_to_return":
		return false
	await _real_click(dialog.confirm_button)
	await _frames(5)
	return true


func _button_with_text(root: Node, needle: String) -> Button:
	if root == null:
		return null
	for candidate: Button in root.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and needle in candidate.text:
			return candidate
	return null


func _real_click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		print("[REAL-INPUT] missing control")
		await _frames(1)
		return
	print("[REAL-INPUT] click control=%s text=%s rect=%s disabled=%s mouse_filter=%s viewport=%s window=%s" % [control.get_path(), str(control.get("text")), control.get_global_rect(), str(control.get("disabled")), str(control.mouse_filter), get_viewport().get_visible_rect(), get_window().size])
	await _real_pointer_click(control.get_global_rect().get_center())


func _real_pointer_click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	await _frames(1)
	var hovered := get_viewport().gui_get_hovered_control()
	print("[REAL-INPUT] pointer=%s hovered=%s" % [position, hovered.get_path() if hovered != null else "none"])
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		get_viewport().push_input(event, true)
		await _frames(1)


func _real_drag(from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	get_viewport().push_input(down, true)
	await _frames(1)
	for step in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(step) / 8.0)
		motion.global_position = motion.position
		motion.relative = (to - from) / 8.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	get_viewport().push_input(up, true)
	await _frames(1)


func _wait_for_scene(path: String, frames: int) -> void:
	for _frame in range(frames):
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and str(current.scene_file_path) == path:
			return


func _visible_content_count(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	for child in root.find_children("*", "Control", true, false):
		var control := child as Control
		if control != null and control.is_visible_in_tree() and control.size.x > 1.0 and control.size.y > 1.0:
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


func _finish() -> void:
	GameState.suppress_disk_save = false
	print("V157_REAL_INPUT_PLAYTEST passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
