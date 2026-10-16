extends Node3D

signal plot_selected(plot_data: Dictionary, plot_node: Node3D)
signal plot_focus_requested(world_position: Vector3)
signal plot_hovered(plot_data: Dictionary, plot_node: Node3D)
signal plot_unhovered(plot_data: Dictionary, plot_node: Node3D)
signal district_selected(district_id: String)
signal capital_exchange_requested
signal west_landmark_requested(landmark_id: String)

const LAND_PLOT_SCENE: = preload("res://scenes/CommercialLandPlot.tscn")
const CityAssetFactoryScript: = preload("res://scripts/CommercialCityAssetFactory.gd")
const MobilityRoutes: = preload("res://scripts/CityMobilityRoutes.gd")
const UrbanFabric: = preload("res://scripts/CityUrbanFabric.gd")
const WestBankLandmarkAssets: = preload("res://scripts/WestBankLandmarkAssets.gd")
const BUILDING_PATH: = "res://assets/models/buildings/%s.tscn"
const PROP_PATH: = "res://assets/models/props/%s.tscn"
const ROAD_PATH: = "res://assets/models/roads/%s.tscn"
const WorldBounds: = preload("res://scripts/CityWorldBounds.gd")
const Regions: = preload("res://scripts/RegionalEconomySystem.gd")
const MAX_VEHICLES: = 18
const MAX_PEDESTRIANS: = 30
const MAX_PARTICLES: = 72
const STALLED_RECOVERY_SECONDS: = 2.2
const KENNEY_COMMERCIAL: = "res://assets/third_party/kenney/commercial/Models/GLB format/"
const KENNEY_INDUSTRIAL: = "res://assets/third_party/kenney/industrial/Models/GLB format/"
const KENNEY_SUBURBAN: = "res://assets/third_party/kenney/suburban/Models/GLB format/"
const KENNEY_CAR_KIT: = "res://assets/third_party/kenney/car_kit/"
const KENNEY_CAR_COLORMAP: Texture2D = preload("res://assets/third_party/kenney/car_kit/Textures/colormap.png")
const METROPOLITAN_CITY_GROUND: = preload("res://assets/ui/city/metropolitan_ground_v915.png")
const WEST_BANK_FINANCIAL_GROUND: = preload("res://assets/ui/city/west_bank_financial_core_v154.png")
const REALTIME_DAY_SECONDS: = 720.0
const WEST_BANK_GROUND_BRIGHTNESS_LIFT := 0.11
const WEST_BANK_COOL_LIFT := Color(0.004, 0.010, 0.018, 1.0)
const WEST_BANK_FILL_COLOR := Color("8bd9ee")

var plots: Array[Node3D] = []
var plot_data_by_id: Dictionary = {}
var selected_plot: Node3D
var player_color: = Color(0.18, 0.46, 0.93, 1.0)
var placed_vehicle_keys: Dictionary = {}
var moving_agents: Array[Dictionary] = []
var city_time: = 0.27
var city_time_tick: = 0.0
var district_highlight_generation: = 0
var selected_district_id: = ""
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var practical_lights: Array[OmniLight3D] = []
var west_bank_fill_lights: Array[OmniLight3D] = []
var sun_body: MeshInstance3D
var moon_body: MeshInstance3D
var anchored_round: = -1


func setup(company_color: Color, round_number: = 1, round_limit: = 10) -> void :
	player_color = company_color
	placed_vehicle_keys.clear()
	moving_agents.clear()
	set_match_time(round_number, round_limit)
	_build_city_shell()
	_load_plots()
	set_process(true)


func setup_staged(company_color: Color, round_number: = 1, round_limit: = 10) -> void :
	player_color = company_color
	placed_vehicle_keys.clear()
	moving_agents.clear()
	set_process(false)
	set_match_time(round_number, round_limit)
	_build_day_night_system()
	_build_living_city_frame()
	await get_tree().process_frame
	await _build_urban_fabric_staged()
	_build_canonical_district_signs()
	_build_west_bank_financial_core()
	_build_city_wayfinding()
	await get_tree().process_frame
	await _build_dynamic_city_life_staged()
	await _load_plots_staged()
	set_process(true)


func _process(delta: float) -> void :
	city_time = fmod(city_time + delta / REALTIME_DAY_SECONDS, 1.0)
	city_time_tick += delta
	if city_time_tick >= 0.1:
		city_time_tick = 0.0
		_apply_time_of_day(city_time)
	for agent: Dictionary in moving_agents:
		if moving_agents.size() > 40 and int(agent.get("motion_seed", 0)) % 2 != Engine.get_process_frames() % 2:
			continue
		var node: = agent.get("node") as Node3D
		var route_nodes: Array = agent.get("route_nodes", [])
		if not is_instance_valid(node) or route_nodes.size() < 2:
			continue
		var pause_left: = maxf(0.0, float(agent.get("pause_left", 0.0)) - delta)
		agent.pause_left = pause_left
		var index: = int(agent.get("index", 0))
		var target_node: Dictionary = route_nodes[(index + 1) % route_nodes.size()]
		var kind: = str(agent.get("kind", ""))
		var target: = MobilityRoutes.node_position(target_node, 0.02 if kind == "vehicle" else 0.1)
		var offset: = target - node.position
		var target_action: = str(target_node.get("action", "cruise" if kind == "vehicle" else "walk"))
		var base_speed: = float(agent.get("speed", 1.0))
		var corner_factor: = clampf(offset.length() / (3.0 if kind == "vehicle" else 1.1), 0.24, 1.0)
		var desired_speed: = 0.0 if pause_left > 0.0 else base_speed * corner_factor
		if kind == "vehicle" and target_action == "turn":
			desired_speed *= 0.68
		elif kind == "vehicle" and target_action == "stop_line":
			desired_speed *= 0.52
		if kind == "vehicle":
			desired_speed *= _vehicle_clearance_factor(agent, node, offset)
		elif kind == "pedestrian":
			desired_speed *= _pedestrian_clearance_factor(agent, node, offset)
			if target_action == "crosswalk" and _vehicle_near_position(target, 1.35):
				desired_speed = 0.0
		var acceleration: = 4.8 if kind == "vehicle" else 2.4
		var current_speed: = move_toward(float(agent.get("current_speed", 0.0)), desired_speed, acceleration * delta)
		agent.current_speed = current_speed
		var travel: = current_speed * delta
		if kind == "vehicle" and travel > 0.0 and offset.length_squared() > 0.0001:
			var safe_travel: = _vehicle_safe_travel(agent, node, offset.normalized(), travel)
			if safe_travel < travel * 0.25:
				agent.current_speed = 0.0
				current_speed = 0.0
			travel = safe_travel
		elif kind == "pedestrian" and travel > 0.0 and offset.length_squared() > 0.0001:
			var safe_travel: = _pedestrian_safe_travel(agent, node, offset.normalized(), travel)
			if safe_travel < travel * 0.25:
				agent.current_speed = 0.0
				current_speed = 0.0
			travel = safe_travel
		if kind == "pedestrian" and travel > 0.0 and offset.length_squared() > 0.0001:
			var proposed_position: = target if offset.length() <= travel else node.position + offset.normalized() * travel
			if not MobilityRoutes.pedestrian_travel_is_valid(node.position, proposed_position) or not WorldBounds.is_valid_pedestrian_position(proposed_position):
				travel = 0.0
				agent.current_speed = 0.0
				current_speed = 0.0
		if offset.length() <= travel:
			node.position = target
			agent.index = (index + 1) % route_nodes.size()
			agent.state = target_action
			if kind == "vehicle" and target_action == "stop_line":
				agent.pause_left = 0.55 + float(int(agent.get("motion_seed", 0)) % 5) * 0.12
			elif kind == "pedestrian" and target_action == "wait_crossing":
				agent.pause_left = 0.75 + float(int(agent.get("motion_seed", 0)) % 4) * 0.18
			elif kind == "pedestrian" and target_action == "interact":
				agent.pause_left = 1.15 + float(int(agent.get("motion_seed", 0)) % 5) * 0.28
		else:
			var direction: = offset.normalized()
			node.position += direction * travel
			node.rotation.y = lerp_angle(node.rotation.y, motion_yaw_for_direction(direction), clampf(delta * (5.4 if kind == "vehicle" else 7.2), 0.0, 1.0))
		if kind == "pedestrian" and not WorldBounds.is_valid_pedestrian_position(node.position):
			node.position = MobilityRoutes.node_position(route_nodes[index], 0.1)
			agent.current_speed = 0.0
			current_speed = 0.0
		if kind == "vehicle":
			_track_vehicle_motion(agent, node, delta, target_action, pause_left)
			for wheel_value: Variant in agent.get("wheels", []):
				var wheel: = wheel_value as Node3D
				if is_instance_valid(wheel):
					wheel.rotate_z(current_speed * delta * 3.4)
			var body: = agent.get("body") as Node3D
			if is_instance_valid(body):
				body.rotation.z = lerpf(body.rotation.z, sin(float(agent.get("phase", 0.0))) * 0.012 * clampf(current_speed, 0.0, 1.0), clampf(delta * 4.0, 0.0, 1.0))
			for light_value: Variant in agent.get("brake_lights", []):
				var brake_light: = light_value as MeshInstance3D
				if is_instance_valid(brake_light):
					brake_light.visible = pause_left > 0.0 or target_action == "stop_line"
		elif kind == "pedestrian":
			var phase: = float(agent.get("phase", 0.0)) + delta * (4.2 + current_speed * 4.6)
			agent.phase = phase
			var movement_ratio: = clampf(current_speed / maxf(0.01, base_speed), 0.0, 1.0)
			node.position.y = float(agent.get("base_y", node.position.y)) + absf(sin(phase * 2.0)) * 0.034 * movement_ratio
			node.rotation.z = sin(phase) * 0.018 * movement_ratio
			var gait: = sin(phase) * 0.68 * movement_ratio
			if str(agent.get("state", "")) == "interact":
				gait = 0.0
			var arms: Array = agent.get("arms", [])
			var legs: Array = agent.get("legs", [])
			for limb_index in range(arms.size()):
				var arm: = arms[limb_index] as Node3D
				if is_instance_valid(arm):
					arm.rotation.x = float(agent.get("arm_base_%d" % limb_index, arm.rotation.x)) + gait * (1.0 if limb_index % 2 == 0 else -1.0)
			for limb_index in range(legs.size()):
				var leg: = legs[limb_index] as Node3D
				if is_instance_valid(leg):
					leg.rotation.x = float(agent.get("leg_base_%d" % limb_index, leg.rotation.x)) - gait * (1.0 if limb_index % 2 == 0 else -1.0)


func visual_quality_profile() -> Dictionary:
	return {
		"tone": "reference_metropolitan_top_down_city", 
		"renderer": "forward_plus_vulkan", 
		"compatibility_launcher": true, 
		"screen_space_ambient_occlusion": true, 
		"screen_space_indirect_lighting": true, 
		"screen_space_reflections": true, 
		"water_normal_layers": 3, 
		"fog_enabled": false, 
		"sun_energy": 0.72, 
		"exposure": 0.86, 
		"brightness": 0.91, 
		"contrast": 1.06, 
		"saturation": 1.03, 
		"daylight_clip_guard": true, 
		"night_readability_floor": 0.58, 
		"model_families": 42, 
		"ground_palette": [Color("30373a"), Color("c9c2b1"), Color("586a49"), Color("2c92a1")], 
	}


func visual_cohesion_profile() -> Dictionary:
	return {
		"ground_system": "metropolitan_reference_master", 
		"legacy_edge_strips": 0, 
		"perimeter_low_poly_strips": 0, 
		"plots_obscured_by_scenery": 0, 
		"plot_outline_contrast": 0.78, 
		"selected_district_emphasis": 0.86, 
		"unselected_district_dim": 0.42, 
		"scenery_clearance": 1.25, 
		"urban_fabric": "validated_native_3d_infill", 
	}


func mobility_ecology_profile() -> Dictionary:
	return {
		"vehicle_motion": "mapped_lane_accelerate_brake_signal_turn_wheel_roll", 
		"pedestrian_motion": "mapped_sidewalk_gait_crosswalk_wait_interact", 
		"desynchronized": true, 
		"plot_intersection": false, 
		"vehicle_overlap": false, 
		"same_lane_follow_distance": 2.95, 
		"intersection_emergency_distance": 0.95, 
		"route_source": "city_mobility_routes.json", 
	}


func performance_profile() -> Dictionary:
	return {"object_pooling": true, "vehicle_cap": MAX_VEHICLES, "pedestrian_cap": MAX_PEDESTRIANS, "particle_cap": MAX_PARTICLES, "far_update_divisor": 2, "active_agents": moving_agents.size()}


func time_of_day_profile(normalized_time: float) -> Dictionary:
	var t: = fposmod(normalized_time, 1.0)
	var daylight: = clampf((sin((t - 0.25) * TAU) + 0.1) * 0.9, 0.0, 1.0)
	var dusk: = clampf(1.0 - absf(t - 0.72) / 0.1, 0.0, 1.0)
	var dawn: = clampf(1.0 - absf(t - 0.25) / 0.09, 0.0, 1.0)
	var sky: = Color("263e60").lerp(Color("67afd0"), daylight)
	sky = sky.lerp(Color("d96f46"), maxf(dawn * 0.38, dusk * 0.66))
	var ambient_color: = Color("8da8c7").lerp(Color("dedbd1"), daylight)
	ambient_color = ambient_color.lerp(Color("d99368"), dusk * 0.46)
	return {
		"phase": "清晨" if t < 0.36 and t >= 0.18 else "白昼" if t < 0.68 and t >= 0.36 else "黄昏" if t < 0.8 and t >= 0.68 else "夜晚", 
		"daylight": daylight, 
		"sun_energy": maxf(lerpf(0.02, 1.05, daylight), dusk * 0.28), 
		"moon_energy": lerpf(0.42, 0.01, daylight), 
		"ambient_energy": maxf(lerpf(0.44, 0.55, daylight), lerpf(0.44, 0.50, dusk)), 
		"exposure": lerpf(0.88, 1.05, daylight), 
		"brightness": lerpf(0.9, 1.0, daylight), 
		"saturation": lerpf(0.91, 1.03, daylight), 
		"street_lights": daylight < 0.42, 
		"sky_color": sky, 
		"ambient_color": ambient_color, 
		"sun_color": Color("f09b62").lerp(Color("fff4dc"), daylight), 
	}


func set_match_time(round_number: int, round_limit: int) -> void :
	if round_limit <= 0:
		round_limit = 12
		round_number = ((maxi(1, round_number) - 1) % round_limit) + 1
	if round_number == anchored_round:
		return
	anchored_round = round_number
	var progress: = float(maxi(0, round_number - 1)) / float(maxi(1, round_limit - 1))
	city_time = lerpf(0.31, 0.91, clampf(progress, 0.0, 1.0))
	_apply_time_of_day(city_time)


func city_time_snapshot() -> Dictionary:
	var profile: = time_of_day_profile(city_time)
	var total_minutes: = posmod(roundi(city_time * 24.0 * 60.0), 24 * 60)
	profile["clock"] = "%02d:%02d" % [total_minutes / 60, total_minutes % 60]
	profile["normalized_time"] = city_time
	return profile


func ecology_profile() -> Dictionary:
	return {"vehicle_variants": 8, "pedestrian_variants": 4, "rendering": "native_3d_meshes_plus_imported_city_models", "vehicle_domain": "road_lane", "pedestrian_domain": "sidewalk", "day_cycle_seconds": int(REALTIME_DAY_SECONDS), "round_driven_time": true, "ecology_layers": ["traffic", "commuters", "housing", "retail", "finance_skyline", "medical_campus", "waterfront", "parks", "street_lights", "district_activity"]}


func urban_density_profile() -> Dictionary:
	return UrbanFabric.validate()


func motion_yaw_for_direction(direction: Vector3) -> float:

	return atan2( - direction.z, direction.x)


func path_respects_domain(kind: String, route: Dictionary) -> bool:
	return bool(MobilityRoutes.validate_route(route, kind).get("ok", false))


func select_next_plot(current_id: String) -> void :
	if plots.is_empty():
		return
	var index: = 0
	for i in range(plots.size()):
		if str(plots[i].data.get("id", "")) == current_id:
			index = (i + 1) % plots.size()
			break
	_select_plot(plots[index])


func select_plot_by_id(plot_id: String) -> void :
	for plot in plots:
		if str(plot.data.get("id", "")) == plot_id:
			_select_plot(plot)
			return


func clear_selection() -> void :
	if selected_plot:
		selected_plot.set_selected(false)
	for plot in plots:
		var in_district: = selected_district_id.is_empty() or str(plot.data.get("district", "")) == selected_district_id
		if plot.has_method("set_context_dimmed"):
			plot.set_context_dimmed( not in_district)
	selected_plot = null


func district_highlight_profile(district_id: String) -> Dictionary:
	var plot_ids: Array[String] = []
	for plot in plots:
		if str(plot.data.get("district", "")) == district_id:
			plot_ids.append(str(plot.data.get("id", "")))
	return {
		"district_id": district_id, 
		"plot_ids": plot_ids, 
		"target_count": plot_ids.size(), 
		"selected_emphasis": 0.86, 
		"context_weight": 0.42, 
	}


func set_selected_district(district_id: String) -> void :
	if district_id.is_empty():
		clear_district_selection()
		return
	if district_highlight_profile(district_id).get("target_count", 0) <= 0:
		return
	selected_district_id = district_id
	district_highlight_generation += 1
	for plot in plots:
		var in_district: = str(plot.data.get("district", "")) == district_id
		if plot.has_method("set_context_dimmed"):
			plot.set_context_dimmed( not in_district)
		if plot.has_method("set_district_focus"):
			plot.set_district_focus(in_district)


func clear_district_selection() -> void :
	selected_district_id = ""
	district_highlight_generation += 1
	for plot in plots:
		if plot.has_method("set_district_focus"):
			plot.set_district_focus(false)
		if plot.has_method("set_context_dimmed"):
			plot.set_context_dimmed(selected_plot != null and plot != selected_plot)


func set_owner_focus(owner_id: String) -> void:
	for plot in plots:
		var owned := not owner_id.is_empty() and str(plot.data.get("owner", "")) == owner_id
		if plot.has_method("set_context_dimmed"):
			plot.set_context_dimmed(not owner_id.is_empty() and not owned)
		if plot.has_method("set_district_focus"):
			plot.set_district_focus(owned)


func district_center(district_id: String) -> Vector3:
	var total: = Vector3.ZERO
	var count: = 0
	for plot in plots:
		if str(plot.data.get("district", "")) == district_id:
			total += plot.global_position
			count += 1
	return total / float(count) if count > 0 else Vector3.ZERO


func apply_plot_owner(plot_id: String, owner_id: String, color: Color, owner_name: = "", land_name: = "") -> void :
	var plot: = get_plot_node(plot_id)
	if plot:
		plot.set_company_owner(owner_id, color, owner_name, land_name)


func release_plot(plot_id: String) -> void :
	var plot: = get_plot_node(plot_id)
	if plot:
		plot.reset_match_state()


func reset_match_visuals() -> void :
	for plot in plots:
		plot.reset_match_state()


func set_wind_markets(markets: Array) -> void :
	for plot in plots:
		if plot.has_method("set_wind_focus"):
			plot.set_wind_focus(markets.has(str(plot.data.get("market_id", ""))))


func set_visualization_mode(mode: String, land_payloads: Dictionary) -> void :
	for plot in plots:
		if not plot.has_method("set_visualization_mode"):
			continue
		var land_id: = str(plot.data.get("land_id", ""))
		plot.set_visualization_mode(mode, land_payloads.get(land_id, {}))


func show_construction(plot_id: String, business_type: Dictionary, plot_state: Dictionary) -> void :
	var plot: = get_plot_node(plot_id)
	if plot:
		plot.show_construction(
			str(business_type.get("name", "")), 
			int(plot_state.get("construction_remaining_rounds", 0)), 
			int(plot_state.get("construction_total_rounds", 1))
		)


func show_business(plot_id: String, business_type: Dictionary) -> void :
	var plot: = get_plot_node(plot_id)
	if plot:
		plot.show_business(business_type)


func show_business_feedback(plot_id: String, feedback: Dictionary) -> void :
	var plot: = get_plot_node(plot_id)
	if plot:
		plot.show_feedback(feedback)


func apply_event_stream(events: Array, _companies_snapshot: = {}) -> void :
	var used_plots: Dictionary = {}
	for event in events:
		var plot_id: = str(event.get("plot_id", ""))
		var market_id: = str(event.get("market_id", ""))
		var target_plot: = get_plot_node(plot_id) if plot_id != "" else null
		if target_plot == null and market_id != "":
			target_plot = _first_plot_for_market(market_id, used_plots)
		if target_plot == null:
			continue
		used_plots[str(target_plot.data.get("id", ""))] = true
		var values: Dictionary = event.get("value_changes", {})
		target_plot.show_feedback({
			"kind": _feedback_kind_from_event(str(event.get("event_type", "")), str(event.get("result_type", ""))), 
			"text": _compact_event_text(event), 
			"profit": int(values.get("cash", 0)) + int(values.get("valuation", 0)), 
			"risk_delta": int(values.get("risk", 0)), 
			"risk_score": 35 if int(event.get("severity", 1)) >= 3 else 0
		})


func _first_plot_for_market(market_id: String, used_plots: Dictionary) -> Node3D:
	for plot in plots:
		if str(plot.data.get("market_id", "")) == market_id and not used_plots.has(str(plot.data.get("id", ""))):
			return plot
	for plot in plots:
		if str(plot.data.get("market_id", "")) == market_id:
			return plot
	return null


func _feedback_kind_from_event(event_type: String, result_type: String) -> String:
	if event_type in ["construction", "business_opening"]:
		return "construction" if event_type == "construction" else "opening"
	if result_type == "loss":
		return "loss"
	if result_type == "risk" or event_type in ["cash_crisis", "risk_warning", "card_attack"]:
		return "risk"
	return "profit"


func _compact_event_text(event: Dictionary) -> String:
	var values: Dictionary = event.get("value_changes", {})
	var cash: = int(values.get("cash", 0))
	var valuation: = int(values.get("valuation", 0))
	var risk: = int(values.get("risk", 0))
	if cash != 0:
		return "%+d万" % cash
	if valuation != 0:
		return "估值%+d" % valuation
	if risk != 0:
		return "风险%+d" % risk
	return str(event.get("short_text", "反馈")).left(8)


func get_plot_node(plot_id: String) -> Node3D:
	for plot in plots:
		if str(plot.data.get("id", "")) == plot_id:
			return plot
	return null


func get_plot_count() -> int:
	return plots.size()


func _build_city_shell() -> void :
	_build_day_night_system()
	_build_living_city_frame()
	_build_urban_fabric()
	_build_canonical_district_signs()
	_build_west_bank_financial_core()
	_build_city_wayfinding()
	_build_dynamic_city_life()


func _build_living_city_frame() -> void :


	_make_metropolitan_city_ground()
	_make_box("CityBoardFoundation", Vector3(0, -0.34, 0.4), Vector3(77.0, 0.4, 52.0), Color("20282b"))
	_make_west_bank_ground()


func _build_urban_fabric() -> void :
	var audit: = UrbanFabric.validate()
	if not bool(audit.get("ok", false)):
		push_error("Urban fabric clearance audit failed: %s" % "; ".join(audit.get("errors", [])))
		return
	for spec: Dictionary in UrbanFabric.placements():
		_place_urban_spec(spec)


func _build_urban_fabric_staged() -> void :
	var audit: = UrbanFabric.validate()
	if not bool(audit.get("ok", false)):
		push_error("Urban fabric clearance audit failed: %s" % "; ".join(audit.get("errors", [])))
		return
	var placements: Array = UrbanFabric.placements()
	for index in placements.size():
		_place_urban_spec(placements[index] as Dictionary)



		await get_tree().process_frame


func _place_urban_spec(spec: Dictionary) -> void :
	var family: = str(spec.get("family", "commercial"))
	var folder: = KENNEY_COMMERCIAL
	if family == "suburban":
		folder = KENNEY_SUBURBAN
	elif family == "industrial":
		folder = KENNEY_INDUSTRIAL
	var width: = float(spec.get("width", 1.8))
	var position_value: = Vector3(float(spec.get("x", 0.0)), 0.02, float(spec.get("z", 0.0)))
	var pad_color: = Color("c9c5b9") if family != "industrial" else Color("747978")
	_make_box("UrbanPad_%s" % str(spec.id), position_value + Vector3(0.0, -0.015, 0.0), Vector3(width + 0.36, 0.04, width + 0.36), pad_color)
	var building: = _place_kenney_model(folder, str(spec.get("model", "")), position_value, deg_to_rad(float(spec.get("yaw", 0.0))), width)
	if building != null:
		building.name = "Urban_%s_%s" % [str(spec.get("tier", "mid")), str(spec.id)]


func _build_city_wayfinding() -> void :

	for road_spec in [
		["启智大道", Vector3(-14.0, 0.2, -19.3), Color("fff1c7")], 
		["金融中轴", Vector3(18.5, 0.2, -8.0), Color("d5ecff")], 
		["中央商业街", Vector3(0.0, 0.2, -3.2), Color("ffe3af")], 
		["社区生活路", Vector3(-4.0, 0.2, 7.2), Color("e2f6d6")], 
		["滨水创意大道", Vector3(4.0, 0.2, 18.7), Color("d4f8ff")], 
	]:
		_make_road_name(str(road_spec[0]), road_spec[1], road_spec[2])


func _build_dynamic_city_life() -> void :
	var mobility: = MobilityRoutes.load_routes()
	var vehicle_routes: Array = mobility.get("vehicles", [])
	var pedestrian_routes: Array = mobility.get("pedestrians", [])
	var counts: = _dynamic_population_counts()
	for i in range(int(counts.vehicles)):
		_spawn_vehicle(i, vehicle_routes)
	for i in range(int(counts.pedestrians)):
		_spawn_pedestrian(i, pedestrian_routes)


func _build_dynamic_city_life_staged() -> void :
	var mobility: = MobilityRoutes.load_routes()
	var vehicle_routes: Array = mobility.get("vehicles", [])
	var pedestrian_routes: Array = mobility.get("pedestrians", [])
	var counts: = _dynamic_population_counts()
	for index in range(int(counts.vehicles)):
		_spawn_vehicle(index, vehicle_routes)
		if index % 2 == 1:
			await get_tree().process_frame
	for index in range(int(counts.pedestrians)):
		_spawn_pedestrian(index, pedestrian_routes)
		if index % 3 == 2:
			await get_tree().process_frame


func _spawn_vehicle(index: int, vehicle_routes: Array) -> void :
	if vehicle_routes.is_empty() or moving_agents.filter( func(agent: Dictionary) -> bool: return str(agent.get("kind", "")) == "vehicle").size() >= MAX_VEHICLES:
		return
	var vehicles_per_route: = ceili(16.0 / float(maxi(1, vehicle_routes.size())))
	var route: Dictionary = vehicle_routes[index % vehicle_routes.size()]
	var premium_route: bool = bool(route.get("premium", false))
	var vehicle_id: = "truck" if not premium_route and index in [2, 7, 13] else "small_car"
	var source_nodes: Array = route.get("nodes", [])
	if source_nodes.is_empty():
		return
	var route_slot: = index / maxi(1, vehicle_routes.size())
	var spacing: = maxi(1, source_nodes.size() / maxi(1, vehicles_per_route))
	var nodes: = MobilityRoutes.rotated_nodes(route, (route_slot * spacing) % maxi(1, source_nodes.size()))
	var start: = MobilityRoutes.node_position(nodes[0], 0.02)
	if not WorldBounds.is_valid_vehicle_position(start): return
	var vehicle: Node3D = _place_premium_vehicle(start, index) if premium_route else _place_prop(vehicle_id, start, 0.0, Vector3.ONE * (1.02 if vehicle_id == "small_car" else 1.1), index)
	if vehicle == null:
		return
	vehicle.set_meta("route_locked", true)
	vehicle.set_meta("mobility_route_id", str(route.get("id", "")))
	_add_moving_agent(vehicle, route, nodes, float(route.get("speed", 3.2)) + float(index % 3) * 0.18, "vehicle")


func _place_premium_vehicle(pos: Vector3, index: int) -> Node3D:
	var model_names := ["sedan.glb", "sedan-sports.glb", "suv-luxury.glb", "hatchback-sports.glb", "taxi.glb", "race-future.glb"]
	var model_name: String = model_names[posmod(index, model_names.size())]
	var path := KENNEY_CAR_KIT + model_name
	if not ResourceLoader.exists(path):
		return _place_prop("small_car", pos, 0.0, Vector3.ONE, index)
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := Node3D.new(); root.name = "WestBankPremiumVehicle_%s" % model_name.get_basename(); root.position = pos; add_child(root)
	var model := packed.instantiate() as Node3D
	if model == null:
		root.queue_free(); return null
	var longest := 0.1
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh:
			var bounds := mesh_node.mesh.get_aabb().size
			longest = maxf(longest, maxf(bounds.x, bounds.z))
	# The GLB files share an atlas.  Their embedded material reference is not
	# reliable in exported builds, so bind the atlas explicitly instead of
	# allowing Godot's white fallback material to hide the vehicle silhouettes.
	var material_ready := true
	for node_value in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node_value as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_texture = KENNEY_CAR_COLORMAP
		material.albedo_color = Color.WHITE
		material.metallic = 0.08 if "wheel" in mesh_node.name.to_lower() else 0.18
		material.roughness = 0.64 if "wheel" in mesh_node.name.to_lower() else 0.32
		mesh_node.material_override = material
		material_ready = material_ready and material.albedo_texture != null
	model.scale = Vector3.ONE * (1.32 / longest)
	model.rotation.y = -PI * 0.5
	root.add_child(model)
	root.set_meta("premium_model", model_name)
	root.set_meta("premium_material_ready", material_ready)
	root.set_meta("premium_palette", "kenney_car_kit_colormap")
	return root


func premium_vehicle_visual_profile() -> Dictionary:
	return {
		"model_variants": 6,
		"palette_texture": KENNEY_CAR_COLORMAP != null,
		"material_layers": 4,
		"layers": ["paint", "glass", "tyres", "signal_lights"],
		"white_fallback_allowed": false,
		"road_lane_only": true,
	}


func _spawn_pedestrian(index: int, pedestrian_routes: Array) -> void :
	if pedestrian_routes.is_empty() or moving_agents.filter( func(agent: Dictionary) -> bool: return str(agent.get("kind", "")) == "pedestrian").size() >= MAX_PEDESTRIANS:
		return
	var route: Dictionary = pedestrian_routes[index % pedestrian_routes.size()]
	var nodes: = _looped_route_nodes(route)
	var spawn_offset: = _pedestrian_spawn_offset(nodes, index)
	if spawn_offset < 0:
		return
	nodes = MobilityRoutes.rotated_nodes({"nodes": nodes}, spawn_offset)
	var pedestrian_id: String = ["pedestrian_blue", "pedestrian_coral", "pedestrian_green", "pedestrian_gold"][index % 4]
	var spawn: = MobilityRoutes.node_position(nodes[0], 0.1)
	if not WorldBounds.is_valid_pedestrian_position(spawn): return
	var walker: = _place_prop(pedestrian_id, spawn, 0.0, Vector3.ONE * (0.92 + float(index % 3) * 0.05), index)
	_add_moving_agent(walker, route, nodes, float(route.get("speed", 0.78)) + float(index % 4) * 0.04, "pedestrian")


func _dynamic_population_counts() -> Dictionary:
	Regions.ensure_state()
	var heat_total: = 0.0
	var traffic_total: = 0.0
	var count: = 0
	for state: Dictionary in GameState.game_data.get("regional_economy", {}).values():
		heat_total += float(state.get("commercial_heat", 100.0));traffic_total += float(state.get("traffic_access", 100.0));count += 1
	var heat_average: = heat_total / float(maxi(1, count)); var traffic_average: = traffic_total / float(maxi(1, count))
	return {"vehicles": clampi(14 + roundi((traffic_average - 96.0) / 5.0), 12, MAX_VEHICLES), "pedestrians": clampi(22 + roundi((heat_average - 96.0) / 2.5), 20, MAX_PEDESTRIANS)}


func _looped_route_nodes(route: Dictionary) -> Array:
	var nodes: Array = route.get("nodes", []).duplicate(true)
	if not bool(route.get("closed", false)):
		for index in range(nodes.size() - 2, 0, -1):
			nodes.append(nodes[index].duplicate(true))
	return nodes


func _add_moving_agent(node: Node3D, route: Dictionary, route_nodes: Array, speed: float, kind: String) -> void :
	if node and path_respects_domain(kind, route):
		var seed: = moving_agents.size()
		var agent: = {
			"node": node, "route_nodes": route_nodes, "route_id": str(route.get("id", "")), "index": 0, "speed": speed, 
			"current_speed": speed * (0.35 + float(seed % 4) * 0.11), 
			"kind": kind, "domain": "road_lane" if kind == "vehicle" else "sidewalk", 
			"forward_axis": "x", "phase": float(seed) * 0.73, "base_y": node.position.y, 
			"pause_left": float(seed % 3) * 0.13, "motion_seed": seed * 11, 
			"state": "cruise" if kind == "vehicle" else "walk", 
			"last_motion_position": node.position, "stalled_seconds": 0.0, "recovery_count": 0, 
		}
		if kind == "vehicle":
			agent["wheels"] = node.find_children("*Wheel*", "Node3D", true, false)
			agent["body"] = node.get_node_or_null("VehicleBody")
			agent["brake_lights"] = _attach_vehicle_brake_lights(node)
		else:
			var arms: = node.find_children("Arm", "Node3D", true, false)
			var legs: = node.find_children("Leg", "Node3D", true, false)
			agent["arms"] = arms
			agent["legs"] = legs
			for limb_index in range(arms.size()):
				agent["arm_base_%d" % limb_index] = (arms[limb_index] as Node3D).rotation.x
			for limb_index in range(legs.size()):
				agent["leg_base_%d" % limb_index] = (legs[limb_index] as Node3D).rotation.x
		moving_agents.append(agent)


func _track_vehicle_motion(agent: Dictionary, node: Node3D, delta: float, target_action: String, pause_left: float) -> void :
	var previous: Vector3 = agent.get("last_motion_position", node.position)
	var moved: = Vector2(node.position.x - previous.x, node.position.z - previous.z).length()
	var intentional_pause: = pause_left > 0.0 or target_action == "stop_line" and float(agent.get("pause_left", 0.0)) > 0.0
	if moved >= 0.012:
		agent.stalled_seconds = 0.0
	elif not intentional_pause:
		agent.stalled_seconds = float(agent.get("stalled_seconds", 0.0)) + delta
	if float(agent.get("stalled_seconds", 0.0)) >= STALLED_RECOVERY_SECONDS:
		_recover_stalled_vehicle(agent, node)
	agent.last_motion_position = node.position


func _recover_stalled_vehicle(agent: Dictionary, node: Node3D) -> bool:
	var route_nodes: Array = agent.get("route_nodes", [])
	if route_nodes.size() < 2:
		return false
	var current: = int(agent.get("index", 0))
	var recovery_count: = int(agent.get("recovery_count", 0))
	for offset in range(1, route_nodes.size()):
		var candidate_index: = (current + offset + recovery_count) % route_nodes.size()
		var candidate: = MobilityRoutes.node_position(route_nodes[candidate_index], 0.02)
		if not WorldBounds.is_valid_vehicle_position(candidate) or not _position_clear_except(candidate, 1.32, node):
			continue
		node.position = candidate
		agent.index = candidate_index
		agent.current_speed = maxf(0.65, float(agent.get("speed", 2.8)) * 0.34)
		agent.pause_left = 0.0
		agent.stalled_seconds = 0.0
		agent.recovery_count = recovery_count + 1
		agent.state = "rejoined_route"
		return true
	agent.index = (current + 1) % route_nodes.size()
	agent.current_speed = 0.4
	agent.stalled_seconds = STALLED_RECOVERY_SECONDS * 0.55
	return false


func _position_clear_except(position: Vector3, clearance: float, ignored: Node3D) -> bool:
	for agent: Dictionary in moving_agents:
		var other: = agent.get("node") as Node3D
		if not is_instance_valid(other) or other == ignored:
			continue
		var separation: = other.position - position
		separation.y = 0.0
		if separation.length() < clearance:
			return false
	return true


func _pedestrian_spawn_offset(nodes: Array, preferred_seed: int) -> int:
	if nodes.is_empty():
		return -1
	for attempt in range(nodes.size()):
		var index: = (preferred_seed + attempt * 3) % nodes.size()
		var candidate: Dictionary = nodes[index]
		if bool(candidate.get("crossing", false)) or str(candidate.get("action", "")) in ["crosswalk", "wait_crossing"]:
			continue
		var position: = MobilityRoutes.node_position(candidate, 0.1)
		if not WorldBounds.is_valid_pedestrian_position(position):
			continue
		if _position_clear_of_agents(position, 0.78):
			return index
	return -1


func _position_clear_of_agents(position: Vector3, clearance: float) -> bool:
	for agent: Dictionary in moving_agents:
		var other: = agent.get("node") as Node3D
		if not is_instance_valid(other):
			continue
		var separation: = other.position - position
		separation.y = 0.0
		if separation.length() < clearance:
			return false
	return true


func _pedestrian_clearance_factor(agent: Dictionary, node: Node3D, offset: Vector3) -> float:
	if offset.length_squared() <= 0.0001:
		return 0.0
	var direction: = offset.normalized()
	var factor: = 1.0
	for other: Dictionary in moving_agents:
		if other == agent:
			continue
		var other_node: = other.get("node") as Node3D
		if not is_instance_valid(other_node):
			continue
		var separation: = other_node.position - node.position
		separation.y = 0.0
		var distance: = separation.length()
		var other_kind: = str(other.get("kind", ""))
		var hard_clearance: = 0.78 if other_kind == "vehicle" else 0.44
		if distance < hard_clearance:
			return 0.0
		if distance <= 0.0001 or separation.normalized().dot(direction) <= 0.18:
			continue
		var slow_distance: = 1.35 if other_kind == "vehicle" else 0.92
		if distance < slow_distance:
			factor = minf(factor, clampf((distance - hard_clearance) / maxf(0.01, slow_distance - hard_clearance), 0.0, 1.0))
	return factor


func _vehicle_near_position(position: Vector3, clearance: float) -> bool:
	for agent: Dictionary in moving_agents:
		if str(agent.get("kind", "")) != "vehicle":
			continue
		var vehicle: = agent.get("node") as Node3D
		if not is_instance_valid(vehicle):
			continue
		var separation: = vehicle.position - position
		separation.y = 0.0
		if separation.length() < clearance:
			return true
	return false


func _pedestrian_safe_travel(agent: Dictionary, node: Node3D, direction: Vector3, proposed_travel: float) -> float:
	var safe_travel: = proposed_travel
	for other: Dictionary in moving_agents:
		if other == agent:
			continue
		var other_node: = other.get("node") as Node3D
		if not is_instance_valid(other_node):
			continue
		var clearance: = 0.78 if str(other.get("kind", "")) == "vehicle" else 0.44
		var candidate: = node.position + direction * safe_travel
		var separation: = other_node.position - candidate
		separation.y = 0.0
		if separation.length() < clearance:
			safe_travel = 0.0
	return safe_travel


func _vehicle_clearance_factor(agent: Dictionary, node: Node3D, offset: Vector3) -> float:
	if offset.length_squared() <= 0.0001:
		return 0.0
	var direction: = offset.normalized()
	var factor: = 1.0
	for other: Dictionary in moving_agents:
		if other == agent:
			continue
		var other_node: = other.get("node") as Node3D
		if not is_instance_valid(other_node):
			continue
		var other_kind: = str(other.get("kind", ""))
		var separation: = other_node.position - node.position
		var distance: = separation.length()
		var hard_clearance: = 0.78 if other_kind == "pedestrian" else 0.95
		if distance < hard_clearance:
			return 0.0
		var is_ahead: = separation.normalized().dot(direction) > 0.28
		if not is_ahead:
			continue
		if other_kind == "vehicle" and str(other.get("route_id", "")) == str(agent.get("route_id", "")) and distance < 2.95:
			factor = minf(factor, clampf((distance - 1.1) / 1.85, 0.0, 1.0))
		elif distance < (1.45 if other_kind == "pedestrian" else 1.55):
			factor = minf(factor, clampf((distance - 0.95) / 0.6, 0.0, 1.0))
	return factor


func _vehicle_safe_travel(agent: Dictionary, node: Node3D, direction: Vector3, proposed_travel: float) -> float:
	var safe_travel: = proposed_travel
	const VEHICLE_CLEARANCE: = 0.92
	for other: Dictionary in moving_agents:
		if other == agent:
			continue
		var other_node: = other.get("node") as Node3D
		if not is_instance_valid(other_node):
			continue
		var separation: = other_node.position - node.position
		separation.y = 0.0
		var forward_distance: = separation.dot(direction)
		if forward_distance <= 0.0:
			continue
		var lateral_squared: = maxf(0.0, separation.length_squared() - forward_distance * forward_distance)
		var clearance: = 0.78 if str(other.get("kind", "")) == "pedestrian" else VEHICLE_CLEARANCE
		if lateral_squared >= clearance * clearance:
			continue
		var protected_forward: = sqrt(clearance * clearance - lateral_squared)
		safe_travel = minf(safe_travel, maxf(0.0, forward_distance - protected_forward))
	return safe_travel


func _attach_vehicle_brake_lights(vehicle: Node3D) -> Array[MeshInstance3D]:
	var lights: Array[MeshInstance3D] = []
	for side in [-0.19, 0.19]:
		var light: = MeshInstance3D.new()
		light.name = "BrakeLight"
		var mesh: = BoxMesh.new()
		mesh.size = Vector3(0.06, 0.07, 0.06)
		light.mesh = mesh
		light.position = Vector3(-0.52, 0.32, side)
		var material: = _material(Color(1.0, 0.08, 0.03, 1.0))
		material.emission_enabled = true
		material.emission = Color(1.0, 0.04, 0.01, 1.0)
		material.emission_energy_multiplier = 1.8
		light.material_override = material
		light.visible = false
		vehicle.add_child(light)
		lights.append(light)
	return lights


func _build_day_night_system() -> void :
	world_environment = WorldEnvironment.new()
	world_environment.name = "UnifiedCityWorldEnvironment"
	var environment: = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	var reflection_sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/Buildings/west_bank_blender/urban_street_01_2k.hdr")
	reflection_sky.sky_material = panorama
	environment.sky = reflection_sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfdee8")
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 2.2
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.03
	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.glow_strength = 0.82
	environment.glow_bloom = 0.06
	environment.glow_hdr_threshold = 1.18
	environment.ssao_enabled = true
	environment.ssao_radius = 0.75
	environment.ssao_intensity = 0.65
	environment.ssao_power = 1.42
	environment.ssao_detail = 0.62
	environment.ssao_horizon = 0.08
	environment.ssao_sharpness = 0.86
	environment.ssao_light_affect = 0.14
	environment.ssil_enabled = true
	environment.ssil_radius = 3.2
	environment.ssil_intensity = 0.74
	environment.ssil_sharpness = 0.92
	environment.ssil_normal_rejection = 0.38
	environment.ssr_enabled = true
	environment.fog_enabled = false
	world_environment.environment = environment
	add_child(world_environment)
	sun_light = DirectionalLight3D.new()
	sun_light.name = "Sun"
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.directional_shadow_blend_splits = true
	sun_light.directional_shadow_max_distance = 80.0
	sun_light.directional_shadow_fade_start = 0.82
	sun_light.shadow_bias = 0.035
	sun_light.shadow_normal_bias = 0.72
	add_child(sun_light)
	moon_light = DirectionalLight3D.new()
	moon_light.name = "Moon"
	moon_light.light_color = Color("a9c8e8")
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon_light.directional_shadow_blend_splits = true
	moon_light.directional_shadow_max_distance = 80.0
	add_child(moon_light)
	sun_body = _create_celestial_body("SunBody", 1.18, Color("f6cf79"), 2.1)
	moon_body = _create_celestial_body("MoonBody", 0.92, Color("c8daef"), 1.0)
	for pos in [Vector3(-24, 2.2, -21.8), Vector3(-12, 2.2, -21.8), Vector3(0, 2.2, -21.8), Vector3(12, 2.2, -21.8), Vector3(24, 2.2, -21.8), Vector3(-24, 2.2, 21.8), Vector3(-12, 2.2, 21.8), Vector3(0, 2.2, 21.8), Vector3(12, 2.2, 21.8), Vector3(24, 2.2, 21.8), Vector3(-18, 2.2, -8), Vector3(-6, 2.2, -8), Vector3(6, 2.2, -8), Vector3(18, 2.2, -8), Vector3(-18, 2.2, 8), Vector3(-6, 2.2, 8), Vector3(6, 2.2, 8), Vector3(18, 2.2, 8)]:
		var light: = OmniLight3D.new()
		light.position = pos
		light.light_color = Color("ffd69a")
		light.omni_range = 6.8
		light.light_energy = 0.0
		light.shadow_enabled = false
		add_child(light)
		practical_lights.append(light)
	_apply_time_of_day(city_time)


func _create_celestial_body(body_name: String, radius: float, color: Color, emission_energy: float) -> MeshInstance3D:
	var body: = MeshInstance3D.new()
	body.name = body_name
	var sphere: = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	body.mesh = sphere
	var material: = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = material
	add_child(body)
	return body


func _apply_time_of_day(value: float) -> void :
	AudioManager.sync_city_time(value)
	if world_environment == null or world_environment.environment == null:
		return
	var profile: = time_of_day_profile(value)
	var environment: = world_environment.environment
	environment.background_color = profile.sky_color
	environment.ambient_light_color = profile.ambient_color
	environment.ambient_light_energy = float(profile.ambient_energy)
	environment.tonemap_exposure = float(profile.exposure)
	environment.adjustment_brightness = float(profile.brightness)
	environment.adjustment_saturation = float(profile.saturation)
	sun_light.light_energy = float(profile.sun_energy)
	sun_light.light_color = profile.sun_color
	sun_light.rotation_degrees = Vector3(-18.0 - float(profile.daylight) * 48.0, value * 360.0 - 110.0, 0.0)
	moon_light.light_energy = float(profile.moon_energy)
	moon_light.rotation_degrees = Vector3(-42.0, value * 360.0 + 70.0, 0.0)
	var sun_angle: = (value - 0.25) * TAU
	var moon_angle: = sun_angle + PI
	var sun_height: = sin(sun_angle)
	var moon_height: = sin(moon_angle)
	if sun_body:
		sun_body.position = Vector3( - cos(sun_angle) * 27.0, 5.5 + sun_height * 18.0, -31.0)
		sun_body.visible = sun_height > -0.04
	if moon_body:
		moon_body.position = Vector3( - cos(moon_angle) * 25.0, 6.0 + moon_height * 17.0, -31.5)
		moon_body.visible = moon_height > -0.04
	for light in practical_lights:
		light.light_energy = 1.2 if bool(profile.street_lights) else 0.0
	for fill_light in west_bank_fill_lights:
		fill_light.light_energy = lerpf(0.92, 0.68, float(profile.daylight))


func _make_low_hill(pos: Vector3, color: Color) -> void :
	var hill: = MeshInstance3D.new()
	hill.name = "LandscapeHill"
	var mesh: = SphereMesh.new()
	mesh.radius = 3.8
	mesh.height = 2.2
	hill.mesh = mesh
	hill.position = pos
	hill.scale = Vector3(1.25, 0.42, 1.0)
	hill.material_override = _material(color)
	add_child(hill)


func _build_canonical_district_signs() -> void :


	var signs: = [
		["教育培训区", "L01–L04", "education", Vector3(-27.2, 1.25, -17.8), Color("d6a84b")], 
		["医疗服务区", "L05–L08", "medical", Vector3(27.0, 1.25, -10.8), Color("69b8bd")], 
		["金融办公区", "L09–L12", "finance", Vector3(27.0, 1.25, -4.8), Color("7897d8")], 
		["商业街区", "L13–L16", "commercial", Vector3(-27.2, 1.25, -0.8), Color("d98a54")], 
		["住宅社区区", "L17–L20", "residential", Vector3(-27.2, 1.25, 7.8), Color("78aa69")], 
		["娱乐消费区", "L21–L24", "entertainment", Vector3(-27.2, 1.25, 15.3), Color("b77bc4")], 
		["滨水生活商务区", "L25–L28", "waterfront", Vector3(27.0, 1.25, 20.5), Color("4da9b7")], 
	]
	for sign_data: Array in signs:
		_make_canonical_district_sign(str(sign_data[0]), str(sign_data[1]), str(sign_data[2]), sign_data[3], sign_data[4])


func _make_canonical_district_sign(title: String, land_range: String, district_id: String, pos: Vector3, accent: Color) -> void :
	var root: = Node3D.new()
	root.name = "DistrictGuide_%s" % land_range.replace("–", "_")
	root.position = pos
	add_child(root)
	var plate: = MeshInstance3D.new()
	var plate_mesh: = BoxMesh.new()
	plate_mesh.size = Vector3(5.8, 0.14, 1.15)
	plate.mesh = plate_mesh
	plate.material_override = _material(Color(0.035, 0.095, 0.12, 0.96))
	root.add_child(plate)
	var stripe: = MeshInstance3D.new()
	var stripe_mesh: = BoxMesh.new()
	stripe_mesh.size = Vector3(5.45, 0.06, 0.13)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0, 0.1, 0.4)
	stripe.material_override = _material(accent)
	root.add_child(stripe)
	var label: = Label3D.new()
	label.text = "%s  %s" % [title, land_range]
	label.font_size = 52
	label.outline_size = 12
	label.modulate = Color("f7f0dc")
	label.outline_modulate = Color("071820")
	label.position = Vector3(0, 0.18, 0.02)
	label.rotation_degrees.x = -88
	label.no_depth_test = true
	root.add_child(label)
	var hit_area: = Area3D.new()
	hit_area.name = "DistrictHitArea"
	hit_area.input_ray_pickable = true
	var collision: = CollisionShape3D.new()
	var shape: = BoxShape3D.new()
	shape.size = Vector3(6.2, 0.8, 1.6)
	collision.shape = shape
	hit_area.add_child(collision)
	hit_area.input_event.connect( func(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void :
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			district_selected.emit(district_id)
			get_viewport().set_input_as_handled()
	)
	root.add_child(hit_area)


func _build_e1_road_markings() -> void :

	for x in range(-22, 23, 2):
		_make_box("LaneDashNorth", Vector3(float(x), 0.17, -3.2), Vector3(0.78, 0.018, 0.07), Color(0.94, 0.88, 0.58, 1))
		_make_box("LaneDashSouth", Vector3(float(x), 0.17, 7.2), Vector3(0.78, 0.018, 0.07), Color(0.94, 0.88, 0.58, 1))
	for z in range(-18, 19, 2):
		_make_box("LaneDashCentral", Vector3(2.5, 0.17, float(z)), Vector3(0.07, 0.018, 0.78), Color(0.94, 0.88, 0.58, 1))
		_make_box("LaneDashTransit", Vector3(18.5, 0.17, float(z)), Vector3(0.07, 0.018, 0.78), Color(0.94, 0.88, 0.58, 1))


func _build_e1_district_accents() -> void :

	for pos in [Vector3(3.6, 0.15, 0.8), Vector3(-1.8, 0.15, 10.3)]:
		_make_box("CommercialPlaza", pos, Vector3(1.2, 0.025, 1.2), Color(0.18, 0.3, 0.38, 1))
	for pos in [Vector3(12.6, 0.15, -6.4), Vector3(18.2, 0.15, 14.0)]:
		_make_box("IndustrialHardstand", pos, Vector3(1.35, 0.025, 1.35), Color(0.28, 0.31, 0.31, 1))
	for pos in [Vector3(-5.0, 0.15, -11.2), Vector3(-14.0, 0.15, -1.2)]:
		_make_box("CommunityCourtyard", pos, Vector3(1.12, 0.025, 1.12), Color(0.38, 0.54, 0.42, 1))


func _build_street_details() -> void :
	for x in [-24, -18, -12, -6, 0, 6, 12, 18, 24]:
		_place_prop("tree", Vector3(x, 0.08, -4.45))
		_place_prop("tree", Vector3(x + 0.6, 0.08, 8.55))
	for z in [-18, -10, -2, 6, 14]:
		_place_prop("tree", Vector3(-9.2, 0.08, z))
		_place_prop("tree", Vector3(11.6, 0.08, z))
		_place_prop("tree", Vector3(19.7, 0.08, z))
	for pos in [Vector3(6.2, 0.16, 4.1), Vector3(13.2, 0.16, -3.8)]:
		_place_vehicle("small_car", pos, 0.0, Vector3.ONE * 0.72)
	for pos in [Vector3(-3.2, 0.08, -3.9), Vector3(0.4, 0.08, -2.4), Vector3(4.7, 0.08, -2.4), Vector3(9.3, 0.08, -2.4), Vector3(-6.7, 0.08, 6.4), Vector3(1.1, 0.08, 8.0)]:
		_place_prop("street_light", pos)
	for pos in [Vector3(-5.8, 0.08, 1.8), Vector3(6.8, 0.08, 2.2), Vector3(15.4, 0.08, 6.8), Vector3(-14.2, 0.08, -8.6)]:
		_place_prop("neon_sign", pos)
	for pos in [Vector3(-2.2, 0.08, 8.0), Vector3(8.4, 0.08, -4.25), Vector3(17.0, 0.08, 13.0)]:
		_place_prop("bus_stop", pos, 0.0, Vector3.ONE * 0.86)


func _load_plots() -> void :
	var text: = FileAccess.get_file_as_string("res://data/land_tiles.json")
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Land plot data is invalid.")
		return
	var index: = 1
	for land_data in parsed:
		_create_plot(land_data as Dictionary, index)
		index += 1


func _load_plots_staged() -> void :
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/land_tiles.json"))
	if not parsed is Array:
		push_error("Land plot data is invalid.")
		return
	for index in (parsed as Array).size():
		_create_plot((parsed as Array)[index] as Dictionary, index + 1)


		await get_tree().process_frame


func _create_plot(land_data: Dictionary, index: int) -> void :
	var plot_data: = _plot_data_from_land(land_data, index)
	var plot: = LAND_PLOT_SCENE.instantiate()
	add_child(plot)
	var pos: Array = plot_data.get("position", [0, 0, 0])
	plot.position = Vector3(float(pos[0]), 0.02, float(pos[2]))
	plot.setup(plot_data)
	plot.clicked.connect(_select_plot)
	plot.double_clicked.connect(_focus_plot)
	plot.hover_changed.connect(_on_plot_hover_changed)
	plots.append(plot)
	plot_data_by_id[plot_data["id"]] = plot_data


func _plot_data_from_land(land_data: Dictionary, index: int) -> Dictionary:
	var environment: Array = land_data.get("environment", [])
	var anchor: Array = land_data.get("anchor", [0.0, 0.0])
	return {
		"id": "P%02d" % index, 
		"land_id": str(land_data.get("id", "")), 
		"name": str(land_data.get("id", "")), 
		"district": str(land_data.get("district", "")), 
		"district_name": str(land_data.get("district_name", "")), 
		"market_id": str(land_data.get("district", "")), 
		"price": int(land_data.get("price", 0)), 
		"position": [float(anchor[0]), 0.0, float(anchor[1])], 
		"polygon": land_data.get("polygon", []).duplicate(true), 
		"entrance": land_data.get("entrance", [0.0, 0.0]).duplicate(true), 
		"building_anchor": land_data.get("building_anchor", [0.0, 0.0]).duplicate(true), 
		"building_scale": float(land_data.get("building_scale", 0.78)), 
		"site_type": str(land_data.get("site_type", "unused_hardstand")), 
		"map_zone": str(land_data.get("map_zone", "")), 
		"environment_tags": _environment_labels(environment), 
		"purchasable": true
	}


func _environment_labels(environment: Array) -> Array[String]:
	var labels: Array[String] = []
	for item in environment:
		var key: = str(item)
		labels.append({
			"technology": "科技园区", 
			"office": "写字楼区", 
			"education": "校园周边", 
			"medical": "医院周边", 
			"newtown": "城市新区", 
			"transport": "交通枢纽", 
			"commercial": "商业中心", 
			"government": "政务区", 
			"finance": "金融办公区", 
			"entertainment": "文娱消费区", 
			"night_control": "夜间监管区", 
			"oldtown": "老城改造区", 
			"residential": "住宅区", 
			"logistics": "物流仓储区"
		}.get(key, key))
	return labels


func _select_plot(plot: Node3D) -> void :
	if selected_plot and selected_plot != plot:
		selected_plot.set_selected(false)
	selected_plot = plot
	selected_plot.set_selected(true)
	for item in plots:
		var in_district: = selected_district_id.is_empty() or str(item.data.get("district", "")) == selected_district_id
		if item.has_method("set_context_dimmed"):
			item.set_context_dimmed( not in_district)
	plot_selected.emit(plot.data, plot)


func _focus_plot(plot: Node3D) -> void :
	_select_plot(plot)
	plot_focus_requested.emit(plot.global_position)


func _on_plot_hover_changed(plot: Node3D, hovered: bool) -> void :
	if hovered:
		plot_hovered.emit(plot.data, plot)
	else:
		plot_unhovered.emit(plot.data, plot)


func _place_building(id: String, pos: Vector3, yaw: = 0.0, scale_value: = Vector3.ONE) -> Node3D:
	var imported: = _place_kenney_building(id, pos, yaw, scale_value)
	if imported != null:
		return imported
	return _place_scene(BUILDING_PATH % id, pos, yaw, scale_value)


func _place_kenney_model(folder: String, file_name: String, pos: Vector3, yaw: float, target_width: float) -> Node3D:
	var path: = folder + file_name
	if not ResourceLoader.exists(path):
		push_warning("Missing unified city model: %s" % path)
		return null
	var packed: = load(path) as PackedScene
	if packed == null:
		return null
	var model: = packed.instantiate() as Node3D
	if model == null:
		return null
	var widest: = 0.1
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: = node as MeshInstance3D
		if mesh_node.mesh:
			var bounds: = mesh_node.mesh.get_aabb().size
			widest = maxf(widest, maxf(bounds.x, bounds.z))
	add_child(model)
	model.name = "CityModel_%s" % file_name.get_basename()
	model.position = pos
	model.rotation.y = yaw
	model.scale = Vector3.ONE * (target_width / widest)
	return model


func _place_kenney_building(id: String, pos: Vector3, yaw: float, scale_value: Vector3) -> Node3D:
	var path: String = {
		"office_tower_01": KENNEY_COMMERCIAL + "building-skyscraper-b.glb", 
		"mall_01": KENNEY_COMMERCIAL + "building-h.glb", 
		"logistics_warehouse_01": KENNEY_INDUSTRIAL + "building-o.glb", 
		"school_building_01": KENNEY_SUBURBAN + "building-type-q.glb", 
		"hospital_01": KENNEY_SUBURBAN + "building-type-r.glb", 
		"small_shop_01": KENNEY_COMMERCIAL + "building-a.glb", 
		"tea_shop_01": KENNEY_COMMERCIAL + "building-b.glb", 
		"convenience_store_01": KENNEY_COMMERCIAL + "building-f.glb", 
		"residential_block_01": KENNEY_SUBURBAN + "building-type-a.glb", 
		"residential_block_02": KENNEY_SUBURBAN + "building-type-c.glb"
	}.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed: = load(path) as PackedScene
	if packed == null:
		return null
	var model: = packed.instantiate() as Node3D
	if model == null:
		return null
	var target_width: float = {
		"office_tower_01": 1.85, "mall_01": 3.4, "logistics_warehouse_01": 3.0, 
		"school_building_01": 2.8, "hospital_01": 2.7, "small_shop_01": 1.35, 
		"tea_shop_01": 1.35, "convenience_store_01": 1.45, "residential_block_01": 1.45, 
		"residential_block_02": 1.45
	}.get(id, 1.6)
	var widest: = 0.1
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: = node as MeshInstance3D
		if mesh_node.mesh:
			var bounds: = mesh_node.mesh.get_aabb().size
			widest = maxf(widest, maxf(bounds.x, bounds.z))
	var fit: = target_width / widest
	add_child(model)
	model.name = "Kenney_%s" % id
	model.position = pos
	model.rotation.y = yaw
	model.scale = scale_value * fit
	return model


func _place_prop(id: String, pos: Vector3, yaw: = 0.0, scale_value: = Vector3.ONE, variant: = 0) -> Node3D:
	if id in ["small_car", "truck"]:
		var vehicle: = CityAssetFactoryScript.create_vehicle_variant(int(variant), id == "truck")
		add_child(vehicle)
		vehicle.position = pos
		vehicle.rotation.y = yaw
		vehicle.scale = scale_value
		return vehicle
	var node: = _place_scene(PROP_PATH % id, pos, yaw, scale_value, false)
	if node == null:
		node = CityAssetFactoryScript.create_prop(id)
		if node:
			add_child(node)
			node.position = pos
			node.rotation.y = yaw
			node.scale = scale_value
	return node


func _place_vehicle(id: String, pos: Vector3, yaw: = 0.0, scale_value: = Vector3.ONE) -> Node3D:
	var key: = "%s:%.2f:%.2f" % [id, pos.x, pos.z]
	if placed_vehicle_keys.has(key):
		return null
	placed_vehicle_keys[key] = true
	return _place_prop(id, pos, yaw, scale_value)


func _place_road(id: String, pos: Vector3, yaw: = 0.0, scale_value: = Vector3.ONE) -> Node3D:
	return _place_scene(ROAD_PATH % id, pos, yaw, scale_value)


func _place_scene(path: String, pos: Vector3, yaw: float, scale_value: Vector3, warn_missing: = true) -> Node3D:
	if not ResourceLoader.exists(path):
		if warn_missing:
			push_warning("Missing city module: %s" % path)
		return null
	var packed: = ResourceLoader.load(path) as PackedScene
	if not packed:
		if warn_missing:
			push_warning("Missing city module: %s" % path)
		return null
	var node: = packed.instantiate() as Node3D
	add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale_value
	return node


func _make_district_label(text: String, pos: Vector3, color: Color) -> void :
	var label: = Label3D.new()
	label.text = text
	label.font_size = 46
	label.outline_size = 9
	label.modulate = color
	label.position = pos
	label.rotation_degrees.x = -58
	add_child(label)


func _make_road_name(text: String, pos: Vector3, color: Color) -> void :
	var label: = Label3D.new()
	label.name = "StreetName_%s" % text
	label.text = text
	label.font_size = 58
	label.pixel_size = 0.01
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color("17242b")
	label.position = pos
	label.rotation_degrees.x = -90
	label.no_depth_test = false
	add_child(label)


func _make_metropolitan_city_ground() -> void :
	var ground: = MeshInstance3D.new()
	ground.name = "MetropolitanReferenceGround"
	var plane: = PlaneMesh.new()
	plane.size = Vector2(76.0, 50.7)
	ground.mesh = plane
	ground.position = Vector3(0, -0.11, 0.4)
	var shader: = Shader.new()
	shader.code = "\nshader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx;\nuniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic;\nvoid fragment() {\n\tvec3 detail = texture(ground_texture, UV).rgb;\n\tALBEDO = detail;\n\tROUGHNESS = 0.88;\n\tSPECULAR = 0.10;\n}\n"










	var material: = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ground_texture", METROPOLITAN_CITY_GROUND)
	ground.material_override = material
	add_child(ground)


func _make_west_bank_ground() -> void:
	# The complete west-bank daylight grade is baked in Unreal Engine 5.8.  The
	# runtime only presents this authored district surface; it does not rebuild
	# or recolour the financial district in Godot.
	_make_box("WestBankFoundation", Vector3(-92.0, -0.34, 0.4), Vector3(72.0, 0.4, 54.0), Color("142127"))
	var ground := MeshInstance3D.new()
	ground.name = "WestBankFinancialGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(72.0, 52.0)
	ground.mesh = plane
	ground.position = Vector3(-92.0, -0.105, 0.4)
	var shader := Shader.new()
	shader.code = "\nshader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx;\nuniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic;\nuniform float brightness_lift : hint_range(0.0, 0.2) = 0.11;\nuniform vec4 cool_lift : source_color = vec4(0.004, 0.010, 0.018, 1.0);\nvoid fragment(){ vec2 map_uv=vec2(UV.x*0.865,UV.y); vec3 detail=texture(ground_texture,map_uv).rgb; ALBEDO=clamp(detail*(1.0+brightness_lift)+cool_lift.rgb,vec3(0.0),vec3(1.0)); ROUGHNESS=0.66; SPECULAR=0.32; }\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ground_texture", WEST_BANK_FINANCIAL_GROUND)
	material.set_shader_parameter("brightness_lift", WEST_BANK_GROUND_BRIGHTNESS_LIFT)
	material.set_shader_parameter("cool_lift", WEST_BANK_COOL_LIFT)
	ground.material_override = material
	add_child(ground)
	_make_west_bank_cool_fill_lights()
	_make_box("WestRiverBed", Vector3(-47.0, -0.22, 0.4), Vector3(17.5, 0.18, 52.0), Color("0b6680"))
	_make_west_river_surface()
	_make_box("WestBankQuay", Vector3(-55.75, -0.02, 0.4), Vector3(0.55, 0.16, 52.0), Color("87989b"))
	_make_box("OldCityQuay", Vector3(-38.25, -0.02, 0.4), Vector3(0.5, 0.16, 52.0), Color("87989b"))
	_make_box("CapitalBridgeDeck", Vector3(-46.75, 0.12, 0.45), Vector3(19.0, 0.18, 3.15), Color("333d43"))
	_make_box("CapitalBridgeMedian", Vector3(-46.75, 0.25, 0.45), Vector3(18.7, 0.035, 0.10), Color("e5c76b"))
	for lane in [-0.78, 0.78]:
		_make_box("CapitalBridgeLane", Vector3(-46.75, 0.245, 0.45 + lane), Vector3(18.4, 0.028, 0.045), Color("d8edf0"))
	for side in [-1.0, 1.0]:
		_make_box("CapitalBridgeRail", Vector3(-46.75, 0.44, 0.45 + side * 1.52), Vector3(19.0, 0.38, 0.10), Color("d0b560"))
		_make_box("CapitalBridgeGlow", Vector3(-46.75, 0.51, 0.45 + side * 1.39), Vector3(18.6, 0.055, 0.055), Color("62d8e5"))
	for x in [-54.6, -38.9]:
		for side in [-1.0, 1.0]:
			_make_box("CapitalBridgePylon", Vector3(x, 1.28, 0.45 + side * 1.48), Vector3(0.34, 2.4, 0.34), Color("d7c06c"))
			_make_box("CapitalBridgeBeacon", Vector3(x, 2.56, 0.45 + side * 1.48), Vector3(0.5, 0.2, 0.5), Color("78dbe2"))
	_make_arch_bridge(Vector3(-46.75, 0.0, 14.6))


func _make_west_bank_cool_fill_lights() -> void:
	west_bank_fill_lights.clear()
	var positions := [
		Vector3(-116.0, 13.0, -14.5),
		Vector3(-116.0, 13.0, 14.5),
		Vector3(-82.0, 13.0, -14.5),
		Vector3(-82.0, 13.0, 14.5),
	]
	var daylight := float(time_of_day_profile(city_time).daylight)
	for index in positions.size():
		var light := OmniLight3D.new()
		light.name = "WestBankCoolFill%d" % (index + 1)
		light.position = positions[index]
		light.light_color = WEST_BANK_FILL_COLOR
		light.light_energy = lerpf(0.92, 0.68, daylight)
		light.light_specular = 0.72
		light.omni_range = 30.0
		light.omni_attenuation = 0.62
		light.shadow_enabled = false
		add_child(light)
		west_bank_fill_lights.append(light)


func _build_west_bank_financial_core() -> void:
	# Small building footprints on inspected paved plots, outside purchase parcels.
	_add_west_bank_landmark("AuroraSpire", Vector3(-124.5, 0.0, 5.1), Color("e0ba59"))
	_add_west_bank_landmark("HarborTwin", Vector3(-98.0, 0.0, -19.0), Color("89d9dd"))
	_add_west_bank_landmark("TerraceHQ", Vector3(-96.5, 0.0, 5.6), Color("e1b65c"))
	_add_west_bank_landmark("PearlFinance", Vector3(-123.0, 0.0, 17.2), Color("e5edf0"))
	_make_capital_exchange(Vector3(-75.5, 0.0, -0.5))
	_make_canonical_district_sign("西岸金融核心区", "L29–L44", "finance", Vector3(-86.0, 1.25, 21.0), Color("e0b85c"))
	if not EndlessOperationsSystem.is_enabled():
		_make_west_bank_locked_banner()


func _make_west_bank_locked_banner() -> void:
	var label := Label3D.new()
	label.name = "WestBankEndlessOnlyBanner"
	label.text = "西岸金融核心区\n仅永续经营模式开放"
	label.font_size = 68
	label.outline_size = 18
	label.modulate = Color("ffe49a")
	label.outline_modulate = Color("061923")
	label.position = Vector3(-76.0, 8.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _add_west_bank_landmark(landmark_id: String, pos: Vector3, accent_color: Color) -> void:
	var root := Node3D.new()
	root.name = landmark_id
	root.position = pos
	add_child(root)
	var model := WestBankLandmarkAssets.instantiate(landmark_id)
	if model == null:
		push_error("Unable to instantiate Blender west-bank landmark: %s" % landmark_id)
		return
	root.add_child(model)
	var model_bounds := WestBankLandmarkAssets.bounds(landmark_id)
	var reflection := ReflectionProbe.new()
	reflection.name = "FacadeReflection"
	reflection.position.y = model_bounds.y * 0.5
	reflection.size = model_bounds + Vector3(4, 4, 4)
	reflection.origin_offset = Vector3(0, 0, 8)
	reflection.max_distance = 70.0
	reflection.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	reflection.ambient_color = Color("cfdee8")
	reflection.ambient_color_energy = 1.1
	reflection.update_mode = ReflectionProbe.UPDATE_ONCE
	root.add_child(reflection)
	_add_landmark_interaction(root, landmark_id, model_bounds.y, accent_color, model_bounds)


func _add_landmark_interaction(root: Node3D, landmark_id: String, model_height: float, accent: Color, model_bounds := Vector3(5.4, 7.5, 5.2)) -> void:
	var names := {
		"AuroraSpire": "曙光宏观塔",
		"HarborTwin": "港湾路演双塔",
		"TerraceHQ": "星汇财富俱乐部",
		"PearlFinance": "明珠财富大厦",
	}
	var label := Label3D.new()
	label.name = "LandmarkLabel"
	label.text = str(names.get(landmark_id, landmark_id))
	label.font_size = 100
	label.pixel_size = 0.010
	label.outline_size = 20
	label.modulate = Color("fff0b5")
	label.outline_modulate = Color("071820")
	label.position = Vector3(0, model_height + 0.45, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
	var hit := Area3D.new()
	hit.name = "LandmarkHitArea"
	hit.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = model_bounds + Vector3(0.1, 0.1, 0.1)
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	hit.add_child(collision)
	hit.input_event.connect(func(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			west_landmark_requested.emit(landmark_id))
	root.add_child(hit)


func _make_arch_bridge(pos: Vector3) -> void:
	_make_box("AuroraArchBridgeFoundation", pos + Vector3(0, 0.13, 0), Vector3(19.6, 0.28, 4.05), Color("26353e"))
	_make_box("AuroraArchBridgeDeck", pos + Vector3(0, 0.38, 0), Vector3(19.25, 0.26, 3.48), Color("27343d"))
	for lane in [-0.82, 0.82]:
		_make_box("AuroraArchBridgeLane", pos + Vector3(0, 0.53, lane), Vector3(18.75, 0.035, 0.065), Color("eaf1e8"))
	for side in [-1.0, 1.0]:
		_make_box("AuroraBridgeWalkway", pos + Vector3(0, 0.55, side * 1.74), Vector3(19.1, 0.10, 0.38), Color("b7c4c7"))
		_make_box("AuroraBridgeEdgeGlow", pos + Vector3(0, 0.68, side * 1.93), Vector3(19.15, 0.08, 0.08), Color("68dbe6"))
	var arch_material := _premium_material(Color("d9bc63"), 0.2, 0.84)
	var rod_material := _premium_emissive_material(Color("83dce5"), 1.35)
	var parent := Node3D.new()
	parent.name = "AuroraArchBridge"
	add_child(parent)
	for side_value: float in [-1.0, 1.0]:
		var z: float = pos.z + side_value * 1.94
		var previous := Vector3(pos.x - 9.1, 0.82, z)
		for index in range(1, 25):
			var x_ratio := -1.0 + float(index) / 24.0 * 2.0
			var current := Vector3(pos.x + x_ratio * 9.1, 0.82 + pow(maxf(0.0, 1.0 - x_ratio * x_ratio), 0.72) * 4.2, z)
			_add_beam_between(parent, previous, current, 0.15, arch_material)
			if index % 2 == 0 and index < 24:
				_add_beam_between(parent, Vector3(current.x, 0.72, z), current, 0.032, rod_material)
			previous = current
	for x in [pos.x - 9.05, pos.x + 9.05]:
		_make_box("AuroraBridgeAbutment", Vector3(x, 0.95, pos.z), Vector3(0.75, 1.55, 4.35), Color("66777d"))
		for side in [-1.0, 1.0]:
			_make_box("AuroraBridgePortal", Vector3(x, 1.85, pos.z + side * 1.95), Vector3(0.46, 2.6, 0.54), Color("d5ba68"))
			_make_box("AuroraBridgeBeacon", Vector3(x, 3.30, pos.z + side * 1.95), Vector3(0.64, 0.20, 0.72), Color("79e0e5"))


func _add_beam_between(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 10
	beam.mesh = mesh
	beam.position = (start + finish) * 0.5
	beam.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	beam.material_override = material
	parent.add_child(beam)


func _make_capital_exchange(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "CapitalExchangeLandmark"
	root.position = pos
	root.scale = Vector3.ONE * 1.55
	root.rotation_degrees.y = 180.0
	add_child(root)
	var model := WestBankLandmarkAssets.instantiate("CapitalExchange")
	if model == null:
		push_error("Capital exchange Blender model unavailable")
		return
	root.add_child(model)
	var model_bounds := WestBankLandmarkAssets.bounds("CapitalExchange")
	var tower_top := model_bounds.y
	var label := Label3D.new()
	label.text = "资本交易中心"
	label.font_size = 100
	label.pixel_size = 0.00645
	label.outline_size = 24
	label.modulate = Color("ffe27a")
	label.outline_modulate = Color("071820")
	label.position = Vector3(0, tower_top + 0.45, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
	var hit := Area3D.new()
	hit.name = "CapitalExchangeHitArea"
	hit.input_ray_pickable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = model_bounds + Vector3(0.1, 0.1, 0.1)
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	hit.add_child(collision)
	hit.input_event.connect(func(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			call_deferred("_emit_capital_exchange_requested"))
	root.add_child(hit)


func _emit_capital_exchange_requested() -> void:
	capital_exchange_requested.emit()


func _add_tower_box(parent: Node3D, size_value: Vector3, position_value: Vector3, material: Material) -> void:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	item.mesh = mesh
	item.position = position_value
	item.material_override = material
	parent.add_child(item)


func _add_tower_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, position_value: Vector3, material: Material, segments: int) -> void:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	item.mesh = mesh
	item.position = position_value
	item.material_override = material
	parent.add_child(item)


func _add_external_tower(parent: Node3D, path: String, target_width: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var widest := 0.1
	var tallest := 0.1
	for candidate: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			var bounds := mesh_node.mesh.get_aabb().size
			widest = maxf(widest, maxf(bounds.x, bounds.z))
			tallest = maxf(tallest, bounds.y)
	var scale_factor := target_width / widest
	model.scale = Vector3.ONE * scale_factor
	model.set_meta("scaled_height", tallest * scale_factor)
	parent.add_child(model)
	return model


func _make_west_river_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "WestRiverSurface"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(17.0, 51.5)
	surface.mesh = mesh
	surface.position = Vector3(-47.0, -0.08, 0.4)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
uniform sampler2D ue_flow_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ue_flow_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ue_foam_mask : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float flow_strength = 1.0;
uniform float texture_ready = 0.0;

void vertex() {
	vec2 displacement_uv = vec2(UV.x * 1.45, UV.y * 5.2 - TIME * 0.026 * flow_strength);
	vec3 displacement_normal = texture(ue_flow_normal, displacement_uv).rgb * 2.0 - 1.0;
	VERTEX.y += displacement_normal.y * 0.010 * texture_ready;
}

void fragment() {
	vec2 flow_a = vec2(UV.x * 1.55 + TIME * 0.004 * flow_strength, UV.y * 5.8 - TIME * 0.030 * flow_strength);
	vec2 flow_b = vec2(1.0 - UV.x * 2.25 - TIME * 0.003 * flow_strength, UV.y * 8.6 - TIME * 0.047 * flow_strength);
	vec3 color_a = texture(ue_flow_color, flow_a).rgb;
	vec3 color_b = texture(ue_flow_color, flow_b).rgb;
	vec3 baked_color = mix(color_a, color_b, 0.32);
	vec3 safe_color = vec3(0.012, 0.115, 0.155);
	vec3 color = mix(safe_color, baked_color, texture_ready);
	// Preserve flowing detail while correcting the muddy green bias.
	color *= vec3(0.62, 0.87, 1.22);
	vec3 normal_a = texture(ue_flow_normal, flow_a).rgb * 2.0 - 1.0;
	vec3 normal_b = texture(ue_flow_normal, flow_b).rgb * 2.0 - 1.0;
	normal_b.x *= -1.0;
	vec3 water_normal = normalize(vec3(mix(normal_a.xy, normal_b.xy, 0.38) * 0.72, 1.0));
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), water_normal * 0.5 + 0.5, texture_ready);
	NORMAL_MAP_DEPTH = 0.24;
	float bank_distance = abs(UV.x - 0.5) * 2.0;
	float shallow_water = smoothstep(0.66, 1.0, bank_distance);
	float shoreline = smoothstep(0.82, 0.99, bank_distance);
	float foam_detail = texture(ue_foam_mask, flow_a * vec2(0.92, 1.15)).r;
	foam_detail = mix(foam_detail, texture(ue_foam_mask, flow_b * vec2(1.12, 0.86)).r, 0.34);
	float foam = foam_detail * shoreline * 0.105 * texture_ready;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.1);
	vec3 bank_tint = vec3(0.025, 0.16, 0.24);
	vec3 sky_reflection = vec3(0.09, 0.23, 0.38);
	color = mix(color, bank_tint, shallow_water * 0.22);
	color = mix(color, sky_reflection, fresnel * 0.22);
	color += vec3(0.56, 0.69, 0.67) * foam;
	ALBEDO = color;
	ROUGHNESS = mix(0.31, 0.16, fresnel) + foam * 0.12;
	SPECULAR = 0.30;
	METALLIC = 0.0;
	EMISSION = vec3(0.025, 0.09, 0.10) * foam * 0.12;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("flow_strength", 0.0 if GameSettings.reduce_motion else 1.0)
	var flow_color_path := "res://assets/ui/city/river_ue58/ue58_river_flow_color.png"
	var flow_normal_path := "res://assets/ui/city/river_ue58/ue58_river_normal.png"
	var foam_mask_path := "res://assets/ui/city/river_ue58/ue58_river_foam.png"
	var textures_ready := ResourceLoader.exists(flow_color_path) and ResourceLoader.exists(flow_normal_path) and ResourceLoader.exists(foam_mask_path)
	if textures_ready:
		material.set_shader_parameter("ue_flow_color", load(flow_color_path) as Texture2D)
		material.set_shader_parameter("ue_flow_normal", load(flow_normal_path) as Texture2D)
		material.set_shader_parameter("ue_foam_mask", load(foam_mask_path) as Texture2D)
		material.set_shader_parameter("texture_ready", 1.0)
	surface.material_override = material
	add_child(surface)


func water_flow_profile() -> Dictionary:
	return {"animated": true, "bake_source": "unreal_engine_5_8", "bake_resolution": 2048, "confined_to_river": true, "flow_directions": 2, "surface_model": "ue58_baked_dual_flow_city_river", "normal_detail_layers": 2, "fresnel_reflection": true, "shoreline_highlight": true, "shoreline_gradient": true, "foam_intensity": "low", "fracture_noise": false, "reduced_motion_supported": true}


func _premium_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _premium_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _premium_material(color, 0.12, 0.72)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _make_box(name_value: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance: = MeshInstance3D.new()
	mesh_instance.name = name_value
	var mesh: = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _material(color)
	add_child(mesh_instance)
	return mesh_instance


func _material(color: Color) -> StandardMaterial3D:
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.38
	mat.metallic = 0.025
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
