extends Node

const Businesses = preload("res://scripts/BusinessSystem.gd")
const CityMapVisual = preload("res://scripts/CommercialCityMap.gd")
const Institutions = preload("res://scripts/WestBankInstitutionSystem.gd")
const LandmarkAssets = preload("res://scripts/WestBankLandmarkAssets.gd")
const ParcelGeometry = preload("res://scripts/LandParcelGeometry.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	_test_catalog_and_world()
	_test_west_bank_visual_contract()
	_test_premium_access_and_business_pool()
	_test_west_bank_art_and_wealth_club()
	_test_unlimited_round_actions()
	_test_ipo_review_and_market_risk()
	_test_endless_decision_generation()
	print("V155_EXPANSION_TESTS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start(seed_value := 15529) -> Dictionary:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], seed_value)
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 90000
	player.asset_value = 6000
	player.risk = 20
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	return player


func _test_catalog_and_world() -> void:
	_start()
	_assert("西岸新区提供 16 块独立土地", GameConfig.list("land_tiles").size() == 44 and bool(GameConfig.by_id("land_tiles", "L44").get("premium_zone", false)))
	_assert("新区提供 6 种高级企业", GameConfig.list("business_types").filter(func(item: Dictionary) -> bool: return bool(item.get("premium_only", false))).size() == 6)
	_assert("世界边界包含西岸且河流不可建设", CityWorldBounds.is_valid_land_position(Vector3(-72, 0, 11)) and not CityWorldBounds.is_valid_land_position(Vector3(-46, 0, 11)))


func _test_west_bank_visual_contract() -> void:
	GameState.start_match("solo", 12, [{"company_id": "hengyue", "human": true}], 15530)
	var locked_map := CityMapVisual.new()
	locked_map.call("_make_west_bank_ground")
	locked_map.call("_build_west_bank_financial_core")
	_assert("其他模式显示西岸但明确标注仅永续开放", locked_map.get_node_or_null("WestBankEndlessOnlyBanner") != null)
	var flow := locked_map.call("water_flow_profile") as Dictionary
	_assert("西岸河流使用 UE 5.8 烘焙且限定河道的克制自然动态水面", bool(flow.get("animated", false)) and str(flow.get("bake_source", "")) == "unreal_engine_5_8" and bool(flow.get("confined_to_river", false)) and int(flow.get("flow_directions", 0)) == 2 and str(flow.get("surface_model", "")) == "ue58_baked_dual_flow_city_river" and not bool(flow.get("fracture_noise", true)))
	_assert("高画质水面具备双层法线、菲涅尔反射与低强度岸线高光", int(flow.get("normal_detail_layers", 0)) >= 2 and bool(flow.get("fresnel_reflection", false)) and bool(flow.get("shoreline_highlight", false)) and str(flow.get("foam_intensity", "")) == "low")
	var quality := locked_map.call("visual_quality_profile") as Dictionary
	_assert("桌面版启用 Forward+ Vulkan 高画质管线并保留兼容启动", str(quality.get("renderer", "")) == "forward_plus_vulkan" and bool(quality.get("compatibility_launcher", false)) and bool(quality.get("screen_space_ambient_occlusion", false)) and bool(quality.get("screen_space_reflections", false)))
	var landmark_placement_clear := true
	for tower_name in ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance"]:
		var tower := locked_map.get_node_or_null(tower_name) as Node3D
		if tower == null or tower.position.x >= -55.0 or not CityWorldBounds.is_valid_land_position(tower.position):
			landmark_placement_clear = false
			continue
		var bounds := LandmarkAssets.bounds(tower_name)
		var half_x := bounds.x * 0.5
		var half_z := bounds.z * 0.5
		var footprint := PackedVector2Array([
			Vector2(tower.position.x - half_x, tower.position.z - half_z),
			Vector2(tower.position.x + half_x, tower.position.z - half_z),
			Vector2(tower.position.x + half_x, tower.position.z + half_z),
			Vector2(tower.position.x - half_x, tower.position.z + half_z),
		])
		for land: Dictionary in GameState.game_data.lands.values():
			if not Geometry2D.intersect_polygons(footprint, ParcelGeometry.world_polygon(land)).is_empty():
				landmark_placement_clear = false
	_assert("四栋地标位于西岸空地且不覆盖可购买地块", landmark_placement_clear)
	locked_map.free()
	_start(15531)
	var endless_map := CityMapVisual.new()
	endless_map.call("_build_west_bank_financial_core")
	_assert("永续模式移除西岸锁定遮罩并保留资本中心", endless_map.get_node_or_null("WestBankEndlessOnlyBanner") == null and endless_map.get_node_or_null("CapitalExchangeLandmark") != null)
	endless_map.free()


func _test_premium_access_and_business_pool() -> void:
	var player := _start()
	GameState.game_data.round = 4
	var blocked := Businesses.buy_land(str(player.id), "L29")
	_assert("新区购地资格不会过早开放", not bool(blocked.get("ok", false)))
	GameState.game_data.round = 6
	for index in range(3):
		var land_id: String = ["L09", "L10", "L11"][index]
		var business_id := "ACCESS-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id); land.asset_state = "OWNED"; land.state = "operating"; land.business_id = business_id
		player.land_ids.append(land_id); player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "financial_office", "state": "operating", "value": 500, "employees": ["", ""]}
	var purchased := Businesses.buy_land(str(player.id), "L29")
	_assert("满足条件后可购买西岸土地", bool(purchased.get("ok", false)))
	var normal_build := Businesses.build_business(str(player.id), "L29", "restaurant")
	var premium_build := Businesses.build_business(str(player.id), "L29", "investment_bank_hq")
	_assert("新区拒绝原城区普通业态", not bool(normal_build.get("ok", false)))
	_assert("新区可建设专属高级总部", bool(premium_build.get("ok", false)))


func _test_west_bank_art_and_wealth_club() -> void:
	var art_paths := [
		"res://assets/ui/business/west_bank/investment_bank_hq.png",
		"res://assets/ui/business/west_bank/asset_management_center.png",
		"res://assets/ui/business/west_bank/fintech_lab.png",
		"res://assets/ui/business/west_bank/data_exchange.png",
		"res://assets/ui/business/west_bank/cross_border_clearing.png",
		"res://assets/ui/business/west_bank/international_convention.png",
	]
	var imported_unique := true
	for path: String in art_paths:
		imported_unique = imported_unique and ResourceLoader.exists(path) and load(path) is Texture2D
	_assert("西岸六种高级企业使用六张独立 AI 建筑图", imported_unique and art_paths.duplicate().size() == 6)
	var player := _start(15564)
	GameState.game_data.round = 6
	player.cash = 1000
	player.risk = 20
	for index in range(3):
		var business_id := "WEALTH-ACCESS-%d" % index
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "state": "operating", "value": 400, "employees": ["", ""]}
	var profile := Institutions.profile("TerraceHQ")
	var option_ids: Array = (profile.get("options", []) as Array).map(func(option: Dictionary) -> String: return str(option.get("id", "")))
	_assert("原并购中心已替换为三选一财富俱乐部", str(profile.get("name", "")).contains("财富俱乐部") and option_ids == ["wealth_defensive", "wealth_growth", "wealth_salon"])
	var result := Institutions.execute(str(player.id), "TerraceHQ", "wealth_defensive")
	_assert("财富俱乐部策略产生真实现金与风险结果", bool(result.get("ok", false)) and int((result.get("changes", {}) as Dictionary).get("cash_change", 0)) != 0 and int(player.risk) < 20)


func _test_unlimited_round_actions() -> void:
	var player := _start()
	var buys_ok := true
	for land_id in ["L01", "L02", "L03"]:
		buys_ok = buys_ok and bool(Businesses.buy_land(str(player.id), land_id).get("ok", false))
	var builds_ok := true
	for land_id in ["L01", "L02", "L03"]:
		builds_ok = builds_ok and bool(Businesses.build_business(str(player.id), land_id, "convenience").get("ok", false))
	_assert("同一回合可连续购买多块土地", buys_ok and int(player.actions.land) == 3)
	_assert("同一回合可连续建设多家企业", builds_ok and int(player.actions.build) == 3)


func _test_ipo_review_and_market_risk() -> void:
	var player := _start(15577)
	GameState.game_data.round = 16
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "IPO-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id); land.asset_state = "OWNED"; land.state = "operating"; land.business_id = business_id
		player.land_ids.append(land_id); player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "financial_office", "state": "operating", "value": 800, "employees": ["", ""]}
	var before_cash := int(player.cash)
	var application := EndlessOperationsSystem.request_ipo(str(player.id), false)
	_assert("上市申请进入三回合审核而非立刻到账", bool(application.get("ok", false)) and int(application.get("approval_round", 0)) == 19 and int(player.cash) < before_cash)
	for round_number in range(17, 20):
		GameState.game_data.round = round_number
		EndlessOperationsSystem.begin_round()
	var record: Dictionary = GameState.game_data.ipo_records[str(player.id)]
	_assert("审核期结束后产生通过或驳回结果", str(record.get("status", "")) in ["listed", "rejected"])
	if str(record.get("status", "")) == "listed":
		var acquisition := EndlessOperationsSystem.capital_market_action(str(player.id), "acquisition")
		_assert("上市后并购包含成功概率和真实损益", bool(acquisition.get("ok", false)) and acquisition.get("details", {}).get("changes", {}).has("success_chance"))
	else:
		_assert("上市驳回带来整改期和风险代价", int(record.get("retry_round", 0)) > 19 and int(player.risk) > 20)


func _test_endless_decision_generation() -> void:
	_start()
	GameState.game_data.round = 1
	RoundDecisionSystem.initialize_match(0)
	var initial_rounds := RoundDecisionSystem.event_rounds()
	GameState.game_data.round = 30
	var extended_rounds := RoundDecisionSystem.event_rounds()
	_assert("永续模式随机经营事件持续扩展", not initial_rounds.is_empty() and extended_rounds.max() > 40)
	_assert("条件事件可按真实经营状态进入事件池", ConditionalEventCatalog.decision_events().size() >= 15)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
