class_name CityAssetFactory
extends RefCounted

const MAT_ROUGH: = 0.68
static func create_building(module_id: String, growth_stage: int = 0) -> Node3D:
	var root: = Node3D.new()
	root.name = module_id
	match module_id:
		"small_shop_01":
			_build_small_shop(root, Color(0.88, 0.52, 0.36, 1), "SHOP")
		"tea_shop_01":
			_build_small_shop(root, Color(0.95, 0.52, 0.42, 1), "TEA")
			_add_awning(root, Vector3(0, 0.92, -0.66), Color(0.98, 0.84, 0.28, 1))
		"convenience_store_01":
			_build_small_shop(root, Color(0.66, 0.86, 0.62, 1), "24H")
			_add_box(root, "StoreStripe", Vector3(0, 1.02, -0.71), Vector3(1.7, 0.16, 0.04), Color(0.95, 0.24, 0.22, 1))
		"residential_block_01":
			_build_residential(root, Color(0.78, 0.62, 0.48, 1), 3, true)
		"residential_block_02":
			_build_residential(root, Color(0.66, 0.74, 0.84, 1), 4, false)
		"school_building_01":
			_build_school(root)
		"hospital_01":
			_build_hospital(root)
		"office_tower_01":
			_build_office(root, 2.8)
		"mall_01":
			_build_mall(root)
		"logistics_warehouse_01":
			_build_warehouse(root)
		"government_building_01":
			_build_government(root)
		"station_01":
			_build_station(root)
		"live_ecommerce_01":
			_build_live_ecommerce(root)
		"entertainment_center_01":
			_build_entertainment_center(root)
		"ai_tech_01":
			_build_ai_tech(root)
		"finance_center_01":
			_build_finance_center(root)
		"hotel_01":
			_build_hotel(root)
		"creative_park_01":
			_build_creative_park(root)
		_:
			_build_small_shop(root, Color(0.82, 0.7, 0.54, 1), "SHOP")
	_add_growth_stage(root, module_id, clampi(growth_stage, 0, 2))
	return root


static func _add_growth_stage(root: Node3D, module_id: String, stage: int) -> void :
	if stage <= 0:
		return
	var accent: Color = {
		"tea_shop_01": Color(1.0, 0.64, 0.22, 1), 
		"convenience_store_01": Color(0.34, 0.92, 0.56, 1), 
		"live_ecommerce_01": Color(1.0, 0.3, 0.68, 1), 
		"entertainment_center_01": Color(0.76, 0.34, 1.0, 1), 
		"ai_tech_01": Color(0.18, 0.84, 1.0, 1), 
		"logistics_warehouse_01": Color(1.0, 0.62, 0.2, 1), 
		"finance_center_01": Color(1.0, 0.78, 0.24, 1), 
		"hotel_01": Color(1.0, 0.66, 0.3, 1), 
		"creative_park_01": Color(0.34, 0.92, 0.68, 1)
	}.get(module_id, Color(0.28, 0.78, 1.0, 1))
	_add_box(root, "ProsperityPlaza", Vector3(0, 0.035, -0.96), Vector3(2.55, 0.07, 0.64), Color(0.34, 0.38, 0.4, 1))
	for x in [-0.92, 0.92]:
		_add_box(root, "ProsperityPlanter", Vector3(x, 0.16, -1.02), Vector3(0.38, 0.28, 0.32), Color(0.22, 0.5, 0.3, 1))
		_add_box(root, "ProsperityLamp", Vector3(x * 0.72, 0.42, -1.1), Vector3(0.055, 0.78, 0.055), Color(0.2, 0.24, 0.28, 1))
		_add_box(root, "ProsperityGlow", Vector3(x * 0.72, 0.82, -1.1), Vector3(0.16, 0.12, 0.16), accent, true)
	_add_box(root, "ProsperityRibbon", Vector3(0, 0.12, -1.18), Vector3(1.55, 0.055, 0.05), accent, true)
	if stage < 2:
		return
	_add_box(root, "LandmarkCrownA", Vector3(0, 3.48, 0), Vector3(1.12, 0.12, 0.22), accent, true)
	_add_box(root, "LandmarkCrownB", Vector3(0, 3.48, 0), Vector3(0.22, 0.12, 1.12), accent, true)
	_add_cylinder(root, "LandmarkBeacon", Vector3(0, 3.9, 0), 0.055, 0.78, accent)
	_add_box(root, "LandmarkLight", Vector3(0, 4.3, 0), Vector3(0.22, 0.22, 0.22), accent, true)
	_add_box(root, "LandmarkTotem", Vector3(-1.15, 0.68, -1.08), Vector3(0.22, 1.22, 0.22), accent, true)
	_add_label(root, "LANDMARK", Vector3(0, 0.34, -1.22), 18, Color(1.0, 0.96, 0.76, 1))


static func building_ids() -> Array[String]:
	return [
		"small_shop_01", 
		"tea_shop_01", 
		"convenience_store_01", 
		"residential_block_01", 
		"residential_block_02", 
		"school_building_01", 
		"hospital_01", 
		"office_tower_01", 
		"mall_01", 
		"logistics_warehouse_01", 
		"government_building_01", 
		"station_01", 
		"live_ecommerce_01", 
		"entertainment_center_01", 
		"ai_tech_01", 
		"finance_center_01", 
		"hotel_01", 
		"creative_park_01"
	]


static func road_ids() -> Array[String]:
	return [
		"straight_road", 
		"crossroad", 
		"corner_road", 
		"sidewalk", 
		"zebra_crossing", 
		"parking_lot"
	]


static func prop_ids() -> Array[String]:
	return [
		"tree", 
		"street_light", 
		"bench", 
		"bus_stop", 
		"billboard", 
		"traffic_sign", 
		"small_car", 
		"truck", 
		"fence", 
		"for_sale_sign"
		, "pedestrian", 
		"pedestrian_blue", 
		"pedestrian_coral", 
		"pedestrian_green", 
		"pedestrian_gold", 
		"neon_sign"
	]


static func create_vehicle_variant(variant: int = 0, is_truck: = false) -> Node3D:
	var root: = Node3D.new()
	root.name = "truck" if is_truck else "small_car_%d" % variant
	if is_truck:
		_build_truck(root)
	else:
		var colors: = [Color("d94b42"), Color("327bbd"), Color("e1b83f"), Color("4f9b69")]
		_build_car(root, colors[posmod(variant, colors.size())], false)
	return root


static func create_prop(module_id: String) -> Node3D:
	var root: = Node3D.new()
	root.name = module_id
	match module_id:
		"tree":
			_add_cylinder(root, "Trunk", Vector3(0, 0.22, 0), 0.055, 0.44, Color(0.36, 0.22, 0.14, 1))
			_add_box(root, "CrownA", Vector3(0, 0.56, 0), Vector3(0.42, 0.46, 0.42), Color(0.2, 0.52, 0.3, 1))
			_add_box(root, "CrownB", Vector3(0.05, 0.82, -0.04), Vector3(0.32, 0.3, 0.32), Color(0.26, 0.62, 0.34, 1))
		"street_light":
			_add_cylinder(root, "Pole", Vector3(0, 0.45, 0), 0.035, 0.9, Color(0.24, 0.26, 0.28, 1))
			_add_box(root, "Head", Vector3(0.12, 0.92, 0), Vector3(0.28, 0.1, 0.16), Color(1.0, 0.86, 0.42, 1), true)
		"bench":
			_add_box(root, "Seat", Vector3(0, 0.26, 0), Vector3(0.72, 0.08, 0.22), Color(0.5, 0.28, 0.16, 1))
			_add_box(root, "Back", Vector3(0, 0.42, 0.12), Vector3(0.72, 0.16, 0.06), Color(0.5, 0.28, 0.16, 1))
			for x in [-0.28, 0.28]:
				_add_box(root, "Leg", Vector3(x, 0.12, 0), Vector3(0.05, 0.24, 0.05), Color(0.2, 0.2, 0.18, 1))
		"bus_stop":
			_add_box(root, "ShelterBack", Vector3(0, 0.52, 0.08), Vector3(1.2, 0.78, 0.06), Color(0.22, 0.42, 0.62, 0.85))
			_add_box(root, "Roof", Vector3(0, 0.95, 0), Vector3(1.36, 0.1, 0.58), Color(0.16, 0.22, 0.3, 1))
			_add_box(root, "Sign", Vector3(-0.46, 0.72, -0.24), Vector3(0.26, 0.22, 0.04), Color(0.96, 0.76, 0.24, 1))
		"billboard":
			_add_cylinder(root, "Pole", Vector3(0, 0.42, 0), 0.035, 0.84, Color(0.28, 0.3, 0.32, 1))
			_add_box(root, "Face", Vector3(0, 0.86, -0.02), Vector3(0.84, 0.38, 0.05), Color(0.92, 0.28, 0.48, 1), true)
			_add_box(root, "Stripe", Vector3(0, 0.92, -0.055), Vector3(0.56, 0.06, 0.03), Color(1.0, 0.95, 0.58, 1), true)
		"traffic_sign":
			_add_cylinder(root, "Pole", Vector3(0, 0.35, 0), 0.025, 0.7, Color(0.32, 0.32, 0.34, 1))
			_add_box(root, "Sign", Vector3(0, 0.72, -0.02), Vector3(0.34, 0.28, 0.04), Color(0.2, 0.54, 0.84, 1))
		"small_car":
			_build_car(root, Color(0.86, 0.24, 0.22, 1), false)
		"truck":
			_build_truck(root)
		"fence":
			for x in [-0.45, 0, 0.45]:
				_add_box(root, "Post", Vector3(x, 0.24, 0), Vector3(0.05, 0.48, 0.05), Color(0.56, 0.42, 0.25, 1))
			_add_box(root, "RailA", Vector3(0, 0.36, 0), Vector3(1.05, 0.05, 0.05), Color(0.68, 0.52, 0.3, 1))
			_add_box(root, "RailB", Vector3(0, 0.18, 0), Vector3(1.05, 0.05, 0.05), Color(0.68, 0.52, 0.3, 1))
		"for_sale_sign":
			_add_cylinder(root, "Pole", Vector3(0, 0.33, 0), 0.032, 0.66, Color(0.36, 0.3, 0.22, 1))
			_add_box(root, "Board", Vector3(0.26, 0.64, 0), Vector3(0.78, 0.32, 0.045), Color(0.96, 0.76, 0.28, 1))
			_add_label(root, "待售", Vector3(0.26, 0.65, -0.04), 26, Color(0.12, 0.09, 0.05, 1))
		"pedestrian", "pedestrian_blue", "pedestrian_coral", "pedestrian_green", "pedestrian_gold":
			_build_pedestrian(root, module_id)
		"neon_sign":
			_add_cylinder(root, "Pole", Vector3(0, 0.42, 0), 0.035, 0.84, Color(0.18, 0.22, 0.28, 1))
			_add_box(root, "GlowBoard", Vector3(0.0, 0.92, -0.02), Vector3(0.92, 0.36, 0.05), Color(0.18, 0.78, 1.0, 1), true)
			_add_box(root, "GoldStripe", Vector3(0.0, 1.0, -0.055), Vector3(0.62, 0.05, 0.03), Color(1.0, 0.72, 0.22, 1), true)
			_add_label(root, "OPEN", Vector3(0.0, 0.9, -0.07), 22, Color(1.0, 0.92, 0.5, 1))
	return root


static func create_road(module_id: String) -> Node3D:
	var root: = Node3D.new()
	root.name = module_id
	match module_id:
		"straight_road":
			_add_box(root, "Asphalt", Vector3.ZERO, Vector3(4.0, 0.08, 1.34), Color(0.105, 0.125, 0.145, 1))
			_add_box(root, "CurbNorth", Vector3(0, 0.065, -0.69), Vector3(4.0, 0.13, 0.08), Color(0.64, 0.67, 0.66, 1))
			_add_box(root, "CurbSouth", Vector3(0, 0.065, 0.69), Vector3(4.0, 0.13, 0.08), Color(0.64, 0.67, 0.66, 1))
			_add_box(root, "EdgeNorth", Vector3(0, 0.052, -0.5), Vector3(4.0, 0.025, 0.035), Color(0.88, 0.88, 0.78, 1))
			_add_box(root, "EdgeSouth", Vector3(0, 0.052, 0.5), Vector3(4.0, 0.025, 0.035), Color(0.88, 0.88, 0.78, 1))
			for x in [-1.2, 0, 1.2]:
				_add_box(root, "LaneDash", Vector3(x, 0.055, 0), Vector3(0.55, 0.025, 0.045), Color(0.96, 0.82, 0.3, 1))
		"crossroad":
			_add_box(root, "RoadA", Vector3.ZERO, Vector3(4.0, 0.08, 1.34), Color(0.105, 0.125, 0.145, 1))
			_add_box(root, "RoadB", Vector3.ZERO, Vector3(1.34, 0.09, 4.0), Color(0.11, 0.13, 0.15, 1))
			for corner in [Vector3(-0.82, 0.055, -0.82), Vector3(0.82, 0.055, -0.82), Vector3(-0.82, 0.055, 0.82), Vector3(0.82, 0.055, 0.82)]:
				_add_box(root, "CornerMark", corner, Vector3(0.34, 0.025, 0.34), Color(0.76, 0.78, 0.74, 1))
		"corner_road":
			_add_box(root, "RoadA", Vector3(-0.7, 0, 0), Vector3(2.6, 0.08, 1.2), Color(0.17, 0.19, 0.21, 1))
			_add_box(root, "RoadB", Vector3(0.7, 0, 0.7), Vector3(1.2, 0.09, 2.6), Color(0.18, 0.2, 0.22, 1))
		"sidewalk":
			_add_box(root, "Pavers", Vector3.ZERO, Vector3(3.8, 0.1, 0.48), Color(0.66, 0.7, 0.7, 1))
			for x in [-1.2, 0, 1.2]:
				_add_box(root, "PaverLine", Vector3(x, 0.045, 0), Vector3(0.035, 0.025, 0.42), Color(0.62, 0.64, 0.6, 1))
		"zebra_crossing":
			for x in [-0.48, -0.24, 0, 0.24, 0.48]:
				_add_box(root, "Stripe", Vector3(x, 0.04, 0), Vector3(0.1, 0.025, 1.15), Color(0.95, 0.95, 0.88, 1))
		"parking_lot":
			_add_box(root, "Base", Vector3.ZERO, Vector3(2.8, 0.06, 1.8), Color(0.18, 0.21, 0.23, 1))
			for x in [-0.9, 0, 0.9]:
				_add_box(root, "Slot", Vector3(x, 0.045, 0), Vector3(0.55, 0.025, 1.25), Color(0.86, 0.86, 0.76, 1))
	return root


static func _build_small_shop(root: Node3D, wall: Color, sign_text: String) -> void :
	_add_box(root, "Body", Vector3(0, 0.55, 0), Vector3(1.55, 1.1, 1.1), wall)
	_add_box(root, "StonePlinth", Vector3(0, 0.13, -0.01), Vector3(1.68, 0.2, 1.2), Color(0.38, 0.42, 0.4, 1))
	_add_box(root, "FrontFrame", Vector3(0, 0.58, -0.63), Vector3(1.44, 0.76, 0.055), wall.darkened(0.22))
	_add_gable_roof(root, "Roof", Vector3(0, 1.02, 0), Vector3(1.78, 0.42, 1.3), wall.darkened(0.35))
	_add_box(root, "GlassDoor", Vector3(-0.42, 0.42, -0.58), Vector3(0.32, 0.58, 0.045), Color(0.55, 0.78, 0.92, 0.92))
	_add_box(root, "WindowA", Vector3(0.2, 0.55, -0.58), Vector3(0.42, 0.34, 0.04), Color(0.76, 0.92, 1.0, 0.92))
	_add_box(root, "WindowB", Vector3(0.68, 0.55, -0.58), Vector3(0.3, 0.34, 0.04), Color(0.76, 0.92, 1.0, 0.92))
	_add_box(root, "SideWindowLeft", Vector3(-0.8, 0.56, 0.1), Vector3(0.04, 0.3, 0.42), Color(0.72, 0.9, 1.0, 0.88), true)
	_add_box(root, "SideWindowRight", Vector3(0.8, 0.56, 0.1), Vector3(0.04, 0.3, 0.42), Color(0.72, 0.9, 1.0, 0.88), true)
	_add_box(root, "SignBoard", Vector3(0, 0.95, -0.62), Vector3(1.15, 0.28, 0.055), Color(0.12, 0.18, 0.24, 1), true)
	_add_label(root, sign_text, Vector3(0, 0.96, -0.67), 24, Color(1.0, 0.92, 0.58, 1))
	for x in [-0.62, -0.18, 0.26, 0.68]:
		_add_box(root, "FacadeRib", Vector3(x, 0.57, -0.67), Vector3(0.035, 0.76, 0.045), wall.darkened(0.35))


static func _build_residential(root: Node3D, wall: Color, floors: int, balconies: bool) -> void :
	var height: = 0.38 * floors + 0.28
	_add_box(root, "Body", Vector3(0, height * 0.5, 0), Vector3(1.3, height, 1.05), wall)
	_add_box(root, "GroundFloorBand", Vector3(0, 0.22, -0.01), Vector3(1.4, 0.24, 1.12), wall.darkened(0.2))
	_add_box(root, "VerticalCore", Vector3(-0.62, height * 0.5, -0.01), Vector3(0.1, height * 0.95, 1.12), wall.darkened(0.28))
	_add_gable_roof(root, "Roof", Vector3(0, height - 0.02, 0), Vector3(1.5, 0.34, 1.24), Color(0.42, 0.46, 0.48, 1))
	for f in range(floors):
		var y: = 0.32 + float(f) * 0.34
		for x in [-0.36, 0.12, 0.48]:
			_add_box(root, "Window", Vector3(x, y, -0.55), Vector3(0.18, 0.16, 0.035), Color(0.96, 0.86, 0.5, 1), true)
			_add_box(root, "BackWindow", Vector3(x, y, 0.55), Vector3(0.18, 0.16, 0.035), Color(0.88, 0.92, 0.76, 1), true)
			_add_box(root, "SideWindowL", Vector3(-0.67, y, x * 0.9), Vector3(0.035, 0.16, 0.16), Color(0.86, 0.92, 1.0, 0.9), true)
			_add_box(root, "SideWindowR", Vector3(0.67, y, x * 0.9), Vector3(0.035, 0.16, 0.16), Color(0.86, 0.92, 1.0, 0.9), true)
		if balconies:
			_add_box(root, "Balcony", Vector3(-0.42, y - 0.08, -0.62), Vector3(0.36, 0.06, 0.18), Color(0.72, 0.72, 0.7, 1))
			_add_box(root, "BalconyRail", Vector3(-0.42, y, -0.72), Vector3(0.36, 0.08, 0.035), Color(0.52, 0.54, 0.54, 1))
			_add_box(root, "BalconySideRail", Vector3(-0.24, y, -0.62), Vector3(0.035, 0.08, 0.18), Color(0.52, 0.54, 0.54, 1))
	_add_box(root, "Entrance", Vector3(0, 0.18, -0.56), Vector3(0.28, 0.36, 0.04), Color(0.22, 0.2, 0.18, 1))
	_add_box(root, "RoofTank", Vector3(0.42, height + 0.24, 0.12), Vector3(0.3, 0.28, 0.24), Color(0.52, 0.58, 0.6, 1))
	_add_box(root, "RoofVent", Vector3(-0.3, height + 0.14, -0.12), Vector3(0.18, 0.16, 0.16), Color(0.62, 0.66, 0.66, 1))


static func _build_school(root: Node3D) -> void :
	_add_box(root, "MainHall", Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 1.05), Color(0.86, 0.66, 0.38, 1))
	_add_box(root, "LeftWing", Vector3(-1.05, 0.36, 0.64), Vector3(0.7, 0.72, 0.8), Color(0.74, 0.52, 0.32, 1))
	_add_box(root, "RightWing", Vector3(1.05, 0.36, 0.64), Vector3(0.7, 0.72, 0.8), Color(0.74, 0.52, 0.32, 1))
	_add_box(root, "FrontArcade", Vector3(0, 0.36, -0.64), Vector3(2.72, 0.18, 0.1), Color(0.48, 0.28, 0.18, 1))
	_add_gable_roof(root, "Roof", Vector3(0, 0.96, 0), Vector3(2.9, 0.42, 1.28), Color(0.48, 0.22, 0.17, 1))
	for floor_index in range(2):
		var y: = 0.46 + floor_index * 0.3
		for i in range(6):
			_add_box(root, "ClassWindow", Vector3(-1.1 + i * 0.44, y, -0.57), Vector3(0.22, 0.14, 0.035), Color(0.98, 0.9, 0.58, 1), true)
			_add_box(root, "BackClassWindow", Vector3(-1.1 + i * 0.44, y, 0.57), Vector3(0.22, 0.14, 0.035), Color(0.98, 0.9, 0.58, 1), true)
	_add_box(root, "Gate", Vector3(0, 0.28, -0.72), Vector3(0.56, 0.55, 0.07), Color(0.42, 0.18, 0.12, 1))
	_add_label(root, "SCHOOL", Vector3(0, 0.98, -0.62), 24, Color(0.18, 0.12, 0.08, 1))
	_add_box(root, "FrontSteps", Vector3(0, 0.08, -0.86), Vector3(0.92, 0.1, 0.28), Color(0.66, 0.62, 0.54, 1))
	_add_box(root, "Playground", Vector3(0, 0.04, 1.25), Vector3(3.1, 0.06, 1.45), Color(0.48, 0.72, 0.44, 1))
	_add_box(root, "Track", Vector3(0, 0.08, 1.25), Vector3(2.55, 0.035, 0.92), Color(0.7, 0.34, 0.24, 1))
	_add_cylinder(root, "FlagPole", Vector3(-1.2, 0.52, -0.76), 0.025, 1.04, Color(0.88, 0.88, 0.82, 1))
	_add_box(root, "Flag", Vector3(-1.02, 0.9, -0.76), Vector3(0.35, 0.2, 0.035), Color(0.88, 0.12, 0.12, 1))
	_add_box(root, "RoofSkylight", Vector3(0.72, 1.2, 0.05), Vector3(0.5, 0.05, 0.24), Color(0.76, 0.92, 1.0, 0.85), true)


static func _build_hospital(root: Node3D) -> void :
	_add_box(root, "Tower", Vector3(0, 0.75, 0), Vector3(1.85, 1.5, 1.2), Color(0.62, 0.78, 0.82, 1))
	_add_box(root, "Wing", Vector3(0.82, 0.45, 0.72), Vector3(1.25, 0.9, 0.82), Color(0.56, 0.72, 0.76, 1))
	_add_box(root, "EmergencyWing", Vector3(-0.92, 0.42, 0.58), Vector3(0.92, 0.84, 0.76), Color(0.58, 0.74, 0.78, 1))
	_add_box(root, "GroundMedicalBand", Vector3(0, 0.2, -0.01), Vector3(2.05, 0.22, 1.34), Color(0.58, 0.72, 0.78, 1))
	_add_box(root, "RoofCapMain", Vector3(0, 1.54, 0), Vector3(2.02, 0.12, 1.32), Color(0.46, 0.6, 0.66, 1))
	_add_box(root, "RoofCapWing", Vector3(0.82, 0.92, 0.72), Vector3(1.36, 0.1, 0.92), Color(0.44, 0.58, 0.64, 1))
	_add_box(root, "BlueTrimA", Vector3(0, 0.42, -0.64), Vector3(1.72, 0.08, 0.05), Color(0.38, 0.66, 0.8, 1))
	_add_box(root, "BlueTrimB", Vector3(0, 0.98, -0.64), Vector3(1.72, 0.08, 0.05), Color(0.38, 0.66, 0.8, 1))
	_add_box(root, "CornerColumnL", Vector3(-0.96, 0.75, -0.04), Vector3(0.08, 1.52, 1.28), Color(0.7, 0.78, 0.8, 1))
	_add_box(root, "CornerColumnR", Vector3(0.96, 0.75, -0.04), Vector3(0.08, 1.52, 1.28), Color(0.7, 0.78, 0.8, 1))
	_add_box(root, "EntranceCanopy", Vector3(0, 0.44, -0.7), Vector3(1.1, 0.14, 0.3), Color(0.52, 0.72, 0.82, 1))
	_add_box(root, "Door", Vector3(0, 0.26, -0.76), Vector3(0.42, 0.48, 0.04), Color(0.26, 0.46, 0.58, 1))
	_add_box(root, "CrossV", Vector3(0, 1.32, -0.62), Vector3(0.16, 0.48, 0.05), Color(0.86, 0.18, 0.22, 1), true)
	_add_box(root, "CrossH", Vector3(0, 1.32, -0.64), Vector3(0.48, 0.16, 0.05), Color(0.86, 0.18, 0.22, 1), true)
	for x in [-0.55, 0.0, 0.55]:
		for y in [0.5, 0.78, 1.06]:
			_add_box(root, "Window", Vector3(x, y, -0.63), Vector3(0.24, 0.16, 0.035), Color(0.72, 0.9, 0.98, 1))
			_add_box(root, "RearWindow", Vector3(x, y, 0.63), Vector3(0.24, 0.16, 0.035), Color(0.72, 0.9, 0.98, 1))
			_add_box(root, "SideWindow", Vector3(-0.96, y, x * 0.7), Vector3(0.035, 0.15, 0.2), Color(0.72, 0.9, 0.98, 1))
			_add_box(root, "RightSideWindow", Vector3(0.96, y, x * 0.7), Vector3(0.035, 0.15, 0.2), Color(0.72, 0.9, 0.98, 1))
	for z in [-0.42, 0.0, 0.42]:
		_add_box(root, "BlueSideStripeL", Vector3(-0.99, 0.72, z), Vector3(0.04, 0.08, 0.32), Color(0.28, 0.58, 0.74, 1))
		_add_box(root, "BlueSideStripeR", Vector3(0.99, 0.72, z), Vector3(0.04, 0.08, 0.32), Color(0.28, 0.58, 0.74, 1))
	_add_box(root, "SideCrossV", Vector3(-0.98, 1.16, 0.05), Vector3(0.04, 0.36, 0.1), Color(0.86, 0.18, 0.22, 1), true)
	_add_box(root, "SideCrossH", Vector3(-0.99, 1.16, 0.05), Vector3(0.04, 0.12, 0.34), Color(0.86, 0.18, 0.22, 1), true)
	_add_box(root, "EmergencySign", Vector3(-0.46, 0.46, -0.7), Vector3(0.52, 0.18, 0.05), Color(0.9, 0.22, 0.2, 1), true)
	_add_box(root, "HelipadBase", Vector3(0.58, 1.55, 0.28), Vector3(0.58, 0.04, 0.58), Color(0.88, 0.9, 0.9, 1))
	_add_box(root, "HelipadH1", Vector3(0.58, 1.58, 0.28), Vector3(0.08, 0.025, 0.36), Color(0.86, 0.18, 0.22, 1), true)
	_add_box(root, "HelipadH2", Vector3(0.58, 1.59, 0.28), Vector3(0.34, 0.025, 0.08), Color(0.86, 0.18, 0.22, 1), true)


static func _build_office(root: Node3D, height: float) -> void :
	_add_box(root, "Tower", Vector3(0, height * 0.5, 0), Vector3(1.15, height, 1.0), Color(0.28, 0.46, 0.62, 1))
	_add_box(root, "GlassFront", Vector3(0, height * 0.5, -0.53), Vector3(0.92, height * 0.88, 0.04), Color(0.56, 0.84, 1.0, 0.92), true)
	_add_box(root, "GlassSideA", Vector3(-0.59, height * 0.5, 0), Vector3(0.04, height * 0.82, 0.72), Color(0.58, 0.78, 0.92, 0.86), true)
	_add_box(root, "GlassSideB", Vector3(0.59, height * 0.5, 0), Vector3(0.04, height * 0.82, 0.72), Color(0.58, 0.78, 0.92, 0.86), true)
	_add_box(root, "SideCoreA", Vector3(-0.42, height * 0.5, -0.55), Vector3(0.08, height * 0.92, 0.06), Color(0.12, 0.18, 0.24, 1))
	_add_box(root, "SideCoreB", Vector3(0.42, height * 0.5, -0.55), Vector3(0.08, height * 0.92, 0.06), Color(0.12, 0.18, 0.24, 1))
	_add_box(root, "RoofCap", Vector3(0, height + 0.08, 0), Vector3(1.32, 0.16, 1.16), Color(0.14, 0.23, 0.3, 1))
	for y in range(max(3, int(height / 0.35))):
		_add_box(root, "GlassBand", Vector3(0, 0.42 + y * 0.32, -0.56), Vector3(0.95, 0.045, 0.035), Color(0.94, 0.98, 1.0, 1), true)
		for x in [-0.27, 0.0, 0.27]:
			_add_box(root, "GlassPane", Vector3(x, 0.42 + y * 0.32, -0.585), Vector3(0.035, 0.2, 0.025), Color(0.12, 0.22, 0.32, 1))
	_add_box(root, "RoofAntenna", Vector3(0.28, height + 0.34, 0), Vector3(0.06, 0.52, 0.06), Color(0.1, 0.16, 0.2, 1))
	_add_box(root, "RoofBeacon", Vector3(-0.25, height + 0.24, -0.15), Vector3(0.18, 0.16, 0.18), Color(0.26, 0.78, 1.0, 1), true)
	_add_box(root, "Lobby", Vector3(0, 0.22, -0.6), Vector3(0.72, 0.38, 0.05), Color(0.94, 0.82, 0.42, 1), true)


static func _build_mall(root: Node3D) -> void :
	_add_box(root, "Podium", Vector3(0, 0.55, 0), Vector3(2.6, 1.1, 1.55), Color(0.5, 0.56, 0.64, 1))
	_add_box(root, "StoneBase", Vector3(0, 0.16, -0.01), Vector3(2.72, 0.28, 1.66), Color(0.38, 0.42, 0.46, 1))
	_add_box(root, "UpperBand", Vector3(0, 1.04, -0.01), Vector3(2.72, 0.18, 1.66), Color(0.18, 0.22, 0.3, 1))
	_add_box(root, "SecondFloor", Vector3(0, 0.94, 0.1), Vector3(2.32, 0.36, 1.28), Color(0.36, 0.44, 0.54, 1))
	_add_box(root, "CornerTower", Vector3(1.04, 0.96, -0.28), Vector3(0.64, 1.1, 0.74), Color(0.28, 0.34, 0.44, 1))
	_add_box(root, "Atrium", Vector3(-0.45, 0.72, -0.84), Vector3(0.95, 0.82, 0.06), Color(0.5, 0.74, 0.92, 0.88), true)
	_add_box(root, "Sign", Vector3(0.45, 0.96, -0.86), Vector3(1.25, 0.3, 0.07), Color(0.12, 0.16, 0.24, 1), true)
	_add_label(root, "MALL", Vector3(0.45, 0.97, -0.91), 26, Color(1.0, 0.82, 0.36, 1))
	_add_box(root, "NeonPink", Vector3(-0.78, 1.18, -0.88), Vector3(0.42, 0.08, 0.05), Color(1.0, 0.3, 0.6, 1), true)
	_add_box(root, "NeonBlue", Vector3(1.05, 1.18, -0.88), Vector3(0.42, 0.08, 0.05), Color(0.18, 0.72, 1.0, 1), true)
	for x in [-1.02, -0.48, 0.08, 0.64, 1.16]:
		_add_box(root, "ShopWindow", Vector3(x, 0.42, -0.84), Vector3(0.34, 0.36, 0.05), Color(0.88, 0.96, 1.0, 0.88), true)
		_add_box(root, "WindowFrame", Vector3(x, 0.42, -0.875), Vector3(0.39, 0.045, 0.035), Color(0.12, 0.16, 0.2, 1))
	for x in [-0.88, -0.28, 0.32, 0.92]:
		_add_box(root, "UpperWindow", Vector3(x, 0.84, -0.86), Vector3(0.34, 0.18, 0.045), Color(0.56, 0.86, 1.0, 0.86), true)
	_add_box(root, "RoofUnitA", Vector3(-0.75, 1.18, 0.32), Vector3(0.44, 0.18, 0.32), Color(0.42, 0.46, 0.48, 1))
	_add_box(root, "RoofUnitB", Vector3(0.86, 1.18, 0.28), Vector3(0.36, 0.16, 0.28), Color(0.48, 0.52, 0.54, 1))
	_add_box(root, "RoofCafe", Vector3(0.12, 1.24, 0.46), Vector3(0.64, 0.2, 0.36), Color(0.72, 0.44, 0.3, 1))
	_add_box(root, "RoofCafeGlass", Vector3(0.12, 1.27, 0.25), Vector3(0.5, 0.14, 0.035), Color(0.72, 0.92, 1.0, 0.88), true)
	_add_box(root, "SideBanner", Vector3(1.33, 0.72, 0.15), Vector3(0.05, 0.76, 0.38), Color(1.0, 0.4, 0.26, 1), true)
	for x in [-1.05, -0.35, 0.35, 1.05]:
		_add_box(root, "VerticalFacade", Vector3(x, 0.64, -0.86), Vector3(0.08, 0.78, 0.06), Color(0.28, 0.34, 0.42, 1))
	for x in [-0.72, 0.0, 0.72]:
		_add_box(root, "SideWindow", Vector3(1.33, 0.42, x), Vector3(0.05, 0.34, 0.28), Color(0.78, 0.92, 1.0, 0.88), true)
		_add_box(root, "LeftSideWindow", Vector3(-1.33, 0.42, x), Vector3(0.05, 0.34, 0.28), Color(0.78, 0.92, 1.0, 0.88), true)
	for x in [-0.78, -0.24, 0.32, 0.88]:
		_add_box(root, "BackArcadeWindow", Vector3(x, 0.48, 0.84), Vector3(0.34, 0.28, 0.05), Color(0.7, 0.92, 1.0, 0.88), true)
		_add_box(root, "BackUpperWindow", Vector3(x, 0.82, 0.84), Vector3(0.34, 0.16, 0.05), Color(0.56, 0.86, 1.0, 0.88), true)
	_add_box(root, "BackSign", Vector3(0, 0.98, 0.86), Vector3(1.3, 0.24, 0.06), Color(0.95, 0.5, 0.22, 1), true)
	_add_label(root, "PLAZA", Vector3(0, 0.99, 0.91), 22, Color(0.12, 0.08, 0.04, 1))


static func _build_warehouse(root: Node3D) -> void :
	_add_box(root, "Warehouse", Vector3(0, 0.58, 0), Vector3(2.6, 1.15, 1.55), Color(0.6, 0.66, 0.66, 1))
	_add_box(root, "PanelBandA", Vector3(-0.7, 0.66, -0.83), Vector3(0.08, 0.82, 0.05), Color(0.42, 0.48, 0.5, 1))
	_add_box(root, "PanelBandB", Vector3(0.05, 0.66, -0.83), Vector3(0.08, 0.82, 0.05), Color(0.42, 0.48, 0.5, 1))
	_add_box(root, "PanelBandC", Vector3(0.8, 0.66, -0.83), Vector3(0.08, 0.82, 0.05), Color(0.42, 0.48, 0.5, 1))
	_add_box(root, "Roof", Vector3(0, 1.22, 0), Vector3(2.84, 0.2, 1.75), Color(0.28, 0.36, 0.38, 1))
	_add_box(root, "LoadingDoor", Vector3(-0.62, 0.4, -0.82), Vector3(0.58, 0.62, 0.05), Color(0.18, 0.24, 0.28, 1))
	_add_box(root, "OfficeDoor", Vector3(0.72, 0.33, -0.82), Vector3(0.32, 0.5, 0.04), Color(0.32, 0.48, 0.58, 1))
	_add_box(root, "SkylightA", Vector3(-0.55, 1.36, 0.2), Vector3(0.62, 0.04, 0.22), Color(0.72, 0.9, 1.0, 0.82), true)
	_add_box(root, "SkylightB", Vector3(0.55, 1.36, 0.2), Vector3(0.62, 0.04, 0.22), Color(0.72, 0.9, 1.0, 0.82), true)
	_add_label(root, "LOGI", Vector3(0.56, 0.78, -0.86), 22, Color(1.0, 0.92, 0.58, 1))
	_build_truck(root, Vector3(1.65, 0, -0.35))
	for x in [-1.0, 0.0, 1.0]:
		_add_box(root, "Container", Vector3(x, 0.25, 1.08), Vector3(0.72, 0.42, 0.42), Color(0.92, 0.48, 0.24, 1))


static func _build_government(root: Node3D) -> void :
	_add_box(root, "Steps", Vector3(0, 0.12, -0.72), Vector3(2.9, 0.24, 0.72), Color(0.7, 0.7, 0.72, 1))
	_add_box(root, "Hall", Vector3(0, 0.72, 0), Vector3(2.55, 1.2, 1.25), Color(0.78, 0.78, 0.82, 1))
	_add_box(root, "PedimentBase", Vector3(0, 1.16, -0.68), Vector3(2.75, 0.18, 0.22), Color(0.62, 0.62, 0.66, 1))
	_add_box(root, "Roof", Vector3(0, 1.42, 0), Vector3(2.88, 0.2, 1.52), Color(0.44, 0.46, 0.5, 1))
	for x in [-0.9, -0.3, 0.3, 0.9]:
		_add_cylinder(root, "Column", Vector3(x, 0.62, -0.68), 0.06, 0.96, Color(0.94, 0.92, 0.86, 1))
		_add_box(root, "TallWindow", Vector3(x, 0.78, 0.64), Vector3(0.18, 0.4, 0.04), Color(0.76, 0.86, 0.94, 1))
	_add_cylinder(root, "FlagPole", Vector3(-1.35, 0.7, -0.84), 0.025, 1.4, Color(0.88, 0.88, 0.82, 1))
	_add_box(root, "Flag", Vector3(-1.15, 1.12, -0.84), Vector3(0.42, 0.24, 0.035), Color(0.86, 0.12, 0.12, 1))


static func _build_station(root: Node3D) -> void :
	_add_box(root, "Hall", Vector3(0, 0.5, 0), Vector3(2.8, 1.0, 1.25), Color(0.44, 0.5, 0.56, 1))
	_add_box(root, "TicketOffice", Vector3(-1.02, 0.42, -0.78), Vector3(0.58, 0.62, 0.26), Color(0.28, 0.36, 0.44, 1))
	_add_box(root, "ClockFace", Vector3(1.05, 0.96, -0.69), Vector3(0.36, 0.36, 0.05), Color(0.92, 0.92, 0.82, 1), true)
	_add_box(root, "Roof", Vector3(0, 1.1, 0), Vector3(3.25, 0.22, 1.62), Color(0.24, 0.3, 0.34, 1))
	_add_box(root, "RoofOverhang", Vector3(0, 1.02, -0.14), Vector3(3.55, 0.1, 1.88), Color(0.18, 0.23, 0.28, 1))
	_add_box(root, "Glass", Vector3(0, 0.6, -0.66), Vector3(2.1, 0.54, 0.05), Color(0.42, 0.7, 0.9, 0.9), true)
	for x in [-1.1, -0.55, 0, 0.55, 1.1]:
		_add_box(root, "StationMullion", Vector3(x, 0.6, -0.7), Vector3(0.05, 0.58, 0.04), Color(0.16, 0.2, 0.24, 1))
	_add_label(root, "STATION", Vector3(0, 1.02, -0.72), 24, Color(1.0, 0.92, 0.55, 1))
	for x in [-0.9, -0.3, 0.3, 0.9]:
		_add_box(root, "BusBay", Vector3(x, 0.06, 1.0), Vector3(0.44, 0.06, 0.42), Color(0.16, 0.24, 0.32, 1))


static func _build_live_ecommerce(root: Node3D) -> void :
	_add_box(root, "StudioPodium", Vector3(0, 0.34, 0), Vector3(2.55, 0.68, 1.55), Color(0.2, 0.25, 0.36, 1))
	_add_box(root, "StudioTower", Vector3(-0.42, 1.22, 0.1), Vector3(1.28, 1.78, 1.1), Color(0.34, 0.4, 0.54, 1))
	_add_box(root, "GlassWall", Vector3(-0.42, 1.2, -0.47), Vector3(1.02, 1.48, 0.05), Color(0.42, 0.78, 0.96, 0.9), true)
	_add_box(root, "LiveScreen", Vector3(0.7, 0.76, -0.81), Vector3(0.88, 0.72, 0.06), Color(0.96, 0.2, 0.55, 1), true)
	_add_label(root, "LIVE", Vector3(0.7, 0.78, -0.86), 28, Color(1.0, 0.94, 0.64, 1))
	for y in [0.72, 1.08, 1.44, 1.8]:
		_add_box(root, "StudioBand", Vector3(-0.42, y, -0.51), Vector3(1.08, 0.05, 0.04), Color(0.1, 0.18, 0.28, 1))
	_add_cylinder(root, "BroadcastMast", Vector3(-0.42, 2.36, 0.1), 0.035, 0.78, Color(0.82, 0.86, 0.9, 1))
	_add_box(root, "SignalA", Vector3(-0.21, 2.54, 0.1), Vector3(0.34, 0.05, 0.05), Color(1.0, 0.36, 0.62, 1), true)
	_add_box(root, "LoadingBay", Vector3(0.72, 0.3, 0.54), Vector3(0.92, 0.46, 0.42), Color(0.42, 0.46, 0.52, 1))


static func _build_entertainment_center(root: Node3D) -> void :
	_add_box(root, "EntertainmentHall", Vector3(0, 0.58, 0), Vector3(2.65, 1.16, 1.55), Color(0.34, 0.24, 0.52, 1))
	_add_box(root, "GlassEntrance", Vector3(0, 0.48, -0.82), Vector3(1.1, 0.72, 0.06), Color(0.48, 0.86, 1.0, 0.9), true)
	_add_box(root, "NeonMarquee", Vector3(0, 1.1, -0.88), Vector3(1.85, 0.34, 0.08), Color(0.98, 0.28, 0.64, 1), true)
	_add_label(root, "PLAY", Vector3(0, 1.11, -0.94), 30, Color(1.0, 0.94, 0.46, 1))
	for x in [-1.12, -0.76, 0.76, 1.12]:
		_add_box(root, "NeonPillar", Vector3(x, 0.66, -0.84), Vector3(0.1, 0.86, 0.08), Color(0.2, 0.76, 1.0, 1), true)
	_add_cylinder(root, "RoofRing", Vector3(0.7, 1.55, 0.12), 0.46, 0.12, Color(1.0, 0.62, 0.18, 1))
	_add_box(root, "RoofStage", Vector3(-0.55, 1.28, 0.2), Vector3(0.7, 0.22, 0.54), Color(0.18, 0.14, 0.3, 1))


static func _build_ai_tech(root: Node3D) -> void :
	_build_office(root, 3.05)
	_add_box(root, "TechFinLeft", Vector3(-0.72, 1.52, 0.12), Vector3(0.18, 2.52, 0.8), Color(0.12, 0.58, 0.84, 1), true)
	_add_box(root, "TechFinRight", Vector3(0.72, 1.52, 0.12), Vector3(0.18, 2.52, 0.8), Color(0.12, 0.58, 0.84, 1), true)
	_add_box(root, "ChipSign", Vector3(0, 1.54, -0.62), Vector3(0.48, 0.48, 0.06), Color(0.12, 0.16, 0.24, 1), true)
	_add_label(root, "AI", Vector3(0, 1.55, -0.68), 34, Color(0.3, 0.94, 1.0, 1))
	_add_box(root, "ServerAnnex", Vector3(0.95, 0.46, 0.52), Vector3(0.64, 0.82, 0.72), Color(0.14, 0.24, 0.34, 1))


static func _build_finance_center(root: Node3D) -> void :
	_add_box(root, "BankHall", Vector3(0, 0.7, 0), Vector3(2.55, 1.18, 1.38), Color(0.72, 0.72, 0.68, 1))
	_add_box(root, "FinanceTower", Vector3(0, 1.72, 0.28), Vector3(1.3, 2.65, 1.02), Color(0.24, 0.36, 0.48, 1))
	_add_box(root, "GoldGlassFront", Vector3(0, 1.72, -0.25), Vector3(1.02, 2.3, 0.05), Color(0.9, 0.66, 0.22, 0.92), true)
	_add_box(root, "GoldGlassBack", Vector3(0, 1.72, 0.81), Vector3(1.02, 2.3, 0.05), Color(0.9, 0.66, 0.22, 0.92), true)
	for y in [0.76, 1.1, 1.44, 1.78, 2.12, 2.46, 2.8]:
		_add_box(root, "FinanceBandFront", Vector3(0, y, -0.29), Vector3(1.08, 0.055, 0.035), Color(0.1, 0.15, 0.22, 1))
		_add_box(root, "FinanceBandBack", Vector3(0, y, 0.85), Vector3(1.08, 0.055, 0.035), Color(0.1, 0.15, 0.22, 1))
	_add_box(root, "BankSteps", Vector3(0, 0.12, -0.88), Vector3(2.85, 0.24, 0.62), Color(0.82, 0.8, 0.72, 1))
	for x in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		_add_cylinder(root, "BankColumn", Vector3(x, 0.7, -0.74), 0.075, 1.08, Color(0.94, 0.91, 0.8, 1))
	_add_box(root, "BankRoof", Vector3(0, 1.38, 0), Vector3(2.82, 0.22, 1.62), Color(0.32, 0.38, 0.42, 1))
	_add_box(root, "GoldSign", Vector3(0, 1.18, -0.83), Vector3(1.36, 0.28, 0.07), Color(0.82, 0.6, 0.16, 1), true)
	_add_label(root, "CAPITAL", Vector3(0, 1.19, -0.89), 22, Color(1.0, 0.94, 0.62, 1))
	_add_label(root, "CAPITAL", Vector3(0, 2.56, 0.87), 22, Color(1.0, 0.88, 0.36, 1))
	_add_box(root, "FinanceCrown", Vector3(0, 3.1, 0.28), Vector3(1.52, 0.2, 1.22), Color(0.78, 0.56, 0.16, 1), true)


static func _build_hotel(root: Node3D) -> void :
	_add_box(root, "HotelTower", Vector3(0, 1.5, 0.1), Vector3(1.62, 3.0, 1.22), Color(0.6, 0.48, 0.5, 1))
	_add_box(root, "HotelLobby", Vector3(0, 0.34, -0.72), Vector3(2.25, 0.68, 0.72), Color(0.36, 0.3, 0.34, 1))
	_add_box(root, "HotelCanopy", Vector3(0, 0.56, -1.06), Vector3(1.26, 0.12, 0.58), Color(0.84, 0.65, 0.25, 1), true)
	for y in [0.72, 1.12, 1.52, 1.92, 2.32, 2.72]:
		for x in [-0.48, 0.0, 0.48]:
			_add_box(root, "HotelWindow", Vector3(x, y, -0.53), Vector3(0.24, 0.18, 0.04), Color(0.82, 0.94, 1.0, 0.9), true)
	_add_box(root, "HotelCrown", Vector3(0, 3.14, 0.1), Vector3(1.86, 0.28, 1.42), Color(0.24, 0.22, 0.28, 1))
	_add_label(root, "HOTEL", Vector3(0, 2.92, -0.56), 26, Color(1.0, 0.78, 0.32, 1))


static func _build_creative_park(root: Node3D) -> void :
	_add_box(root, "StudioOrange", Vector3(-0.68, 0.58, 0.08), Vector3(1.25, 1.16, 1.28), Color(0.9, 0.42, 0.24, 1))
	_add_box(root, "StudioBlue", Vector3(0.7, 0.46, -0.1), Vector3(1.18, 0.92, 1.42), Color(0.2, 0.58, 0.78, 1))
	_add_box(root, "GlassBridge", Vector3(0, 0.76, -0.05), Vector3(0.68, 0.28, 0.42), Color(0.66, 0.9, 1.0, 0.85), true)
	for x in [-1.02, -0.68, -0.34, 0.36, 0.7, 1.04]:
		_add_box(root, "StudioWindow", Vector3(x, 0.56, -0.76), Vector3(0.18, 0.22, 0.04), Color(0.9, 0.96, 1.0, 0.9), true)
	_add_box(root, "RoofGarden", Vector3(-0.68, 1.2, 0.08), Vector3(1.12, 0.08, 1.1), Color(0.28, 0.62, 0.34, 1))
	_add_cylinder(root, "ArtTotem", Vector3(0.05, 0.48, -0.96), 0.16, 0.96, Color(0.98, 0.72, 0.2, 1))
	_add_label(root, "CREATE", Vector3(0.7, 0.96, -0.84), 22, Color(1.0, 0.92, 0.54, 1))


static func _build_car(root: Node3D, color: Color, vertical: = false, offset: = Vector3.ZERO) -> void :
	var pivot: = Node3D.new()
	pivot.name = "VehicleBody"
	pivot.position = offset
	pivot.rotation.y = PI * 0.5 if vertical else 0.0
	root.add_child(pivot)
	_add_box(pivot, "LowerBody", Vector3(0, 0.19, 0), Vector3(0.78, 0.22, 0.38), color)
	_add_box(pivot, "Hood", Vector3(0.29, 0.31, 0), Vector3(0.26, 0.12, 0.36), color.lightened(0.06))
	_add_box(pivot, "Trunk", Vector3(-0.31, 0.29, 0), Vector3(0.2, 0.1, 0.35), color.darkened(0.05))
	_add_box(pivot, "Cabin", Vector3(-0.02, 0.39, 0), Vector3(0.4, 0.22, 0.33), color.lightened(0.18))
	_add_box(pivot, "Roof", Vector3(-0.05, 0.52, 0), Vector3(0.3, 0.06, 0.31), color.lightened(0.1))
	var glass: = Color(0.24, 0.64, 0.86, 0.94)
	_add_box(pivot, "FrontWindshield", Vector3(0.18, 0.42, 0), Vector3(0.025, 0.15, 0.29), glass, true)
	_add_box(pivot, "RearWindshield", Vector3(-0.23, 0.42, 0), Vector3(0.025, 0.14, 0.29), glass, true)
	_add_box(pivot, "LeftWindows", Vector3(-0.03, 0.42, -0.172), Vector3(0.32, 0.13, 0.018), glass, true)
	_add_box(pivot, "RightWindows", Vector3(-0.03, 0.42, 0.172), Vector3(0.32, 0.13, 0.018), glass, true)
	for x in [-0.25, 0.25]:
		for z in [-0.215, 0.215]:
			var wheel: = _add_cylinder(pivot, "Wheel", Vector3(x, 0.12, z), 0.085, 0.065, Color(0.035, 0.04, 0.045, 1))
			wheel.rotation_degrees.x = 90
	_add_box(pivot, "Headlights", Vector3(0.405, 0.23, 0), Vector3(0.025, 0.085, 0.25), Color(1.0, 0.91, 0.54, 1), true)
	_add_box(pivot, "TailLights", Vector3(-0.415, 0.23, 0), Vector3(0.025, 0.075, 0.25), Color(1.0, 0.12, 0.08, 1), true)
	_add_box(pivot, "FrontBumper", Vector3(0.43, 0.145, 0), Vector3(0.035, 0.055, 0.34), Color(0.85, 0.88, 0.9, 1))
	_add_box(pivot, "RearBumper", Vector3(-0.43, 0.145, 0), Vector3(0.035, 0.055, 0.34), Color(0.85, 0.88, 0.9, 1))


static func _build_truck(root: Node3D, offset: = Vector3.ZERO) -> void :
	_add_box(root, "CargoBody", offset + Vector3(-0.2, 0.4, 0), Vector3(0.92, 0.62, 0.52), Color(0.98, 0.66, 0.18, 1))
	_add_box(root, "CargoRoof", offset + Vector3(-0.2, 0.73, 0), Vector3(0.94, 0.06, 0.54), Color(1.0, 0.8, 0.34, 1))
	_add_box(root, "TruckCab", offset + Vector3(0.46, 0.32, 0), Vector3(0.38, 0.48, 0.5), Color(0.16, 0.56, 0.88, 1))
	_add_box(root, "CabRoof", offset + Vector3(0.46, 0.59, 0), Vector3(0.4, 0.07, 0.52), Color(0.1, 0.42, 0.72, 1))
	_add_box(root, "Windshield", offset + Vector3(0.66, 0.43, 0), Vector3(0.025, 0.2, 0.38), Color(0.28, 0.72, 0.92, 1), true)
	_add_box(root, "LeftCabWindow", offset + Vector3(0.45, 0.43, -0.26), Vector3(0.25, 0.18, 0.018), Color(0.28, 0.72, 0.92, 1), true)
	_add_box(root, "RightCabWindow", offset + Vector3(0.45, 0.43, 0.26), Vector3(0.25, 0.18, 0.018), Color(0.28, 0.72, 0.92, 1), true)
	_add_box(root, "FrontGrille", offset + Vector3(0.67, 0.24, 0), Vector3(0.03, 0.13, 0.34), Color(0.13, 0.16, 0.18, 1))
	_add_box(root, "TruckHeadlights", offset + Vector3(0.69, 0.34, 0), Vector3(0.025, 0.08, 0.42), Color(1.0, 0.92, 0.58, 1), true)
	_add_box(root, "TruckRearLights", offset + Vector3(-0.67, 0.25, 0), Vector3(0.025, 0.08, 0.4), Color(1.0, 0.1, 0.06, 1), true)
	for x in [-0.48, -0.08, 0.48]:
		for z in [-0.29, 0.29]:
			var wheel: = _add_cylinder(root, "TruckWheel", offset + Vector3(x, 0.13, z), 0.105, 0.075, Color(0.035, 0.04, 0.045, 1))
			wheel.rotation_degrees.x = 90


static func _build_pedestrian(root: Node3D, variant: String) -> void :
	var cloth: Color = {
		"pedestrian_coral": Color(0.94, 0.3, 0.28, 1), 
		"pedestrian_green": Color(0.2, 0.68, 0.38, 1), 
		"pedestrian_gold": Color(0.92, 0.64, 0.16, 1), 
	}.get(variant, Color(0.18, 0.5, 0.9, 1))
	var skin: = Color(0.92, 0.69, 0.52, 1)
	_add_box(root, "Torso", Vector3(0, 0.42, 0), Vector3(0.2, 0.28, 0.13), cloth)
	_add_box(root, "ShirtAccent", Vector3(0.105, 0.45, 0), Vector3(0.018, 0.15, 0.09), cloth.lightened(0.28))
	_add_sphere(root, "Head", Vector3(0, 0.66, 0), 0.105, skin)
	_add_box(root, "Hair", Vector3(-0.018, 0.745, 0), Vector3(0.17, 0.07, 0.14), Color(0.16, 0.09, 0.05, 1))
	for z in [-0.145, 0.145]:
		var arm: = _add_cylinder(root, "Arm", Vector3(0, 0.4, z), 0.035, 0.26, skin)
		arm.rotation_degrees.x = 8.0 * signf(z)
	for z in [-0.062, 0.062]:
		_add_cylinder(root, "Leg", Vector3(0, 0.16, z), 0.042, 0.3, Color(0.12, 0.18, 0.32, 1))
		_add_box(root, "Shoe", Vector3(0.035, 0.025, z), Vector3(0.13, 0.05, 0.075), Color(0.06, 0.07, 0.08, 1))
	_add_box(root, "Backpack", Vector3(-0.12, 0.43, 0), Vector3(0.08, 0.2, 0.16), cloth.darkened(0.22))


static func _add_awning(root: Node3D, pos: Vector3, color: Color) -> void :
	_add_box(root, "Awning", pos, Vector3(1.55, 0.16, 0.3), color)
	for x in [-0.54, -0.18, 0.18, 0.54]:
		_add_box(root, "AwningStripe", pos + Vector3(x, 0.01, -0.02), Vector3(0.12, 0.18, 0.32), Color(1.0, 0.96, 0.78, 1))


static func _add_label(root: Node3D, text: String, pos: Vector3, font_size: int, color: Color) -> void :
	var label: = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 5
	label.modulate = color
	label.position = pos
	root.add_child(label)


static func _add_gable_roof(root: Node3D, name_value: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var sx: = size.x * 0.5
	var sy: = size.y
	var sz: = size.z * 0.5
	var verts: = [
		Vector3( - sx, 0, - sz), 
		Vector3(sx, 0, - sz), 
		Vector3(sx, 0, sz), 
		Vector3( - sx, 0, sz), 
		Vector3( - sx, sy, 0), 
		Vector3(sx, sy, 0)
	]
	var faces: = [
		[0, 1, 5], [0, 5, 4], 
		[3, 5, 2], [3, 4, 5], 
		[0, 4, 3], 
		[1, 2, 5], 
		[0, 3, 2], [0, 2, 1]
	]
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in face:
			st.add_vertex(pos + verts[index])
	st.generate_normals()
	var mesh: = st.commit()
	var instance: = MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.material_override = _material(color)
	root.add_child(instance)
	return instance


static func _add_box(root: Node3D, name_value: String, pos: Vector3, size: Vector3, color: Color, emission: = false) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	mesh.name = name_value
	var box: = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color, emission)
	root.add_child(mesh)
	return mesh


static func _add_cylinder(root: Node3D, name_value: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	mesh.name = name_value
	var cylinder: = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	mesh.mesh = cylinder
	mesh.position = pos
	mesh.material_override = _material(color)
	root.add_child(mesh)
	return mesh


static func _add_sphere(root: Node3D, name_value: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh: = MeshInstance3D.new()
	mesh.name = name_value
	var sphere: = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.position = pos
	mesh.material_override = _material(color)
	root.add_child(mesh)
	return mesh


static func _material(color: Color, emission: = false) -> StandardMaterial3D:
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.46 if color.get_luminance() > 0.48 else 0.58
	mat.metallic = 0.18 if color.b > color.r * 1.12 else 0.05
	mat.metallic_specular = 0.68
	mat.rim_enabled = true
	mat.rim = 0.16
	mat.rim_tint = 0.48
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		mat.emission_enabled = true
		mat.emission = color.lightened(0.1)
		mat.emission_energy_multiplier = 1.18
		mat.roughness = 0.3
	return mat
