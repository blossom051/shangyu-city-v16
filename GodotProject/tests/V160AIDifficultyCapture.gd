extends Node

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().size = Vector2i(1920, 1080)
	var screen := (load("res://scenes/ModeSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	screen.call("_set_mode", "ai")
	screen.get_node("Content/Config/AIDifficultyChooser/Choices/hard").pressed.emit()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../Screenshots/V160-AI三档难度-游戏实景.png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("V160_AI_UI_CAPTURE result=", result, " path=", path)
	get_tree().quit(0 if result == OK else 1)
