extends Node

const RoundDecisions = preload("res://scripts/RoundDecisionSystem.gd")
const RoundDialog = preload("res://scripts/RoundDecisionDialog.gd")
const LiquidationDialog = preload("res://scripts/VoluntaryLiquidationDialog.gd")
const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")
const Cards = preload("res://scripts/CardSystem.gd")
const CardDraftDialog = preload("res://scripts/RoundCardDraftDialog.gd")

var output_dir := ""


func _ready() -> void:
	var forced_width := int(OS.get_environment("V154_CAPTURE_WIDTH"))
	var forced_height := int(OS.get_environment("V154_CAPTURE_HEIGHT"))
	if forced_width > 0 and forced_height > 0:
		get_window().content_scale_size = Vector2i(forced_width, forced_height)
		get_window().size = Vector2i(forced_width, forced_height)
		await _frames(3)
	output_dir = ProjectSettings.globalize_path("res://../Screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)
	_prepare_game()
	await _capture_city()
	await _capture_startup()
	await _capture_capital_market(false)
	await _capture_capital_market_review()
	await _capture_capital_market(true)
	await _capture_west_bank_cards()
	await _capture_random_decision()
	await _capture_liquidation_summary()
	print("V154_EVIDENCE_CAPTURE completed=11 output=%s" % output_dir)
	get_tree().quit(0)


func _prepare_game() -> void:
	GameState.start_match("local", 0, [{"company_id": "hengyue", "human": true}, {"company_id": "qiming", "human": false}], 15488)
	var player := GameState.game_data.players[0] as Dictionary
	GameState.game_data.turn_order = [str(player.id), str(GameState.game_data.players[1].id)]
	GameState.game_data.active_order_index = 0
	player.cash = 12000
	player.asset_value = 6000
	player.risk = 20
	GameState.game_data.round = 16
	GameState.game_data.phase = "player_turn"
	GameState.game_data.startup_schedule = [16]
	GameState.game_data.startup_offers = {}
	GameState.game_data.economic_cycle = {"index": 1, "phase": "boom", "name": "上行", "started_round": 3, "ends_round": 7}
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "EVIDENCE-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id); land.asset_state = "OWNED"; land.state = "operating"; land.acquired_round = 1; land.business_id = business_id
		player.land_ids.append(land_id); player.business_ids.append(business_id)
		var type_id := "investment_bank_hq" if land_id in ["L29", "L30"] else "financial_office"
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "name": GameConfig.by_id("business_types", type_id).get("name", "金融企业"), "type_id": type_id, "state": "operating", "operating_since_round": 1, "value": 900, "employees": ["", ""], "mortgaged": false}


func _capture_city() -> void:
	var scene := await _spawn("res://scenes/CityMap.tscn")
	for _frame in range(300):
		await get_tree().process_frame
		if scene != null and scene.find_child("GameHUD", true, false) != null: break
	await _frames(10)
	var viewport_size := get_viewport().get_visible_rect().size
	await _save("V15.4-城市主界面-%dx%d.png" % [int(viewport_size.x), int(viewport_size.y)])
	if scene != null:
		scene.call("_on_district_legend_pressed", "west_finance")
	await _frames(16)
	await _save("V15.4-西岸金融中心与交易所.png")
	if scene != null:
		scene.call("_set_map_mode", "mine")
		scene.call("_select_land", "L29")
	await _frames(6)
	await _save("V15.4-西岸高级土地与企业.png")
	await _dispose(scene)


func _capture_startup() -> void:
	var scene := await _spawn("res://scenes/StartupPitchEvent.tscn")
	await _frames(8)
	var project_card: Button = null
	for candidate: Button in scene.find_children("*", "Button", true, false):
		if candidate.get_script() == load("res://scripts/StartupProjectCard.gd"):
			project_card = candidate; break
	if project_card != null: project_card.emit_signal("pressed")
	await _frames(5)
	await _save("V15.4-创投尽调与二次确认.png")
	await _dispose(scene)


func _capture_capital_market(listed: bool) -> void:
	var player := GameState.active_player()
	if listed:
		if not GameState.game_data.ipo_records.has(str(player.id)):
			EndlessOperationsSystem.request_ipo(str(player.id), false)
		GameState.game_data.ipo_records[str(player.id)].status = "listed"
		GameState.game_data.ipo_records[str(player.id)].listed_round = int(GameState.game_data.round)
		ListedMarket.initialize_listing(str(player.id), GameState.game_data.ipo_records[str(player.id)])
		var rival := GameState.game_data.players[1] as Dictionary
		rival.asset_value = 5600
		rival.last_round_income = 340
		rival.risk = 24
		GameState.game_data.ipo_records[str(rival.id)] = {"status": "listed", "listed_round": 14, "market_confidence": 78, "disclosure_gap": 0.06, "aggressive": true}
		ListedMarket.initialize_listing(str(rival.id), GameState.game_data.ipo_records[str(rival.id)])
		ListedMarket.queue_impulse(str(rival.id), 0.11, "业绩超预期")
		ListedMarket.price_all(17)
	var scene := await _spawn("res://scenes/CapitalMarket.tscn")
	await _frames(6)
	await _save("V15.4-资本市场-%s.png" % ("上市后经营" if listed else "上市规则"))
	await _dispose(scene)


func _capture_capital_market_review() -> void:
	var player := GameState.active_player()
	if not GameState.game_data.ipo_records.has(str(player.id)):
		EndlessOperationsSystem.request_ipo(str(player.id), false)
	var scene := await _spawn("res://scenes/CapitalMarket.tscn")
	await _frames(6)
	await _save("V15.4-资本市场-三回合审核.png")
	await _dispose(scene)


func _capture_random_decision() -> void:
	var player := GameState.active_player()
	RoundDecisions.generate_round(["brand_public_opinion"])
	var dialog := RoundDialog.new()
	dialog.open_for_player(str(player.id))
	add_child(dialog)
	await _frames(48)
	await _save("V15.4-随机经营事件决策.png")
	dialog.queue_free()
	await _frames(2)


func _capture_west_bank_cards() -> void:
	var player := GameState.active_player()
	var player_id := str(player.get("id", ""))
	Cards.create_round_offer(player_id, 5)
	# CardEngine keeps the two five-choice stages separate.  Skip the already
	# proven old-city stage here so the evidence image focuses on the new deck.
	GameState.game_data.round_card_offers.erase(player_id)
	var dialog := CardDraftDialog.new()
	dialog.open_for_player(player_id)
	add_child(dialog)
	await _frames(8)
	await _save("V15.4-西岸专属卡牌-独立背面五选一.png")
	var offer: Array = Cards.round_offer(player_id)
	if not offer.is_empty():
		var card_id := str(offer[0])
		var button := dialog.choice_buttons.get(card_id) as Button
		if button != null:
			dialog.call("_select_card", card_id, button)
			dialog.call("_confirm_card")
			await _frames(90)
			await _save("V15.4-西岸专属卡牌-独立正面.png")
	dialog.queue_free()
	await _frames(3)


func _capture_liquidation_summary() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15489)
	var player := GameState.game_data.players[0] as Dictionary
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	GameState.game_data.round = 22
	player.asset_value = 6380
	player.cash = 1720
	player.debt = 430
	player.risk = 38
	player.land_ids = ["L01", "L02", "L09", "L29"]
	player.business_ids = ["B01", "B02", "B03"]
	player.talent_ids = ["T01", "T02", "T03", "T04"]
	player.round_history = [{"round": 18, "summary": {"asset_after": 7020, "rank_after": 1, "net": 860}}, {"round": 21, "summary": {"asset_after": 6380, "rank_after": 2, "net": -240}}]
	var dialog := LiquidationDialog.new()
	dialog.open_for_player(str(player.id))
	add_child(dialog)
	await _frames(4)
	dialog.call("_confirm_liquidation")
	await _frames(5)
	await _save("V15.4-主动破产经营总结.png")
	dialog.queue_free()
	await _frames(3)


func _spawn(path: String) -> Node:
	var packed := load(path) as PackedScene
	var instance := packed.instantiate() if packed != null else null
	if instance != null: add_child(instance)
	await get_tree().process_frame
	return instance


func _dispose(instance: Node) -> void:
	if instance != null: instance.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for _frame in range(count): await get_tree().process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var logical_size := get_viewport().get_visible_rect().size
	if image.get_width() != int(logical_size.x) or image.get_height() != int(logical_size.y):
		image.resize(int(logical_size.x), int(logical_size.y), Image.INTERPOLATE_LANCZOS)
	var result := image.save_png(output_dir.path_join(file_name))
	print("CAPTURE_%s %s %dx%d" % ["OK" if result == OK else "FAIL", file_name, image.get_width(), image.get_height()])
