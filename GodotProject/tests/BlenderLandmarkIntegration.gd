extends Node

const Assets = preload("res://scripts/WestBankLandmarkAssets.gd")
const IDS = ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance", "CapitalExchange"]
var passed := 0
var failed := 0

func check(label: String, valid: bool) -> void:
	if valid:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error(label)

func _ready() -> void:
	GameFlow.suppress_background_preload_for_tests = true
	GameState.suppress_disk_save = true
	for id in IDS:
		var model := Assets.instantiate(id)
		check(id + " loads GLB", model != null)
		if model == null:
			continue
		add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		check(id + " contains real mesh", not meshes.is_empty())
		var combined := AABB()
		var first := true
		var triangle_count := 0
		var glass_count := 0
		var room_count := 0
		var textured_count := 0
		for mesh_node: MeshInstance3D in meshes:
			var box := mesh_node.global_transform * mesh_node.get_aabb()
			combined = box if first else combined.merge(box)
			first = false
			check(id + " <=16 surfaces", mesh_node.mesh.get_surface_count() <= 16)
			for i in mesh_node.mesh.get_surface_count():
				var mat := mesh_node.get_active_material(i) as StandardMaterial3D
				var arrays := mesh_node.mesh.surface_get_arrays(i)
				triangle_count += arrays[Mesh.ARRAY_INDEX].size() / 3
				if mat != null:
					if mat.resource_name.begins_with("Glazing"):
						glass_count += 1
						check(id + " real-time glazing", mat.metallic > 0.3 and not mat.emission_enabled)
					if mat.resource_name.ends_with("Interior"):
						room_count += 1
					if mat.albedo_texture != null:
						textured_count += 1
		check(id + " glazing and interior layers", glass_count >= 3 and room_count >= 2)
		check(id + " packed stone textures", textured_count >= 1)
		check(id + " correctly grounded and upright", absf(combined.position.y) < 0.02 and combined.size.y > 2.0)
		check(id + " interaction bounds enclose mesh", (combined.size - Assets.bounds(id)).length() < 0.02)
		check(id + " triangle budget", triangle_count > 20000 and triangle_count < 160000)
		print("GEOMETRY ", id, " triangles=", triangle_count, " bounds=", combined)
		model.free()
	GameState.start_match("solo", 0, [{"company_id":"hengyue", "human":true}], 15599)
	var city := (load("res://scenes/CityMap.tscn") as PackedScene).instantiate()
	add_child(city)
	for frame in range(600):
		await get_tree().process_frame
		if city.get("city_intro_complete") and city.get_node_or_null("UI/GameHUD") != null:
			break
	await get_tree().create_timer(1.0).timeout
	await get_tree().physics_frame
	for id in IDS:
		var landmark := city.find_child("CapitalExchangeLandmark" if id == "CapitalExchange" else id, true, false) as Node3D
		check(id + " present in city", landmark != null)
		if landmark == null:
			continue
		var shapes := landmark.find_children("*", "CollisionShape3D", true, false)
		var collision := shapes[0] as CollisionShape3D if not shapes.is_empty() else null
		check(id + " has click shape", collision != null)
		if collision != null:
			var shape := collision.shape as BoxShape3D
			check(id + " click shape covers height", shape != null and shape.size.y >= Assets.bounds(id).y)
		var labels := landmark.find_children("*", "Label3D", true, false)
		var land_label := labels[0] as Label3D if not labels.is_empty() else null
		check(id + " label clears crown", land_label != null and land_label.position.y > Assets.bounds(id).y)
		check(id + " readable name scale", land_label != null and land_label.font_size * land_label.pixel_size * landmark.scale.y >= 0.99 and land_label.outline_size >= 20)
		if id == "CapitalExchange":
			check("exchange enlarged horizontal footprint", is_equal_approx(landmark.scale.x, 1.55) and is_equal_approx(absf(landmark.rotation_degrees.y), 180.0))
		var probe := landmark.get_node_or_null("FacadeReflection") as ReflectionProbe
		if id != "CapitalExchange":
			check(id + " local facade reflection", probe != null and probe.update_mode == ReflectionProbe.UPDATE_ONCE)
		var target := landmark.global_position + Vector3(0, Assets.bounds(id).y * 0.5, 0)
		# Match the game's elevated view. A horizontal ray through the new skyline
		# can legitimately hit the intervening Pearl tower before Aurora.
		var query := PhysicsRayQueryParameters3D.create(target + Vector3(0, 15, 10), target)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var ray_hit := landmark.get_world_3d().direct_space_state.intersect_ray(query)
		check(id + " physical ray hits institution", ray_hit.get("collider") == landmark.get_node("CapitalExchangeHitArea" if id == "CapitalExchange" else "LandmarkHitArea"))
	if DisplayServer.get_name() != "headless":
		get_window().content_scale_size = Vector2i(1920,1080)
		get_window().size = Vector2i(1920,1080)
		city.set("camera_distance", 60.0)
		city.get("camera_rig").position = Vector3(-108.0,0,-2)
		city.call("_apply_camera")
		city.get_node("CameraRig/Camera3D").make_current()
		await get_tree().create_timer(1.0).timeout
		await capture("Blender-西岸地图-四地标实景.png")
		city.get_node("UI").hide()
		await get_tree().process_frame
		await capture("Blender-西岸地图-无界面.png")
		city.set("camera_distance", 32.0)
		city.get("camera_rig").position = Vector3(-117,0,-20)
		city.call("_apply_camera")
		await get_tree().create_timer(0.5).timeout
		await capture("Blender-曙光宏观塔-游戏近景.png")
		city.get("camera_rig").position = Vector3(-117,0,12)
		await get_tree().create_timer(0.5).timeout
		await capture("Blender-星汇与明珠-游戏近景.png")
	print("BLENDER_LANDMARK_INTEGRATION passed=%d failed=%d" % [passed,failed])
	city.queue_free()
	for frame in range(4):
		await get_tree().process_frame
	call_deferred("finish")

func finish() -> void:
	await get_tree().process_frame
	get_tree().quit(0 if failed == 0 else 1)

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../BlenderWestBank/" + filename)
	var result := get_viewport().get_texture().get_image().save_png(path)
	check("capture " + filename, result == OK)
