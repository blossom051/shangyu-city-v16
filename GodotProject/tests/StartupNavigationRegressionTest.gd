extends Node

var passed := 0
var failed := 0


func _ready() -> void:
	GameFlow.suppress_background_preload_for_tests = true
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15541)
	GameState.begin_round()
	GameState.game_data.round = 2
	GameState.game_data.startup_schedule = [2]
	GameState.game_data.startup_offers = {}
	await get_tree().process_frame
	var packed := load("res://scenes/CityMap.tscn") as PackedScene
	var city := packed.instantiate()
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	for _frame in range(300):
		await get_tree().process_frame
		if city.find_child("GameHUD", true, false) != null:
			break
	city.call("_open_startup")
	for _frame in range(8):
		await get_tree().process_frame
	var startup := get_tree().current_scene
	_assert("城市按钮切换到创投场景", startup != null and str(startup.scene_file_path).ends_with("StartupPitchEvent.tscn"))
	var layout := startup.get_node_or_null("Layout") as Control if startup != null else null
	var visible_labels := 0
	if startup != null:
		for candidate: Node in startup.find_children("*", "Label", true, false):
			var label := candidate as Label
			if label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
				visible_labels += 1
	_assert("创投页面不是纯色蓝屏", layout != null and layout.is_visible_in_tree() and layout.size.x > 1000.0 and layout.size.y > 600.0 and visible_labels >= 8)
	var project_card: Button = null
	if startup != null:
		for candidate: Node in startup.find_children("*", "Button", true, false):
			if candidate.get_script() == load("res://scripts/StartupProjectCard.gd"):
				project_card = candidate as Button
				break
	if project_card != null:
		project_card.emit_signal("pressed")
	for _frame in range(3):
		await get_tree().process_frame
	var diligence := startup.get_node_or_null("StartupDueDiligenceDialog") if startup != null else null
	var decline: Button = null
	if diligence != null:
		for candidate: Node in diligence.find_children("*", "Button", true, false):
			var button := candidate as Button
			if button != null and button.text == "暂不投资":
				decline = button
				break
	var decline_found := decline != null
	if decline != null:
		decline.emit_signal("pressed")
	for _frame in range(3):
		await get_tree().process_frame
	_assert("创投详情点击暂不投资后恢复项目页面而非纯蓝屏", project_card != null and decline_found and get_tree().current_scene == startup and startup.is_visible_in_tree() and layout != null and layout.is_visible_in_tree())
	var back := startup.get_node_or_null("Layout/Header/Back") as Button if startup != null else null
	if back != null:
		back.emit_signal("pressed")
	for _frame in range(8):
		await get_tree().process_frame
	_assert("创投返回后恢复原城市实例", get_tree().current_scene == city and bool(GameFlow.city_lifecycle_profile().get("reused_city", false)))
	GameFlow.open_city_system("res://scenes/__missing_startup_scene__.tscn", {"system": "startup"})
	await get_tree().process_frame
	_assert("创投资源加载失败时不会留下纯蓝空场景", get_tree().current_scene == city and city.get_parent() == get_tree().root)
	print("STARTUP_NAVIGATION_REGRESSION passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
