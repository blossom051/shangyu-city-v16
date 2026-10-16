extends Node

var passed := 0
var failed := 0


func _ready() -> void:
	await _check_main_menu()
	await _check_mode_select()
	await _prepare_game()
	await _check_stock_market()
	await _check_startup_confirmation()
	await _check_capital_market()
	await _check_city()
	print("V154_UI_SMOKE passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


func _dispose(instance: Node) -> void:
	if instance != null:
		instance.queue_free()
	await get_tree().process_frame


func _check_main_menu() -> void:
	var scene := await _scene("res://scenes/MainMenu.tscn")
	_assert("主菜单可实例化", scene != null)
	_assert("正式版无售卖授权遮罩", scene != null and scene.find_child("SaleLicenseOverlay", true, false) == null)
	await _dispose(scene)


func _check_mode_select() -> void:
	var scene := await _scene("res://scenes/ModeSelect.tscn")
	_assert("赛制页可实例化", scene != null)
	_assert("赛制页包含永续经营入口", scene != null and scene.find_child("Season0", true, false) != null)
	await _dispose(scene)


func _prepare_game() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15390)
	GameState.begin_round()


func _check_stock_market() -> void:
	var scene := await _scene("res://scenes/StockMarket.tscn")
	_assert("证券页可实例化", scene != null)
	_assert("证券页包含一键清仓", scene != null and scene.find_child("ClearPosition", true, false) != null)
	await _dispose(scene)


func _check_startup_confirmation() -> void:
	GameState.game_data.round = 2
	GameState.game_data.startup_schedule = [2]
	GameState.game_data.startup_offers = {}
	var before_cash := int(GameState.active_player().cash)
	var scene := await _scene("res://scenes/StartupPitchEvent.tscn")
	var project_card: Button = null
	var buttons := scene.find_children("*", "Button", true, false) if scene != null else []
	for candidate: Button in buttons:
		if candidate.get_script() == load("res://scripts/StartupProjectCard.gd"):
			project_card = candidate
			break
	if project_card != null:
		project_card.emit_signal("pressed")
	await get_tree().process_frame
	_assert("创投首次点击打开尽调而不扣款", scene != null and scene.find_child("StartupDueDiligenceDialog", true, false) != null and int(GameState.active_player().cash) == before_cash)
	await _dispose(scene)


func _check_capital_market() -> void:
	var scene := await _scene("res://scenes/CapitalMarket.tscn")
	_assert("资本市场页可实例化", scene != null)
	_assert("资本市场页展示上市规则与操作按钮", scene != null and scene.find_child("CapitalMarketTitle", true, false) != null and not scene.find_children("*", "Button", true, false).is_empty())
	await _dispose(scene)


func _check_city() -> void:
	var player := GameState.active_player()
	GameState.game_data.round = 5
	var land: Dictionary = GameState.game_data.lands["L11"]
	land.owner_id = str(player.id)
	land.asset_state = "OWNED"
	land.state = "operating"
	land.acquired_round = 1
	land.business_id = "UI-L11"
	player.land_ids.append("L11")
	player.business_ids.append("UI-L11")
	GameState.game_data.businesses["UI-L11"] = {"id": "UI-L11", "owner_id": str(player.id), "land_id": "L11", "name": "界面验证企业", "type_id": "financial_office", "state": "operating", "operating_since_round": 1, "value": 420, "employees": ["", ""], "mortgaged": false}
	var scene := await _scene("res://scenes/CityMap.tscn")
	# The production city deliberately streams its 3D assets over multiple frames.
	# Wait for the mature HUD sentinel instead of assuming a fixed fast machine.
	for _frame in range(240):
		await get_tree().process_frame
		if scene != null and scene.find_child("GameHUD", true, false) != null:
			break
	_assert("城市主界面可完成分阶段初始化", scene != null and scene.find_child("GameHUD", true, false) != null)
	_assert("城市地图包含我的土地入口", scene != null and scene.find_child("Mine", true, false) != null)
	_assert("城市主界面包含常驻经营快捷栏", scene != null and scene.find_child("EndlessQuickBar", true, false) != null)
	_assert("城市主界面包含经济周期入口", scene != null and scene.find_child("Cycle", true, false) != null)
	_assert("西岸交易所建筑提供资本市场入口", scene != null and scene.find_child("CapitalExchangeLandmark", true, false) != null)
	if scene != null:
		scene.call("_select_land", "L11")
		await get_tree().process_frame
	_assert("土地详情包含拆除重建操作", scene != null and scene.find_child("Demolish", true, false) != null)
	_assert("土地详情包含银行快速变现操作", scene != null and scene.find_child("BankSale", true, false) != null)
	var sale_button := scene.find_child("BankSale", true, false) as Button if scene != null else null
	if sale_button != null:
		sale_button.emit_signal("pressed")
	await get_tree().process_frame
	_assert("出售给银行首次点击只显示报价确认", scene != null and scene.find_child("ConfirmAction", true, false) != null and str(land.get("owner_id", "")) == str(player.id))
	var sale_dialog := scene.find_child("AssetActionConfirmDialog", true, false)
	if sale_dialog != null: sale_dialog.queue_free()
	await get_tree().process_frame
	var demolish_button := scene.find_child("Demolish", true, false) as Button if scene != null else null
	if demolish_button != null:
		demolish_button.emit_signal("pressed")
	await get_tree().process_frame
	_assert("拆除重建首次点击只显示后果确认", scene != null and scene.find_child("ConfirmAction", true, false) != null and str(GameState.game_data.businesses["UI-L11"].state) == "operating")
	await _dispose(scene)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
