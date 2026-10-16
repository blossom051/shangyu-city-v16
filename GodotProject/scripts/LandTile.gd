class_name LandTile
extends Node3D

signal selected(land_id: String)

const BUILDING_MODEL_PATH: = "res://assets/models/buildings/%s.tscn"
const PLOT_MODEL_PATH: = "res://assets/models/land_plots/%s.tscn"

var land_id: = ""
var data: Dictionary = {}
var body_root: Node3D
var state_root: Node3D

func setup(value: Dictionary) -> void :
	data = value
	land_id = str(value.id)
	position = Vector3(float(value.x), 0, float(value.z))
	_build_base()
	refresh(value)

func refresh(value: Dictionary) -> void :
	data = value
	if state_root:
		state_root.queue_free()
	state_root = Node3D.new()
	state_root.name = "StateVisual"
	add_child(state_root)

	var state: = str(value.get("state", "available"))
	if state == "available":
		_sale_visual()
	elif state == "owned_empty":
		_owner_visual()
	elif state == "constructing":
		_construction_visual()
	elif state in ["operating", "loss_watch", "mortgaged", "auction"]:
		_business_visual()

func _build_base() -> void :
	body_root = Node3D.new()
	add_child(body_root)
	var size: = _lot_size()
	mesh_box(body_root, Vector3(0, 0.06, 0), Vector3(size.x, 0.12, size.y), Color("b8cda2"))
	mesh_box(body_root, Vector3(0, 0.15, 0), Vector3(size.x + 0.18, 0.06, size.y + 0.18), Color("e8dfc4"), true)

	var static_body: = StaticBody3D.new()
	var collision: = CollisionShape3D.new()
	var shape: = BoxShape3D.new()
	shape.size = Vector3(size.x, 0.5, size.y)
	collision.shape = shape
	static_body.add_child(collision)
	static_body.input_event.connect(_on_input_event)
	body_root.add_child(static_body)

	var district: = Label3D.new()
	district.text = str(data.district_name)
	district.font_size = 24
	district.outline_size = 7
	district.modulate = Color("24474d")
	district.position = Vector3(0, 0.27, size.y * 0.36)
	district.rotation_degrees = Vector3(-90, 0, 0)
	body_root.add_child(district)

func _sale_visual() -> void :
	_instance_scene(PLOT_MODEL_PATH % "empty_land_plot", state_root, Vector3.ZERO, Vector3(1.28, 1.0, 1.12))
	_instance_scene("res://assets/models/props/for_sale_sign.tscn", state_root, Vector3(0.0, 0.16, 0.15), Vector3(1.75, 1.75, 1.75))
	var sign: = Label3D.new()
	sign.text = "待售\n%d 万" % int(data.price)
	sign.font_size = 34
	sign.outline_size = 8
	sign.modulate = Color("b84b3c")
	sign.position = Vector3(0, 1.05, 0.18)
	state_root.add_child(sign)

func _owner_visual() -> void :
	_instance_scene(PLOT_MODEL_PATH % "owned_land_plot", state_root, Vector3.ZERO, Vector3(1.22, 1.0, 1.08))
	var owner: = GameState.player(str(data.owner_id))
	var color: = Color(str(owner.color)) if not owner.is_empty() else Color.WHITE
	_flag(color, str(owner.name))

func _construction_visual() -> void :
	_owner_visual()
	var size: = _lot_size()
	_instance_scene(PLOT_MODEL_PATH % "construction_plot", state_root, Vector3(0.0, 0.08, 0.0), Vector3(1.18, 1.0, 1.0))
	for x in [ - size.x * 0.38, size.x * 0.38]:
		for z in [ - size.y * 0.35, size.y * 0.35]:
			mesh_box(state_root, Vector3(x, 0.55, z), Vector3(0.16, 1.0, 0.16), Color("d8a239"))
	mesh_box(state_root, Vector3(0, 0.48, - size.y * 0.35), Vector3(size.x * 0.8, 0.16, 0.12), Color("f2bd45"))
	mesh_box(state_root, Vector3(0, 0.48, size.y * 0.35), Vector3(size.x * 0.8, 0.16, 0.12), Color("f2bd45"))
	mesh_box(state_root, Vector3(size.x * 0.23, 2.0, 0), Vector3(0.2, 3.5, 0.2), Color("d99032"))
	mesh_box(state_root, Vector3(0, 3.6, 0), Vector3(size.x * 0.65, 0.16, 0.16), Color("d99032"))

	var business: Dictionary = GameState.game_data.businesses.get(str(data.business_id), {})
	var label: = Label3D.new()
	label.text = "施工中  %d 回合" % int(business.get("remaining_rounds", 0))
	label.font_size = 30
	label.outline_size = 8
	label.position = Vector3(0, 2.4, 0)
	state_root.add_child(label)

func _business_visual() -> void :
	_owner_visual()
	var business: Dictionary = GameState.game_data.businesses.get(str(data.business_id), {})
	if business.is_empty():
		return

	var type_id: = str(business.type_id)
	var type_data: = GameConfig.by_id("business_types", type_id)
	var visual_name: = str(type_data.get("visual", "small_shop_01"))
	var model: = VisualAssets.instantiate_building(type_id)
	if model:
		state_root.add_child(model)
	else:

		model = _instance_scene(BUILDING_MODEL_PATH % visual_name, state_root, Vector3(0, 0.2, -0.15), _model_scale(visual_name))
		if model:
			model.rotation_degrees.y = _model_rotation(type_id)
	if model:
		_business_decorations(type_id)

	var sign: = Label3D.new()
	sign.text = str(business.name)
	sign.font_size = 26
	sign.outline_size = 7
	sign.position = Vector3(0, _label_height(visual_name), 1.85)
	state_root.add_child(sign)

	for slot in 2:
		var employee_id: = str(business.employees[slot])
		var marker_color: = Color("8aa4a0") if employee_id.is_empty() else Color("f3c55f")
		mesh_box(state_root, Vector3(-1.0 + slot * 2.0, 0.55, -1.85), Vector3(0.72, 0.72, 0.18), marker_color)
		var avatar: = Label3D.new()
		avatar.text = "+" if employee_id.is_empty() else str(GameConfig.by_id("talents", employee_id).name).left(1)
		avatar.font_size = 34
		avatar.outline_size = 5
		avatar.position = Vector3(-1.0 + slot * 2.0, 0.56, -1.74)
		avatar.rotation_degrees = Vector3(0, 180, 0)
		state_root.add_child(avatar)

	if str(data.state) == "loss_watch":
		_status_label("亏损观察", Color("d5483f"))
	elif bool(data.get("mortgaged", false)):
		_status_label("已抵押", Color("d49332"))
	elif str(data.state) == "auction":
		_status_label("暗标拍卖", Color("a54343"))

func _model_scale(visual_name: String) -> Vector3:
	match visual_name:
		"office_tower_01":
			return Vector3(2.25, 2.15, 2.25)
		"mall_01":
			return Vector3(2.05, 1.9, 2.05)
		"logistics_warehouse_01":
			return Vector3(2.25, 1.75, 2.0)
		"school_building_01", "hospital_01", "government_building_01":
			return Vector3(2.0, 1.9, 2.0)
		"residential_block_01", "residential_block_02":
			return Vector3(1.8, 1.9, 1.8)
	return Vector3(2.15, 1.95, 2.15)

func _business_decorations(type_id: String) -> void :
	match type_id:
		"convenience":
			_sign_board("24H", Color("f2c75f"), Vector3(0, 2.55, -1.55))
			_instance_scene("res://assets/models/props/bench.tscn", state_root, Vector3(1.6, 0.15, -1.75), Vector3(1.4, 1.4, 1.4))
		"restaurant":
			_sign_board("FOOD", Color("d64f42"), Vector3(0, 2.8, -1.6))
			_canopy(Color("e7b44a"), 1.8)
		"supermarket":
			_sign_board("MARKET", Color("3d8f6b"), Vector3(0, 2.6, -1.65))
			mesh_box(state_root, Vector3(1.75, 0.45, -1.65), Vector3(0.6, 0.55, 0.35), Color("d9e6ed"))
			mesh_box(state_root, Vector3(2.1, 0.2, -1.65), Vector3(0.25, 0.2, 0.25), Color("333333"))
		"entertainment":
			_sign_board("SHOW", Color("8b5cc8"), Vector3(0, 4.95, -1.8))
			_rooftop_light(Color("f5d45d"), 5.2)
		"ecommerce":
			_sign_board("LIVE", Color("ed6a4d"), Vector3(0, 7.05, -1.75))
			_rooftop_antenna(7.2)
			_instance_scene("res://assets/models/props/truck.tscn", state_root, Vector3(2.1, 0.15, 1.4), Vector3(1.25, 1.25, 1.25))
		"logistics":
			_sign_board("仓储", Color("4f86b7"), Vector3(0, 3.0, -1.75))
			_instance_scene("res://assets/models/props/truck.tscn", state_root, Vector3(-1.8, 0.15, 1.55), Vector3(1.35, 1.35, 1.35))
			_instance_scene("res://assets/models/props/fence.tscn", state_root, Vector3(1.9, 0.15, -1.2), Vector3(1.8, 1.8, 1.8))
		"research":
			_sign_board("R&D", Color("65b8d0"), Vector3(0, 7.2, -1.75))
			_rooftop_antenna(7.45)
			_rooftop_light(Color("74e0ff"), 7.55)
		"incubator":
			_sign_board("START", Color("f0b24f"), Vector3(0, 6.9, -1.75))
			mesh_box(state_root, Vector3(1.8, 1.1, 0.8), Vector3(1.15, 1.7, 1.15), Color("6ab0a1"))
			_rooftop_light(Color("ffe08a"), 7.2)
		"mall":
			_sign_board("MALL", Color("e5c45a"), Vector3(0, 4.95, -1.8))
			_canopy(Color("d95d50"), 3.1)
		"financial_office":
			_sign_board("FIN", Color("d6b14b"), Vector3(0, 7.2, -1.75))
			mesh_box(state_root, Vector3(0, 7.55, 0), Vector3(1.7, 0.18, 1.7), Color("f2d980"))
			_rooftop_antenna(7.75)
		"training":
			_sign_board("EDU", Color("5f8fc4"), Vector3(0, 4.8, -1.65))
			mesh_box(state_root, Vector3(-1.9, 0.8, -1.5), Vector3(0.7, 1.1, 0.12), Color("2c5f46"))
		"clinic":
			_sign_board("+", Color("d84d47"), Vector3(0, 4.9, -1.65))
			mesh_box(state_root, Vector3(1.8, 1.0, -1.4), Vector3(0.24, 1.1, 0.14), Color("d84d47"))
			mesh_box(state_root, Vector3(1.8, 1.0, -1.4), Vector3(0.85, 0.24, 0.14), Color("d84d47"))

func _sign_board(text: String, color: Color, pos: Vector3) -> void :
	mesh_box(state_root, pos + Vector3(0, -0.02, 0), Vector3(1.65, 0.48, 0.12), Color("24343a"))
	var label: = Label3D.new()
	label.text = text
	label.font_size = 24
	label.outline_size = 5
	label.modulate = color
	label.position = pos + Vector3(0, 0, -0.08)
	state_root.add_child(label)

func _canopy(color: Color, y: float) -> void :
	mesh_box(state_root, Vector3(0, y, -1.75), Vector3(3.2, 0.22, 0.55), color)
	for x in [-1.2, 0.0, 1.2]:
		mesh_box(state_root, Vector3(x, y - 0.15, -1.85), Vector3(0.12, 0.5, 0.12), color.darkened(0.2))

func _rooftop_antenna(y: float) -> void :
	mesh_box(state_root, Vector3(0.9, y, 0.15), Vector3(0.12, 1.2, 0.12), Color("2d3d43"))
	mesh_box(state_root, Vector3(0.9, y + 0.62, 0.15), Vector3(0.8, 0.08, 0.08), Color("2d3d43"))

func _rooftop_light(color: Color, y: float) -> void :
	var mesh: = SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.48
	var light: = MeshInstance3D.new()
	light.mesh = mesh
	light.position = Vector3(-0.9, y, -0.4)
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	light.material_override = mat
	state_root.add_child(light)

func _label_height(visual_name: String) -> float:
	if visual_name == "office_tower_01":
		return 7.2
	if visual_name in ["mall_01", "hospital_01", "school_building_01", "government_building_01"]:
		return 4.8
	return 3.8

func _model_rotation(type_id: String) -> float:
	return 180.0 if type_id in ["restaurant", "supermarket", "entertainment", "mall"] else 0.0

func _status_label(text: String, color: Color) -> void :
	var label: = Label3D.new()
	label.text = text
	label.font_size = 36
	label.outline_size = 9
	label.modulate = color
	label.position = Vector3(0, 4.8, 0)
	state_root.add_child(label)

func _flag(color: Color, owner_name: String) -> void :
	mesh_box(state_root, Vector3(-2.0, 1.35, -1.6), Vector3(0.12, 2.5, 0.12), Color("eef1e6"))
	mesh_box(state_root, Vector3(-1.35, 2.2, -1.6), Vector3(1.2, 0.75, 0.08), color)
	var label: = Label3D.new()
	label.text = owner_name.left(2)
	label.font_size = 22
	label.outline_size = 4
	label.position = Vector3(-1.35, 2.2, -1.54)
	state_root.add_child(label)

func _lot_size() -> Vector2:
	match str(data.get("shape", "standard")):
		"wide":
			return Vector2(6.0, 4.6)
		"corner":
			return Vector2(5.4, 5.2)
	return Vector2(5.0, 4.6)

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(land_id)

func _instance_scene(path: String, parent: Node, pos: Vector3, scale_value: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	var node: = packed.instantiate() as Node3D
	if node == null:
		return null
	parent.add_child(node)
	node.position = pos
	node.scale = scale_value
	return node

func mesh_box(parent: Node, pos: Vector3, size: Vector3, color: Color, wire: = false) -> MeshInstance3D:
	var instance: = MeshInstance3D.new()
	var mesh: = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if wire:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = mat
	parent.add_child(instance)
	return instance
