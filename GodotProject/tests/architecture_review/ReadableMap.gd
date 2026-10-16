extends Node

func _ready() -> void:
	GameState.suppress_disk_save = true
	GameFlow.suppress_background_preload_for_tests = true
	GameState.start_match("solo", 0, [{"company_id":"hengyue", "human":true}], 90926)
	var city = (load("res://scenes/CityMap.tscn") as PackedScene).instantiate()
	add_child(city)
	for frame in range(600):
		await get_tree().process_frame
		if city.get("city_intro_complete") and city.get_node_or_null("UI/GameHUD") != null: break
	city.get_node("UI").hide()
	var environment_owner = city.find_children("*", "Node3D", true, false)
	for node in environment_owner:
		if node.has_method("city_time_snapshot"):
			node.set("city_time", 0.5)
			node.call("_apply_time_of_day", 0.5)
			print("CAPTURE_TIME ", node.call("city_time_snapshot"))
	var camera = city.get_node("CameraRig/Camera3D") as Camera3D
	camera.make_current()
	var views = [
		["Readable-WestBank", Vector3(-106,0,0), Vector3(0,58,38)],
		["Natural-Exchange-River", Vector3(-65,0,0), Vector3(0,32,24)],
		["Exchange-Lot", Vector3(-76.5,0,-0.5), Vector3(0,23,14)]
	]
	for view in views:
		camera.global_position = view[1] + view[2]
		camera.look_at(view[1])
		camera.fov = 43
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		var path = ProjectSettings.globalize_path("res://../BlenderWestBank/AuroraRealism/output/" + view[0] + ".png")
		print("MAP_CAPTURE ", view[0], " result=", get_viewport().get_texture().get_image().save_png(path))
	get_tree().quit()
