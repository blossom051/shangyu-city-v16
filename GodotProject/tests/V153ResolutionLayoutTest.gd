extends Node

const TARGETS := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(2560, 1440)]

var passed := 0
var failed := 0


func _ready() -> void:
	for target in TARGETS:
		await _check_resolution(target)
	print("V154_RESOLUTION_TESTS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check_resolution(target: Vector2i) -> void:
	get_window().content_scale_size = target
	get_window().size = target
	await _frames(2)
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15300 + target.x)
	GameState.begin_round()
	var city := await _spawn("res://scenes/CityMap.tscn")
	for _frame in range(300):
		await get_tree().process_frame
		if city != null and city.find_child("GameHUD", true, false) != null:
			break
	await _frames(4)
	var city_ok := city != null
	for path in ["UI/HUDBack", "UI/Bottom", "UI/Ranking", "UI/GameHUD/TurnPanel", "UI/GameHUD/EndlessQuickBar", "UI/GameHUD/Go"]:
		var control := city.get_node_or_null(path) as Control if city != null else null
		var control_ok := _inside(control, target)
		if not control_ok:
			printerr("LAYOUT_DETAIL %dx%d %s rect=%s visible=%s" % [target.x, target.y, path, str(control.get_global_rect()) if control != null else "null", str(control.visible) if control != null else "false"])
		city_ok = city_ok and control_ok
	_assert("%dx%d 城市关键控件在安全区" % [target.x, target.y], city_ok)
	await _dispose(city)

	var stock := await _spawn("res://scenes/StockMarket.tscn")
	await _frames(5)
	var clear := stock.find_child("ClearPosition", true, false) as Control if stock != null else null
	var back := stock.get_node_or_null("Layout/Header/Back") as Control if stock != null else null
	if not _inside(clear, target):
		printerr("LAYOUT_DETAIL %dx%d ClearPosition rect=%s" % [target.x, target.y, str(clear.get_global_rect()) if clear != null else "null"])
	_assert("%dx%d 证券清仓与返回按钮完整" % [target.x, target.y], _inside(clear, target) and _inside(back, target))
	await _dispose(stock)

	var capital := await _spawn("res://scenes/CapitalMarket.tscn")
	await _frames(5)
	_assert("%dx%d 资本市场页面完整" % [target.x, target.y], capital != null and capital.find_child("CapitalMarketTitle", true, false) != null and _inside(capital as Control, target))
	await _dispose(capital)


func _spawn(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	add_child(instance)
	await get_tree().process_frame
	return instance


func _dispose(instance: Node) -> void:
	if instance != null:
		instance.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _inside(control: Control, target: Vector2i) -> bool:
	if control == null or not control.visible:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= float(target.x) + 1.0 and rect.end.y <= float(target.y) + 1.0


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
