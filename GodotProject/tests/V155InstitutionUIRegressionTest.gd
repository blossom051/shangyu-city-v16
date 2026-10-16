extends Node

const DialogScript = preload("res://scripts/WestBankInstitutionDialog.gd")
const Institutions = preload("res://scripts/WestBankInstitutionSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15541)
	GameState.game_data.endless = true
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 1000
	player.asset_value = 1200
	player.risk = 20
	GameState.game_data.round = 6
	for index in range(3):
		var business_id := "INSTITUTION-UI-%d" % index
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "state": "operating", "value": 400, "employees": ["", ""]}
	var layouts := {}
	var regions := {}
	for landmark_id in ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance"]:
		var profile := Institutions.profile(landmark_id)
		layouts[str(profile.get("layout", ""))] = true
		regions[str(profile.get("scene_region", []))] = true
		var dialog := DialogScript.new()
		dialog.open(landmark_id, str(player.id))
		add_child(dialog)
		await get_tree().process_frame
		_assert("%s 使用专属场景图" % str(profile.get("name", landmark_id)), _has_atlas_scene(dialog))
		_assert("%s 提供非文本式实时决策席" % str(profile.get("name", landmark_id)), _find_named(dialog, "InstitutionConsole") != null and dialog.options_host != null)
		_assert("%s 方案标题与效果文字达到游戏主要信息字号" % str(profile.get("name", landmark_id)), _minimum_option_font_size(dialog) >= 18)
		dialog.queue_free()
		await get_tree().process_frame
	_assert("四座机构拥有四种独立界面语义", layouts.size() == 4 and regions.size() == 4)
	var preview_dialog := DialogScript.new()
	preview_dialog.open("AuroraSpire", str(player.id))
	add_child(preview_dialog)
	await get_tree().process_frame
	var option: Dictionary = Institutions.profile("AuroraSpire").options[0]
	var cash_before := int(player.cash)
	preview_dialog._preview(option)
	_assert("首次点击机构方案只预览不扣款", int(player.cash) == cash_before and preview_dialog.confirm_button.visible)
	preview_dialog._confirm_selected()
	_assert("二次确认后才执行机构委托", int(player.cash) == cash_before - int(option.cost) and not preview_dialog.confirm_button.visible)
	preview_dialog.queue_free()
	print("V155_INSTITUTION_UI passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _has_atlas_scene(node: Node) -> bool:
	if node is TextureRect and (node as TextureRect).texture is AtlasTexture:
		return true
	for child in node.get_children():
		if _has_atlas_scene(child):
			return true
	return false


func _find_named(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, target_name)
		if found != null:
			return found
	return null


func _minimum_option_font_size(node: Node) -> int:
	var minimum := 999
	for candidate in node.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label.text.contains("点击查看") or label.text.contains("风险") or label.text.contains("审核") or label.text.contains("现金"):
			minimum = mini(minimum, label.get_theme_font_size("font_size"))
	return minimum


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		push_error("FAIL  %s" % label)
