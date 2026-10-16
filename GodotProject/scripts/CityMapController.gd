extends Node3D

const CommercialCityMapScene = preload("res://scenes/CommercialCityMap.tscn")
const Businesses = preload("res://scripts/BusinessSystem.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const AI = preload("res://scripts/AIPlayer.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")
const Stocks = preload("res://scripts/StockSystem.gd")
const Styles = preload("res://scripts/UIStyles.gd")
const V7 = preload("res://scripts/V7Theme.gd")
const Selection = preload("res://scripts/SelectionState.gd")
const CardHandOverlayScene = preload("res://scenes/CardHandPanel.tscn")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const EmployeeDialog = preload("res://scripts/EmployeeManagementDialog.gd")
const RoundCardDraftDialog = preload("res://scripts/RoundCardDraftDialog.gd")
const DebtDueDialog = preload("res://scripts/DebtDueDialog.gd")
const StartupResultDialog = preload("res://scripts/StartupResultDialog.gd")
const Cards = preload("res://scripts/CardSystem.gd")
const CapitalReactionWindowScene = preload("res://scripts/CapitalReactionWindow.gd")
const AITurnPresenterScene = preload("res://scripts/AITurnPresenter.gd")
const AuctionNotices = preload("res://scripts/AuctionNoticeState.gd")
const Recommendations = preload("res://scripts/BusinessRecommendationEngine.gd")
const Authority = preload("res://scripts/HumanTurnAuthority.gd")
const LandPurchaseDialogScene = preload("res://scripts/LandPurchaseDialog.gd")
const LandRenameDialogScene = preload("res://scripts/LandRenameDialog.gd")
const LandNames = preload("res://scripts/LandNamingService.gd")
const RiskDetailPanelScene = preload("res://scripts/RiskDetailPanel.gd")
const ForcedCollectionAlertScene = preload("res://scripts/ForcedCollectionAlert.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const OperatingDashboardScene = preload("res://scripts/OperatingDashboard.gd")
const HeatScale = preload("res://scripts/MapHeatScale.gd")
const RoundDecisionDialogScene = preload("res://scripts/RoundDecisionDialog.gd")
const RoundDecisions = preload("res://scripts/RoundDecisionSystem.gd")
const MapActionBadgeScene = preload("res://scripts/MapActionBadge.gd")
const CapitalHudRibbonScene = preload("res://scripts/CapitalHudRibbon.gd")
const AssetActionConfirmDialogScene = preload("res://scripts/AssetActionConfirmDialog.gd")
const EconomicCycleDialogScene = preload("res://scripts/EconomicCycleDialog.gd")
const EndlessCheatDialogScene = preload("res://scripts/EndlessCheatDialog.gd")
const LiquidationWarningButtonScene = preload("res://scripts/LiquidationWarningButton.gd")
const VoluntaryLiquidationDialogScene = preload("res://scripts/VoluntaryLiquidationDialog.gd")
const WestBankInstitutionDialogScene = preload("res://scripts/WestBankInstitutionDialog.gd")
const WestBankEligibilityDialogScene = preload("res://scripts/WestBankEligibilityDialog.gd")
const WestBankInstitutions = preload("res://scripts/WestBankInstitutionSystem.gd")
const HUD_METRIC_ICONS = preload("res://assets/ui/hud/hud_capital_icons_v135.png")

@onready var camera: Camera3D = $CameraRig / Camera3D
@onready var camera_rig: Node3D = $CameraRig
@onready var side: VBoxContainer = $UI / Side / Scroll / Content

var selected_land_id: = ""
var dragging: = false
var last_mouse: = Vector2.ZERO
var camera_distance: = 46.0
var city_map_visual: Node3D
var land_to_plot: Dictionary = {}
var plot_to_land: Dictionary = {}
var last_hud_values: Dictionary = {}
var land_selection: = Selection.new()
var left_drag_candidate: = false
var drag_distance: = 0.0
var pointer_hit_plot: = false
var hud_metric_controls: Dictionary = {}
var hud_metric_cells: Dictionary = {}
var hud_help_popup: PopupPanel
var hud_help_label: Label
var ranking_cards: VBoxContainer
var battle_feed_label: Label
var battle_feed_panel: PanelContainer
var battle_feed_toggle: Button
var battle_feed_expanded: = false
var ranking_compact: = false
var opportunity_radar_label: Label
var opportunity_radar_panel: PanelContainer
var hud_clock: = 0.0
var recommended_action: = ""
var ai_turn_presenter: Control
var map_mode: = "default"
var side_collapsed: = false
var selected_district_id: = ""
var district_buttons: Dictionary = {}
var city_intro_complete: = false
var ai_sequence_running: = false
var entry_sequence_running: = false
var entry_sequence_generation: = 0
var city_visuals_initialized: = false


func _ready() -> void :
	GameState.normalize_compatible_state()
	if GameState.game_data.players.is_empty():
		GameFlow.go("menu")
		return
	if str(GameState.game_data.get("phase", "")) == "settlement":
		GameFlow.go("summary")
		return
	_configure_presentation()
	call_deferred("_initialize_city_staged")


func suspend_for_navigation() -> void :
	entry_sequence_generation += 1
	entry_sequence_running = false
	_reset_pointer_navigation_state()
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)


func resume_from_navigation(_context: = {}) -> void :
	_reset_pointer_navigation_state()
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	_refresh_all()
	call_deferred("_run_turn_entry_sequence")


func _reset_pointer_navigation_state() -> void:
	dragging = false
	left_drag_candidate = false
	drag_distance = 0.0
	pointer_hit_plot = false
	last_mouse = Vector2.ZERO


func _initialize_city_staged() -> void :
	await get_tree().process_frame
	if not is_inside_tree(): return
	await _build_city_staged()
	if not is_inside_tree(): return
	_play_city_intro()
	await get_tree().process_frame
	if not is_inside_tree(): return
	await _style_ui()
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	await _build_mature_hud()
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	get_viewport().size_changed.connect(_apply_resolution_profile)
	GameState.changed.connect(_on_state_changed)
	TutorialDirector.sandbox_visuals_changed.connect(_on_tutorial_visuals_changed)
	ModalManager.active_changed.connect(_on_modal_activity_changed)
	$UI / Bottom / Actions / Talent.pressed.connect(_open_system.bind("talent", "res://scenes/TalentMarket.tscn"))
	$UI / Bottom / Actions / News.pressed.connect(_open_system.bind("news", "res://scenes/NewsCenter.tscn"))
	$UI / Bottom / Actions / Startup.pressed.connect(_open_startup)
	$UI / Bottom / Actions / Auction.pressed.connect(_open_system.bind("auction", "res://scenes/AuctionPanel.tscn"))
	$UI / Bottom / Actions / Cards.pressed.connect(_open_card_hand)
	$UI / Bottom / Actions / Stocks.pressed.connect(_open_system.bind("stocks", "res://scenes/StockMarket.tscn"))
	$UI / Bottom / Actions / Bank.pressed.connect(_open_system.bind("bank", "res://scenes/BankPanel.tscn"))
	$UI / Bottom / Actions / EndTurn.pressed.connect(_show_turn_confirmation)
	$UI / Side / Scroll / Content / Buy.pressed.connect(_buy_selected)
	$UI / Side / Scroll / Content / Build.pressed.connect(_open_build)
	$UI / Side / Scroll / Content / Locate.pressed.connect(_locate_selected_district)
	$UI / Side / Scroll / Content / Rename.pressed.connect(_open_land_rename)
	$UI / Side / Scroll / Content / Employee1.pressed.connect( func() -> void : _assign_employee(0))
	$UI / Side / Scroll / Content / Employee2.pressed.connect( func() -> void : _assign_employee(1))
	get_tree().process_frame.connect(_refresh_all_staged_map, CONNECT_ONE_SHOT)


func _run_turn_entry_sequence() -> void :
	if entry_sequence_running or not is_inside_tree():
		return
	entry_sequence_running = true
	AudioManager.round_start()
	entry_sequence_generation += 1
	var generation: = entry_sequence_generation
	get_tree().process_frame.connect(_continue_turn_entry_sequence.bind(generation), CONNECT_ONE_SHOT)


func _continue_turn_entry_sequence(generation: int) -> void :
	if not is_inside_tree() or str(GameState.game_data.get("phase", "")) != "player_turn":
		entry_sequence_running = false
		return
	if not GameState.is_human_turn():
		await _run_ai_until_human()
	if not is_inside_tree() or generation != entry_sequence_generation or str(GameState.game_data.get("phase", "")) != "player_turn":
		entry_sequence_running = false
		return
	while not city_intro_complete:
		await get_tree().process_frame
		if not is_inside_tree() or generation != entry_sequence_generation:
			entry_sequence_running = false
			return
	if not GameState.is_human_turn():
		entry_sequence_running = false
		return
	_refresh_all()
	if TutorialDirector.needs_city_target_attachment():
		_attach_standalone_tutorial()
		entry_sequence_running = false
		return
	if TutorialDirector.active or ModalManager.is_blocked():
		entry_sequence_running = false
		return
	var active: = GameState.active_player()
	if not active.is_empty() and Startups.pending_result_count(str(active.id)) > 0:
		_show_startup_result_notice()
		entry_sequence_running = false
		return
	if not active.is_empty() and not Cards.round_offer(str(active.id)).is_empty():
		_show_round_card_draft()
		entry_sequence_running = false
		return
	_show_debt_due_notice()
	if ModalManager.is_blocked():
		entry_sequence_running = false
		return
	_show_round_decision()
	if ModalManager.is_blocked():
		entry_sequence_running = false
		return
	_offer_auction_notice()
	entry_sequence_running = false


func _on_modal_activity_changed(modal_id: String) -> void :
	if modal_id.is_empty() and is_inside_tree():
		call_deferred("_run_turn_entry_sequence")


func _human_action_allowed(show_reason: = true) -> bool:
	var verdict: = Authority.check(GameState.game_data, ai_sequence_running)
	if bool(verdict.get("allowed", false)):
		var active: = GameState.active_player()
		if not active.is_empty() and not RoundDecisions.pending(str(active.id)).is_empty():
			if show_reason and has_node("UI/Toast"):
				$UI / Toast.text = "请先完成本组的城市经营抉择"
			if is_inside_tree():
				call_deferred("_show_round_decision")
			return false
		return true
	if show_reason and has_node("UI/Toast"):
		$UI / Toast.text = str(verdict.get("reason", "当前不能操作"))
	return false


func _attach_standalone_tutorial() -> void :
	await get_tree().process_frame
	await get_tree().process_frame
	while not city_intro_complete:
		await get_tree().process_frame
	var map_anchor: = get_node_or_null("UI/TutorialMapArea") as Control
	if map_anchor == null:
		map_anchor = Control.new()
		map_anchor.name = "TutorialMapArea"
		map_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_anchor.position = Vector2(get_viewport().get_visible_rect().size.x * 0.18, 126)
		map_anchor.size = Vector2(get_viewport().get_visible_rect().size.x * 0.52, get_viewport().get_visible_rect().size.y - 300)
		$UI.add_child(map_anchor)
	var systems_anchor: = get_node_or_null("UI/TutorialSystemsArea") as Control
	if systems_anchor == null:
		systems_anchor = Control.new()
		systems_anchor.name = "TutorialSystemsArea"
		systems_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var viewport_size: = get_viewport().get_visible_rect().size
		systems_anchor.position = Vector2(viewport_size.x * 0.23, viewport_size.y - 150.0)
		systems_anchor.size = Vector2(viewport_size.x * 0.58, 126.0)
		$UI.add_child(systems_anchor)
	TutorialDirector.attach_city_targets({
		"turn_panel": $UI / GameHUD / TurnPanel, 
		"operations": $UI / GameHUD / TurnPanel / Box / Operations, 
		"map_area": map_anchor, 
		"asset_panel": $UI / Side, 
		"buy": $UI / Side / Scroll / Content / Buy, 
		"build": $UI / Side / Scroll / Content / Build, 
		"talent": $UI / Bottom / Actions / Talent, 
		"news": $UI / Bottom / Actions / News, 
		"cards": $UI / Bottom / Actions / Cards, 
		"stocks": $UI / Bottom / Actions / Stocks, 
		"bank": $UI / Bottom / Actions / Bank, 
		"startup": $UI / Bottom / Actions / Startup, 
		"auction": $UI / Bottom / Actions / Auction, 
		"finance_group": $UI / Bottom / Actions, 
		"systems": systems_anchor, 
		"risk": $UI / GameHUD / TurnPanel / Box / RiskMonitor, 
		"end_turn": $UI / GameHUD / Go
	})


func _play_city_intro() -> void :
	if GameSettings.reduce_motion:
		_apply_camera()
		city_intro_complete = true
		return
	camera.position = Vector3(0, 49.0, 64.0)
	camera.rotation_degrees = Vector3(-48.0, 0.0, 0.0)
	camera.fov = 48.0
	camera_rig.position = Vector3(0.0, 0.0, -5.5)
	var tween: = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", Vector3(0, camera_distance * 0.98, camera_distance * 0.68), 0.82)
	tween.tween_property(camera, "rotation_degrees", Vector3(-55.0, 0.0, 0.0), 0.82)
	tween.tween_property(camera, "fov", 44.0, 0.82)
	tween.tween_property(camera_rig, "position", Vector3.ZERO, 0.82)
	tween.finished.connect( func() -> void : city_intro_complete = true)


func _configure_presentation() -> void :

	RenderingServer.set_default_clear_color(Color("14233d"))


func _build_city() -> void :
	city_map_visual = CommercialCityMapScene.instantiate()
	$LandRoot.add_child(city_map_visual)
	if city_map_visual.has_method("setup"):
		var active: = GameState.active_player()
		var color: = Color(str(active.get("color", "#2F6F8F"))) if not active.is_empty() else Color("2F6F8F")
		city_map_visual.call("setup", color, int(GameState.game_data.round), int(GameState.game_data.round_limit))
	if city_map_visual.has_signal("plot_selected"):
		city_map_visual.plot_selected.connect(_select_city_plot)
	if city_map_visual.has_signal("plot_focus_requested"):
		city_map_visual.plot_focus_requested.connect(_focus_camera_on_plot)
	if city_map_visual.has_signal("district_selected"):
		city_map_visual.district_selected.connect(_on_map_district_selected)
	if city_map_visual.has_signal("capital_exchange_requested"):
		city_map_visual.capital_exchange_requested.connect(_open_capital_market_deferred)
	if city_map_visual.has_signal("west_landmark_requested"):
		city_map_visual.west_landmark_requested.connect(_open_west_bank_institution)
	_build_city_mapping()
	_refresh_city_visuals()


func _build_city_staged() -> void :
	city_map_visual = CommercialCityMapScene.instantiate()
	$LandRoot.add_child(city_map_visual)
	var active: = GameState.active_player()
	var color: = Color(str(active.get("color", "#2F6F8F"))) if not active.is_empty() else Color("2F6F8F")
	if city_map_visual.has_method("setup_staged"):
		await city_map_visual.call("setup_staged", color, int(GameState.game_data.round), int(GameState.game_data.round_limit))
	elif city_map_visual.has_method("setup"):
		city_map_visual.call("setup", color, int(GameState.game_data.round), int(GameState.game_data.round_limit))
	if city_map_visual.has_signal("plot_selected"):
		city_map_visual.plot_selected.connect(_select_city_plot)
	if city_map_visual.has_signal("plot_focus_requested"):
		city_map_visual.plot_focus_requested.connect(_focus_camera_on_plot)
	if city_map_visual.has_signal("district_selected"):
		city_map_visual.district_selected.connect(_on_map_district_selected)
	if city_map_visual.has_signal("capital_exchange_requested"):
		city_map_visual.capital_exchange_requested.connect(_open_capital_market_deferred)
	if city_map_visual.has_signal("west_landmark_requested"):
		city_map_visual.west_landmark_requested.connect(_open_west_bank_institution)
	_build_city_mapping()
	_refresh_city_visuals()


func _build_city_mapping() -> void :
	land_to_plot.clear()
	plot_to_land.clear()
	var land_ids: Array = GameState.game_data.lands.keys()
	land_ids.sort()
	var index: = 1
	for land_id in land_ids:
		var plot_id: = "P%02d" % index
		land_to_plot[str(land_id)] = plot_id
		plot_to_land[plot_id] = str(land_id)
		index += 1


func _select_city_plot(plot_data: Dictionary, plot_node: Node3D) -> void :
	pointer_hit_plot = true
	var land_id: = str(plot_data.get("land_id", ""))
	if land_id.is_empty():
		var plot_id: = str(plot_data.get("id", ""))
		land_id = str(plot_to_land.get(plot_id, ""))
	if land_id.is_empty():
		return
	var next_id: = land_selection.toggle(land_id)
	if next_id.is_empty():
		_clear_land_selection()
	else:
		_select_land(next_id)
		_focus_camera_on_plot(plot_node.global_position)


func _focus_camera_on_plot(world_position: Vector3) -> void :
	var target: = Vector3(world_position.x, camera_rig.position.y, world_position.z)
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera_rig, "position", target, 0.35)
	camera_distance = clampf(camera_distance, 24.0, 62.0)
	_apply_camera()


func district_focus_profile(land_id: String) -> Dictionary:
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if land.is_empty():
		return {}
	var district_id: = str(land.get("district", ""))
	var plot_id: = str(land_to_plot.get(land_id, ""))
	var target_count: = 0
	for candidate: Dictionary in GameState.game_data.get("lands", {}).values():
		if str(candidate.get("district", "")) == district_id:
			target_count += 1
	return {
		"land_id": land_id, 
		"plot_id": plot_id, 
		"district_id": district_id, 
		"district_name": str(land.get("district_name", district_id)), 
		"target_count": target_count, 
	}


func _locate_selected_district() -> void :
	var profile: = district_focus_profile(selected_land_id)
	if profile.is_empty() or city_map_visual == null:
		return
	_select_district(str(profile.district_id), true, false)
	$UI / Toast.text = "已选择%s；再次点击街区按钮或按 Esc 可取消" % str(profile.district_name)
	AudioManager.click()


func _refresh_city_visuals() -> void :
	if city_map_visual == null:
		return



	if city_visuals_initialized and city_map_visual.has_method("reset_match_visuals"):
		city_map_visual.call("reset_match_visuals")
	city_visuals_initialized = true
	for land_id in land_to_plot.keys():
		var land: Dictionary = GameState.game_data.lands.get(str(land_id), {})
		if land.is_empty():
			continue
		var plot_id: = str(land_to_plot[str(land_id)])
		var player: = GameState.player(str(land.get("owner_id", "")))
		if not player.is_empty() and city_map_visual.has_method("apply_plot_owner"):
			city_map_visual.call("apply_plot_owner", plot_id, str(player.id), Color(str(player.color)), str(player.name), LandNames.display_name(land))

		var business: Dictionary = GameState.game_data.businesses.get(str(land.get("business_id", "")), {})
		if not business.is_empty():
			var visual_data: = _business_visual(business)
			if str(land.state) == "constructing" and city_map_visual.has_method("show_construction"):
				var construction := ConstructionProgressService.progress_snapshot(business, int(GameState.game_data.round))
				city_map_visual.call("show_construction", plot_id, visual_data, {
					"construction_remaining_rounds": int(construction.remaining_rounds),
					"construction_total_rounds": int(construction.base_rounds) + int(construction.delay_rounds)
				})
			elif str(land.state) in ["operating", "loss_watch", "mortgaged", "auction"] and city_map_visual.has_method("show_business"):
				city_map_visual.call("show_business", plot_id, visual_data)

		if bool(land.get("mortgaged", false)) and city_map_visual.has_method("show_business_feedback"):
			city_map_visual.call("show_business_feedback", plot_id, {"kind": "risk", "text": "抵押", "risk_delta": 8})
		if str(land.get("state", "")) == "auction" and city_map_visual.has_method("show_business_feedback"):
			city_map_visual.call("show_business_feedback", plot_id, {"kind": "risk", "text": "拍卖", "risk_delta": 12})
		if str(land.get("state", "")) == "loss_watch" and city_map_visual.has_method("show_business_feedback"):
			city_map_visual.call("show_business_feedback", plot_id, {"kind": "risk", "text": "亏损观察", "risk_delta": 10})
		var tutorial_visual: Dictionary = TutorialDirector.tutorial_visual(str(land_id))
		if not tutorial_visual.is_empty():
			var active: = GameState.active_player()
			var tutorial_color: = Color(str(active.get("color", "#2F6F8F"))) if not active.is_empty() else Color("2F6F8F")
			if str(tutorial_visual.get("kind", "")) in ["owned", "construction"] and city_map_visual.has_method("apply_plot_owner"):
				city_map_visual.call("apply_plot_owner", plot_id, "tutorial", tutorial_color, "教学资产")
			if str(tutorial_visual.get("kind", "")) == "construction" and city_map_visual.has_method("show_construction"):
				var demo_business: Dictionary = tutorial_visual.get("business", {})
				city_map_visual.call("show_construction", plot_id, _business_visual(demo_business), {
					"construction_remaining_rounds": int(demo_business.get("remaining_rounds", 1)), 
					"construction_total_rounds": int(demo_business.get("remaining_rounds", 1)), 
				})


func _business_visual(business: Dictionary) -> Dictionary:
	var type_id: = str(business.get("type_id", ""))
	var type_data: = GameConfig.by_id("business_types", type_id)
	var visual_type: String = {
		"convenience": "convenience_store", 
		"restaurant": "tea_shop", 
		"supermarket": "supermarket", 
		"entertainment": "entertainment", 
		"ecommerce": "live_ecommerce", 
		"logistics": "logistics", 
		"research": "ai_company", 
		"incubator": "creative_park", 
		"mall": "mall", 
		"financial_office": "finance_center", 
		"training": "education_center", 
		"clinic": "clinic"
		,"investment_bank_hq": "premium_spire"
		,"asset_management_center": "premium_twin"
		,"fintech_lab": "premium_crystal"
		,"data_exchange": "premium_terrace"
		,"cross_border_clearing": "premium_crown"
		,"international_convention": "premium_arc"
	}.get(type_id, "tea_shop")
	return {
		"name": str(business.get("name", type_data.get("name", ""))), 
		"visual_type": visual_type, 
		"visual_stage": 1, 
		"build_rounds": int(type_data.get("build_rounds", 1))
	}


func _select_land(next_land_id: String) -> void :
	var tutorial_route: Dictionary = TutorialDirector.route_action("select_land", {"land_id": next_land_id})
	if bool(tutorial_route.get("handled", false)) and not bool(tutorial_route.get("ok", false)):
		_clear_land_selection(false)
		_show_result(tutorial_route)
		return
	selected_land_id = next_land_id
	var land: Dictionary = GameState.game_data.get("lands", {}).get(next_land_id, {})
	_select_district(str(land.get("district", "")), false, false)
	side_collapsed = false
	AudioManager.click()
	_refresh_side()
	_animate_side_panel(true)
	_refresh_detail_toggle()

func _clear_land_selection(play_sound: = true, clear_district: = true) -> void :
	land_selection.clear()
	selected_land_id = ""
	if city_map_visual and city_map_visual.has_method("clear_selection"):
		city_map_visual.call("clear_selection")
	if clear_district:
		_clear_district_selection(false)
	$UI / Side.visible = false
	$UI / Ranking.visible = selected_district_id.is_empty()
	_refresh_detail_toggle()
	_animate_side_panel(false)
	if play_sound: AudioManager.click()


func _buy_selected() -> void :
	if not _human_action_allowed():
		return
	var active: = GameState.active_player()
	if active.is_empty() or selected_land_id.is_empty():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("buy_land", {"player_id": str(active.id), "land_id": selected_land_id})
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		if bool(tutorial_route.get("ok", false)):
			_show_plot_feedback(selected_land_id, "教学购入（未写入对局）", 0)
			_refresh_city_visuals()
			_refresh_side()
		return
	if $UI.has_node("LandPurchaseDialog"):
		return
	var dialog: = LandPurchaseDialogScene.new()
	dialog.open_purchase(str(active.id), selected_land_id)
	dialog.purchase_confirmed.connect(_complete_land_purchase)
	$UI.add_child(dialog)


func _complete_land_purchase(player_id: String, land_id: String) -> void :
	var result: = Businesses.buy_land(player_id, land_id)
	if bool(result.ok):
		AudioManager.buy_land()
	_show_result(result)
	if bool(result.ok):
		_show_plot_feedback(land_id, "购入成功", - int(GameState.game_data.lands[land_id].price))


func _open_build() -> void :
	if not _human_action_allowed():
		return
	if selected_land_id.is_empty():
		return
	var gate: Dictionary = TutorialDirector.route_action("open_build", {"land_id": selected_land_id})
	if bool(gate.get("handled", false)) and not bool(gate.get("ok", false)):
		_show_result(gate)
		return
	var drawer: Node = load("res://scenes/BusinessBuildPanel.tscn").instantiate()
	drawer.land_id = selected_land_id
	drawer.tutorial_mode = bool(gate.get("handled", false)) and bool(gate.get("ok", false))
	drawer.business_chosen.connect( func(type_id: String) -> void :
		if not _human_action_allowed():
			drawer.queue_free()
			return
		if bool(drawer.tutorial_mode):
			var demo_result: Dictionary = TutorialDirector.route_action("build_business", {"player_id": str(GameState.active_player().get("id", "")), "type_id": type_id, "land_id": selected_land_id})
			_show_result(demo_result)
			if bool(demo_result.get("ok", false)):
				_show_plot_feedback(selected_land_id, "教学开工（未写入对局）", 0)
				_refresh_city_visuals()
				_refresh_side()
			return
		var active: = GameState.active_player()
		var result: = Businesses.build_business(str(active.id), selected_land_id, type_id)
		if bool(result.ok):
			AudioManager.build_start()
		_show_result(result)
		if bool(result.ok):
			_show_plot_feedback(selected_land_id, "施工启动", 0)
	)
	$UI.add_child(drawer)


func _assign_employee(slot: int) -> void :
	if not _human_action_allowed():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("talent_resolve", {"slot": slot})
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		return
	var active: = GameState.active_player()
	if active.is_empty() or selected_land_id.is_empty():
		return
	var land: Dictionary = GameState.game_data.lands[selected_land_id]
	var business: Dictionary = GameState.game_data.businesses.get(str(land.business_id), {})
	if business.is_empty():
		return
	if str(business.get("state", "")) not in ["operating", "constructing"]:
		$UI / Toast.text = "企业当前不可安排员工"
		return
	if $UI.has_node("EmployeeManagementDialog"):
		return
	var dialog: = EmployeeDialog.new()
	dialog.open_for_slot(str(active.id), str(business.id), slot)
	dialog.changed.connect(_show_result)
	$UI.add_child(dialog)


func _end_turn() -> void :
	if not _human_action_allowed():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("end_turn")
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		return
	AudioManager.click()
	if GameState.advance_turn():
		entry_sequence_generation += 1
		call_deferred("_run_turn_entry_sequence")
		return
	GameFlow.suspend_city_for_navigation({"kind": "round_summary"})
	Settlement.settle_round()
	GameFlow.open_round_summary()

func _show_turn_confirmation() -> void :
	if not _human_action_allowed():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("end_turn")
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		return
	var readiness: = Cards.can_end_turn(str(GameState.active_player().get("id", "")))
	if not bool(readiness.get("ok", false)):
		$UI / Toast.text = str(readiness.message)
		if not Cards.round_offer(str(GameState.active_player().get("id", ""))).is_empty(): _show_round_card_draft()
		else: _open_card_hand()
		return
	if $UI.has_node("TurnConfirm"): return
	AudioManager.click(); var shade: = ColorRect.new();shade.name = "TurnConfirm";shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color = Color(0.12, 0.17, 0.18, 0.62);shade.mouse_filter = Control.MOUSE_FILTER_STOP;shade.z_index = 300;shade.add_to_group("managed_modal_owner");$UI.add_child(shade)
	var turn_modal_token: = ModalManager.open_modal("turn_confirmation", shade, shade)
	shade.tree_exiting.connect( func() -> void : ModalManager.close_modal(turn_modal_token, "turn_confirmation_closed"))
	var is_final_round: = EndlessOperationsSystem.is_final_round()
	var final_notice: = Bank.final_debt_notice(str(GameState.active_player().get("id", ""))) if is_final_round else {}
	var has_final_debt: = int(final_notice.get("total_debt", 0)) > 0
	var panel: = PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.position = Vector2(-330, -285 if has_final_debt else -245);panel.size = Vector2(660, 570 if has_final_debt else 490);panel.add_theme_stylebox_override("panel", Styles.toy_panel());shade.add_child(panel)
	var body: = VBoxContainer.new();body.add_theme_constant_override("separation", 18);panel.add_child(body); var title: = Label.new();title.text = "确认结束本回合？";title.horizontal_alignment = 1;title.add_theme_font_size_override("font_size", 32);title.add_theme_color_override("font_color", Styles.TOY_INK);body.add_child(title)
	if has_final_debt:
		title.text = "终局债务清算警告"
	var s: Dictionary = TurnDirector.turn_summary(); var summary: = Label.new();summary.text = "本回合行动摘要\n\n土地  %d      建设  %d      卡牌  %d\n证券  %d      融资  %d" % [s.buy_land, s.build_business, s.card, s.stock, s.loan];summary.horizontal_alignment = 1;summary.add_theme_font_size_override("font_size", 21);summary.add_theme_color_override("font_color", Styles.TOY_INK);summary.add_theme_stylebox_override("normal", Styles.toy_card(Styles.TOY_BLUE, false));body.add_child(summary)
	var note: = Label.new();note.text = "确认后将依次播放 AI 财团行动快报，再进入结算。";note.horizontal_alignment = 1;note.add_theme_color_override("font_color", Styles.TOY_MUTED);body.add_child(note)
	if has_final_debt:
		summary.text = "未结贷款  %s     当前现金  %s     现金缺口  %s\n折价回收预估：土地企业 %s  证券 %s  项目 %s" % [
			Styles.money(int(final_notice.get("total_debt", 0))), Styles.money(int(final_notice.get("cash", 0))), Styles.money(int(final_notice.get("cash_shortfall", 0))), 
			Styles.money(int(final_notice.get("property_recovery", 0))), Styles.money(int(final_notice.get("stock_recovery", 0))), Styles.money(int(final_notice.get("project_recovery", 0))), 
		]
		note.text = "继续后先以现金强制清偿；不足时按 55% / 70% / 45% 处置全部可变现资产，仍不足的余额将作为负净值进入排名。"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions: = HBoxContainer.new();actions.alignment = BoxContainer.ALIGNMENT_CENTER;actions.add_theme_constant_override("separation", 18);body.add_child(actions)
	var cancel: = Button.new();cancel.text = "继续经营";cancel.custom_minimum_size = Vector2(190, 56);Styles.apply_toy_button(cancel, false, Styles.TOY_BLUE, 19);cancel.pressed.connect(shade.queue_free);actions.add_child(cancel)
	var confirm: = Button.new();confirm.text = "继续并执行终局清算" if has_final_debt else "确认结束  →";confirm.custom_minimum_size = Vector2(260 if has_final_debt else 220, 56);Styles.apply_toy_button(confirm, true, Styles.TOY_YELLOW, 19);confirm.pressed.connect( func() -> void : shade.queue_free();_end_turn());actions.add_child(confirm)

func _open_support(action: String, path: String) -> void :
	if not _human_action_allowed():
		return
	var reason: = TurnDirector.unavailable_reason(action)
	if not reason.is_empty(): $UI / Toast.text = reason;AudioManager.click();return
	GameFlow.open_city_system(path, {"system": action})


func _open_system(system_id: String, path: String) -> void :
	if not _human_action_allowed():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("scene_navigation", {"system": system_id})
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		return
	if TutorialDirector.active:
		var auxiliary_id: String = str({"talent": "talent_market", "stocks": "stock_market", "bank": "city_bank", "auction": "auction_center", "news": "news_center"}.get(system_id, ""))
		if auxiliary_id.is_empty() or not TutorialDirector.suspend_for_auxiliary(auxiliary_id):
			return
	GameFlow.open_city_system(path, {"system": system_id})


func _open_capital_market_deferred() -> void:
	# Never remove the city scene while an Area3D input callback is still being
	# dispatched.  Deferring one frame prevents the renderer/input use-after-free
	# observed when clicking the exchange landmark.
	if not EndlessOperationsSystem.is_enabled():
		$UI / Toast.text = "西岸资本市场仅在永续经营模式开放"
		AudioManager.click()
		return
	call_deferred("_open_system", "capital_market", "res://scenes/CapitalMarket.tscn")


func _open_card_hand() -> void :
	if not _human_action_allowed():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("scene_navigation", {"system": "cards"})
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		return
	var tutorial_cards: = TutorialDirector.active
	if tutorial_cards and not TutorialDirector.suspend_for_auxiliary("card_hand"):
		return
	if $UI.has_node("CardHandOverlay"):
		$UI / CardHandOverlay.queue_free()
		return


	var reason: = "" if tutorial_cards else TurnDirector.unavailable_reason("cards")
	if not reason.is_empty():
		$UI / Toast.text = reason
		AudioManager.click()
		return
	var overlay: Control = CardHandOverlayScene.instantiate()
	overlay.name = "CardHandOverlay"
	if tutorial_cards:
		overlay.closed.connect( func() -> void : TutorialDirector.call_deferred("resume_from_auxiliary", "card_hand"))
	$UI.add_child(overlay)


func _open_startup() -> void :
	if not _human_action_allowed():
		return
	var tutorial_route: Dictionary = TutorialDirector.route_action("scene_navigation", {"system": "startup"})
	if bool(tutorial_route.get("handled", false)):
		_show_result(tutorial_route)
		return
	if TutorialDirector.active:
		if not TutorialDirector.suspend_for_auxiliary("startup_center"):
			return
		GameFlow.open_city_system("res://scenes/StartupPitchEvent.tscn", {"system": "startup"})
		return
	if not Startups.is_event_round():
		var next_round: = Startups.next_event_round()
		$UI / Toast.text = "本局创投项目已结束" if next_round < 0 else "创投项目将在第 %d 回合开放" % next_round
		AudioManager.click()
		return
	GameFlow.open_city_system("res://scenes/StartupPitchEvent.tscn", {"system": "startup"})

func _action_label(action: String) -> String: return {"news": "查看市场情报", "land": "购买一块地", "build": "建设企业", "cards": "发动策略卡", "end_turn": "确认结束回合"}.get(action, "自由经营")

func _highlight_recommended(action: String) -> void :
	recommended_action = action
	var mapping: = {"news": $UI / Bottom / Actions / News, "land": $UI / Side / Scroll / Content / Buy, "build": $UI / Side / Scroll / Content / Build, "cards": $UI / Bottom / Actions / Cards, "end_turn": $UI / Bottom / Actions / EndTurn}
	for key in mapping:
		var button: Button = mapping[key];Styles.apply_toy_button(button, key == action, Styles.TOY_YELLOW if key == action else Styles.TOY_BLUE, 16)


func _run_ai_until_human() -> void :
	if ai_sequence_running:
		return
	ai_sequence_running = true
	_refresh_all()
	_ensure_ai_turn_presenter()
	ai_turn_presenter.call("reset_sequence_skip")
	while GameState.game_data.phase == "player_turn":
		var active: = GameState.active_player()
		if active.is_empty() or bool(active.human):
			break
		await ai_turn_presenter.call("begin_turn", active, AI.action_stages().size())
		for stage: String in AI.action_stages():
			var events: Array[Dictionary] = AI.execute_stage_events(str(active.id), stage)
			for event: Dictionary in events:
				var reaction: Dictionary = event.get("reaction", {})
				if bool(reaction.get("requires_reaction_choice", false)):
					var choice: String = await _show_capital_reaction(reaction)
					var final_result: Dictionary = Cards.play(str(event.player_id), str(event.card_id), str(event.target_id), choice)
					event.detail = "%s  %s" % [str(GameConfig.by_id("cards", str(event.card_id)).get("name", event.card_id)), str(final_result.get("message", "已结算"))]
				_refresh_all()
				await ai_turn_presenter.call("play_action", event)
		var brief: Array[String] = TurnDirector.ai_brief(str(active.id))
		await ai_turn_presenter.call("finish_turn", brief)
		if not GameState.advance_turn():
			break
	if GameState.game_data.phase == "settlement":
		ai_sequence_running = false
		GameFlow.suspend_city_for_navigation({"kind": "round_summary"})
		Settlement.settle_round()
		GameFlow.open_round_summary()
		return
	ai_sequence_running = false
	if is_inside_tree():
		_refresh_all()


func _show_capital_reaction(data: Dictionary) -> String:
	var window: = CapitalReactionWindowScene.new()
	$UI.add_child(window)
	window.open(data)
	return await window.resolved


func _ensure_ai_turn_presenter() -> void :
	if ai_turn_presenter != null and is_instance_valid(ai_turn_presenter):
		return
	ai_turn_presenter = AITurnPresenterScene.new()
	var replay_layer: = CanvasLayer.new()
	replay_layer.name = "AIReplayLayer"
	replay_layer.layer = 2100
	add_child(replay_layer)
	replay_layer.add_child(ai_turn_presenter)
	ai_turn_presenter.focus_land_requested.connect(_focus_ai_land)


func _focus_ai_land(land_id: String) -> void :
	var plot_id: = str(land_to_plot.get(land_id, ""))
	if plot_id.is_empty() or city_map_visual == null or not city_map_visual.has_method("get_plot_node"):
		return
	var plot: = city_map_visual.call("get_plot_node", plot_id) as Node3D
	if plot != null:
		_focus_camera_on_plot(plot.global_position)


func _show_turn_entry_prompts() -> void :
	var active: = GameState.active_player()
	if active.is_empty() or not bool(active.get("human", false)):
		return
	if _show_pending_card_notifications(str(active.id)):
		return
	if _show_forced_collection_alert(str(active.id)):
		return
	if not Cards.round_offer(str(active.id)).is_empty():
		_show_round_card_draft()
		return
	_show_debt_due_notice()


func _show_pending_card_notifications(player_id: String) -> bool:
	var notices: Array = Cards.pending_notices(player_id)
	if notices.is_empty():
		return false
	var lines: Array[String] = []
	for notice: Dictionary in notices:
		lines.append("◆ %s\n%s" % [str(notice.get("title", "策略战报")), str(notice.get("body", ""))])
	Cards.acknowledge_notices(player_id)
	GlobalFeedbackOverlay.show_notice("本轮策略攻防战报", "\n\n".join(lines), "确认战报并继续")
	return true


func _show_forced_collection_alert(player_id: String) -> bool:
	if $UI.has_node("ForcedCollectionAlert"):
		return true
	var alerts: Array = GameState.game_data.get("forced_collection_alerts", [])
	for alert: Dictionary in alerts:
		if str(alert.get("player_id", "")) != player_id or bool(alert.get("acknowledged", false)):
			continue
		if str(alert.get("status", "")) == "judicial_notice":
			continue
		var dialog: = ForcedCollectionAlertScene.new()
		dialog.open_alert(alert)
		dialog.acknowledged.connect( func(receipt: Dictionary) -> void :
			alert.acknowledged = true
			GameState._record(player_id, "forced_collection_acknowledged", receipt)
			call_deferred("_show_turn_entry_prompts"))
		$UI.add_child(dialog)
		return true
	return false


func _offer_auction_notice() -> void :
	if TutorialDirector.is_standalone_pending() or TutorialDirector.active or ModalManager.is_blocked():
		return
	var active_id: = str(GameState.active_player().get("id", ""))
	var pending: = AuctionNotices.pending_notices(active_id)
	if pending.is_empty() or $UI.has_node("AuctionEventNotice"):
		_refresh_auction_badge()
		return
	_show_auction_notice(pending[0])


func _show_auction_notice(notice: Dictionary) -> void :
	AuctionNotices.mark_seen(str(notice.key), str(GameState.active_player().get("id", "")))
	var shade: = ColorRect.new()
	shade.name = "AuctionEventNotice"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.018, 0.025, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 420
	shade.add_to_group("managed_modal_owner")
	$UI.add_child(shade)
	var auction_modal_token: = ModalManager.open_modal("auction", shade, shade)
	shade.tree_exiting.connect( func() -> void : ModalManager.close_modal(auction_modal_token, "auction_notice_closed"))
	var panel: = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -235)
	panel.size = Vector2(660, 470)
	panel.add_theme_stylebox_override("panel", Styles.toy_panel(Color("0b2633"), Color("d5aa4e")))
	shade.add_child(panel)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	panel.add_child(body)
	var kicker: = Label.new()
	kicker.text = "CITY AUCTION ALERT  第 %d 回合" % int(notice.round)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", Color("d9b85d"))
	body.add_child(kicker)
	var title: = Label.new()
	title.text = str(notice.get("title", "本轮新增竞拍事件"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("f4ead1"))
	body.add_child(title)
	var hammer: = Label.new()
	hammer.text = "▰  城市资产拍卖委员会  ▰"
	hammer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hammer.add_theme_font_size_override("font_size", 20)
	hammer.add_theme_color_override("font_color", Color("d6ad54"))
	body.add_child(hammer)
	var asset: = Label.new()
	asset.text = "%s\n起拍价  %s" % [str(notice.asset_name), Styles.money(int(notice.start_price))]
	asset.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asset.add_theme_font_size_override("font_size", 26)
	asset.add_theme_color_override("font_color", Color("eaf2f3"))
	asset.add_theme_stylebox_override("normal", Styles.toy_card(Color("173b48"), true))
	asset.custom_minimum_size = Vector2(0, 118)
	body.add_child(asset)
	var note: = Label.new()
	note.text = "暗标席位已经开放。所有财团提交后统一揭晓；若选择稍后查看，可随时从底部拍卖入口进入。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color("b8cbd0"))
	body.add_child(note)
	var actions: = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	body.add_child(actions)
	var later: = Button.new()
	later.text = "稍后查看"
	later.custom_minimum_size = Vector2(190, 58)
	Styles.apply_toy_button(later, false, Styles.TOY_BLUE, 18)
	later.pressed.connect(shade.queue_free)
	actions.add_child(later)
	var enter: = Button.new()
	enter.text = "立即前往拍卖中心"
	enter.custom_minimum_size = Vector2(250, 58)
	Styles.apply_toy_button(enter, true, Styles.TOY_YELLOW, 18)
	enter.pressed.connect( func() -> void :
		shade.queue_free()
		GameFlow.open_city_system("res://scenes/AuctionPanel.tscn", {"system": "auction_notice"}))
	actions.add_child(enter)
	_refresh_auction_badge()


func _show_round_card_draft() -> void :
	if not Authority.can_open_turn_modal(GameState.game_data, ai_sequence_running):
		return
	if $UI.has_node("RoundCardDraftDialog"):
		return
	var active: = GameState.active_player()
	if active.is_empty() or Cards.round_offer(str(active.id)).is_empty():
		_show_debt_due_notice()
		return
	var dialog: = RoundCardDraftDialog.new()
	dialog.open_for_player(str(active.id))
	dialog.card_chosen.connect( func(result: Dictionary) -> void :
		_show_result(result)
		var player: = GameState.active_player()
		if not player.is_empty() and not Cards.round_offer(str(player.id)).is_empty():
			call_deferred("_show_round_card_draft")
		elif not player.is_empty() and player.get("hand", []).size() > 5:
			$UI / Toast.text = "手牌已超过 5 张，请选择要弃置并转化为积分的卡牌"
			call_deferred("_open_card_hand")
		else:
			call_deferred("_show_debt_due_notice")
	)
	$UI.add_child(dialog)


func _show_debt_due_notice() -> void :
	if not Authority.can_open_turn_modal(GameState.game_data, ai_sequence_running):
		return
	if $UI.has_node("DebtDueDialog"):
		return
	var active: = GameState.active_player()
	if active.is_empty():
		return
	var notice: = Bank.round_payment_notice(str(active.id))
	if int(notice.get("total_due", 0)) <= 0 or int(active.get("debt_notice_round", -1)) == int(GameState.game_data.round):
		return
	active.debt_notice_round = int(GameState.game_data.round)
	var dialog: = DebtDueDialog.new()
	dialog.open_notice(notice)
	dialog.open_bank.connect( func() -> void : GameFlow.open_city_system("res://scenes/BankPanel.tscn", {"system": "debt_notice"}))
	$UI.add_child(dialog)


func _show_startup_result_notice() -> void :
	if not Authority.can_open_turn_modal(GameState.game_data, ai_sequence_running):
		return
	if $UI.has_node("StartupResultDialog"):
		return
	var active: = GameState.active_player()
	if active.is_empty():
		return
	var notice: = Startups.pop_result_notice(str(active.id))
	if notice.is_empty():
		return
	var dialog: = StartupResultDialog.new()
	dialog.open_result(notice)
	$UI.add_child(dialog)


func _show_round_decision() -> void :
	if not Authority.can_open_turn_modal(GameState.game_data, ai_sequence_running):
		return
	if has_node("RoundDecisionDialog"):
		return
	var active: = GameState.active_player()
	if active.is_empty() or RoundDecisions.pending(str(active.id)).is_empty():
		return
	var dialog: = RoundDecisionDialogScene.new()
	dialog.open_for_player(str(active.id))
	dialog.completed.connect( func(result: Dictionary) -> void :
		_show_result(result)
		call_deferred("_run_turn_entry_sequence")
	)
	add_child(dialog)


func _show_result(result: Dictionary) -> void :
	$UI / Toast.text = str(result.message)
	$UI / Toast.scale = Vector2(0.92, 0.92)
	$UI / Toast.modulate = Color("f2c969") if bool(result.get("ok", false)) else Color("e46f70")
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property($UI / Toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($UI / Toast, "modulate", Color.WHITE, 0.7)
	_refresh_all()


func _show_plot_feedback(land_id: String, text: String, amount: int) -> void :
	var plot_id: = str(land_to_plot.get(land_id, ""))
	if not plot_id.is_empty() and city_map_visual.has_method("show_business_feedback"):
		city_map_visual.call("show_business_feedback", plot_id, {
			"kind": "opening" if amount == 0 else "profit", 
			"text": text, 
			"profit": amount, 
			"risk_delta": 0
		})


func _on_state_changed(_snapshot: Dictionary) -> void :
	if is_inside_tree():
		_refresh_all()


func _on_tutorial_visuals_changed() -> void :
	if is_inside_tree():
		_refresh_city_visuals()
		_refresh_side()
		if not TutorialDirector.active:
			$UI / Toast.text = ""


func _refresh_all() -> void :


	if not is_inside_tree():
		return
	_restore_authority_button_states()
	if city_map_visual and city_map_visual.has_method("set_match_time"):
		city_map_visual.call("set_match_time", int(GameState.game_data.round), int(GameState.game_data.round_limit))
	_refresh_city_visuals()
	var active: = GameState.active_player()
	if active.is_empty():
		return
	_set_hud_value(hud_metric_controls.cash, "cash", int(active.cash), "%s")
	var net_assets: = int(active.cash) + Businesses.estimate_assets(str(active.id)) + Stocks.market_value(str(active.id)) - int(active.debt)
	_set_hud_value(hud_metric_controls.assets, "assets", net_assets, "%s")
	_set_hud_value(hud_metric_controls.rank, "rank", int(active.rank), "#%d")
	_update_hud_metric_colors(int(active.risk))
	$UI / Bottom / Limits.text = "买地 自由   建设 自由   策略点 ◆%d/%d   秘策 %d/2   进攻 %d/1" % [int(active.get("strategy_points", 3)), int(active.get("strategy_points_max", 3)), active.get("secret_zone", []).size(), active.actions.get("attack_card", 0)]
	_refresh_tasks(active)
	_refresh_side()
	_refresh_ranking()
	_refresh_game_hud(active)
	_refresh_startup_action()
	_refresh_auction_badge()
	_refresh_strategy_dock_signal(active)
	_sync_turn_action_button_group()
	_apply_authority_button_lock()


func _refresh_all_staged_map() -> void :





	if not is_inside_tree():
		return
	_restore_authority_button_states()
	if city_map_visual and city_map_visual.has_method("set_match_time"):
		city_map_visual.call("set_match_time", int(GameState.game_data.round), int(GameState.game_data.round_limit))
	_refresh_city_visuals()
	get_tree().process_frame.connect(_refresh_all_staged_player, CONNECT_ONE_SHOT)


func _refresh_all_staged_player() -> void :
	if not is_inside_tree():
		return
	var active: = GameState.active_player()
	if active.is_empty():
		return
	_set_hud_value(hud_metric_controls.cash, "cash", int(active.cash), "%s")
	var net_assets: = int(active.cash) + Businesses.estimate_assets(str(active.id)) + Stocks.market_value(str(active.id)) - int(active.debt)
	_set_hud_value(hud_metric_controls.assets, "assets", net_assets, "%s")
	_set_hud_value(hud_metric_controls.rank, "rank", int(active.rank), "#%d")
	_update_hud_metric_colors(int(active.risk))
	_refresh_tasks(active)
	_refresh_side()
	get_tree().process_frame.connect(_refresh_all_staged_summary, CONNECT_ONE_SHOT)


func _refresh_all_staged_summary() -> void :
	if not is_inside_tree():
		return
	var active: = GameState.active_player()
	if active.is_empty():
		return
	_refresh_ranking()
	_refresh_game_hud(active)
	_refresh_startup_action()
	get_tree().process_frame.connect(_refresh_all_staged_finish, CONNECT_ONE_SHOT)


func _refresh_all_staged_finish() -> void :
	if not is_inside_tree():
		return
	var active: = GameState.active_player()
	if active.is_empty():
		return
	_refresh_auction_badge()
	_refresh_strategy_dock_signal(active)
	_sync_turn_action_button_group()
	_apply_authority_button_lock()
	GameFlow.notify_scene_input_ready("city")
	call_deferred("_run_turn_entry_sequence")


func _restore_authority_button_states() -> void :
	if not has_node("UI"):
		return
	for value: Node in get_tree().get_nodes_in_group("turn_action_button"):
		var button: = value as Button
		if button == null or not $UI.is_ancestor_of(button):
			continue
		if button.has_meta("authority_disabled_before_lock"):
			button.disabled = bool(button.get_meta("authority_disabled_before_lock"))
			button.remove_meta("authority_disabled_before_lock")


func _apply_authority_button_lock() -> void :
	if _human_action_allowed(false):
		return
	for value: Node in get_tree().get_nodes_in_group("turn_action_button"):
		var button: = value as Button
		if button == null or not $UI.is_ancestor_of(button) or button.has_meta("authority_disabled_before_lock"):
			continue
		button.set_meta("authority_disabled_before_lock", button.disabled)
		button.disabled = true


func _sync_turn_action_button_group() -> void :
	for value: Node in $UI.find_children("*", "Button", true, false):
		var button: = value as Button
		if button == null:
			continue
		if _button_belongs_to_modal(button):
			button.remove_from_group("turn_action_button")
			continue
		button.add_to_group("turn_action_button")


func _button_belongs_to_modal(button: Button) -> bool:
	if button.is_in_group("modal_action_button"):
		return true
	var cursor: Node = button
	while cursor != null and cursor != $UI:
		if cursor.is_in_group("managed_modal_surface") or cursor.is_in_group("managed_modal_owner"):
			return true
		cursor = cursor.get_parent()
	return false


func _refresh_auction_badge() -> void :
	var button: = $UI / Bottom / Actions / Auction as Button
	var count: = AuctionNotices.pending_notices().size()
	button.text = "\n\n拍卖 %d" % count if count > 0 else "\n\n拍卖"
	button.tooltip_text = "%d 宗新拍品等待查看" % count if count > 0 else "进入城市暗标拍卖中心"


func _refresh_startup_action() -> void :
	var button: = $UI / Bottom / Actions / Startup as Button
	var tutorial_open: = TutorialDirector.active and TutorialDirector.current_step_id() == "startup_review"
	var active: = Startups.is_event_round() or tutorial_open
	button.disabled = not active
	button.modulate = Color.WHITE if active else Color(0.7, 0.78, 0.82, 0.58)
	if active:
		button.text = "\n\n创投"
		button.tooltip_text = "教学尽调入口" if tutorial_open else "本回合项目投资窗口开放，项目列表固定"
	else:
		var next_round: = Startups.next_event_round()
		button.text = "\n\n创投预告"
		button.tooltip_text = "本局创投项目已结束" if next_round < 0 else "下一次创投项目：第 %d 回合" % next_round


func _refresh_tasks(active: Dictionary) -> void :
	var guide: Dictionary = TurnDirector.snapshot(); var steps: Array = guide.steps
	$UI / TaskPanel / Tasks / Title.text = "%s  第 %d 回合" % [guide.player, guide.round]
	$UI / TaskPanel / Tasks / Line1.text = "%s  %s" % ["✓" if steps[0].done else "○", steps[0].label]
	$UI / TaskPanel / Tasks / Line2.text = "%s  %s" % ["✓" if steps[1].done else "○", steps[1].label]
	$UI / TaskPanel / Tasks / Line3.text = "%s  %s" % ["✓" if steps[2].done else "○", steps[2].label]
	$UI / TaskPanel / Tasks / Hint.text = "推荐下一步：%s" % _action_label(str(guide.recommended))
	_highlight_recommended(str(guide.recommended))


func _refresh_side() -> void :
	_ensure_business_detail_labels()
	var has_selection: = not selected_land_id.is_empty()
	$UI / Side.visible = has_selection and not side_collapsed
	$UI / Ranking.visible = ( not has_selection or side_collapsed) and selected_district_id.is_empty()
	_refresh_district_summary()
	_refresh_detail_toggle()
	if not has_selection:
		return
	var land: Dictionary = GameState.game_data.lands[selected_land_id]
	var district: Dictionary = GameState.game_data.districts.get(str(land.district), {})
	var active: = GameState.active_player()
	var active_id: = str(active.get("id", ""))
	var active_control: = float(district.get("control", {}).get(active_id, 0.0)) * 100.0
	var controller_id: = str(district.get("dominant_id", district.get("leader_id", "")))
	var controller: = GameState.player(controller_id)
	var controller_name: = "暂无控制者" if controller.is_empty() else str(controller.name)
	var owner: = GameState.player(str(land.get("owner_id", "")))
	var owner_name: = "城市公共市场" if owner.is_empty() else str(owner.name)
	var site_name: String = str({
		"parking_redevelopment": "停车场更新用地", 
		"brownfield": "旧厂更新用地", 
		"unused_hardstand": "闲置硬地", 
		"courtyard_renewal": "庭院更新用地", 
		"waterfront_reserve": "滨水预留用地", 
	}.get(str(land.get("site_type", "")), "城市开发用地"))
	side.get_node("Title").text = "%s  %s" % [selected_land_id, land.district_name]
	side.get_node("Category").text = "◆ %s  %s\n开发类型：%s\n归属：%s\n热度 %.0f  你的控制 %.0f%%  %s" % [land.district_name, _state_name(str(land.state)), site_name, owner_name, float(district.get("heat", 100.0)), active_control, controller_name]
	side.get_node("Category").add_theme_color_override("font_color", Color(str(owner.get("color", "#61a9d0"))) if not owner.is_empty() else V7.BLUE)
	side.get_node("Locate").text = "定位 %s  高亮整个%s" % [selected_land_id, str(land.district_name)]
	side.get_node("Price").text = "%s  %s" % ["购买价格" if owner.is_empty() else "土地估值", Styles.money(int(land.price))]
	side.get_node("Return").text = "预计经营回报  +%d%%" % _land_expected_return(land)
	side.get_node("RiskLevel").text = "经营风险  %s" % _risk_stars(land)
	var district_card_count: int = GameState.game_data.get("district_effects", []).filter( func(effect: Dictionary) -> bool: return str(effect.get("district_id", "")) == str(land.district)).size()
	side.get_node("Environment").text = "区位  %s\n商圈卡牌影响 %d  地块归属 %s" % [" / ".join(_environment_labels(land.environment)), district_card_count, "公共市场" if str(land.owner_id).is_empty() else str(GameState.player(str(land.owner_id)).get("name", "未知财团"))]
	var tutorial_owned: = TutorialDirector.sandbox_owns_land(selected_land_id)
	side.get_node("Buy").visible = str(land.state) == "available" and not tutorial_owned
	side.get_node("Build").visible = tutorial_owned or (str(land.state) == "owned_empty" and str(land.owner_id) == active_id)
	side.get_node("Rename").visible = not tutorial_owned and str(land.owner_id) == active_id
	if side.get_node("Rename").visible:
		side.get_node("Rename").text = "编辑地名  %s" % LandNames.display_name(land)
	if tutorial_owned:
		side.get_node("Build").text = "教学：模拟建设企业"
		side.get_node("Category").text += "\n教学资产  模拟购入，不影响正式对局"
		side.get_node("Category").add_theme_color_override("font_color", Color("f2c85d"))
	else:
		side.get_node("Build").text = "建设企业"
	var business: Dictionary = GameState.game_data.businesses.get(str(land.business_id), {})
	side.get_node("Business").visible = not business.is_empty()
	side.get_node("BusinessLedger").visible = not business.is_empty()
	var owns_land := not active.is_empty() and str(land.get("owner_id", "")) == str(active.id)
	var demolish_button := side.get_node_or_null("Demolish") as Button
	if demolish_button != null:
		var demolition_quote := Businesses.demolition_quote(str(active.get("id", "")), selected_land_id)
		demolish_button.visible = EndlessOperationsSystem.is_enabled() and owns_land
		demolish_button.disabled = not bool(demolition_quote.get("ok", false))
		demolish_button.text = "拆除重建" if not demolish_button.disabled else "拆除重建  未满足条件"
		demolish_button.tooltip_text = str(demolition_quote.get("message", ""))
	var bank_sale_button := side.get_node_or_null("BankSale") as Button
	if bank_sale_button != null:
		var bank_quote := Businesses.bank_sale_quote(str(active.get("id", "")), selected_land_id)
		bank_sale_button.visible = EndlessOperationsSystem.is_enabled() and owns_land
		bank_sale_button.disabled = not bool(bank_quote.get("ok", false))
		bank_sale_button.text = "出售给银行" if not bank_sale_button.disabled else "出售给银行  未满足条件"
		bank_sale_button.tooltip_text = str(bank_quote.get("message", ""))
	side.get_node("Employee1").visible = not business.is_empty() and str(land.owner_id) == str(active.id)
	side.get_node("Employee2").visible = not business.is_empty() and str(land.owner_id) == str(active.id)
	if not business.is_empty():
		var detail: = asset_detail_profile(selected_land_id)
		if str(business.state) == "constructing":
			side.get_node("Business").text = "%s｜%s\n建设总回合 %d  已完成 %d  剩余回合 %d\n项目估值 %s" % [detail.business_name, detail.business_type, detail.construction_total, detail.construction_completed, detail.construction_remaining, Styles.money(int(detail.value))]
		else:
			side.get_node("Business").text = "%s｜%s\n%s  企业估值 %s" % [detail.business_name, detail.business_type, detail.state_name, Styles.money(int(detail.value))]
		side.get_node("BusinessLedger").text = _business_detail_text(business, owner_name)
		side.get_node("Employee1").text = _employee_text(business, 0)
		side.get_node("Employee2").text = _employee_text(business, 1)
		side.get_node("Employee1").disabled = str(business.state) not in ["operating", "constructing"]
		side.get_node("Employee2").disabled = str(business.state) not in ["operating", "constructing"]


func _open_land_rename() -> void :
	if selected_land_id.is_empty():
		return
	var active: = GameState.active_player()
	var land: Dictionary = GameState.game_data.get("lands", {}).get(selected_land_id, {})
	if active.is_empty() or str(land.get("owner_id", "")) != str(active.get("id", "")):
		$UI / Toast.text = "只能编辑自己的地块"
		return
	var dialog: = LandRenameDialogScene.new()
	dialog.open_for_land(str(active.id), selected_land_id)
	dialog.connect("land_name_saved", func(result: Dictionary) -> void :
		$UI / Toast.text = "%s  %s" % [str(result.get("name", selected_land_id)), str(result.get("message", "已更新"))]
		_refresh_city_visuals()
		_refresh_side()
	)
	$UI.add_child(dialog)


func asset_detail_profile(land_id: String) -> Dictionary:
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	if land.is_empty():
		return {}
	var owner: Dictionary = GameState.player(str(land.get("owner_id", "")))
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(str(land.get("business_id", "")), {})
	var business_type: Dictionary = GameConfig.by_id("business_types", str(business.get("type_id", ""))) if not business.is_empty() else {}
	var construction := ConstructionProgressService.progress_snapshot(business, int(GameState.game_data.round)) if str(business.get("state", "")) == "constructing" else {}
	var total_rounds: = int(construction.get("base_rounds", business_type.get("build_rounds", business.get("remaining_rounds", 0)))) + int(construction.get("delay_rounds", 0))
	var remaining_rounds: = int(construction.get("remaining_rounds", business.get("remaining_rounds", 0)))
	return {
		"land_id": land_id, 
		"district_name": str(land.get("district_name", "")), 
		"owner_name": "城市公共市场" if owner.is_empty() else str(owner.get("name", "未知财团")), 
		"business_name": str(business.get("name", "待建设企业")), 
		"business_type": _sector_name(str(business_type.get("sector", "property"))), 
		"state": str(business.get("state", land.get("state", "available"))), 
		"state_name": _state_name(str(business.get("state", land.get("state", "available")))), 
		"construction_total": total_rounds, 
		"construction_completed": maxi(0, total_rounds - remaining_rounds), 
		"construction_remaining": remaining_rounds, 
		"value": int(business.get("value", land.get("price", 0))), 
		"employees": business.get("employees", []).duplicate(), 
	}


func _sector_name(sector: String) -> String:
	return {
		"consumer": "消费服务", 
		"entertainment": "文娱商业", 
		"technology": "科技产业", 
		"logistics": "物流产业", 
		"property": "商业地产", 
		"finance": "金融办公", 
		"medical": "医疗服务", 
	}.get(sector, "城市企业")


func _refresh_ranking() -> void :
	var lines: Array[String] = ["企业价值榜"]
	var players: Array = GameState.game_data.players.duplicate()
	players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.asset_value) > int(b.asset_value))
	for i in range(players.size()):
		lines.append("#%d  %s  %s" % [i + 1, players[i].name, Styles.money(int(players[i].asset_value))])
	$UI / Ranking / Text.text = "\n".join(lines)


func _employee_text(business: Dictionary, slot: int) -> String:
	if str(business.get("state", "")) == "constructing":
		var construction_talent_id := str(business.employees[slot])
		if construction_talent_id.is_empty():
			return "施工位 %d  + 建设人才" % (slot + 1)
		var construction_talent := GameConfig.by_id("talents", construction_talent_id)
		var applied: bool = business.get("construction_talent_accelerators", []).has(construction_talent_id)
		return "施工位 %d  %s  %s" % [slot + 1, str(construction_talent.get("name", construction_talent_id)), "已加速一次" if applied else "待生效"]
	if str(business.get("state", "")) != "operating":
		return "员工位 %d  暂不可用" % (slot + 1)
	var talent_id: = str(business.employees[slot])
	if talent_id.is_empty():
		return "员工位 %d  + 安排" % (slot + 1)
	var talent: = GameConfig.by_id("talents", talent_id)
	return "员工位 %d  [%s] %s  %s" % [slot + 1, Talents.quality_name(str(talent.get("quality", "blue"))), str(talent.get("name", talent_id)), str(talent.get("role", "经营"))]


func _ensure_business_detail_labels() -> void :
	if side.has_node("BusinessLedger"):
		return
	var ledger: = Label.new()
	ledger.name = "BusinessLedger"
	ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger.add_theme_font_size_override("font_size", 15)
	ledger.add_theme_color_override("font_color", Color("d7e5e8"))
	ledger.add_theme_stylebox_override("normal", Styles.panel(Color(0.025, 0.09, 0.14, 0.94), Color("4e8994"), 10, 10))
	side.add_child(ledger)
	side.move_child(ledger, side.get_node("Business").get_index() + 1)
	var demolish := Button.new()
	demolish.name = "Demolish"
	demolish.text = "拆除重建"
	demolish.visible = false
	demolish.pressed.connect(_demolish_selected)
	V7.apply_button(demolish, false, Color("d3a854"), 15)
	side.add_child(demolish)
	side.move_child(demolish, side.get_node("Business").get_index() + 1)
	var bank_sale := Button.new()
	bank_sale.name = "BankSale"
	bank_sale.text = "出售给银行"
	bank_sale.visible = false
	bank_sale.pressed.connect(_sell_selected_to_bank)
	V7.apply_button(bank_sale, false, Color("64b8c8"), 15)
	side.add_child(bank_sale)
	side.move_child(bank_sale, demolish.get_index() + 1)
	side.move_child(ledger, bank_sale.get_index() + 1)


func _demolish_selected() -> void:
	var active := GameState.active_player()
	var quote := Businesses.demolition_quote(str(active.get("id", "")), selected_land_id)
	if not bool(quote.get("ok", false)):
		_show_result(quote)
		return
	var data: Dictionary = quote.get("data", {})
	var dialog := AssetActionConfirmDialogScene.new()
	dialog.configure("确认拆除企业", "%s将停止经营，企业估值 %s 不返还。拆除耗时 1 回合，完成后地块恢复为空地，可重新建设。" % [str(data.get("business_name", "现有企业")), Styles.money(int(data.get("business_value_lost", 0)))], "确认拆除", true)
	dialog.confirmed.connect(func() -> void:
		var result := Businesses.start_demolition(str(active.get("id", "")), selected_land_id)
		_show_result(result)
		_refresh_city_visuals()
		_refresh_side())
	$UI.add_child(dialog)


func _sell_selected_to_bank() -> void:
	var active := GameState.active_player()
	var quote := Businesses.bank_sale_quote(str(active.get("id", "")), selected_land_id)
	if not bool(quote.get("ok", false)):
		_show_result(quote)
		return
	var data: Dictionary = quote.get("data", {})
	var dialog := AssetActionConfirmDialogScene.new()
	dialog.configure("出售资产给银行", "土地与企业合计估值 %s\n银行按 60%% 回收，预计到账 %s。确认后资产立即移交且不可撤销。" % [Styles.money(int(data.get("gross_value", 0))), Styles.money(int(data.get("proceeds", 0)))], "确认出售  %s" % Styles.money(int(data.get("proceeds", 0))), true)
	dialog.confirmed.connect(func() -> void:
		var result := Businesses.sell_land_to_bank(str(active.get("id", "")), selected_land_id)
		_show_result(result)
		_refresh_city_visuals()
		_refresh_side())
	$UI.add_child(dialog)


func _business_detail_text(business: Dictionary, owner_name: String) -> String:
	if str(business.get("state", "")) == "constructing":
		return "经营档案｜%s\n尚未营业，完工后将记录收入、成本与人才贡献。" % owner_name
	var ledger: Dictionary = business.get("last_ledger", {})
	var lines: Array[String] = ["经营档案｜%s" % owner_name]
	if ledger.is_empty():
		lines.append("尚无结算记录  当前净收益 %s" % Styles.money(int(business.get("last_net", 0))))
	else:
		lines.append("营业收入 %s + 人才增益 %s" % [Styles.money(int(ledger.get("operating_revenue", 0))), Styles.money(int(ledger.get("talent_income", 0)))])
		lines.append("经营成本 %s - 人才节省 %s" % [Styles.money(int(ledger.get("fixed_cost", 0))), Styles.money(int(ledger.get("talent_cost_saving", 0)))])
		var complaint: Dictionary = ledger.get("complaint", {})
		if bool(complaint.get("occurred", false)):
			lines.append("客诉损失 %s  公关减免 %s" % [Styles.money(int(complaint.get("loss", 0))), Styles.money(int(complaint.get("reduction", 0)))])
		lines.append("本轮净收益 %s" % Styles.money(int(ledger.get("net", 0))))
	var employee_lines: Array[String] = []
	for talent_id: String in business.get("employees", []):
		if talent_id.is_empty():
			continue
		var talent: = GameConfig.by_id("talents", talent_id)
		var contribution: = ""
		for item: Dictionary in ledger.get("employee_contributions", []):
			if str(item.get("id", "")) == talent_id:
				contribution = "  %s" % str(item.get("contribution_text", ""))
				break
		employee_lines.append("[%s] %s｜%s%s" % [Talents.quality_name(str(talent.get("quality", "blue"))), str(talent.get("name", talent_id)), str(talent.get("effect", "")), contribution])
	lines.append("人才：暂无安排" if employee_lines.is_empty() else "人才：\n" + "\n".join(employee_lines))
	return "\n".join(lines)


func _state_name(value: String) -> String:
	return {
		"available": "待售", 
		"owned_empty": "待建设", 
		"constructing": "建设中", 
		"operating": "经营中", 
		"loss_watch": "亏损观察", 
		"mortgaged": "抵押中", 
		"auction": "拍卖中", 
		"government_locked": "政府锁定", 
		"closed": "已关闭", 
		"acquired": "已征收"
	}.get(value, value)


func _environment_labels(environment: Array) -> Array[String]:
	var labels: Array[String] = []
	for item in environment:
		var key: = str(item)
		labels.append({
			"technology": "科技", 
			"office": "办公", 
			"education": "教育", 
			"medical": "医疗", 
			"newtown": "新区", 
			"transport": "交通", 
			"commercial": "商业", 
			"government": "政务", 
			"finance": "金融", 
			"entertainment": "文娱", 
			"night_control": "夜间监管", 
			"oldtown": "老城", 
			"residential": "住宅", 
			"logistics": "物流"
		}.get(key, key))
	return labels


func _unhandled_input(event: InputEvent) -> void :
	if ModalManager.is_blocked():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if EndlessOperationsSystem.is_enabled() and _human_action_allowed():
			get_viewport().set_input_as_handled()
			_open_endless_cheat_dialog()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_drag_candidate = true
				dragging = false
				drag_distance = 0.0
				last_mouse = event.position
				pointer_hit_plot = false
			else:
				if left_drag_candidate and not dragging and not pointer_hit_plot:
					_clear_land_selection()
				left_drag_candidate = false
				dragging = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			last_mouse = event.position
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_clear_land_selection()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = maxf(24.0, camera_distance - 3.0)
			_apply_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = minf(62.0, camera_distance + 3.0)
			_apply_camera()
	elif event is InputEventMouseMotion and (dragging or left_drag_candidate):
		var delta: Vector2 = event.position - last_mouse
		last_mouse = event.position
		drag_distance += delta.length()
		if drag_distance > 7.0:
			dragging = true
		if dragging:
			camera_rig.position += Vector3( - delta.x * 0.032, 0, - delta.y * 0.032)
			_clamp_camera_rig()
	elif event.is_action_pressed("ui_cancel"):
		_clear_land_selection()

func _process(delta: float) -> void :
	var move: = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_W): move.y -= 1.0
	if Input.is_key_pressed(KEY_S): move.y += 1.0
	move = move.limit_length(1.0)
	if move.length() > 0.1:
		camera_rig.position += Vector3(move.x, 0, move.y) * delta * 14.0
		_clamp_camera_rig()
	hud_clock += delta
	_refresh_city_time_hud()
	var guide_map: = {"news": $UI / Bottom / Actions / News, "land": $UI / Side / Scroll / Content / Buy, "build": $UI / Side / Scroll / Content / Build, "cards": $UI / Bottom / Actions / Cards, "end_turn": $UI / Bottom / Actions / EndTurn}
	if guide_map.has(recommended_action): guide_map[recommended_action].modulate = Color(1.0, 1.0, 1.0, 0.88 + sin(hud_clock * 3.0) * 0.12)
	var go: = get_node_or_null("UI/GameHUD/Go") as Button
	if go:
		go.scale = Vector2.ONE * (1.0 + sin(hud_clock * 3.0) * 0.035)

func _clamp_camera_rig() -> void :
	camera_rig.position.x = clampf(camera_rig.position.x, -120.0, 24.0)
	camera_rig.position.z = clampf(camera_rig.position.z, -19.0, 22.0)


func _apply_camera() -> void :
	camera.position = Vector3(0, camera_distance * 0.98, camera_distance * 0.68)
	camera.rotation_degrees = Vector3(-55, 0, 0)


func _style_ui() -> void :
	$UI / Side / Scroll / Content / Buy.text = "购买土地"
	$UI / Side / Scroll / Content / Build.text = "建设企业"
	$UI / Side / Scroll / Content / Locate.text = "在地图上定位街区"
	$UI / Side / Scroll / Content / Employee1.text = "员工位 1"
	$UI / Side / Scroll / Content / Employee2.text = "员工位 2"
	var bottom_labels: = {
		"Talent": "人才", 
		"News": "新闻", 
		"Startup": "创投", 
		"Auction": "拍卖", 
		"Cards": "手牌", 
		"Stocks": "证券", 
		"Bank": "银行", 
		"EndTurn": "结束回合"
	}
	for key in bottom_labels.keys():
		var button: = $UI / Bottom / Actions.get_node(key) as Button
		button.text = bottom_labels[key]
		button.custom_minimum_size = Vector2(104, 52) if key == "EndTurn" else Vector2(82, 52)
	$UI / Bottom / Limits.custom_minimum_size = Vector2(250, 0)
	$UI / Bottom / Actions.add_theme_constant_override("separation", 8)
	for panel_path in ["UI/HUDBack", "UI/TaskPanel", "UI/Ranking", "UI/Side"]:
		var panel: = get_node_or_null(panel_path) as PanelContainer
		if panel:
			panel.add_theme_stylebox_override("panel", V7.panel(Color(0.035, 0.12, 0.22, 0.94), V7.BLUE, 22, 9))
			_set_text_color_recursive(panel, V7.WHITE)
	await get_tree().process_frame
	for button in _ui_buttons():
		V7.apply_button(button, false, V7.BLUE, 16)
		button.mouse_entered.connect(AudioManager.hover)
	await get_tree().process_frame
	for hud_label in hud_metric_controls.values():
		hud_label.add_theme_color_override("font_color", V7.WHITE)
	$UI / Bottom / Limits.add_theme_color_override("font_color", V7.WHITE)
	$UI / Bottom / Limits.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	$UI / Bottom / Limits.add_theme_constant_override("outline_size", 5)
	$UI / Toast.add_theme_color_override("font_color", V7.WHITE)
	$UI / Toast.add_theme_color_override("font_outline_color", Color("07111f"))
	$UI / Toast.add_theme_constant_override("outline_size", 7)
	$UI / Side / Scroll / Content / Category.add_theme_color_override("font_color", V7.BLUE)
	$UI / Side / Scroll / Content / Return.add_theme_color_override("font_color", V7.GREEN)
	$UI / Side / Scroll / Content / RiskLevel.add_theme_color_override("font_color", V7.RED)


func _set_text_color_recursive(node: Node, color: Color) -> void :
	if node is Label:
		(node as Label).add_theme_color_override("font_color", color)
	for child in node.get_children():
		_set_text_color_recursive(child, color)


func _ui_buttons() -> Array[Button]:
	return [
		$UI / Side / Scroll / Content / Locate, $UI / Side / Scroll / Content / Buy, $UI / Side / Scroll / Content / Build, $UI / Side / Scroll / Content / Rename, $UI / Side / Scroll / Content / Employee1, $UI / Side / Scroll / Content / Employee2, 
		$UI / Bottom / Actions / Talent, $UI / Bottom / Actions / News, $UI / Bottom / Actions / Startup, $UI / Bottom / Actions / Auction, 
		$UI / Bottom / Actions / Cards, $UI / Bottom / Actions / Stocks, $UI / Bottom / Actions / Bank, $UI / Bottom / Actions / EndTurn
	]


func _land_expected_return(land: Dictionary) -> int:
	var best: = 0.0
	for business_type: Dictionary in GameConfig.list("business_types"):
		var multiplier: = 1.0
		if business_type.get("fit", []).has(str(land.district)):
			multiplier = 1.12
		elif business_type.get("avoid", []).has(str(land.district)):
			multiplier = 0.82
		var annual_net: = float(business_type.income) * multiplier - float(business_type.fixed_cost)
		var investment: = float(land.price) + float(business_type.cost)
		best = maxf(best, annual_net / maxf(1.0, investment) * 100.0)
	return clampi(roundi(best), 3, 25)


func _risk_stars(land: Dictionary) -> String:
	var risk: = 2
	if str(land.district) in ["entertainment", "oldtown"]:
		risk += 1
	if land.environment.has("government") or land.environment.has("night_control"):
		risk += 1
	risk = clampi(risk, 1, 5)
	return "★".repeat(risk) + "☆".repeat(5 - risk)


func _set_hud_value(label, key: String, value: int, pattern: String) -> void :
	if key in ["cash", "assets", "debt"]:
		label.text = pattern % _compact_hud_money(value)
	elif pattern.contains("%"):
		label.text = pattern % value
	else:
		label.text = pattern
	_fit_hud_value(label)
	if not last_hud_values.has(key):
		last_hud_values[key] = value
		return
	var previous: = int(last_hud_values[key])
	if previous == value:
		return
	last_hud_values[key] = value
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.1, 1.1)
	label.modulate = Color("79d88c") if (key != "rank" and value > previous) or (key == "rank" and value < previous) else Color("ef7777")
	if key == "rank":
		AudioManager.rank_change(1 if value < previous else -1)
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.55)


func _compact_hud_money(value: int) -> String:
	var prefix: = "-" if value < 0 else ""
	var amount: = absi(value)
	if amount >= 100000:
		return "%s%.0f亿" % [prefix, float(amount) / 10000.0]
	if amount >= 10000:
		return "%s%.1f亿" % [prefix, float(amount) / 10000.0]
	return "%s%d万" % [prefix, amount]


func _fit_hud_value(control: Control) -> void :
	var label: = control as Label
	if label == null:
		return
	var max_size: = int(label.get_meta("hud_max_font_size", 28))
	var min_size: = int(label.get_meta("hud_min_font_size", 16))
	var safe_width: = float(label.get_meta("hud_safe_width", maxf(72.0, label.custom_minimum_size.x)))
	var font: = label.get_theme_font("font")
	var chosen: = max_size
	while chosen > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > safe_width:
		chosen -= 1
	label.add_theme_font_size_override("font_size", chosen)


func _show_risk_detail() -> void :
	if not _human_action_allowed():
		return
	if $UI.has_node("RiskDetailPanel"):
		return
	var tutorial_risk: = TutorialDirector.active
	if tutorial_risk and not TutorialDirector.suspend_for_auxiliary("risk_detail"):
		return
	AudioManager.click()
	var panel: = RiskDetailPanelScene.new()
	panel.open_for_player(str(GameState.active_player().get("id", "")))
	$UI.add_child(panel)
	if tutorial_risk:
		panel.closed.connect( func() -> void :
			TutorialDirector.call_deferred("resume_from_auxiliary", "risk_detail"))


func _build_capital_metric_strip(compact: bool) -> void :
	var hud: = $UI / HUD as HBoxContainer
	hud.clip_contents = false
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 28 if compact else 42)
	var specs: Array[Dictionary] = [
		{"key": "cash", "node": "Cash", "index": 0, "color": Color("63d3ad"), "width": 156 if compact else 176, "value_size": 25 if compact else 28, "help": "现金｜用于买地、建设、创投、证券交易与偿债"}, 
		{"key": "assets", "node": "Assets", "index": 1, "color": Color("efc967"), "width": 190 if compact else 220, "value_size": 31 if compact else 35, "help": "净资产｜现金＋经营资产＋证券－负债，决定资本排名"}, 
		{"key": "rank", "node": "Rank", "index": 4, "color": Color("aeb8ff"), "width": 122 if compact else 140, "value_size": 25 if compact else 28, "help": "排名｜按实时净资产计算，数字越小越领先"}, 
	]
	for hidden_name in ["Debt", "Risk"]:
		var hidden: = hud.get_node_or_null(hidden_name) as Control
		if hidden != null:
			hidden.visible = false
	for spec_index in range(specs.size()):
		var spec: Dictionary = specs[spec_index]
		var control: = hud.get_node(str(spec.node)) as Control
		hud.remove_child(control)
		var cell: = HBoxContainer.new()
		cell.name = "Capital%s" % str(spec.node)
		cell.custom_minimum_size = Vector2(float(spec.width), 64)
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 8 if compact else 10)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.tooltip_text = "点击查看说明"
		cell.set_meta("metric_help", str(spec.help))
		cell.gui_input.connect(_on_hud_metric_input.bind(cell))
		hud.add_child(cell)
		var icon: = TextureRect.new()
		icon.name = "Icon"
		var atlas: = AtlasTexture.new()
		atlas.atlas = HUD_METRIC_ICONS
		atlas.region = Rect2(float(int(spec.index)) * 434.4, 0.0, 434.4, 724.0)
		icon.texture = atlas
		var icon_size: = 44 if str(spec.key) == "assets" and not compact else 39 if str(spec.key) == "assets" else 34 if compact else 37
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var safe_width: = float(spec.width) - float(icon_size) - (20.0 if compact else 24.0)
		control.custom_minimum_size = Vector2(safe_width, 42)
		control.clip_contents = true
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.add_theme_font_size_override("font_size", int(spec.value_size))
		control.add_theme_color_override("font_color", Color(spec.color))
		control.add_theme_color_override("font_outline_color", Color("06131f"))
		control.add_theme_constant_override("outline_size", 4)
		control.set_meta("hud_base_color", Color(spec.color))
		control.set_meta("hud_max_font_size", int(spec.value_size))
		control.set_meta("hud_min_font_size", 16 if compact else 18)
		control.set_meta("hud_safe_width", safe_width - 4.0)
		if control is Label:
			(control as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			(control as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			(control as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		elif control is Button:
			(control as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
			(control as Button).flat = true
		cell.add_child(control)
		hud_metric_controls[str(spec.key)] = control
		hud_metric_cells[str(spec.key)] = cell
		await get_tree().process_frame


func _on_hud_metric_input(event: InputEvent, cell: Control) -> void :
	var click: = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	_show_hud_metric_help(cell)
	cell.accept_event()


func _show_hud_metric_help(cell: Control) -> void :
	if hud_help_popup == null:
		hud_help_popup = PopupPanel.new()
		hud_help_popup.name = "CapitalMetricHelp"
		hud_help_popup.transparent_bg = true
		var margin: = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 13)
		margin.add_theme_constant_override("margin_bottom", 13)
		hud_help_popup.add_child(margin)
		hud_help_label = Label.new()
		hud_help_label.custom_minimum_size = Vector2(304, 32)
		hud_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hud_help_label.add_theme_font_size_override("font_size", 15)
		hud_help_label.add_theme_color_override("font_color", Color("eff7f5"))
		hud_help_label.add_theme_color_override("font_outline_color", Color("03101a"))
		hud_help_label.add_theme_constant_override("outline_size", 3)
		margin.add_child(hud_help_label)
		var bubble: = StyleBoxFlat.new()
		bubble.bg_color = Color(0.018, 0.075, 0.105, 0.985)
		bubble.border_color = Color("d6b85f", 0.88)
		bubble.set_border_width_all(1)
		bubble.set_corner_radius_all(12)
		bubble.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		bubble.shadow_size = 10
		hud_help_popup.add_theme_stylebox_override("panel", bubble)
		$UI.add_child(hud_help_popup)
	hud_help_label.text = str(cell.get_meta("metric_help", ""))
	var bubble_size: = Vector2i(340, 68)
	hud_help_popup.min_size = bubble_size
	var rect: = cell.get_global_rect()
	var viewport_size: = get_viewport().get_visible_rect().size
	var popup_x: = clampi(int(rect.get_center().x) - bubble_size.x / 2, 12, int(viewport_size.x) - bubble_size.x - 12)
	var popup_y: = mini(int(rect.end.y) + 8, int(viewport_size.y) - bubble_size.y - 12)
	hud_help_popup.popup(Rect2i(Vector2i(popup_x, popup_y), bubble_size))


func _update_hud_metric_colors(risk_value: int) -> void :
	var colors: = {
		"cash": Color("63d3ad"), "assets": Color("efc967"), "debt": Color("ed8a68"), 
		"risk": Color("61d4ac") if risk_value < 30 else Color("e4b85e") if risk_value < 60 else Color("ee6b72"), 
		"rank": Color("9aa9ff"), 
	}
	for key: String in colors:
		var control: = hud_metric_controls.get(key) as Control
		if control == null:
			continue
		control.add_theme_color_override("font_color", colors[key])
		control.set_meta("hud_base_color", colors[key])

func _build_mature_hud() -> void :
	var compact: bool = get_viewport().get_visible_rect().size.x < 1500.0
	ranking_compact = get_viewport().get_visible_rect().size.x <= 1366.0
	$UI / TaskPanel.visible = false
	$UI / Ranking / Text.visible = false
	$UI / HUDBack.anchor_left = 0.5
	$UI / HUDBack.anchor_right = 0.5
	$UI / HUDBack.offset_left = -335.0 if compact else -385.0
	$UI / HUDBack.offset_right = 335.0 if compact else 385.0
	$UI / HUDBack.offset_top = 12.0
	$UI / HUDBack.offset_bottom = 94.0
	$UI / HUDBack.clip_contents = false
	var clear_hud_back: = StyleBoxFlat.new()
	clear_hud_back.bg_color = Color.TRANSPARENT
	clear_hud_back.set_border_width_all(0)
	clear_hud_back.set_content_margin_all(0)
	$UI / HUDBack.add_theme_stylebox_override("panel", clear_hud_back)
	if not $UI / HUDBack.has_node("ExecutiveRibbon"):
		var ribbon: = CapitalHudRibbonScene.new()
		ribbon.name = "ExecutiveRibbon"
		ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		$UI / HUDBack.add_child(ribbon)
	await get_tree().process_frame
	$UI / HUD.anchor_left = 0.5
	$UI / HUD.anchor_right = 0.5
	$UI / HUD.offset_left = -310.0 if compact else -350.0
	$UI / HUD.offset_right = 310.0 if compact else 350.0
	$UI / HUD.offset_top = 18.0
	$UI / HUD.offset_bottom = 88.0
	$UI / HUD.add_theme_constant_override("separation", 14 if compact else 24)
	await _build_capital_metric_strip(compact)
	await get_tree().process_frame
	$UI / Bottom / Limits.visible = false
	$UI / Bottom.offset_left = 150.0
	$UI / Bottom.offset_top = -112.0
	$UI / Bottom.offset_right = -150.0
	$UI / Bottom / Actions.alignment = BoxContainer.ALIGNMENT_CENTER
	$UI / Bottom / Actions / EndTurn.visible = false
	var action_labels: = {
		"Talent": "\n\n人才", "News": "\n\n新闻", "Startup": "\n\n创投", "Auction": "\n\n拍卖", 
		"Cards": "\n\n策略", "Stocks": "\n\n证券", "Bank": "\n\n银行"
	}
	for key: String in action_labels:
		var button: = $UI / Bottom / Actions.get_node(key) as Button
		button.text = action_labels[key]
		button.custom_minimum_size = Vector2(84, 90) if compact else Vector2(98, 94)
		button.pivot_offset = Vector2(46, 74)
		button.add_theme_font_size_override("font_size", 14 if compact else 16)
		button.mouse_entered.connect(_hud_button_hover.bind(button, true))
		button.mouse_exited.connect(_hud_button_hover.bind(button, false))
		_decorate_action_button(button, key)
		await get_tree().process_frame
	await get_tree().process_frame
	var root: = Control.new()
	root.name = "GameHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(root)
	var quick_bar := HBoxContainer.new()
	quick_bar.name = "EndlessQuickBar"
	quick_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# 街区导航占用 y=98..156，快捷栏放在其下方的独立层，不再相互遮挡。
	quick_bar.position = Vector2(-214, 164)
	quick_bar.size = Vector2(428, 54)
	quick_bar.z_index = 35
	quick_bar.add_theme_constant_override("separation", 12)
	quick_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(quick_bar)
	for spec: Array in [["MyLands", "我的土地", "mine"], ["Cycle", "经济周期", "cycle"]]:
		var quick_button := Button.new()
		quick_button.name = str(spec[0])
		quick_button.text = str(spec[1])
		quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_button.custom_minimum_size = Vector2(208, 54)
		V7.apply_button(quick_button, str(spec[2]) == "mine", V7.GOLD if str(spec[2]) == "mine" else V7.BLUE, 14)
		if str(spec[2]) == "mine": quick_button.pressed.connect(_set_map_mode.bind("mine"))
		elif str(spec[2]) == "cycle": quick_button.pressed.connect(_show_economic_cycle)
		quick_bar.add_child(quick_button)
	var liquidation_button := LiquidationWarningButtonScene.new()
	liquidation_button.name = "VoluntaryLiquidation"
	liquidation_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# 全局音乐吉祥物固定在右上角；清算入口紧邻其左侧，不再与简洁
	# 模式或顶部信息条重叠。
	liquidation_button.position = Vector2(-150, 16)
	liquidation_button.visible = EndlessOperationsSystem.is_enabled()
	liquidation_button.pressed.connect(_open_voluntary_liquidation)
	root.add_child(liquidation_button)
	var turn_panel: = PanelContainer.new()
	turn_panel.name = "TurnPanel"
	turn_panel.position = Vector2(18, 18)
	turn_panel.size = Vector2(310, 314)
	turn_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	turn_panel.add_theme_stylebox_override("panel", V7.panel(Color(0.025, 0.105, 0.18, 0.97), V7.GOLD, 22, 5))
	root.add_child(turn_panel)
	var turn_box: = VBoxContainer.new();turn_box.name = "Box";turn_box.add_theme_constant_override("separation", 4);turn_panel.add_child(turn_box)
	for spec in [["Round", "当前财团", 29], ["CityTime", "07:30  清晨", 18], ["Index", "城市指数 1.00", 15], ["Actions", "买地 0/1  建设 0/1  用卡 0/2  攻击 0/1", 13]]:
		var label: = Label.new();label.name = spec[0];label.text = spec[1];label.clip_text = true;label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS;label.add_theme_font_size_override("font_size", spec[2]);label.add_theme_color_override("font_color", V7.GOLD if spec[0] == "Round" else V7.WHITE);turn_box.add_child(label)
	var game_date: = Label.new()
	game_date.name = "GameDate"
	game_date.text = "游戏时间  2026.01.01  周四"
	game_date.clip_text = true
	game_date.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	game_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_date.add_theme_font_size_override("font_size", 18)
	game_date.add_theme_color_override("font_color", Color("74d9e7"))
	game_date.add_theme_stylebox_override("normal", V7.panel(Color(0.02, 0.095, 0.13, 0.92), Color("58b9ca"), 12, 2))
	turn_box.add_child(game_date)
	var objective: = Label.new()
	objective.name = "Objective"
	objective.text = "本轮建议  查看市场情报后自由决策"
	objective.clip_text = true
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective.tooltip_text = objective.text
	objective.add_theme_font_size_override("font_size", 14)
	objective.add_theme_color_override("font_color", Color("efcf78"))
	turn_box.add_child(objective)
	var task_divider: = HSeparator.new();task_divider.name = "TaskDivider";task_divider.add_theme_constant_override("separation", 8);turn_box.add_child(task_divider)
	var mode_row: = HBoxContainer.new();mode_row.name = "MapModes";mode_row.add_theme_constant_override("separation", 5);turn_box.add_child(mode_row)
	for mode_spec in [["常规", "default"], ["收益", "heat"], ["控制", "control"], ["交通", "traffic"], ["我的", "mine"]]:
		var mode_button: = Button.new()
		mode_button.name = str(mode_spec[1]).capitalize()
		mode_button.text = str(mode_spec[0])
		mode_button.custom_minimum_size = Vector2(58, 28)
		mode_button.tooltip_text = {"default": "现代城市常规视图", "heat": "商圈热度与潜在收益", "control": "按财团归属着色", "traffic": "突出交通与物流区位", "mine": "高亮当前财团持有的全部土地"}.get(str(mode_spec[1]), "")
		V7.apply_button(mode_button, str(mode_spec[1]) == "default", V7.GOLD if str(mode_spec[1]) == "default" else V7.BLUE, 13)
		mode_button.pressed.connect(_set_map_mode.bind(str(mode_spec[1])))
		mode_row.add_child(mode_button)
	var operations: = Button.new()
	operations.name = "Operations"
	operations.text = "◆ 经营驾驶舱  本组全景"
	operations.clip_text = true
	operations.custom_minimum_size = Vector2(0, 42)
	operations.tooltip_text = "现金、净资产、负债、风险、上一轮资金流与 AI 经营建议"
	V7.apply_button(operations, true, Color("d8b45c"), 16)
	operations.pressed.connect(_show_operating_dashboard.bind("", true))
	turn_box.add_child(operations)
	var risk_monitor: = Button.new()
	risk_monitor.name = "RiskMonitor"
	risk_monitor.text = "◇ 风险监控  点击查看完整影响"
	risk_monitor.clip_text = true
	risk_monitor.custom_minimum_size = Vector2(0, 38)
	risk_monitor.tooltip_text = "查看当前风险分、等级、资产折价、授信影响与下一阈值"
	V7.apply_button(risk_monitor, false, Color("63c99b"), 15)
	risk_monitor.pressed.connect(_show_risk_detail)
	turn_box.add_child(risk_monitor)
	await get_tree().process_frame
	var heat_legend: = PanelContainer.new()
	heat_legend.name = "HeatLegend"
	heat_legend.position = Vector2(390, 158)
	heat_legend.size = Vector2(430, 54)
	heat_legend.visible = false
	heat_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_legend.add_theme_stylebox_override("panel", V7.panel(Color(0.025, 0.07, 0.12, 0.94), Color("d8b45c"), 16, 6))
	root.add_child(heat_legend)
	var legend_row: = HBoxContainer.new();legend_row.add_theme_constant_override("separation", 8);heat_legend.add_child(legend_row)
	var legend_title: = Label.new();legend_title.text = "收益潜力";legend_title.add_theme_font_size_override("font_size", 15);legend_title.add_theme_color_override("font_color", V7.WHITE);legend_row.add_child(legend_title)
	var gradient: = Gradient.new();gradient.colors = PackedColorArray([Color("2e6fb4"), Color("35b9c5"), Color("e2b84b"), Color("d94d45")]);gradient.offsets = PackedFloat32Array([0.0, 0.36, 0.68, 1.0])
	var texture: = GradientTexture1D.new();texture.gradient = gradient;texture.width = 256
	var strip: = TextureRect.new();strip.texture = texture;strip.custom_minimum_size = Vector2(205, 14);strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;strip.stretch_mode = TextureRect.STRETCH_SCALE;legend_row.add_child(strip)
	for word in ["低", "中", "高"]:
		var legend_label: = Label.new();legend_label.text = word;legend_label.add_theme_font_size_override("font_size", 13);legend_label.add_theme_color_override("font_color", V7.WHITE);legend_row.add_child(legend_label)
	var detail_toggle: = Button.new()
	detail_toggle.name = "DetailToggle"
	detail_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	detail_toggle.position = Vector2(-474, 320)
	detail_toggle.size = Vector2(104, 42)
	detail_toggle.visible = false
	detail_toggle.text = "收起详情"
	detail_toggle.tooltip_text = "折叠资产详情，归还地图观察空间"
	V7.apply_button(detail_toggle, false, V7.BLUE, 14)
	detail_toggle.pressed.connect(_toggle_side_detail)
	root.add_child(detail_toggle)
	battle_feed_panel = PanelContainer.new()
	battle_feed_panel.name = "BattleFeed"
	battle_feed_panel.position = Vector2(18, 344)
	battle_feed_panel.size = Vector2(310, 132)
	battle_feed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_feed_panel.add_theme_stylebox_override("panel", V7.panel(Color(0.018, 0.075, 0.125, 0.97), Color("4da7be"), 18, 4))
	root.add_child(battle_feed_panel)
	var feed_box: = VBoxContainer.new();feed_box.add_theme_constant_override("separation", 5);battle_feed_panel.add_child(feed_box)
	var feed_header: = HBoxContainer.new();feed_box.add_child(feed_header)
	var feed_title: = Label.new();feed_title.text = "城市脉冲  可核对战况";feed_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;feed_title.add_theme_font_size_override("font_size", 17);feed_title.add_theme_color_override("font_color", Color("f0c96d"));feed_header.add_child(feed_title)
	battle_feed_toggle = Button.new();battle_feed_toggle.text = "展开";battle_feed_toggle.custom_minimum_size = Vector2(58, 28);V7.apply_button(battle_feed_toggle, false, V7.BLUE, 12);battle_feed_toggle.pressed.connect(_toggle_battle_feed);feed_header.add_child(battle_feed_toggle)
	var feed_scroll: = ScrollContainer.new();feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;feed_box.add_child(feed_scroll)
	battle_feed_label = Label.new();battle_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;battle_feed_label.add_theme_font_size_override("font_size", 15);battle_feed_label.add_theme_color_override("font_color", Color("d5e4e8"));battle_feed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL;battle_feed_label.size_flags_vertical = Control.SIZE_EXPAND_FILL;feed_scroll.add_child(battle_feed_label)
	var go: = Button.new()
	go.name = "Go";go.text = "GO\n结束回合";go.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	go.position = Vector2(-142, -154);go.size = Vector2(124, 124);go.pivot_offset = Vector2(62, 62)
	go.add_theme_font_size_override("font_size", 24);go.add_theme_color_override("font_color", Color("fff7d6"))
	var go_normal: = V7.button(true, V7.GOLD);go_normal.set_corner_radius_all(62);go_normal.shadow_color = Color(V7.GOLD.r, V7.GOLD.g, V7.GOLD.b, 0.36);go_normal.shadow_size = 12
	var go_hover: = V7.button(true, V7.GOLD.lightened(0.12));go_hover.set_corner_radius_all(62);go_hover.shadow_color = Color(V7.GOLD.r, V7.GOLD.g, V7.GOLD.b, 0.55);go_hover.shadow_size = 18
	go.add_theme_stylebox_override("normal", go_normal);go.add_theme_stylebox_override("hover", go_hover);go.add_theme_stylebox_override("pressed", go_hover)
	go.pressed.connect(_show_turn_confirmation);go.mouse_entered.connect(AudioManager.hover);root.add_child(go)
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	var ranking_scroll: = ScrollContainer.new()
	ranking_scroll.name = "Scroll"
	ranking_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ranking_scroll.offset_left = 10.0
	ranking_scroll.offset_top = 68.0
	ranking_scroll.offset_right = -10.0
	ranking_scroll.offset_bottom = -10.0
	ranking_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$UI / Ranking.add_child(ranking_scroll)
	var rank_header: = Label.new();rank_header.name = "CapitalRankHeader";rank_header.position = Vector2(18, 12);rank_header.size = Vector2(276, 28);rank_header.text = "城市资本榜";rank_header.add_theme_font_size_override("font_size", 21);rank_header.add_theme_color_override("font_color", V7.GOLD);rank_header.mouse_filter = Control.MOUSE_FILTER_IGNORE;$UI / Ranking.add_child(rank_header)
	var rank_subtitle: = Label.new();rank_subtitle.name = "CapitalRankSubtitle";rank_subtitle.position = Vector2(18, 40);rank_subtitle.size = Vector2(276, 20);rank_subtitle.text = "净资产排名  点击席位查看经营档案";rank_subtitle.add_theme_font_size_override("font_size", 12);rank_subtitle.add_theme_color_override("font_color", Color("91b6c2"));rank_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE;$UI / Ranking.add_child(rank_subtitle)
	var rank_toggle: = Button.new();rank_toggle.name = "RankToggle";rank_toggle.position = Vector2(228, 11);rank_toggle.size = Vector2(70, 30);rank_toggle.text = "展开" if ranking_compact else "简洁";rank_toggle.tooltip_text = "切换资本榜简洁/完整状态";V7.apply_button(rank_toggle, false, V7.BLUE, 12);rank_toggle.pressed.connect(_toggle_ranking_compact);$UI / Ranking.add_child(rank_toggle)
	ranking_cards = VBoxContainer.new()
	ranking_cards.name = "Cards"
	ranking_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ranking_cards.add_theme_constant_override("separation", 7)
	ranking_scroll.add_child(ranking_cards)
	$UI / Ranking.offset_bottom = 390.0
	$UI / Ranking.add_theme_stylebox_override("panel", V7.panel(Color(0.022, 0.085, 0.15, 0.97), Color("4da7be"), 22, 5))
	await get_tree().process_frame
	_build_opportunity_radar(root)
	_build_intelligence_card_switcher(root)
	await get_tree().process_frame
	_build_district_legend()
	_animate_side_panel(false)
	_apply_resolution_profile()


func _build_intelligence_card_switcher(root: Control) -> void :
	var switcher: HBoxContainer = HBoxContainer.new();switcher.name = "CityIntelligenceCards";switcher.position = Vector2(18, 300);switcher.size = Vector2(310, 46);switcher.add_theme_constant_override("separation", 6);root.add_child(switcher)
	var specs: Array = [["驾驶舱", "cockpit", "◆"], ["城市情报", "intel", "▤"], ["机会雷达", "radar", "◇"]]
	for spec: Array in specs:
		var button: Button = Button.new();button.name = str(spec[1]).capitalize();button.text = "%s %s" % [spec[2], spec[0]];button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;button.custom_minimum_size = Vector2(0, 44);V7.apply_button(button, str(spec[1]) == "cockpit", V7.GOLD if str(spec[1]) == "cockpit" else V7.BLUE, 13);button.pressed.connect(_select_intelligence_card.bind(str(spec[1])));switcher.add_child(button)
	if battle_feed_panel != null: battle_feed_panel.visible = false
	if opportunity_radar_panel != null: opportunity_radar_panel.visible = false
	var turn_panel: Control = root.get_node_or_null("TurnPanel") as Control
	if turn_panel != null:
		turn_panel.size.y = 274
		var box: Node = turn_panel.get_node_or_null("Box")
		for key in ["CityTime", "Index", "Actions", "TaskDivider", "MapModes"]:
			var item: CanvasItem = box.get_node_or_null(key) as CanvasItem if box != null else null
			if item != null: item.visible = false


func _select_intelligence_card(kind: String) -> void :
	var root: Node = get_node_or_null("UI/GameHUD")
	if root == null: return
	var cockpit: Control = root.get_node_or_null("TurnPanel") as Control
	if cockpit != null: cockpit.visible = kind == "cockpit"
	if battle_feed_panel != null:
		battle_feed_panel.visible = kind == "intel";battle_feed_panel.position = Vector2(18, 354);battle_feed_panel.size = Vector2(310, 132 if not battle_feed_expanded else 252)
	if opportunity_radar_panel != null:
		var low: = get_viewport().get_visible_rect().size.y <= 768.0
		opportunity_radar_panel.visible = kind == "radar";opportunity_radar_panel.position = Vector2(18, 354);opportunity_radar_panel.size = Vector2(278 if low else 310, 176 if low else 204)
	var switcher: Node = root.get_node_or_null("CityIntelligenceCards")
	if switcher != null:
		for child: Node in switcher.get_children():
			if child is Button:
				var button: = child as Button
				V7.apply_button(button, button.name.to_lower() == kind, V7.GOLD if button.name.to_lower() == kind else V7.BLUE, 13)
	AudioManager.click()


func _decorate_action_button(button: Button, key: String) -> void :
	var old: = button.get_node_or_null("ActionBadge")
	if old != null:
		old.queue_free()
	var badge: = MapActionBadgeScene.new()
	badge.name = "ActionBadge"
	badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	badge.position = Vector2(-20.0, 4.0)
	badge.size = Vector2(40, 40)
	badge.setup(key, _action_color(key))
	button.add_child(badge)
	button.add_theme_color_override("font_color", Color("eef8f8"))
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.035, 0.72))
	button.add_theme_constant_override("outline_size", 3)


func _action_color(key: String) -> Color:
	return {
		"Talent": Color("7cc6f0"), 
		"News": Color("d2b35f"), 
		"Startup": Color("75d0a2"), 
		"Auction": Color("f0c35e"), 
		"Cards": Color("9fc2ff"), 
		"Stocks": Color("73d6dc"), 
		"Bank": Color("d8bd73"), 
	}.get(key, Color("61b9c8"))


func _refresh_strategy_dock_signal(active: Dictionary) -> void :
	var button: Button = $UI / Bottom / Actions / Cards
	var has_attack: bool = active.get("hand", []).any( func(card_id: Variant) -> bool: return str(GameConfig.by_id("cards", str(card_id)).get("type", "")) == "attack") and int(active.actions.get("attack_card", 0)) < 1
	var can_secret: bool = active.get("hand", []).any( func(card_id: Variant) -> bool: return str(GameConfig.by_id("cards", str(card_id)).get("type", "")) in ["defense", "counter"]) and active.get("secret_zone", []).size() < 2
	var ongoing: bool = not active.get("continuous_zone", []).is_empty()
	button.modulate = Color("fff0a8") if has_attack or can_secret or ongoing else Color.WHITE
	button.tooltip_text = "有可发动攻击或可部署秘策" if has_attack or can_secret else "持续策略即将触发" if ongoing else "查看策略手牌"


func _build_opportunity_radar(root: Control) -> void :
	opportunity_radar_panel = PanelContainer.new();opportunity_radar_panel.name = "OpportunityRadar";opportunity_radar_panel.position = Vector2(18, 488);opportunity_radar_panel.size = Vector2(310, 184);opportunity_radar_panel.clip_contents = true;opportunity_radar_panel.mouse_filter = Control.MOUSE_FILTER_STOP;opportunity_radar_panel.tooltip_text = "非强制提示，可完全忽略"
	opportunity_radar_panel.add_theme_stylebox_override("panel", V7.panel(Color(0.022, 0.085, 0.13, 0.96), Color("d6ad54"), 18, 4));root.add_child(opportunity_radar_panel)
	var box: = VBoxContainer.new();box.add_theme_constant_override("separation", 7);opportunity_radar_panel.add_child(box)
	var title: = Label.new();title.text = "机会雷达  非强制";title.add_theme_font_size_override("font_size", 16);title.add_theme_color_override("font_color", Color("f0c96d"));box.add_child(title)
	var scroll: = ScrollContainer.new();scroll.name = "RadarScroll";scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO;box.add_child(scroll)
	opportunity_radar_label = Label.new();opportunity_radar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL;opportunity_radar_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;opportunity_radar_label.add_theme_font_size_override("font_size", 13);opportunity_radar_label.add_theme_color_override("font_color", Color("d5e4e8"));opportunity_radar_label.add_theme_constant_override("line_spacing", 5);scroll.add_child(opportunity_radar_label)


static func responsive_profile_for_size(size: Vector2) -> Dictionary:
	var low: = size.x <= 1366.0 or size.y <= 768.0
	return {"low_resolution": low, "ranking_compact": low, "left_width": 278.0 if low else 310.0, "right_width": 280.0 if low else 312.0, "dock_button": Vector2(68, 62) if low else Vector2(92, 82), "safe_margin": 12.0 if low else 18.0, "map_minimum_ratio": 0.58 if low else 0.64}


static func intelligence_stack_profile_for_size(size: Vector2, expanded: bool) -> Dictionary:
	var low: = size.x <= 1366.0 or size.y <= 768.0
	var width: = 278.0 if low else 310.0
	var top: = 314.0 if low else 344.0
	var radar_height: = 176.0 if low else 204.0
	var bottom_safe: = size.y - (98.0 if low else 118.0)
	var maximum_feed: = maxf(110.0, bottom_safe - top - 10.0 - radar_height)
	var feed_height: = minf(194.0 if low else 252.0, maximum_feed) if expanded else (126.0 if low else 132.0)
	var radar_top: = top + feed_height + 10.0
	return {
		"feed_rect": Rect2(18.0, top, width, feed_height), 
		"radar_rect": Rect2(18.0, radar_top, width, radar_height), 
		"overlap": Rect2(18.0, top, width, feed_height).intersects(Rect2(18.0, radar_top, width, radar_height)), 
	}


func _layout_intelligence_stack() -> void :
	var layout: = intelligence_stack_profile_for_size(get_viewport().get_visible_rect().size, battle_feed_expanded)
	if battle_feed_panel != null:
		battle_feed_panel.position = layout.feed_rect.position
		battle_feed_panel.size = layout.feed_rect.size
	if opportunity_radar_panel != null:
		opportunity_radar_panel.position = layout.radar_rect.position
		opportunity_radar_panel.size = layout.radar_rect.size


func _apply_resolution_profile() -> void :
	if not $UI.has_node("GameHUD"): return
	var size: = get_viewport().get_visible_rect().size
	var profile: = responsive_profile_for_size(size)
	var low: = bool(profile.low_resolution)
	if low and not ranking_compact:
		ranking_compact = true
	var left_width: = float(profile.left_width)
	var turn_panel: = get_node_or_null("UI/GameHUD/TurnPanel") as Control
	if turn_panel: turn_panel.size.x = left_width;turn_panel.size.y = 248.0 if low else 274.0
	_layout_intelligence_stack()
	$UI / Ranking.offset_left = - float(profile.right_width) - float(profile.safe_margin)
	$UI / Ranking.offset_right = - float(profile.safe_margin)
	$UI / Ranking.offset_top = 74.0 if low else 92.0
	$UI / Side.offset_left = -310.0 if low else -370.0
	$UI / Side.offset_right = - float(profile.safe_margin)
	$UI / Bottom.offset_left = 112.0 if low else 150.0
	$UI / Bottom.offset_right = -112.0 if low else -150.0
	$UI / Bottom.offset_top = -86.0 if low else -112.0
	for key in ["Talent", "News", "Startup", "Auction", "Cards", "Stocks", "Bank"]:
		var button: = $UI / Bottom / Actions.get_node(key) as Button
		button.custom_minimum_size = profile.dock_button
		button.add_theme_font_size_override("font_size", 14 if low else 18)
	_refresh_rank_cards()


func _toggle_ranking_compact() -> void :
	ranking_compact = not ranking_compact
	var toggle: = $UI / Ranking.get_node_or_null("RankToggle") as Button
	if toggle: toggle.text = "展开" if ranking_compact else "简洁"
	_refresh_rank_cards();AudioManager.click()


func _build_district_legend() -> void :
	if $UI.has_node("DistrictLegend"):
		return
	var panel: = PanelContainer.new()
	panel.name = "DistrictLegend"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var compact: bool = get_viewport().get_visible_rect().size.x < 1500.0
	var panel_width: float = minf(1010.0, get_viewport().get_visible_rect().size.x - 660.0) if compact else 1010.0
	panel.position = Vector2( - panel_width * 0.5, 98)
	panel.size = Vector2(panel_width, 58)
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.065, 0.095, 0.94)
	style.border_color = Color("4c8797")
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	$UI.add_child(panel)
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var districts: = [
		["education", "教育培训", "L01–04", Color("d6a84b")], 
		["medical", "医疗服务", "L05–08", Color("69b8bd")], 
		["finance", "金融办公", "L09–12", Color("7897d8")], 
		["commercial", "商业街区", "L13–16", Color("d98a54")], 
		["residential", "住宅社区", "L17–20", Color("78aa69")], 
		["entertainment", "娱乐消费", "L21–24", Color("b77bc4")], 
		["waterfront", "滨水商务", "L25–28", Color("4da9b7")], 
		["west_finance", "西岸核心", "L29–44", Color("d8b45c")], 
	]
	var button_width: = (panel_width - 16.0 - 35.0) / 8.0 if compact else 116.0
	for district: Array in districts:
		var district_id: = str(district[0])
		var accent: Color = district[3]
		var button: = Button.new()
		button.name = "District_%s" % district_id
		button.text = "%s\n%s" % [str(district[1]), str(district[2])]
		button.custom_minimum_size = Vector2(button_width, 42)
		button.add_theme_font_size_override("font_size", 11 if compact else 14)
		button.clip_text = compact
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_color_override("font_color", Color("f4f0df"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.set_meta("district_id", district_id)
		button.set_meta("accent", accent)
		button.set_meta("base_text", "%s\n%s" % [str(district[1]), str(district[2])])
		button.tooltip_text = "点击聚焦%s；再次点击取消" % str(district[1])
		button.pressed.connect(_on_district_legend_pressed.bind(district_id))
		button.mouse_entered.connect(AudioManager.hover)
		row.add_child(button)
		district_buttons[district_id] = button
	panel.set_meta("compact", compact)
	_style_district_buttons()
	_build_district_summary()


func _build_district_summary() -> void :
	if $UI.has_node("DistrictSummary"):
		return
	var panel: = PanelContainer.new()
	panel.name = "DistrictSummary"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -438.0
	panel.offset_top = 172.0
	panel.offset_right = -18.0
	panel.offset_bottom = 478.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", V7.panel(Color(0.025, 0.1, 0.15, 0.97), V7.GOLD, 22, 10))
	$UI.add_child(panel)
	var margin: = MarginContainer.new()
	margin.name = "Body"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box: = VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var header: = HBoxContainer.new()
	header.name = "Header"
	box.add_child(header)
	var title: = Label.new()
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", V7.GOLD)
	header.add_child(title)
	var close: = Button.new()
	close.name = "Close"
	close.text = "关闭"
	close.custom_minimum_size = Vector2(76, 38)
	V7.apply_button(close, false, V7.BLUE, 15)
	close.pressed.connect(_clear_district_selection)
	header.add_child(close)
	for spec in [["Metrics", 17, V7.WHITE], ["Ownership", 16, Color("a9dce7")], ["Recommendation", 16, Color("f0cf75")], ["Effects", 15, Color("b8c8cf")]]:
		var label: = Label.new()
		label.name = spec[0]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", spec[1])
		label.add_theme_color_override("font_color", spec[2])
		box.add_child(label)


func _on_district_legend_pressed(district_id: String) -> void :
	_select_district(district_id, true, true)


func _on_map_district_selected(district_id: String) -> void :
	pointer_hit_plot = true
	_select_district(district_id, true, true)


func _select_district(district_id: String, focus_camera: = true, toggle: = true) -> void :
	if district_id.is_empty():
		return
	if toggle and selected_district_id == district_id:
		_clear_district_selection()
		return
	selected_district_id = district_id
	if city_map_visual and city_map_visual.has_method("set_selected_district"):
		city_map_visual.call("set_selected_district", district_id)
	if focus_camera and city_map_visual and city_map_visual.has_method("district_center"):
		if district_id == "west_finance":
			camera_distance = 58.0
		elif camera_distance > 52.0:
			camera_distance = 46.0
		_focus_camera_on_plot(city_map_visual.call("district_center", district_id))
	_style_district_buttons()
	_refresh_district_summary()
	$UI / Ranking.visible = false


func _clear_district_selection(play_sound: = true) -> void :
	selected_district_id = ""
	if city_map_visual and city_map_visual.has_method("clear_district_selection"):
		city_map_visual.call("clear_district_selection")
	_style_district_buttons()
	_refresh_district_summary()
	$UI / Ranking.visible = selected_land_id.is_empty() or side_collapsed
	if play_sound:
		AudioManager.click()


func _style_district_buttons() -> void :
	var compact: = bool($UI / DistrictLegend.get_meta("compact", false)) if $UI.has_node("DistrictLegend") else false
	for district_id: String in district_buttons:
		var button: = district_buttons[district_id] as Button
		var accent: Color = button.get_meta("accent")
		var selected: = district_id == selected_district_id
		var base_text: = str(button.get_meta("base_text", button.text))
		button.text = "✓ %s\n已聚焦  %s" % [base_text.get_slice("\n", 0), base_text.get_slice("\n", 1)] if selected else base_text
		button.add_theme_color_override("font_color", Color.WHITE if selected else Color("b8c5c5"))
		button.add_theme_font_size_override("font_size", (12 if selected else 11) if compact else (15 if selected else 14))
		for state in ["normal", "hover", "pressed"]:
			var badge: = StyleBoxFlat.new()
			var alpha: = 0.86 if selected else 0.12
			if state == "hover":
				alpha += 0.08
			badge.bg_color = Color(accent, alpha)
			badge.border_color = Color(accent.lightened(0.28) if selected else accent, 1.0 if selected else 0.62)
			badge.set_border_width_all(4 if selected else 2)
			badge.set_corner_radius_all(8)
			if selected:
				badge.shadow_color = Color(accent, 0.72)
				badge.shadow_size = 10
			button.add_theme_stylebox_override(state, badge)


func _refresh_district_summary() -> void :
	var panel: = get_node_or_null("UI/DistrictSummary") as PanelContainer
	if panel == null:
		return
	panel.visible = not selected_district_id.is_empty() and selected_land_id.is_empty()
	if not panel.visible:
		return
	var lands: Array[Dictionary] = []
	for land: Dictionary in GameState.game_data.get("lands", {}).values():
		if str(land.get("district", "")) == selected_district_id:
			lands.append(land)
	if lands.is_empty():
		return
	var name: = str(lands[0].get("district_name", selected_district_id))
	var available: = lands.filter( func(land: Dictionary) -> bool: return str(land.get("state", "")) == "available").size()
	var building: = lands.filter( func(land: Dictionary) -> bool: return str(land.get("state", "")) == "constructing").size()
	var operating: = lands.filter( func(land: Dictionary) -> bool: return str(land.get("state", "")) in ["operating", "loss_watch"]).size()
	var district: Dictionary = GameState.game_data.get("districts", {}).get(selected_district_id, {})
	var active: = GameState.active_player()
	var active_control: = float(district.get("control", {}).get(str(active.get("id", "")), 0.0)) * 100.0
	var controller: = GameState.player(str(district.get("dominant_id", district.get("leader_id", ""))))
	var recommendation: Array[Dictionary] = Recommendations.rank_for_land(lands[0])
	var recommended_names: Array[String] = []
	for item: Dictionary in recommendation.slice(0, 2):
		recommended_names.append("%s（净收益 %d 万）" % [str(item.business.get("name", "")), int(item.adjusted_net)])
	var effects: Array[String] = []
	for effect: Dictionary in GameState.game_data.get("district_effects", []):
		if str(effect.get("district_id", "")) == selected_district_id:
			effects.append(str(effect.get("name", effect.get("card_name", "策略影响"))))
	panel.get_node("Body/Content/Header/Title").text = name
	panel.get_node("Body/Content/Metrics").text = "地块 %d  待售 %d  建设中 %d  经营中 %d\n街区热度 %.0f" % [lands.size(), available, building, operating, float(district.get("heat", 100.0))]
	panel.get_node("Body/Content/Ownership").text = "当前控制：%s  你的控制 %.0f%%" % ["暂无控制者" if controller.is_empty() else str(controller.get("name", "")), active_control]
	panel.get_node("Body/Content/Recommendation").text = "真实区位建议：%s" % ("、".join(recommended_names) if not recommended_names.is_empty() else "暂无")
	panel.get_node("Body/Content/Effects").text = "生效策略：%s\n点击街区内任意地块查看价格、建设与企业详情" % ("、".join(effects) if not effects.is_empty() else "无")

func _refresh_game_hud(active: Dictionary) -> void :
	var box: = get_node_or_null("UI/GameHUD/TurnPanel/Box")
	if box:
		var players: Array = GameState.game_data.players.duplicate()
		players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.asset_value) > int(b.asset_value))
		var rank: = maxi(1, players.find(active) + 1)
		var round_label: = box.get_node("Round") as Label
		var cockpit_name: = str(active.name).replace("董事会", "").replace("资本", "").strip_edges()
		if cockpit_name.length() > 6: cockpit_name = cockpit_name.left(6)
		round_label.text = "%s  第%d回合 / 永续" % [cockpit_name, int(GameState.game_data.round)] if EndlessOperationsSystem.is_enabled() else "%s  %d/%d回合" % [cockpit_name, int(GameState.game_data.round), int(GameState.game_data.round_limit)]
		round_label.add_theme_font_size_override("font_size", 23)
		round_label.add_theme_color_override("font_color", Color(str(active.get("color", "#f0c76a"))).lightened(0.18))
		box.get_node("Index").text = "城市指数 %.2f  排名 #%d" % [1.0 + float(GameState.game_data.round - 1) * 0.025, rank]
		box.get_node("Index").add_theme_color_override("font_color", Color("9fd6e2"))
		box.get_node("Actions").text = "买地 自由   建设 自由   策略 %d/2   进攻 %d/1" % [active.actions.card, active.actions.get("attack_card", 0)]
		var game_date_label: = box.get_node_or_null("GameDate") as Label
		if game_date_label:
			game_date_label.text = _game_calendar_label(int(GameState.game_data.round))
		var objective_label: = box.get_node_or_null("Objective") as Label
		if objective_label:
			var radar_items: Array = GameState.game_data.get("opportunity_radar", [])
			var recommendation: = "查看市场情报后自由决策" if radar_items.is_empty() else str(radar_items[0].get("text", "查看市场情报后自由决策"))
			objective_label.text = "本轮建议  %s" % recommendation
			objective_label.tooltip_text = recommendation
		var risk_button: = box.get_node_or_null("RiskMonitor") as Button
		if risk_button:
			var risk_value: = int(active.get("risk", 0))
			var risk_profile: = Risks.profile(str(active.get("id", "")))
			risk_button.text = "风险监控  %d  %s" % [risk_value, str(risk_profile.get("tier", "稳健"))]
			V7.apply_button(risk_button, risk_value >= 60, Risks.tier_color(risk_value), 15)
	_refresh_city_time_hud()
	_refresh_battle_feed()
	_refresh_opportunity_radar()
	_refresh_rank_cards()
	_refresh_endless_quick_bar(active)


func _refresh_endless_quick_bar(active: Dictionary) -> void:
	var bar := get_node_or_null("UI/GameHUD/EndlessQuickBar") as HBoxContainer
	var liquidation := get_node_or_null("UI/GameHUD/VoluntaryLiquidation") as Button
	if liquidation:
		liquidation.visible = EndlessOperationsSystem.is_enabled() and GameState.is_human_turn() and not bool(active.get("eliminated", false))
	if bar == null:
		return
	bar.visible = EndlessOperationsSystem.is_enabled()
	if not bar.visible:
		return
	var mine := bar.get_node("MyLands") as Button
	mine.text = "我的土地  %d" % active.get("land_ids", []).size()
	mine.tooltip_text = "高亮当前财团持有的全部土地"
	var cycle := EndlessOperationsSystem.current_cycle()
	var cycle_button := bar.get_node("Cycle") as Button
	cycle_button.text = "经济周期  %s期" % str(cycle.get("name", "常态"))
	cycle_button.tooltip_text = "点击查看建设、创投与包装风险修正"


func _open_endless_cheat_dialog() -> void:
	if not EndlessOperationsSystem.is_enabled() or $UI.has_node("EndlessCheatDialog"):
		return
	var dialog := EndlessCheatDialogScene.new()
	dialog.open_for_player(str(GameState.active_player().get("id", "")))
	dialog.cheat_applied.connect(func(result: Dictionary) -> void:
		$UI / Toast.text = str(result.get("message", "无限权限已启用"))
		_refresh_all())
	$UI.add_child(dialog)


func _open_west_bank_institution(landmark_id: String) -> void:
	if not EndlessOperationsSystem.is_enabled() or not _human_action_allowed():
		$UI / Toast.text = "西岸机构玩法仅永续经营模式开放"
		return
	if $UI.has_node("WestBankInstitutionDialog") or $UI.has_node("WestBankEligibilityDialog"):
		return
	var player_id := str(GameState.active_player().get("id", ""))
	var access := WestBankInstitutions.eligibility(player_id)
	if not bool(access.get("ok", false)):
		var locked := WestBankEligibilityDialogScene.new()
		locked.name = "WestBankEligibilityDialog"
		locked.open(landmark_id, player_id, access)
		locked.closed.connect(func() -> void:
			call_deferred("_reset_pointer_navigation_state"))
		$UI.add_child(locked)
		return
	var dialog := WestBankInstitutionDialogScene.new()
	dialog.name = "WestBankInstitutionDialog"
	dialog.open(landmark_id, player_id)
	$UI.add_child(dialog)


func _open_voluntary_liquidation() -> void:
	if not EndlessOperationsSystem.is_enabled() or not _human_action_allowed():
		return
	if $UI.has_node("VoluntaryLiquidationDialog"):
		return
	var active := GameState.active_player()
	if active.is_empty():
		return
	var dialog := VoluntaryLiquidationDialogScene.new()
	dialog.open_for_player(str(active.get("id", "")))
	dialog.liquidation_completed.connect(func(_summary: Dictionary, solo: bool) -> void:
		call_deferred("_after_voluntary_liquidation", solo))
	$UI.add_child(dialog)


func _after_voluntary_liquidation(solo: bool) -> void:
	await get_tree().process_frame
	if solo or GameState.game_data.get("turn_order", []).is_empty():
		GameFlow.go("menu")
		return
	selected_land_id = ""
	_reset_pointer_navigation_state()
	_refresh_all()
	call_deferred("_run_turn_entry_sequence")


func _show_economic_cycle() -> void:
	if $UI.has_node("EconomicCycleDialog"):
		return
	var dialog := EconomicCycleDialogScene.new()
	dialog.name = "EconomicCycleDialog"
	$UI.add_child(dialog)


func _refresh_opportunity_radar() -> void :
	if opportunity_radar_label == null: return
	var items: Array = GameState.game_data.get("opportunity_radar", [])
	var lines: Array[String] = []
	for item: Dictionary in items.slice(0, 3): lines.append("%s %s" % [str(item.get("icon", "◇")), str(item.get("text", ""))])
	opportunity_radar_label.text = "本回合暂无高优先机会" if lines.is_empty() else "\n".join(lines)


func _refresh_city_time_hud() -> void :
	var label: = get_node_or_null("UI/GameHUD/TurnPanel/Box/CityTime") as Label
	if label == null or city_map_visual == null or not city_map_visual.has_method("city_time_snapshot"):
		return
	var snapshot: Dictionary = city_map_visual.call("city_time_snapshot")
	label.text = "%s  %s" % [str(snapshot.get("clock", "--:--")), str(snapshot.get("phase", ""))]
	var phase: = str(snapshot.get("phase", ""))
	label.add_theme_color_override("font_color", Color("f2c572") if phase in ["清晨", "黄昏"] else Color("b9d8ef") if phase == "夜晚" else Color("d9eef4"))


func _game_calendar_label(round_number: int) -> String:
	# 一回合对应七个经营日，保证读档、AI 和结算页看到的日期一致。
	const START_UNIX := 1767225600
	const DAY_SECONDS := 86400
	var date := Time.get_datetime_dict_from_unix_time(START_UNIX + maxi(0, round_number - 1) * 7 * DAY_SECONDS)
	var weekdays := ["日", "一", "二", "三", "四", "五", "六"]
	return "游戏时间  %04d.%02d.%02d  周%s" % [int(date.year), int(date.month), int(date.day), weekdays[int(date.weekday)]]

func _refresh_battle_feed() -> void :
	if battle_feed_label == null:
		return
	var entries: Array = GameState.game_data.get("battle_ledger", []).duplicate(true)
	entries.reverse()
	var competition_entries: Array = GameState.game_data.get("competition_feed", []).duplicate(true)
	competition_entries.reverse()
	var lines: Array[String] = []
	var active: = GameState.active_player()
	if not active.is_empty():
		var loan_summary: = Bank.loan_summary(str(active.id))
		if int(loan_summary.get("debt", 0)) > 0:
			lines.append("贷款  本金 %s  |  下期利息 %s" % [Styles.money(int(loan_summary.debt)), Styles.money(int(loan_summary.next_interest))])
		var projects: Array = []
		for project_value: Variant in active.get("active_projects", []):
			if project_value is Dictionary and str((project_value as Dictionary).get("status", "")) == "active":
				projects.append(project_value)
		if not projects.is_empty():
			var nearest: Dictionary = projects[0]
			lines.append("创投  %s  |  剩余 %d 回合" % [str(GameConfig.by_id("startup_projects", str(nearest.project_id)).get("name", nearest.project_id)), int(nearest.remaining_rounds)])
		var portfolio: = Stocks.portfolio_summary(str(active.id))
		if int(portfolio.get("position_count", 0)) > 0:
			lines.append("证券  持仓 %d 家  |  浮盈 %s%s" % [int(portfolio.position_count), "+" if int(portfolio.pnl) >= 0 else "", Styles.money(int(portfolio.pnl))])
	for entry: Dictionary in entries.slice(0, 7):
		lines.append(_battle_entry_text(entry))
	for entry: Dictionary in competition_entries.slice(0, 5):
		lines.append("竞争  %s" % str(entry.get("title", "对手采取经营行动")))
	var visible_count: = 8 if battle_feed_expanded else 3
	battle_feed_label.text = "本回合尚无关键行动" if lines.is_empty() else "\n".join(lines.slice(0, visible_count))

func _refresh_rank_cards() -> void :
	if ranking_cards == null: return
	for child in ranking_cards.get_children(): child.queue_free()
	var players: Array = GameState.game_data.players.duplicate()
	players.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.asset_value) > int(b.asset_value))
	var active: = GameState.active_player()
	var leader_value: = int(players[0].get("asset_value", 0)) if not players.is_empty() else 0
	var visible_players: Array = players
	if ranking_compact:
		visible_players = players.slice(0, mini(3, players.size()))
		if not active.is_empty() and not visible_players.any( func(item: Dictionary) -> bool: return str(item.get("id", "")) == str(active.get("id", ""))):
			visible_players.append(active)
	for player: Dictionary in visible_players:
		var real_rank: = players.find(player) + 1
		ranking_cards.add_child(_make_rank_card(player, real_rank, str(player.get("id", "")) == str(active.get("id", "")), leader_value))
	var ranking_panel: = get_node_or_null("UI/Ranking") as Control
	if ranking_panel:
		var desired_height: = clampf(78.0 + visible_players.size() * (76.0 if ranking_compact else 104.0), 250.0 if ranking_compact else 286.0, 390.0 if ranking_compact else 470.0)
		ranking_panel.offset_bottom = ranking_panel.offset_top + desired_height

func _make_rank_card(player: Dictionary, rank: int, is_active: bool, leader_value: int) -> Control:
	var panel: = Button.new();panel.custom_minimum_size = Vector2(254 if ranking_compact else 286, 68 if ranking_compact else 96);panel.flat = true;panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var color: = Color(str(player.color)); var accent: = V7.GOLD if is_active else color.lightened(0.1); var style: = V7.panel(Color(0.025, 0.105, 0.18, 0.98), accent, 16, 3);panel.add_theme_stylebox_override("normal", style);panel.add_theme_stylebox_override("hover", V7.panel(Color(0.045, 0.15, 0.235, 0.99), accent.lightened(0.16), 16, 6))
	panel.tooltip_text = "点击查看%s经营情况" % ("本组完整" if is_active else "对手公开")
	panel.pressed.connect(_show_operating_dashboard.bind(str(player.id), is_active))
	var row: = HBoxContainer.new();row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left = 10;row.offset_top = 9;row.offset_right = -10;row.offset_bottom = -9;row.mouse_filter = Control.MOUSE_FILTER_IGNORE;row.add_theme_constant_override("separation", 11);panel.add_child(row)
	var avatar: = Label.new();avatar.custom_minimum_size = Vector2(52, 64);avatar.text = ["♛", "✦", "◆"][rank - 1] if rank <= 3 else "%02d" % rank;avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;avatar.add_theme_font_size_override("font_size", 28 if rank <= 3 else 20);avatar.add_theme_color_override("font_color", [Color("f6d568"), Color("dce7ec"), Color("d69054")][rank - 1] if rank <= 3 else V7.WHITE);avatar.add_theme_stylebox_override("normal", V7.button(true, accent));row.add_child(avatar)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info: = VBoxContainer.new();info.mouse_filter = Control.MOUSE_FILTER_IGNORE;info.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(info)
	var title: = Label.new();title.text = "%s%s" % [str(player.name), "  ● 本组" if is_active else ""];title.add_theme_font_size_override("font_size", 18);title.add_theme_color_override("font_color", Color("fff0bd") if is_active else V7.WHITE);info.add_child(title)
	var gap: = maxi(0, leader_value - int(player.get("asset_value", 0))); var stats: = Label.new();stats.text = "净资产 %s%s" % [Styles.money(int(player.asset_value)), "  距榜首 %s" % Styles.money(gap) if rank > 1 else ""];stats.add_theme_font_size_override("font_size", 14);stats.add_theme_color_override("font_color", Color("6ed2df"));info.add_child(stats)
	if not ranking_compact:
		var detail: = Label.new();detail.text = "现金 %s   负债 %s   风险 %d" % [Styles.money(int(player.cash)), Styles.money(int(player.get("debt", 0))), int(player.get("risk", 0))];detail.add_theme_font_size_override("font_size", 12);detail.add_theme_color_override("font_color", Color("a9bec4"));info.add_child(detail)
	return panel


func _battle_entry_text(entry: Dictionary) -> String:
	var category: = str(entry.get("category", "城市"))
	var category_name: String = str({"event": "事件", "settlement": "结算", "loan": "贷款", "card": "卡牌", "business": "企业", "auction": "拍卖", "stock": "证券"}.get(category, "城市"))
	var details: Dictionary = entry.get("details", {})
	var active_id: = str(GameState.active_player().get("id", ""))
	if category == "event":
		var receipt: Dictionary = details.get("impact_receipt", {})
		if bool(receipt.get("negative", false)):
			for outcome: Dictionary in receipt.get("player_outcomes", []):
				if str(outcome.get("player_id", "")) != active_id:
					continue
				var status: = str(outcome.get("status", "unaffected"))
				var impact: = "未波及本组"
				if status == "blocked": impact = "本组能力已抵消"
				elif status == "applied": impact = str(outcome.get("details", ["负面效果已生效"])[0]) if not outcome.get("details", []).is_empty() else "负面效果已生效"
				return "%s  %s  |  %s" % [category_name, str(entry.get("title", "城市事件")), impact]
	if category == "settlement":
		var report: Dictionary = details.get("players", {}).get(active_id, {})
		if not report.is_empty():
			return "结算  现金 %+d 万  |  净资产 %+d 万  |  %s" % [int(report.get("cash_change", 0)), int(report.get("asset_change", 0)), "已对账" if bool(report.get("cash_audit", {}).get("balanced", true)) else "账目待核对"]
	var delta: = int(details.get("cash_delta", details.get("value", 0)))
	var suffix: = "  |  现金 %+d 万" % delta if delta != 0 else ""
	return "%s  %s%s" % [category_name, str(entry.get("title", "城市局势发生变化")), suffix]


func _toggle_battle_feed() -> void :
	battle_feed_expanded = not battle_feed_expanded
	_layout_intelligence_stack()
	if battle_feed_toggle != null:
		battle_feed_toggle.text = "收起" if battle_feed_expanded else "展开"
	_refresh_battle_feed()
	AudioManager.click()


func _show_operating_dashboard(target_player_id: = "", include_private: = true) -> void :
	if not _human_action_allowed():
		return
	if $UI.has_node("OperatingDashboard"):
		return
	var tutorial_context: = TutorialDirector.active
	if tutorial_context and not TutorialDirector.suspend_for_auxiliary("operating_dashboard"):
		return
	var resolved_id: = target_player_id
	if resolved_id.is_empty():
		resolved_id = str(GameState.active_player().get("id", ""))
	var panel: = OperatingDashboardScene.new()
	panel.open_for_player(resolved_id, include_private and resolved_id == str(GameState.active_player().get("id", "")))
	panel.set("tutorial_context", tutorial_context)
	if tutorial_context:
		panel.tree_exited.connect( func() -> void :
			TutorialDirector.call_deferred("resume_from_auxiliary", "operating_dashboard", "dashboard_reviewed"))
	$UI.add_child(panel)
	AudioManager.click()


func _set_camera_preset(distance: float) -> void :
	camera_distance = clampf(distance, 24.0, 62.0)
	var target_position: = Vector3(0, camera_distance * 0.98, camera_distance * 0.68)
	var tween: = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", target_position, 0.38)
	tween.tween_property(camera, "rotation_degrees", Vector3(-55, 0, 0), 0.38)
	AudioManager.click()


func _set_map_mode(next_mode: String) -> void :
	map_mode = next_mode if next_mode in ["default", "heat", "control", "traffic", "mine"] else "default"
	var payloads: = HeatScale.build_land_payloads(GameState.game_data.get("lands", {}), GameState.game_data.get("districts", {}))
	if city_map_visual and city_map_visual.has_method("set_visualization_mode"):
		city_map_visual.call("set_visualization_mode", "default" if map_mode == "mine" else map_mode, payloads)
	if city_map_visual and city_map_visual.has_method("set_owner_focus"):
		city_map_visual.call("set_owner_focus", str(GameState.active_player().get("id", "")) if map_mode == "mine" else "")
	var heat_legend: = get_node_or_null("UI/GameHUD/HeatLegend") as Control
	if heat_legend:
		heat_legend.visible = map_mode == "heat"
	var row: = get_node_or_null("UI/GameHUD/TurnPanel/Box/MapModes")
	if row:
		for button: Button in row.get_children():
			var selected: = button.name.to_lower() == map_mode
			V7.apply_button(button, selected, V7.GOLD if selected else V7.BLUE, 13)
	$UI / Toast.text = {"default": "常规城市视图", "heat": "收益潜力：蓝色偏低  青金适中  红色偏高", "control": "区域控制图：按财团归属着色", "traffic": "交通图：青色越亮，区位连接越强", "mine": "已高亮当前财团全部土地"}.get(map_mode, "常规城市视图")
	AudioManager.click()


func _toggle_side_detail() -> void :
	if selected_land_id.is_empty():
		return
	side_collapsed = not side_collapsed
	_refresh_side()
	AudioManager.click()


func _refresh_detail_toggle() -> void :
	var toggle: = get_node_or_null("UI/GameHUD/DetailToggle") as Button
	if toggle == null:
		return
	toggle.visible = not selected_land_id.is_empty()
	toggle.text = "展开详情" if side_collapsed else "收起详情"

func _hud_button_hover(button: Button, entered: bool) -> void :
	var tween: = create_tween();tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);tween.tween_property(button, "scale", Vector2(1.12, 1.12) if entered else Vector2.ONE, 0.14)

func _animate_side_panel(show: bool) -> void :
	var panel: = $UI / Side
	if show:
		panel.visible = true;panel.modulate.a = 0.0;panel.position.x += 42.0
		var tween: = create_tween().set_parallel(true);tween.tween_property(panel, "modulate:a", 1.0, 0.18);tween.tween_property(panel, "position:x", panel.position.x - 42.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		panel.visible = false
