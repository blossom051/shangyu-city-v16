extends Node

const Assets = preload("res://scripts/WestBankLandmarkAssets.gd")


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().size = Vector2i(1920, 1080)
	var stage := Node3D.new()
	add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("8fb8c7")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dcecf2")
	settings.ambient_light_energy = 1.15
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("fff2d3")
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(36.0, 22.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("263d49")
	ground_material.metallic = 0.2
	ground_material.roughness = 0.52
	ground.material_override = ground_material
	stage.add_child(ground)
	var ids := ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance"]
	var xs := [-11.0, -3.8, 3.8, 11.0]
	for index in ids.size():
		var model := Assets.instantiate(ids[index])
		model.position = Vector3(xs[index], 0.0, 0.0)
		stage.add_child(model)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 18.0, 30.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 4.0, 0.0))
	camera.fov = 43.0
	stage.add_child(camera)
	camera.current = true
	for _frame in range(24):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../Screenshots/V15.5-UE58四地标细节对比.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result := image.save_png(output)
	print("V155_UE58_LANDMARK_GALLERY result=%d path=%s" % [result, output])
	get_tree().quit(0 if result == OK else 1)
