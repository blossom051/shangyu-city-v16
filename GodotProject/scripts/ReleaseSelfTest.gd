extends Node


func _ready() -> void:
	var errors: Array[String] = []
	if not GameConfig.validation_errors.is_empty():
		errors.append_array(GameConfig.validation_errors)
	for script_path in [
		"res://scripts/ConstructionProgressService.gd",
		"res://scripts/EndlessOperationsSystem.gd",
		"res://scripts/AIDifficultyPolicy.gd",
		"res://scripts/NewsSystem.gd",
		"res://scripts/RandomEventSystem.gd",
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
	for landmark_id in ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance", "CapitalExchange"]:
		var model := WestBankLandmarkAssets.instantiate(landmark_id)
		if model == null or model.find_children("*", "MeshInstance3D", true, false).is_empty():
			errors.append("无法加载 Blender 地标 %s" % landmark_id)
		if model != null:
			model.free()
	if FileAccess.file_exists("res://assets/Buildings/west_bank_ue58/manifest.json"):
		errors.append("旧地标资产不应留在发行包中")
	if GameConfig.list("random_events").size() < 24 or GameConfig.list("news_events").size() < 21:
		errors.append("新增事件和新闻目录未进入发行包")
	var west_cards: Array = GameConfig.list("cards").filter(func(card: Dictionary) -> bool: return str(card.get("series", "")) == "west_bank")
	if west_cards.size() != 42 or not west_cards.all(func(card: Dictionary) -> bool: return str(card.get("description", "")).length() <= 40):
		errors.append("西岸卡牌精简文案未进入发行包")
	print("RELEASE_SMOKE passed=%d failed=%d" % [21 - errors.size(), errors.size()])
	for error in errors:
		printerr("FAIL  %s" % error)
	get_tree().quit(0 if errors.is_empty() else 1)
