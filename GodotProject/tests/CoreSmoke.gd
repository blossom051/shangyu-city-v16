extends Node


func _ready() -> void:
	var errors: Array[String] = []
	if not GameConfig.validation_errors.is_empty():
		errors.append_array(GameConfig.validation_errors)
	for script_path in [
		"res://scripts/ConstructionProgressService.gd",
		"res://scripts/EndlessOperationsSystem.gd",
		"res://scripts/BusinessSystem.gd",
		"res://scripts/StockSystem.gd",
		"res://scripts/TurnSettlement.gd",
	]:
		if load(script_path) == null:
			errors.append("无法加载 %s" % script_path)
	for scene_path in [
		"res://scenes/MainMenu.tscn",
		"res://scenes/ModeSelect.tscn",
		"res://scenes/CityMap.tscn",
		"res://scenes/StockMarket.tscn",
		"res://scenes/TurnSummary.tscn",
	]:
		if load(scene_path) == null:
			errors.append("无法加载 %s" % scene_path)
	print("CORE_SMOKE passed=%d failed=%d" % [10 - errors.size(), errors.size()])
	for error in errors:
		printerr("FAIL  %s" % error)
	get_tree().quit(0 if errors.is_empty() else 1)
