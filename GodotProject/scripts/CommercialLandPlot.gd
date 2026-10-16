class_name LandPlot
extends Node3D

const MapHeatScale = preload("res://scripts/MapHeatScale.gd")

signal clicked(plot: LandPlot)
signal double_clicked(plot: LandPlot)
signal hover_changed(plot: LandPlot, hovered: bool)

const BORDER_COLOR: = Color(0.8, 0.88, 0.87, 1.0)
const PAVER_COLOR: = Color(0.16, 0.21, 0.22, 1.0)
const SALE_SIGN_COLOR: = Color(0.96, 0.76, 0.28, 1.0)
const SELECTED_COLOR: = Color(1.0, 0.78, 0.24, 1.0)
const HOVER_COLOR: = Color(0.24, 0.4, 0.43, 1.0)
const CityAssetFactoryScript: = preload("res://scripts/CommercialCityAssetFactory.gd")
const ParcelGeometry: = preload("res://scripts/LandParcelGeometry.gd")
const ObjectPool: = preload("res://scripts/CityObjectPool.gd")
const KENNEY_COMMERCIAL: = "res://assets/third_party/kenney/commercial/Models/GLB format/"
const KENNEY_INDUSTRIAL: = "res://assets/third_party/kenney/industrial/Models/GLB format/"
const KENNEY_SUBURBAN: = "res://assets/third_party/kenney/suburban/Models/GLB format/"

var data: Dictionary = {}
var plot_size: = Vector2(3.0, 2.0)
var parcel_points: = PackedVector2Array()
var parcel_bounds: = Rect2()
var building_anchor: = Vector2.ZERO
var entrance_anchor: = Vector2.ZERO
var building_scale: = 0.78
var owner_color: = Color(0.18, 0.46, 0.93, 1.0)
var available_color: = Color(0.29, 0.38, 0.29, 1.0)
var is_selected: = false
var is_hovered: = false
var is_wind_focus: = false
var is_district_focus: = false
var context_dimmed: = false
var last_click_time: = -10.0
var visual_state: = "unowned"
var current_business_type: Dictionary = {}
var business_stage: = 0
var prosperity_points: = 0
var visualization_mode: = "default"
var visualization_payload: Dictionary = {}

var base_mesh: MeshInstance3D
var surface_mesh: MeshInstance3D
var glow_mesh: MeshInstance3D
var owner_band_root: Node3D
var sale_sign_root: Node3D
var flag_root: Node3D
var company_plate_root: Node3D
var construction_root: Node3D
var business_root: Node3D
var feedback_root: Node3D
var risk_badge_root: Node3D
var construction_progress: MeshInstance3D
var construction_skeleton: MeshInstance3D
var construction_time: = 0.0
var title_label: Label3D
var land_name_label: Label3D
var title_bubble_back: MeshInstance3D
var title_bubble_accent: MeshInstance3D
var state_beacon_root: Node3D
var focus_outline_root: Node3D
var transient_pool: = ObjectPool.new()


func setup(plot_data: Dictionary) -> void :
	data = plot_data
	parcel_points = ParcelGeometry.points_from_data(data.get("polygon", []))
	if not ParcelGeometry.is_valid_polygon(parcel_points):
		push_error("Invalid parcel polygon: %s" % str(data.get("land_id", "")))
		return
	parcel_bounds = ParcelGeometry.bounds(parcel_points)
	plot_size = parcel_bounds.size
	building_anchor = ParcelGeometry.point_from_array(data.get("building_anchor", [0.0, 0.0]))
	entrance_anchor = ParcelGeometry.point_from_array(data.get("entrance", [0.0, 0.0]))
	building_scale = clampf(float(data.get("building_scale", 0.78)), 0.55, 0.9)
	available_color = _available_color_from_tags(data.get("environment_tags", []))
	_create_body()
	_create_collision()
	_create_border()
	_create_focus_outline()
	_create_district_surface_details()
	_create_sale_sign()
	_create_owner_band()
	_create_flag()
	_create_company_plate()
	_create_construction_site()
	_create_business_root()
	_create_feedback_root()
	_create_label()
	_create_state_beacon()
	_refresh_visual()


func set_company_owner(owner_id: String, color: Color, owner_name: = "", land_name: = "") -> void :
	data["owner"] = owner_id
	data["owner_name"] = owner_name if not owner_name.is_empty() else owner_id
	data["land_name"] = land_name if not land_name.is_empty() else str(data.get("land_id", data.get("id", "地块")))
	data["purchasable"] = false
	owner_color = color
	visual_state = "owned"
	flag_root.visible = true
	company_plate_root.visible = true
	var company_label: = company_plate_root.get_node_or_null("CompanyName") as Label3D
	if company_label:
		company_label.text = "已购  %s" % str(data.owner_name).left(7)
		company_label.modulate = Color.WHITE
	sale_sign_root.visible = false
	_update_title_label()
	_refresh_visual()
	flag_root.scale = Vector3(0.2, 0.2, 0.2)
	company_plate_root.scale = Vector3(0.2, 0.2, 0.2)
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flag_root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(company_plate_root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_floating_text("购买成功", Color(1.0, 0.78, 0.22, 1.0))
	_play_ground_pulse(Color(1.0, 0.78, 0.22, 0.72))
	var buy_light: = OmniLight3D.new()
	buy_light.name = "PurchasePulse"
	buy_light.light_color = color.lightened(0.25)
	buy_light.light_energy = 2.0
	buy_light.omni_range = 3.4
	buy_light.position = Vector3(0, 1.0, 0)
	add_child(buy_light)
	var light_tween: = buy_light.create_tween()
	light_tween.tween_property(buy_light, "light_energy", 0.0, 0.7)
	light_tween.tween_callback(buy_light.queue_free)


func reset_match_state() -> void :
	data["owner"] = ""
	data["owner_name"] = ""
	data["land_name"] = ""
	data["purchasable"] = true
	owner_color = Color(0.18, 0.46, 0.93, 1.0)
	visual_state = "unowned"
	current_business_type.clear()
	business_stage = 0
	prosperity_points = 0
	flag_root.visible = false
	company_plate_root.visible = false
	sale_sign_root.visible = true
	construction_root.visible = false
	_clear_business_visual()
	_set_risk_badge(false)
	_refresh_visual()


func show_construction(business_name: String, remaining_rounds: int, total_rounds: int = 1) -> void :
	_clear_business_visual()
	visual_state = "construction"
	_refresh_visual()
	construction_root.visible = true
	data["construction_remaining"] = remaining_rounds
	data["construction_total"] = total_rounds
	var label: = construction_root.get_node("ConstructionLabel") as Label3D

	label.text = "建设中"
	label.visible = false
	_update_title_label()
	var ratio: float = clamp(1.0 - float(remaining_rounds) / max(1.0, float(total_rounds)), 0.08, 1.0)
	construction_progress.scale.x = ratio
	construction_progress.position.x = -0.55 + 0.55 * ratio
	construction_skeleton.scale.y = 0.35 + ratio * 0.95
	construction_skeleton.position.y = 0.48 + construction_skeleton.scale.y * 0.34
	var tween: = create_tween()
	tween.tween_property(construction_skeleton, "scale:y", construction_skeleton.scale.y + 0.12, 0.12)
	tween.tween_property(construction_skeleton, "scale:y", construction_skeleton.scale.y, 0.12)
	var label_tween: = label.create_tween()
	label_tween.tween_property(label, "modulate", Color(1.0, 0.88, 0.42, 1.0), 0.16)
	label_tween.tween_property(label, "modulate", Color.WHITE, 0.18)
	_show_floating_text("开工建设", Color(1.0, 0.76, 0.22, 1.0))
	_play_ground_pulse(Color(1.0, 0.72, 0.2, 0.62))
	set_process(true)


func _process(delta: float) -> void :
	if construction_root == null or not construction_root.visible:
		return
	construction_time += delta
	for i in range(3):
		var worker: = construction_root.get_node_or_null("Worker%d" % i) as Node3D
		if worker:
			var base: Vector3 = worker.get_meta("base_position", worker.position)
			worker.position = base + Vector3(
				sin(construction_time * (1.7 + i * 0.22) + i * 1.8) * 0.1, 
				absf(sin(construction_time * 3.2 + i)) * 0.018, 
				cos(construction_time * (1.5 + i * 0.18) + i) * 0.08
			)
			worker.rotation.y = sin(construction_time * 1.3 + i) * 0.8
	var crane_arm: = construction_root.get_node_or_null("CraneArm") as Node3D
	if crane_arm:
		crane_arm.rotation.y = sin(construction_time * 0.55) * 0.34
	var crane_hook: = construction_root.get_node_or_null("CraneHook") as Node3D
	if crane_hook:
		crane_hook.position.y = 0.68 + sin(construction_time * 1.15) * 0.18
	var delivery: = construction_root.get_node_or_null("DeliveryVehicle") as Node3D
	if delivery:
		var delivery_base: Vector3 = delivery.get_meta("base_position", delivery.position)
		var travel_direction: Vector3 = delivery.get_meta("travel_direction", Vector3.RIGHT)
		var loading_pass: = sin(construction_time * 0.52) * minf(0.32, plot_size.x * 0.1)
		delivery.position = delivery_base + travel_direction * loading_pass


func show_business(business_type: Dictionary) -> void :
	construction_root.visible = false
	_clear_business_visual()
	current_business_type = business_type.duplicate(true)
	visual_state = "open"
	data.erase("construction_remaining")
	_update_title_label()
	business_stage = clampi(int(business_type.get("visual_stage", business_stage)), 0, 2)
	_build_business_visual(str(business_type.get("visual_type", "")), str(business_type.get("name", "")))
	_refresh_visual()
	business_root.scale = Vector3(0.22, 0.04, 0.22)
	var tween: = create_tween()
	tween.tween_property(business_root, "scale", Vector3.ONE, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var opening_light: = OmniLight3D.new()
	opening_light.name = "OpeningLight"
	opening_light.light_color = Color(1.0, 0.74, 0.28, 1.0)
	opening_light.light_energy = 2.4
	opening_light.omni_range = 4.2
	opening_light.position = Vector3(0, 1.35, 0)
	business_root.add_child(opening_light)
	var light_tween: = opening_light.create_tween()
	light_tween.tween_property(opening_light, "light_energy", 0.0, 0.9)
	light_tween.tween_callback(opening_light.queue_free)
	_show_floating_text("开业成功", Color(1.0, 0.78, 0.22, 1.0))
	_play_ground_pulse(Color(1.0, 0.78, 0.22, 0.72))
	_play_celebration_burst()
	show_feedback({"kind": "opening", "text": "企业开业", "risk_delta": 0, "profit": 0})


func clear_business_visual() -> void :
	construction_root.visible = false
	_clear_business_visual()
	current_business_type.clear()
	business_stage = 0
	prosperity_points = 0
	visual_state = "owned" if str(data.get("owner", "")) != "" else "unowned"
	_refresh_visual()


func show_feedback(feedback: Dictionary) -> void :
	var kind: = str(feedback.get("kind", "profit"))
	var profit: = int(feedback.get("profit", 0))
	var risk_delta: = int(feedback.get("risk_delta", 0))
	var color: = Color(0.3, 0.9, 0.42, 1)
	if kind == "loss" or profit < 0:
		color = Color(1.0, 0.32, 0.24, 1)
	elif kind == "risk" or risk_delta >= 8:
		color = Color(1.0, 0.72, 0.2, 1)
	elif kind == "construction":
		color = Color(0.95, 0.78, 0.26, 1)
	elif kind == "opening":
		color = Color(0.32, 0.88, 1.0, 1)
	var feedback_text: = str(feedback.get("text", ""))
	if feedback_text == "" and profit != 0:
		feedback_text = "%+d万" % profit
	_show_floating_text(feedback_text, color)
	_set_risk_badge(risk_delta >= 8 or int(feedback.get("risk_score", 0)) >= 35)
	if profit > 0 and not current_business_type.is_empty():
		prosperity_points += profit
		var next_stage: = 2 if prosperity_points >= 70 else (1 if prosperity_points >= 30 else 0)
		if next_stage > business_stage:
			_set_business_stage(next_stage)


func set_selected(value: bool) -> void :
	is_selected = value
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 0.035 if value else 0.0, 0.18)
	tween.tween_property(self, "scale", Vector3(1.025, 1.025, 1.025) if value else Vector3.ONE, 0.18)
	_refresh_visual()


func set_context_dimmed(value: bool) -> void :
	context_dimmed = value
	_refresh_visual()


func set_district_focus(value: bool) -> void :
	is_district_focus = value
	_refresh_visual()


func set_hovered(value: bool) -> void :
	if is_hovered == value:
		return
	is_hovered = value
	hover_changed.emit(self, value)
	var target_y: = 0.035 if is_selected else 0.018 if value else 0.0
	var target_scale: = Vector3(1.025, 1.025, 1.025) if is_selected else Vector3(1.015, 1.015, 1.015) if value else Vector3.ONE
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", target_y, 0.08)
	tween.tween_property(self, "scale", target_scale, 0.08)
	_refresh_visual()


func set_wind_focus(value: bool) -> void :
	is_wind_focus = value
	var existing: = get_node_or_null("WindArrow")
	if value and existing == null:
		var arrow: = Label3D.new();arrow.name = "WindArrow";arrow.text = "↑";arrow.font_size = 44;arrow.outline_size = 7;arrow.modulate = Color(1.0, 0.76, 0.2, 1);arrow.position = Vector3(0, 1.75, 0);arrow.rotation_degrees.x = -58;add_child(arrow)
		var tween: = arrow.create_tween();tween.set_loops();tween.tween_property(arrow, "position:y", 2.05, 0.55);tween.tween_property(arrow, "position:y", 1.75, 0.55)
	elif not value and existing:
		existing.queue_free()
	_refresh_visual()


func set_visualization_mode(mode: String, payload: = {}) -> void :
	visualization_mode = mode if mode in ["default", "heat", "control", "traffic"] else "default"
	visualization_payload = payload.duplicate(true)
	_refresh_visual()


func _create_body() -> void :
	base_mesh = MeshInstance3D.new()
	base_mesh.name = "PlotStoneBase"
	base_mesh.mesh = ParcelGeometry.mesh_for_polygon(parcel_points, 0.0)
	base_mesh.position.y = 0.005
	base_mesh.material_override = _material(Color(0.02, 0.05, 0.06, 0.58), true)
	add_child(base_mesh)

	surface_mesh = MeshInstance3D.new()
	surface_mesh.name = "PlotBuildableSurface"
	surface_mesh.mesh = ParcelGeometry.mesh_for_polygon(parcel_points, 0.0)
	surface_mesh.position.y = 0.03
	add_child(surface_mesh)

	glow_mesh = MeshInstance3D.new()
	glow_mesh.name = "SelectionGlow"
	glow_mesh.mesh = ParcelGeometry.mesh_for_polygon(parcel_points, 0.0)
	glow_mesh.position.y = 0.055
	glow_mesh.scale = Vector3(1.08, 1.0, 1.08)
	add_child(glow_mesh)


func _create_collision() -> void :
	var area: = Area3D.new()
	area.name = "ClickArea"
	area.input_ray_pickable = true
	var shape: = CollisionShape3D.new()
	var polygon_shape: = ConcavePolygonShape3D.new()
	polygon_shape.set_faces(ParcelGeometry.mesh_for_polygon(parcel_points, 0.0).get_faces())
	shape.shape = polygon_shape
	shape.position.y = 0.28
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect( func() -> void : set_hovered(true))
	area.mouse_exited.connect( func() -> void : set_hovered(false))


func _create_border() -> void :
	for index in range(parcel_points.size()):
		_add_line_segment("ParcelEdge%d" % index, parcel_points[index], parcel_points[(index + 1) % parcel_points.size()], 0.075, 0.02, 0.064, BORDER_COLOR)
	_add_line_segment("StreetAccess", building_anchor, entrance_anchor, 0.055, 0.014, 0.08, Color(0.94, 0.86, 0.58, 0.82))


func _create_focus_outline() -> void :
	focus_outline_root = Node3D.new()
	focus_outline_root.name = "DistrictFocusOutline"
	focus_outline_root.visible = false
	add_child(focus_outline_root)
	for index in range(parcel_points.size()):
		focus_outline_root.add_child(_line_segment_mesh("FocusEdge%d" % index, parcel_points[index], parcel_points[(index + 1) % parcel_points.size()], 0.15, 0.03, 0.092, Color.WHITE))


func _create_district_surface_details() -> void :
	var accent: = _site_accent(str(data.get("site_type", "")))
	for offset in [-0.14, 0.14]:
		var start: = building_anchor.lerp(entrance_anchor, 0.22) + Vector2( - offset, offset)
		var end: = building_anchor.lerp(entrance_anchor, 0.72) + Vector2( - offset, offset)
		_add_line_segment("SiteInlay", start, end, 0.035, 0.012, 0.082, Color(accent, 0.7))


func _create_sale_sign() -> void :
	sale_sign_root = Node3D.new()
	sale_sign_root.name = "SaleSign"


	sale_sign_root.position = Vector3(building_anchor.x, 0.34, building_anchor.y)
	add_child(sale_sign_root)
	var board: = _mesh_box("ListingPlaque", Vector3(1.3, 0.68, 0.07), Color("071e29"))
	board.position = Vector3(0.0, 0.34, 0.0)
	sale_sign_root.add_child(board)
	var rim: = _mesh_box("ListingRim", Vector3(1.42, 0.8, 0.035), Color("f0c65d"))
	rim.position = Vector3(0.0, 0.34, 0.045)
	sale_sign_root.add_child(rim)
	var face: = _mesh_box("ListingFace", Vector3(1.22, 0.6, 0.018), Color("0b3441"))
	face.position = Vector3(0.0, 0.34, -0.05)
	sale_sign_root.add_child(face)
	var label: = Label3D.new()
	label.name = "ListingMark"
	label.text = "待售"
	label.font_size = 34
	label.outline_size = 7
	label.modulate = Color("fff2ba")
	label.outline_modulate = Color("06141d")
	label.position = Vector3(0.0, 0.46, -0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	sale_sign_root.add_child(label)


func _create_owner_band() -> void :
	owner_band_root = Node3D.new()
	owner_band_root.name = "OwnerColorBand"
	add_child(owner_band_root)
	for index in range(parcel_points.size()):
		owner_band_root.add_child(_line_segment_mesh("OwnerEdge%d" % index, parcel_points[index], parcel_points[(index + 1) % parcel_points.size()], 0.2, 0.16, 0.53, owner_color))
	owner_band_root.visible = false


func _create_flag() -> void :
	flag_root = Node3D.new()
	flag_root.name = "CompanyFlag"
	flag_root.position = Vector3(plot_size.x * 0.28, 0.42, - plot_size.y * 0.22)
	flag_root.visible = false
	add_child(flag_root)
	var pole: = _mesh_cylinder("FlagPole", 0.035, 1.15, Color(0.94, 0.94, 0.88, 1.0))
	pole.position.y = 0.58
	flag_root.add_child(pole)
	var flag: = _mesh_box("FlagCloth", Vector3(0.72, 0.38, 0.035), owner_color)
	flag.position = Vector3(0.36, 0.92, 0)
	flag_root.add_child(flag)
	var cap: = _mesh_box("FlagTip", Vector3(0.14, 0.14, 0.14), Color(0.98, 0.82, 0.34, 1))
	cap.position = Vector3(0, 1.19, 0)
	flag_root.add_child(cap)


func _create_company_plate() -> void :
	company_plate_root = Node3D.new()
	company_plate_root.name = "CompanyPlate"
	company_plate_root.position = Vector3(0, 0.47, plot_size.y * 0.25)
	company_plate_root.visible = false
	add_child(company_plate_root)
	var plate: = _mesh_box("PlateBoard", Vector3(1.75, 0.46, 0.07), Color(0.08, 0.14, 0.2, 1))
	company_plate_root.add_child(plate)
	var label: = Label3D.new()
	label.name = "CompanyName"
	label.text = "公司"
	label.font_size = 32
	label.outline_size = 6
	label.modulate = Color(0.84, 0.93, 1.0, 1)
	label.position = Vector3(0, 0.0, -0.045)
	company_plate_root.add_child(label)


func _create_construction_site() -> void :
	construction_root = Node3D.new()
	construction_root.name = "ConstructionSite"
	construction_root.visible = false
	add_child(construction_root)
	for x in [ - plot_size.x * 0.28, plot_size.x * 0.28]:
		construction_root.add_child(_positioned_box("FenceX", Vector3(x, 0.68, 0), Vector3(0.12, 0.54, plot_size.y * 0.72), Color(0.94, 0.72, 0.24, 1)))
	for z in [ - plot_size.y * 0.28, plot_size.y * 0.28]:
		construction_root.add_child(_positioned_box("FenceZ", Vector3(0, 0.68, z), Vector3(plot_size.x * 0.72, 0.54, 0.12), Color(0.94, 0.72, 0.24, 1)))
	construction_root.add_child(_positioned_box("CraneBase", Vector3(plot_size.x * 0.22, 0.7, - plot_size.y * 0.1), Vector3(0.16, 0.9, 0.16), Color(0.96, 0.8, 0.18, 1)))
	construction_root.add_child(_positioned_box("CraneArm", Vector3(plot_size.x * 0.02, 1.14, - plot_size.y * 0.1), Vector3(plot_size.x * 0.55, 0.1, 0.1), Color(0.96, 0.8, 0.18, 1)))
	construction_root.add_child(_positioned_box("CraneCable", Vector3( - plot_size.x * 0.2, 0.9, - plot_size.y * 0.1), Vector3(0.025, 0.44, 0.025), Color("4c5458")))
	construction_root.add_child(_positioned_box("CraneHook", Vector3( - plot_size.x * 0.2, 0.68, - plot_size.y * 0.1), Vector3(0.14, 0.1, 0.14), Color("de5c31")))
	construction_skeleton = _positioned_box("BuildingSkeleton", Vector3( - plot_size.x * 0.18, 0.7, 0.08), Vector3(0.82, 0.75, 0.7), Color(0.72, 0.66, 0.52, 1))
	construction_root.add_child(construction_skeleton)
	construction_root.add_child(_positioned_box("ProgressFrame", Vector3(0, 0.72, plot_size.y * 0.42), Vector3(1.35, 0.12, 0.06), Color(0.12, 0.13, 0.12, 1)))
	construction_progress = _positioned_box("ProgressFill", Vector3(-0.36, 0.73, plot_size.y * 0.42 - 0.035), Vector3(1.05, 0.07, 0.04), Color(0.28, 0.88, 0.38, 1))
	construction_root.add_child(construction_progress)
	var label: = Label3D.new()
	label.name = "ConstructionLabel"
	label.text = "建设中"
	label.font_size = 28
	label.outline_size = 6
	label.modulate = Color(0.16, 0.11, 0.05, 1)
	label.position = Vector3(0, 0.98, 0)
	label.rotation_degrees.x = -62
	construction_root.add_child(label)
	for i in range(3):
		construction_root.add_child(_make_construction_worker(i))
	var delivery: = CityAssetFactoryScript.create_vehicle_variant(6, true)
	delivery.name = "DeliveryVehicle"
	var approach: = (entrance_anchor - building_anchor).normalized()
	if approach.length_squared() < 0.01:
		approach = Vector2(0.0, 1.0)
	var tangent: = Vector2( - approach.y, approach.x)
	# 施工车辆停在围挡入口外侧，避免小地块上与建筑骨架穿插。
	var loading_point: Vector2 = entrance_anchor + approach * 0.62
	delivery.position = Vector3(loading_point.x, 0.3, loading_point.y)
	delivery.scale = Vector3.ONE * 0.36
	delivery.rotation.y = atan2(tangent.x, tangent.y)
	delivery.set_meta("base_position", delivery.position)
	delivery.set_meta("travel_direction", Vector3(tangent.x, 0.0, tangent.y))
	construction_root.add_child(delivery)


func _make_construction_worker(index: int) -> Node3D:
	var worker: = Node3D.new()
	worker.name = "Worker%d" % index
	var approach: = (entrance_anchor - building_anchor).normalized()
	if approach.length_squared() < 0.01:
		approach = Vector2(0.0, 1.0)
	var tangent: = Vector2( - approach.y, approach.x)
	# 工人沿入口外侧排布；不再生成在围挡和建筑骨架内部。
	var access_center: = entrance_anchor + approach * 0.34
	var lateral_offsets: = [-0.48, 0.0, 0.48]
	var depth_offsets: = [0.02, 0.12, 0.02]
	var worker_point: Vector2 = access_center + tangent * float(lateral_offsets[index]) + approach * float(depth_offsets[index])
	worker.position = Vector3(worker_point.x, 0.44, worker_point.y)
	var person_id: String = ["pedestrian_gold", "pedestrian_blue", "pedestrian_coral"][index]
	var person: = CityAssetFactoryScript.create_prop(person_id)
	person.scale = Vector3.ONE * 0.78
	person.position.y = -0.36
	worker.add_child(person)
	worker.add_child(_positioned_box("Tool", Vector3(0.15, 0.2, 0), Vector3(0.2, 0.035, 0.035), Color("4d5357")))
	worker.set_meta("base_position", worker.position)
	return worker


func _create_business_root() -> void :
	business_root = Node3D.new()
	business_root.name = "BusinessVisual"
	business_root.position = Vector3(building_anchor.x, 0.0, building_anchor.y)
	business_root.scale = Vector3.ONE * building_scale
	add_child(business_root)


func _create_feedback_root() -> void :
	feedback_root = Node3D.new()
	feedback_root.name = "FeedbackRoot"
	add_child(feedback_root)
	risk_badge_root = Node3D.new()
	risk_badge_root.name = "RiskBadge"
	risk_badge_root.visible = false
	risk_badge_root.position = Vector3( - plot_size.x * 0.34, 1.62, plot_size.y * 0.28)
	add_child(risk_badge_root)
	risk_badge_root.add_child(_mesh_box("RiskBadgeBoard", Vector3(0.72, 0.38, 0.05), Color(0.92, 0.2, 0.16, 1)))
	var label: = Label3D.new()
	label.text = "风险"
	label.font_size = 25
	label.outline_size = 5
	label.modulate = Color(1.0, 0.96, 0.88, 1)
	label.position = Vector3(0, 0, -0.045)
	risk_badge_root.add_child(label)


func _clear_business_visual() -> void :
	for child in business_root.get_children():
		child.queue_free()


func _build_business_visual(visual_type: String, business_name: String) -> void :
	if not _add_kenney_business(visual_type):
		var factory_id: = _business_factory_id(visual_type)
		if factory_id != "":
			var module: = CityAssetFactoryScript.create_building(factory_id, business_stage)
			module.scale = Vector3.ONE * _business_module_scale(visual_type)
			module.position = Vector3(0, 0.38, 0)
			business_root.add_child(module)
		else:
			match visual_type:
				"premium_spire", "premium_twin", "premium_crystal", "premium_terrace", "premium_crown", "premium_arc":
					_build_premium_business(visual_type)
				"live_ecommerce":
					_build_live_ecommerce()
				"entertainment":
					_build_entertainment()
				"ai_company":
					_build_ai_company()
				"supermarket":
					_build_supermarket()
				"education_center":
					_build_education_center()
				"clinic":
					_build_clinic()
				"logistics":
					_build_logistics()
				_:
					_build_tea_shop()
	_add_industry_signature(visual_type)
	var label: = Label3D.new()
	label.text = business_name
	label.font_size = 30 if visual_type.begins_with("premium_") else 26
	label.outline_size = 8 if visual_type.begins_with("premium_") else 6
	label.modulate = Color("ffe18a") if visual_type.begins_with("premium_") else Color(0.96, 0.98, 0.92, 1)
	label.position = Vector3(0, 3.15 if visual_type.begins_with("premium_") else 1.42, plot_size.y * 0.28)
	label.rotation_degrees.x = -62
	business_root.add_child(label)


func _build_premium_business(visual_type: String) -> void:
	# 高级业态统一从真正的 GLB 建筑起步，再用不同体量、裙房、冠顶和
	# 发光构件形成六种轮廓；不再回退到旧版的纯方块楼。
	var finance_path := "res://assets/Buildings/finance/finance_tower.glb"
	var tech_path := "res://assets/Buildings/tech/tech_lab.glb"
	var gold := Color("e6bf5f")
	var cyan := Color("68d8e6")
	match visual_type:
		"premium_spire":
			_add_premium_import(finance_path, "InvestmentBankSpire", 2.0, Vector3(0, 0.38, 0))
			business_root.add_child(_positioned_box("SpireBeacon", Vector3(0, 3.0, 0), Vector3(0.07, 1.05, 0.07), gold))
		"premium_twin":
			_add_premium_import(finance_path, "AssetTowerA", 1.08, Vector3(-0.58, 0.38, 0.08), -0.08)
			_add_premium_import(finance_path, "AssetTowerB", 1.0, Vector3(0.58, 0.38, 0.08), 0.08)
			business_root.add_child(_positioned_box("AssetSkyBridge", Vector3(0, 1.72, -0.02), Vector3(1.28, 0.14, 0.34), cyan))
		"premium_crystal":
			_add_premium_import(tech_path, "FintechCrystalCampus", 2.35, Vector3(0, 0.38, 0), PI)
			business_root.add_child(_positioned_box("ResearchLightAxis", Vector3(0, 1.7, -0.76), Vector3(1.9, 0.05, 0.05), Color("b69af1")))
		"premium_terrace":
			_add_premium_import(tech_path, "DataExchangeTerrace", 2.25, Vector3(0, 0.38, 0), PI * 0.5)
			for level in range(3):
				business_root.add_child(_positioned_box("DataRibbon%d" % level, Vector3(0, 0.82 + level * 0.42, -0.82), Vector3(2.1 - level * 0.22, 0.045, 0.05), cyan))
		"premium_crown":
			_add_premium_import(finance_path, "ClearingCrownTower", 2.05, Vector3(0, 0.38, 0), PI)
			for index in range(5):
				business_root.add_child(_positioned_box("ClearingCrown%d" % index, Vector3((index - 2) * 0.22, 2.66 + abs(index - 2) * 0.1, 0), Vector3(0.12, 0.5 - abs(index - 2) * 0.05, 0.12), gold))
		"premium_arc":
			_add_premium_import(tech_path, "ConventionAtrium", 1.65, Vector3(0, 0.38, -0.02))
			for side in [-1.0, 1.0]:
				var wing := _positioned_box("ConventionWing", Vector3(side * 0.88, 0.72, 0.08), Vector3(0.92, 0.54, 1.38), Color("497f91"))
				wing.rotation_degrees.z = side * 8.0
				business_root.add_child(wing)
			business_root.add_child(_positioned_box("ConventionArch", Vector3(0, 1.18, -0.72), Vector3(1.2, 0.09, 0.09), gold))


func _add_premium_import(path: String, model_name: String, target_width: float, position_value: Vector3, yaw: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	model.name = model_name
	model.position = position_value
	model.rotation.y = yaw
	_fit_imported_model(model, target_width)
	model.scale *= 1.0 + float(business_stage) * 0.08
	business_root.add_child(model)
	return model


func _add_industry_signature(visual_type: String) -> void :
	var accent: = Color(0.28, 0.78, 1.0, 1.0)
	var sign: = _positioned_box("IndustrySign", Vector3(0, 1.18, - plot_size.y * 0.29), Vector3(0.72, 0.24, 0.05), accent)
	var marker: = _mesh_cylinder("IndustryMarker", 0.12, 0.22, accent)
	marker.position = Vector3( - plot_size.x * 0.28, 1.04, - plot_size.y * 0.18)
	match visual_type:
		"finance_center":
			accent = Color(1.0, 0.72, 0.22, 1.0)
			sign.scale = Vector3(1.2, 1.0, 1.0)
			marker.position.y = 1.38
		"ai_company":
			accent = Color(0.22, 0.78, 1.0, 1.0)
			marker.position.y = 1.58
			marker.scale = Vector3(0.72, 1.8, 0.72)
		"clinic":
			accent = Color(0.95, 0.28, 0.28, 1.0)
			sign.scale = Vector3(0.72, 1.2, 1.0)
		"education_center":
			accent = Color(0.36, 0.78, 0.52, 1.0)
			marker.scale = Vector3(1.2, 0.76, 1.2)
		"logistics":
			accent = Color(0.94, 0.52, 0.2, 1.0)
			sign.scale = Vector3(1.3, 0.85, 1.0)
		"mall":
			accent = Color(0.96, 0.42, 0.72, 1.0)
			sign.scale = Vector3(1.42, 1.1, 1.0)
		"entertainment":
			accent = Color(0.74, 0.44, 1.0, 1.0)
			marker.scale = Vector3(1.5, 1.5, 1.5)
		"supermarket", "convenience_store":
			accent = Color(0.42, 0.86, 0.44, 1.0)
		"live_ecommerce":
			accent = Color(0.96, 0.34, 0.68, 1.0)
		"creative_park", "tea_shop":
			accent = Color(0.58, 0.78, 0.98, 1.0)
	sign.material_override = _material(accent, true, true)
	marker.material_override = _material(accent, true, true)
	business_root.add_child(sign)
	business_root.add_child(marker)


func _add_kenney_business(visual_type: String) -> bool:
	var path: String = {
		"convenience_store": KENNEY_COMMERCIAL + "building-a.glb", 
		"tea_shop": KENNEY_COMMERCIAL + "building-b.glb", 
		"supermarket": KENNEY_COMMERCIAL + "building-f.glb", 
		"entertainment": KENNEY_COMMERCIAL + "building-j.glb", 
		"live_ecommerce": KENNEY_COMMERCIAL + "building-e.glb", 
		"logistics": KENNEY_INDUSTRIAL + "building-p.glb", 
		"ai_company": KENNEY_COMMERCIAL + "building-skyscraper-d.glb", 
		"creative_park": KENNEY_SUBURBAN + "building-type-l.glb", 
		"mall": KENNEY_COMMERCIAL + "building-h.glb", 
		"finance_center": KENNEY_COMMERCIAL + "building-skyscraper-a.glb", 
		"education_center": KENNEY_SUBURBAN + "building-type-q.glb", 
		"clinic": KENNEY_SUBURBAN + "building-type-r.glb"
	}.get(visual_type, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var packed: = load(path) as PackedScene
	if packed == null:
		return false
	var model: = packed.instantiate() as Node3D
	if model == null:
		return false
	model.name = "Kenney_%s" % visual_type
	model.position = Vector3(0, 0.37, 0)
	model.rotation.y = PI if visual_type in ["mall", "finance_center"] else 0.0
	_fit_imported_model(model, 2.05 if visual_type not in ["mall", "logistics"] else 2.65)
	model.scale *= 1.0 + float(business_stage) * 0.1
	business_root.add_child(model)
	return true


func _fit_imported_model(model: Node3D, target_width: float) -> void :
	var widest: = 0.1
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: = node as MeshInstance3D
		if mesh_node.mesh:
			var bounds: = mesh_node.mesh.get_aabb().size
			widest = maxf(widest, maxf(bounds.x, bounds.z))
	var scale_value: = target_width / widest
	model.scale = Vector3.ONE * scale_value

func _business_factory_id(visual_type: String) -> String:
	return {
		"tea_shop": "tea_shop_01", 
		"convenience_store": "convenience_store_01", 
		"live_ecommerce": "live_ecommerce_01", 
		"entertainment": "entertainment_center_01", 
		"ai_company": "ai_tech_01", 
		"finance_center": "finance_center_01", 
		"hotel": "hotel_01", 
		"creative_park": "creative_park_01", 
		"mall": "mall_01"
	}.get(visual_type, "")


func _set_business_stage(stage: int) -> void :
	business_stage = clampi(stage, 0, 2)
	_clear_business_visual()
	_build_business_visual(str(current_business_type.get("visual_type", "")), str(current_business_type.get("name", "")))
	_show_floating_text("繁荣升级" if business_stage == 1 else "地标升级", Color(1.0, 0.82, 0.28, 1))
	_play_ground_pulse(Color(0.26, 0.82, 1.0, 0.62) if business_stage == 1 else Color(1.0, 0.72, 0.2, 0.72))


func _business_module_scale(visual_type: String) -> float:
	match visual_type:
		"logistics":
			return 0.72
		"ai_company":
			return 0.58
		"mall":
			return 0.74
		"finance_center":
			return 0.64
		_:
			return 0.82


func _build_tea_shop() -> void :
	business_root.add_child(_positioned_box("TeaShopBody", Vector3(0, 0.82, 0), Vector3(1.35, 0.72, 0.9), Color(0.96, 0.58, 0.42, 1)))
	business_root.add_child(_positioned_box("TeaShopRoof", Vector3(0, 1.25, 0), Vector3(1.55, 0.16, 1.05), Color(0.42, 0.26, 0.22, 1)))
	business_root.add_child(_positioned_box("TeaAwning", Vector3(0, 1.02, -0.52), Vector3(1.5, 0.16, 0.25), Color(0.98, 0.84, 0.3, 1)))
	business_root.add_child(_positioned_box("TeaSign", Vector3(0, 1.17, -0.57), Vector3(0.88, 0.26, 0.05), Color(0.28, 0.18, 0.12, 1)))


func _build_convenience_store() -> void :
	business_root.add_child(_positioned_box("StoreBody", Vector3(0, 0.78, 0), Vector3(1.55, 0.68, 1.0), Color(0.7, 0.92, 0.72, 1)))
	business_root.add_child(_positioned_box("StoreRoof", Vector3(0, 1.19, 0), Vector3(1.75, 0.16, 1.15), Color(0.18, 0.48, 0.32, 1)))
	business_root.add_child(_positioned_box("StoreStripe", Vector3(0, 1.02, -0.53), Vector3(1.42, 0.18, 0.05), Color(0.96, 0.35, 0.3, 1)))
	business_root.add_child(_positioned_box("StoreDoor", Vector3(-0.42, 0.6, -0.54), Vector3(0.28, 0.42, 0.05), Color(0.22, 0.42, 0.55, 1)))


func _build_live_ecommerce() -> void :
	business_root.add_child(_positioned_box("LiveStudio", Vector3(-0.25, 0.82, 0.05), Vector3(1.25, 0.84, 0.9), Color(0.3, 0.34, 0.48, 1)))
	business_root.add_child(_positioned_box("LiveGlass", Vector3(-0.25, 0.78, -0.48), Vector3(0.98, 0.56, 0.05), Color(0.62, 0.84, 1.0, 0.92)))
	business_root.add_child(_positioned_box("LiveScreen", Vector3(-0.25, 1.08, -0.53), Vector3(0.92, 0.34, 0.05), Color(0.95, 0.28, 0.68, 1)))
	business_root.add_child(_positioned_box("LiveRoof", Vector3(-0.25, 1.28, 0.05), Vector3(1.42, 0.16, 1.05), Color(0.14, 0.18, 0.28, 1)))
	business_root.add_child(_positioned_box("LiveWarehouse", Vector3(0.75, 0.62, 0.2), Vector3(0.9, 0.52, 0.85), Color(0.62, 0.68, 0.72, 1)))
	business_root.add_child(_positioned_box("LiveTower", Vector3(-0.92, 1.16, 0.32), Vector3(0.18, 1.35, 0.18), Color(0.18, 0.24, 0.35, 1)))
	business_root.add_child(_positioned_box("LiveAntenna", Vector3(-0.92, 1.92, 0.32), Vector3(0.08, 0.38, 0.08), Color(0.95, 0.28, 0.68, 1)))


func _build_entertainment() -> void :
	business_root.add_child(_positioned_box("FunHall", Vector3(0.1, 0.72, 0.1), Vector3(1.45, 0.62, 0.95), Color(0.74, 0.38, 0.82, 1)))
	business_root.add_child(_positioned_box("FunGlassFront", Vector3(0.1, 0.72, -0.4), Vector3(1.1, 0.42, 0.05), Color(0.92, 0.76, 1.0, 0.9)))
	business_root.add_child(_positioned_box("FunRoof", Vector3(0.1, 1.12, 0.1), Vector3(1.7, 0.18, 1.16), Color(0.3, 0.16, 0.48, 1)))
	business_root.add_child(_positioned_box("FunSign", Vector3(0.1, 1.02, -0.52), Vector3(0.86, 0.22, 0.05), Color(1.0, 0.72, 0.22, 1)))
	for angle in [0, 60, 120]:
		var spoke: = _mesh_box("WheelSpoke", Vector3(0.08, 0.72, 0.08), Color(0.96, 0.76, 0.24, 1))
		spoke.position = Vector3(-0.78, 1.02, -0.3)
		spoke.rotation_degrees.z = angle
		business_root.add_child(spoke)
	business_root.add_child(_positioned_box("WheelStand", Vector3(-0.78, 0.58, -0.3), Vector3(0.12, 0.65, 0.12), Color(0.24, 0.24, 0.3, 1)))


func _build_ai_company() -> void :
	business_root.add_child(_positioned_box("AiTower", Vector3(0, 1.08, 0), Vector3(1.18, 1.38, 0.92), Color(0.34, 0.62, 0.84, 1)))
	business_root.add_child(_positioned_box("AiGlass", Vector3(0, 1.12, -0.48), Vector3(0.82, 1.02, 0.05), Color(0.8, 0.96, 1.0, 0.96)))
	business_root.add_child(_positioned_box("AiCore", Vector3(0.52, 1.44, 0.1), Vector3(0.18, 0.76, 0.18), Color(0.2, 0.86, 1.0, 1)))
	business_root.add_child(_positioned_box("AiRoof", Vector3(0, 1.84, 0), Vector3(1.35, 0.14, 1.05), Color(0.12, 0.22, 0.32, 1)))


func _build_logistics() -> void :
	business_root.add_child(_positioned_box("Warehouse", Vector3(-0.1, 0.7, 0), Vector3(1.75, 0.62, 1.15), Color(0.62, 0.68, 0.68, 1)))
	business_root.add_child(_positioned_box("WarehouseRoof", Vector3(-0.1, 1.08, 0), Vector3(1.95, 0.18, 1.3), Color(0.3, 0.38, 0.4, 1)))
	business_root.add_child(_positioned_box("LoadingDoor", Vector3(-0.55, 0.6, -0.61), Vector3(0.42, 0.42, 0.05), Color(0.18, 0.24, 0.28, 1)))
	business_root.add_child(_positioned_box("TruckBody", Vector3(0.72, 0.55, -0.38), Vector3(0.72, 0.34, 0.36), Color(0.22, 0.52, 0.86, 1)))
	business_root.add_child(_positioned_box("Container", Vector3(0.55, 0.52, 0.42), Vector3(0.7, 0.36, 0.45), Color(0.94, 0.54, 0.28, 1)))


func _build_supermarket() -> void :
	business_root.add_child(_positioned_box("MarketBody", Vector3(0, 0.76, 0), Vector3(1.95, 0.72, 1.18), Color(0.72, 0.88, 0.62, 1)))
	business_root.add_child(_positioned_box("MarketRoof", Vector3(0, 1.2, 0), Vector3(2.15, 0.18, 1.36), Color(0.18, 0.54, 0.34, 1)))
	business_root.add_child(_positioned_box("MarketFrontGlass", Vector3(0, 0.74, -0.61), Vector3(1.46, 0.42, 0.05), Color(0.7, 0.92, 1.0, 0.92)))
	business_root.add_child(_positioned_box("MarketSign", Vector3(0, 1.08, -0.68), Vector3(1.36, 0.24, 0.05), Color(0.98, 0.84, 0.28, 1)))
	for x in [-0.55, 0.0, 0.55]:
		business_root.add_child(_positioned_box("MarketAwning", Vector3(x, 1.0, -0.73), Vector3(0.36, 0.12, 0.12), Color(0.96, 0.34, 0.28, 1)))


func _build_education_center() -> void :
	business_root.add_child(_positioned_box("EducationBody", Vector3(0, 0.82, 0), Vector3(1.62, 0.86, 1.05), Color(0.82, 0.68, 0.48, 1)))
	business_root.add_child(_positioned_box("EducationRoof", Vector3(0, 1.32, 0), Vector3(1.86, 0.16, 1.22), Color(0.36, 0.28, 0.22, 1)))
	business_root.add_child(_positioned_box("EducationBookA", Vector3(-0.42, 1.58, -0.14), Vector3(0.18, 0.42, 0.55), Color(0.3, 0.5, 0.82, 1)))
	business_root.add_child(_positioned_box("EducationBookB", Vector3(-0.12, 1.56, -0.14), Vector3(0.18, 0.36, 0.55), Color(0.86, 0.42, 0.3, 1)))
	business_root.add_child(_positioned_box("EducationBoard", Vector3(0.38, 0.86, -0.56), Vector3(0.58, 0.34, 0.05), Color(0.12, 0.34, 0.24, 1)))
	business_root.add_child(_positioned_box("EducationStep", Vector3(0, 0.42, -0.62), Vector3(1.05, 0.14, 0.22), Color(0.54, 0.46, 0.36, 1)))


func _build_clinic() -> void :
	business_root.add_child(_positioned_box("ClinicBody", Vector3(0, 0.8, 0), Vector3(1.58, 0.78, 1.04), Color(0.88, 0.96, 0.94, 1)))
	business_root.add_child(_positioned_box("ClinicRoof", Vector3(0, 1.26, 0), Vector3(1.82, 0.16, 1.2), Color(0.26, 0.62, 0.64, 1)))
	business_root.add_child(_positioned_box("ClinicGlass", Vector3(0, 0.75, -0.55), Vector3(1.12, 0.4, 0.05), Color(0.62, 0.88, 1.0, 0.92)))
	business_root.add_child(_positioned_box("ClinicCrossV", Vector3(0, 1.2, -0.62), Vector3(0.16, 0.48, 0.05), Color(0.86, 0.18, 0.2, 1)))
	business_root.add_child(_positioned_box("ClinicCrossH", Vector3(0, 1.2, -0.63), Vector3(0.48, 0.16, 0.05), Color(0.86, 0.18, 0.2, 1)))


func _create_label() -> void :
	var bubble_position: = Vector3(0, 1.58, plot_size.y * 0.36)
	title_bubble_back = MeshInstance3D.new()
	title_bubble_back.name = "PlotInfoBubble"
	var back_mesh: = QuadMesh.new()
	back_mesh.size = Vector2(1.85, 0.84)
	title_bubble_back.mesh = back_mesh
	title_bubble_back.position = bubble_position
	title_bubble_back.material_override = _bubble_material(Color(0.025, 0.075, 0.105, 0.94), -2)
	title_bubble_back.visible = false
	add_child(title_bubble_back)

	title_bubble_accent = MeshInstance3D.new()
	title_bubble_accent.name = "PlotInfoAccent"
	var accent_mesh: = QuadMesh.new()
	accent_mesh.size = Vector2(0.14, 0.66)
	title_bubble_accent.mesh = accent_mesh
	title_bubble_accent.position = bubble_position + Vector3(-0.78, 0.0, 0.0)
	title_bubble_accent.material_override = _bubble_material(available_color, -1)
	title_bubble_accent.visible = false
	add_child(title_bubble_accent)

	title_label = Label3D.new()
	title_label.name = "PlotLabel"
	title_label.font_size = 42
	title_label.pixel_size = 0.011
	title_label.outline_size = 7
	title_label.modulate = Color(0.96, 0.98, 0.94, 1.0)
	title_label.outline_modulate = Color(0.035, 0.075, 0.095, 0.96)
	title_label.position = bubble_position
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title_label.no_depth_test = true
	title_label.visible = false
	add_child(title_label)
	_update_title_label()


func _update_title_label() -> void :
	if title_label == null:
		return
	var owner_id: = str(data.get("owner", ""))
	var owner_name: = str(data.get("owner_name", owner_id))
	var district_name: = str(data.get("district_name", "城市地块")).replace("服务区", "").replace("办公区", "").replace("社区区", "社区").replace("消费区", "").replace("生活商务区", "滨水区")
	var site_name: String = str({
		"parking_redevelopment": "停车更新", 
		"brownfield": "旧厂更新", 
		"unused_hardstand": "闲置硬地", 
		"courtyard_renewal": "庭院更新", 
		"waterfront_reserve": "滨水预留", 
	}.get(str(data.get("site_type", "")), "开发用地"))
	var status: = "%s %s" % [district_name, site_name]
	if not owner_id.is_empty():
		status = "%s  已购" % owner_name.left(7)
	if visual_state == "construction":
		status = "%s  建设中" % owner_name.left(7)
	elif visual_state == "open":
		status = "%s  经营中" % owner_name.left(7)
	title_label.text = status
	_resize_title_bubble(clampf(1.95 + float(status.length()) * 0.16, 2.45, 4.35))
	if title_bubble_accent:
		var accent_color: = owner_color if not owner_id.is_empty() else available_color
		title_bubble_accent.material_override = _bubble_material(accent_color, -1)
	if not owner_id.is_empty():
		_ensure_land_name_label()
	if land_name_label:
		land_name_label.text = str(data.get("land_name", data.get("land_id", "")))
		land_name_label.modulate = owner_color.lerp(Color.WHITE, 0.46)
		land_name_label.outline_modulate = Color(0.015, 0.045, 0.065, 0.98)
		land_name_label.position = Vector3(building_anchor.x, _land_name_height(), building_anchor.y)
		land_name_label.visible = not owner_id.is_empty()


func _ensure_land_name_label() -> void :
	if land_name_label:
		return
	land_name_label = Label3D.new()
	land_name_label.name = "OwnedLandName"
	land_name_label.font_size = 48
	land_name_label.pixel_size = 0.0115
	land_name_label.outline_size = 10
	land_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	land_name_label.no_depth_test = true
	land_name_label.visible = false
	add_child(land_name_label)


func _land_name_height() -> float:
	if visual_state == "open":
		return 7.4
	if visual_state == "construction":
		return 4.8
	return 2.45


func _resize_title_bubble(width: float) -> void :
	if title_bubble_back and title_bubble_back.mesh is QuadMesh:
		(title_bubble_back.mesh as QuadMesh).size = Vector2(width, 0.84)
	if title_bubble_accent:
		title_bubble_accent.position.x = - width * 0.5 + 0.15


func debug_information_profile() -> Dictionary:
	var construction_label: = construction_root.get_node_or_null("ConstructionLabel") as Label3D if construction_root else null
	var construction_text: = construction_label.text if construction_label else ""
	return {
		"has_bubble_back": title_bubble_back != null, 
		"bubble_line_count": title_label.text.count("\n") + 1 if title_label else 0, 
		"bubble_text": title_label.text if title_label else "", 
		"construction_label_lines": construction_text.count("\n") + 1 if not construction_text.is_empty() else 0, 
		"label_pixel_size": title_label.pixel_size if title_label else 0.0, 
		"owned_land_name": land_name_label.text if land_name_label else "", 
		"owned_land_name_visible": land_name_label.visible if land_name_label else false, 
	}


func _bubble_material(color: Color, priority: int) -> StandardMaterial3D:
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = priority
	return mat


func _create_state_beacon() -> void :
	state_beacon_root = Node3D.new()
	state_beacon_root.name = "StateBeacon"
	state_beacon_root.position = Vector3(plot_size.x * 0.34, 0.42, plot_size.y * 0.3)
	add_child(state_beacon_root)
	var pedestal: = _mesh_cylinder("BeaconPedestal", 0.16, 0.1, Color(0.12, 0.16, 0.18, 1.0))
	pedestal.position.y = 0.05
	state_beacon_root.add_child(pedestal)
	var light: = _mesh_cylinder("BeaconLight", 0.1, 0.24, Color(0.32, 0.84, 1.0, 1.0))
	light.position.y = 0.2
	state_beacon_root.add_child(light)
	var crown: = _mesh_box("LandmarkCrown", Vector3(0.34, 0.06, 0.34), Color(1.0, 0.74, 0.24, 1.0))
	crown.position.y = 0.36
	crown.visible = false
	state_beacon_root.add_child(crown)
	state_beacon_root.visible = false


func _site_accent(site_type: String) -> Color:
	return {
		"parking_redevelopment": Color(0.56, 0.7, 0.76, 1.0), 
		"brownfield": Color(0.72, 0.56, 0.34, 1.0), 
		"unused_hardstand": Color(0.62, 0.66, 0.62, 1.0), 
		"courtyard_renewal": Color(0.4, 0.7, 0.5, 1.0), 
		"waterfront_reserve": Color(0.3, 0.72, 0.82, 1.0), 
	}.get(site_type, Color(0.6, 0.64, 0.58, 1.0))


func _add_line_segment(name_value: String, start: Vector2, end: Vector2, width: float, height: float, y: float, color: Color) -> void :
	add_child(_line_segment_mesh(name_value, start, end, width, height, y, color))


func _line_segment_mesh(name_value: String, start: Vector2, end: Vector2, width: float, height: float, y: float, color: Color) -> MeshInstance3D:
	var delta: = end - start
	var line: = _mesh_box(name_value, Vector3(maxf(delta.length(), 0.01), height, width), color)
	var middle: = (start + end) * 0.5
	line.position = Vector3(middle.x, y, middle.y)
	line.rotation.y = - atan2(delta.y, delta.x)
	return line


func _add_bar(name_value: String, pos: Vector3, size: Vector3, color: Color) -> void :
	add_child(_positioned_box(name_value, pos, size, color))


func _positioned_box(name_value: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: = _mesh_box(name_value, size, color)
	mesh.position = pos
	return mesh


func _mesh_box(name_value: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	mesh.name = name_value
	var box: = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	return mesh


func _mesh_cylinder(name_value: String, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	mesh.name = name_value
	var cylinder: = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	return mesh


func _on_area_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var now: = Time.get_ticks_msec() / 1000.0
		if now - last_click_time < 0.32:
			double_clicked.emit(self)
		else:
			clicked.emit(self)
		last_click_time = now
		get_viewport().set_input_as_handled()


func _refresh_visual() -> void :
	var has_owner: = str(data.get("owner", "")) != ""
	var surface_color: = PAVER_COLOR.lerp(available_color, 0.12)
	if visual_state == "construction":
		surface_color = Color(0.28, 0.25, 0.18, 1)
	elif visual_state == "open":
		surface_color = owner_color.lerp(Color(0.16, 0.24, 0.23, 1), 0.42)
	elif has_owner:
		surface_color = owner_color.lerp(Color(0.18, 0.28, 0.26, 1), 0.35)
	elif is_hovered:
		surface_color = HOVER_COLOR
	if visualization_mode == "heat":
		surface_color = MapHeatScale.color_for_ratio(float(visualization_payload.get("ratio", 0.5)))
	elif visualization_mode == "control":
		surface_color = owner_color.lightened(0.08) if has_owner else Color("58646a")
	elif visualization_mode == "traffic":
		var traffic_score: = clampf(float(visualization_payload.get("traffic", 0.0)), 0.0, 1.0)
		surface_color = Color("354a55").lerp(Color("3bd4c5"), traffic_score)
	if context_dimmed and not is_selected:
		surface_color = surface_color.darkened(0.58)


	surface_color.a = 0.96 if is_selected or is_hovered or has_owner else 0.72 if not context_dimmed else 0.44
	surface_mesh.material_override = _material(surface_color, true)
	var idle_base_alpha: = 0.46 if is_selected or is_hovered or has_owner else 0.32
	base_mesh.material_override = _material(Color(0.01, 0.03, 0.04, idle_base_alpha + 0.12) if context_dimmed else Color(0.03, 0.07, 0.08, idle_base_alpha), true)
	glow_mesh.visible = is_selected or is_hovered or is_wind_focus or is_district_focus
	var glow_color: = Color(SELECTED_COLOR, 0.26) if is_selected else Color(0.46, 0.92, 1.0, 0.16)
	if is_district_focus and not is_selected and not is_hovered:
		glow_color = Color(0.2, 0.92, 1.0, 0.18)
	elif is_wind_focus and not is_selected and not is_hovered:
		glow_color = Color(1.0, 0.76, 0.24, 0.5)
	glow_mesh.material_override = _overlay_material(glow_color)
	focus_outline_root.visible = is_selected or is_district_focus




	var show_title: = is_selected or is_hovered or is_district_focus
	title_label.visible = show_title
	if title_bubble_back:
		title_bubble_back.visible = show_title
	if title_bubble_accent:
		title_bubble_accent.visible = show_title
	var focus_color: = SELECTED_COLOR if is_selected else Color(0.2, 0.94, 1.0, 1.0)
	for child: Node in focus_outline_root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _overlay_material(focus_color)
	title_label.modulate = Color(0.58, 0.65, 0.66, 0.48) if context_dimmed else Color(1.0, 1.0, 0.96, 1.0)
	if is_district_focus:
		title_label.modulate = Color(0.94, 1.0, 1.0, 1.0)
	if title_bubble_back:
		var bubble_alpha: = 0.4 if context_dimmed else 0.96 if is_district_focus else 0.9
		title_bubble_back.material_override = _bubble_material(Color(0.018, 0.055, 0.072, bubble_alpha), -2)
	owner_band_root.visible = has_owner
	sale_sign_root.visible = not has_owner and visual_state == "unowned"
	if sale_sign_root.visible:
		var sign_scale: = 1.1 if is_selected else 1.04 if is_hovered or is_district_focus else 0.88
		sale_sign_root.scale = Vector3.ONE * sign_scale
	for child in owner_band_root.get_children():
		if child is MeshInstance3D:
			child.material_override = _material(owner_color)
	var flag: = flag_root.get_node("FlagCloth") as MeshInstance3D
	flag.material_override = _material(owner_color)
	_refresh_state_beacon(has_owner)
	_update_title_label()


func _refresh_state_beacon(has_owner: bool) -> void :
	if state_beacon_root == null:
		return
	state_beacon_root.visible = has_owner
	var light: = state_beacon_root.get_node_or_null("BeaconLight") as MeshInstance3D
	var crown: = state_beacon_root.get_node_or_null("LandmarkCrown") as MeshInstance3D
	if light == null or crown == null:
		return
	var color: = owner_color.lightened(0.12)
	if visual_state == "construction":
		color = Color(1.0, 0.7, 0.22, 1.0)
	elif visual_state == "open":
		color = Color(0.35, 0.86, 0.55, 1.0)
	light.material_override = _material(color, true, true)
	crown.visible = visual_state == "open" and business_stage >= 2
	if crown.visible:
		crown.material_override = _material(Color(1.0, 0.74, 0.24, 1.0), true, true)


func _available_color_from_tags(tags: Array) -> Color:
	if tags.has("商业中心"):
		return Color(0.62, 0.54, 0.38, 1)
	if tags.has("校园周边"):
		return Color(0.58, 0.6, 0.4, 1)
	if tags.has("医院周边"):
		return Color(0.47, 0.65, 0.61, 1)
	if tags.has("住宅区"):
		return Color(0.49, 0.64, 0.43, 1)
	if tags.has("交通枢纽"):
		return Color(0.48, 0.53, 0.52, 1)
	if tags.has("郊区空地"):
		return Color(0.46, 0.61, 0.42, 1)
	if tags.has("政务区"):
		return Color(0.5, 0.55, 0.56, 1)
	return Color(0.54, 0.56, 0.47, 1)


func _show_floating_text(text: String, color: Color) -> void :
	for child in feedback_root.get_children():
		transient_pool.release(child)
	var label: = transient_pool.acquire("floating_label", feedback_root, func() -> Node: return Label3D.new()) as Label3D
	label.text = text
	label.font_size = 34
	label.outline_size = 8
	label.modulate = color
	label.position = Vector3(0, 1.65, - plot_size.y * 0.2)
	label.rotation_degrees.x = -58
	label.position = Vector3(0, 1.65, - plot_size.y * 0.2)
	label.modulate.a = 1.0
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 2.35, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.1)
	tween.tween_callback(transient_pool.release.bind(label))


func _play_ground_pulse(color: Color) -> void :
	var pulse: = transient_pool.acquire("ground_pulse", self, func() -> Node: return MeshInstance3D.new()) as MeshInstance3D
	pulse.name = "GroundPulse"
	pulse.mesh = ParcelGeometry.mesh_for_polygon(parcel_points, 0.0)
	pulse.position = Vector3(0, 0.095, 0)
	pulse.material_override = _material(color, true, true)
	pulse.scale = Vector3.ONE
	var tween: = pulse.create_tween()
	tween.tween_property(pulse, "scale", Vector3(1.18, 1.0, 1.18), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(transient_pool.release.bind(pulse))


func _play_celebration_burst() -> void :
	for index in range(8):
		var spark: = transient_pool.acquire("opening_spark", self, func() -> Node: return MeshInstance3D.new()) as MeshInstance3D
		spark.name = "OpeningSpark"
		var mesh: = BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.08)
		spark.mesh = mesh
		spark.position = Vector3(0, 1.35, 0)
		spark.material_override = _material(Color(1.0, 0.72 + randf() * 0.2, 0.18, 0.92), true, true)
		spark.scale = Vector3.ONE
		var angle: = TAU * float(index) / 8.0
		var target: = Vector3(cos(angle) * 1.25, 2.05 + randf() * 0.35, sin(angle) * 0.85)
		var tween: = spark.create_tween()
		tween.tween_property(spark, "position", target, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.62)
		tween.tween_callback(transient_pool.release.bind(spark))


func _set_risk_badge(visible_value: bool) -> void :
	risk_badge_root.visible = visible_value


func _material(color: Color, transparent: = false, emission: = false) -> StandardMaterial3D:
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.48
	mat.metallic = 0.06
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.65
	return mat


func _overlay_material(color: Color) -> StandardMaterial3D:
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 1.8
	mat.render_priority = 6
	return mat
