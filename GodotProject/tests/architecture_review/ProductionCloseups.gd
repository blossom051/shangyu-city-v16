extends Node

func _ready() -> void:
	GameState.suppress_disk_save=true
	GameFlow.suppress_background_preload_for_tests=true
	GameState.start_match("solo",0,[{"company_id":"hengyue","human":true}],90926)
	var city=(load("res://scenes/CityMap.tscn") as PackedScene).instantiate()
	add_child(city)
	for frame in range(600):
		await get_tree().process_frame
		if city.get("city_intro_complete") and city.get_node_or_null("UI/GameHUD")!=null:break
	city.get_node("UI").hide()
	var camera=city.get_node("CameraRig/Camera3D") as Camera3D
	camera.make_current()
	for id in ["AuroraSpire","HarborTwin","PearlFinance","TerraceHQ","CapitalExchangeLandmark"]:
		var building=city.find_child(id,true,false) as Node3D
		var asset_id="CapitalExchange" if id=="CapitalExchangeLandmark" else id
		var height=WestBankLandmarkAssets.bounds(asset_id).y
		var target=building.global_position+Vector3(0,height*.45,0)
		camera.global_position=target+Vector3(maxf(10,height*1.95),maxf(3,height*.38),4)
		camera.look_at(target)
		camera.fov=43
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		var path=ProjectSettings.globalize_path("res://../BlenderWestBank/AuroraRealism/output/Current-"+id+".png")
		print("CLOSEUP ",id," result=",get_viewport().get_texture().get_image().save_png(path))
	get_tree().quit()
