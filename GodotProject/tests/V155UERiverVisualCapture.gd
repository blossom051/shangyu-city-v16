extends Node


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().size = Vector2i(1920, 1080)
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15581)
	GameState.game_data.endless = true
	var scene := (load("res://scenes/CityMap.tscn") as PackedScene).instantiate()
	add_child(scene)
	for _frame in range(120):
		await get_tree().process_frame
		if scene.find_child("GameHUD", true, false) != null:
			break
	if scene.has_method("_on_district_legend_pressed"):
		scene.call("_on_district_legend_pressed", "west_finance")
	for _frame in range(32):
		await get_tree().process_frame
	# Visual QA close-up: include all four dedicated landmark pads at the west edge.
	if scene.get("camera_rig") != null:
		scene.get("camera_rig").position = Vector3(-120.0, 0.0, -16.0)
		scene.set("camera_distance", 34.0)
		scene.call("_apply_camera")
	for _frame in range(16):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../Screenshots/V15.5-UE58西岸高精度地标.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result := image.save_png(output)
	print("V155_UE58_RIVER_CAPTURE result=%d size=%dx%d path=%s" % [result, image.get_width(), image.get_height(), output])
	get_tree().quit(0 if result == OK else 1)
