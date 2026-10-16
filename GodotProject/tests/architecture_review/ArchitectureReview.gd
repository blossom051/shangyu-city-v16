extends Node

const OUT := "res://../BlenderWestBank/AuroraRealism/output/"
var city: Node3D
var visual: Node3D
var camera: Camera3D
var failed := 0
var passed := 0

func check(label: String, valid: bool) -> void:
	if valid:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		push_error(label)

func _ready() -> void:
	GameState.suppress_disk_save = true
	GameFlow.suppress_background_preload_for_tests = true
	get_window().size = Vector2i(1920,1080)
	get_window().content_scale_size = Vector2i(1920,1080)
	GameState.start_match("solo",0,[{"company_id":"hengyue","human":true}],90926)
	city = (load("res://scenes/CityMap.tscn") as PackedScene).instantiate()
	add_child(city)
	for frame in range(600):
		await get_tree().process_frame
		if city.get("city_intro_complete") and city.get_node_or_null("UI/GameHUD") != null:
			break
	await get_tree().create_timer(1.0).timeout
	visual = city.get("city_map_visual")
	camera = city.get_node("CameraRig/Camera3D")
	camera.make_current()
	city.get_node("UI").hide()
	visual.set_process(false)
	view(Vector3(-89,50,39),Vector3(-89,0,0),57)
	await snap("04-Game-Before-WestBank.png")
	view(Vector3(-116,23,-3),Vector3(-116,4,-19),43)
	await snap("05-Game-Before-Aurora.png")
	view(Vector3(-68,14,13),Vector3(-76,3,0),46)
	await snap("06-Game-Before-Exchange.png")
	# Review-only replacement: no changes to the maintained loader or release EXE.
	replace_model("AuroraSpire","AuroraSpire_Atelier",Vector3(-124.5,0,5.1),"LandmarkHitArea",true)
	replace_model("CapitalExchangeLandmark","CapitalExchange_Atelier",Vector3(-76.5,0,-0.5),"CapitalExchangeHitArea",false)
	replace_model("HarborTwin","HarborTwin_Atelier",Vector3(-98,0,-19),"LandmarkHitArea",false)
	replace_model("PearlFinance","PearlFinance_Atelier",Vector3(-123,0,17.2),"LandmarkHitArea",false)
	replace_model("TerraceHQ","TerraceHQ_Atelier",Vector3(-96.5,0,5.6),"LandmarkHitArea",false)
	bright_daylight()
	view(Vector3(-89,50,39),Vector3(-89,0,0),57)
	await snap("07-Game-After-WestBank.png")
	view(Vector3(-120,16,20.1),Vector3(-124.5,4,5.1),42)
	await snap("08-Game-After-Aurora.png")
	view(Vector3(-68,14,13),Vector3(-76,3,0),46)
	await snap("09-Game-After-Exchange.png")
	view(Vector3(-54,90,72),Vector3(-54,0,0),68)
	await snap("10-Game-After-FullMap.png")
	# A top-down review checks placement against the actual baked ground artwork.
	view(Vector3(-124.5,22,5.1),Vector3(-124.5,0,5.11),38)
	await snap("11-Game-Aurora-Site.png")
	view(Vector3(-76.5,25,-.5),Vector3(-76.5,0,-.49),38)
	await snap("12-Game-Exchange-Site.png")
	for item in [["HarborTwin",Vector3(-98,0,-19)],["PearlFinance",Vector3(-123,0,17.2)],["TerraceHQ",Vector3(-96.5,0,5.6)]]:
		var anchor: Vector3=item[1]
		view(anchor+Vector3(5,15,18),anchor+Vector3(0,3,0),43)
		await snap("Game-"+str(item[0])+"-Detail.png")
		view(anchor+Vector3(0,22,0),anchor+Vector3(0,0,.01),38)
		await snap("Game-"+str(item[0])+"-Site.png")
	print("ARCHITECTURE_REVIEW passed=%d failed=%d" % [passed,failed])
	if OS.get_cmdline_user_args().has("--hold"):
		view(Vector3(-120,16,20.1),Vector3(-124.5,4,5.1),42)
		return
	get_tree().quit(0 if failed == 0 else 1)

func replace_model(node_name: String,asset_name: String,position_value: Vector3,hit_name: String,aurora: bool) -> void:
	var root := visual.find_child(node_name,true,false) as Node3D
	check(node_name+" original interaction root exists",root!=null)
	if root==null:return
	var hit := root.get_node(hit_name) as Area3D
	var label: Label3D
	for child in root.get_children():
		if child is Label3D:label=child
		elif child != hit:
			root.remove_child(child)
			child.queue_free()
	root.scale=Vector3.ONE
	root.position=position_value
	var model := (load("res://tests/architecture_review/assets/"+asset_name+".glb") as PackedScene).instantiate() as Node3D
	root.add_child(model)
	if node_name in ["HarborTwin","TerraceHQ"]:
		model.scale=Vector3.ONE*.82
	var local_bounds:=AABB()
	var first:=true
	var triangles:=0
	var material_names:={}
	var normal_maps:=0
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var box := root.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		local_bounds = box if first else local_bounds.merge(box)
		first=false
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			var material:=mesh.get_active_material(surface) as StandardMaterial3D
			if material!=null:
				material_names[material.resource_name]=true
				if material.normal_texture!=null:normal_maps+=1
	check(node_name+" physically grounded",absf(local_bounds.position.y)<.01)
	check(node_name+" smaller architectural footprint",local_bounds.size.x<4.6 and local_bounds.size.z<3.5)
	check(node_name+" game height reasonable",local_bounds.size.y>2 and local_bounds.size.y<10)
	check(node_name+" distinct glazing preserved",material_names.has("Glazing_PearlBlue") and material_names.has("Glazing_Sky") and material_names.has("Glazing_Deep"))
	check(node_name+" imported stone normal map",normal_maps>0)
	check(node_name+" material budget",material_names.size()<=16)
	var collision := hit.get_children()[0] as CollisionShape3D
	var shape:=BoxShape3D.new();shape.size=local_bounds.size+Vector3(.1,.1,.1)
	collision.shape=shape;collision.position=local_bounds.get_center()
	if label!=null:
		label.position=Vector3(0,local_bounds.size.y+.45,0)
		label.font_size=70;label.pixel_size=.006
	print("REVIEW_GEOMETRY ",node_name," bounds=",local_bounds," triangles=",triangles," materials=",material_names.size())
	# Reject any polygon overlap, including crossings with no contained vertices.
	var lands: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/land_tiles.json"))
	var footprint:=Rect2(Vector2(root.position.x+local_bounds.position.x,root.position.z+local_bounds.position.z),Vector2(local_bounds.size.x,local_bounds.size.z))
	var clear:=true
	var rectangle:=PackedVector2Array([footprint.position,footprint.position+Vector2(footprint.size.x,0),footprint.end,footprint.position+Vector2(0,footprint.size.y)])
	for land: Dictionary in lands:
		var anchor: Array=land.get("anchor",[0,0])
		var polygon:=PackedVector2Array()
		for point: Array in land.get("polygon",[]):
			polygon.append(Vector2(float(anchor[0])+float(point[0]),float(anchor[1])+float(point[1])))
		if not Geometry2D.intersect_polygons(rectangle,polygon).is_empty():clear=false
	check(node_name+" clear of purchase parcel polygons",clear)

func bright_daylight() -> void:
	var world:=visual.get("world_environment") as WorldEnvironment
	var environment:=world.environment
	environment.background_color=Color("a9cadd")
	var sky:=Sky.new()
	var panorama:=PanoramaSkyMaterial.new()
	panorama.panorama=load("res://tests/architecture_review/assets/urban_street_01_2k.hdr")
	sky.sky_material=panorama
	environment.sky=sky
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("e2edee")
	environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.05
	environment.adjustment_brightness=1.0
	environment.adjustment_contrast=1.02
	environment.adjustment_saturation=1.02
	environment.ssao_intensity=.65
	environment.ssao_radius=.75
	environment.ssil_intensity=.7
	var sun:=visual.get("sun_light") as DirectionalLight3D
	sun.rotation_degrees=Vector3(-52,-35,0)
	sun.light_energy=1.05
	sun.light_color=Color("fff7e9")
	sun.directional_shadow_max_distance=180
	(visual.get("moon_light") as DirectionalLight3D).light_energy=0

func view(position_value: Vector3,target: Vector3,fov_value: float) -> void:
	camera.global_position=position_value
	camera.look_at(target)
	camera.fov=fov_value

func snap(filename: String) -> void:
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	var result:=get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+filename))
	check(filename,result==OK)
