extends Node

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15804)
	GameState.begin_round()
	var scene := (load("res://scenes/CityMap.tscn") as PackedScene).instantiate()
	add_child(scene)
	for _frame in range(300):
		await get_tree().process_frame
		if scene.find_child("EndlessQuickBar", true, false) != null and scene.find_child("DistrictLegend", true, false) != null:
			break
	var quick_bar := scene.find_child("EndlessQuickBar", true, false) as Control
	var district_legend := scene.find_child("DistrictLegend", true, false) as Control
	_assert("我的土地与经济周期快捷按钮已恢复", quick_bar != null and quick_bar.visible and quick_bar.find_child("MyLands", true, false) != null and quick_bar.find_child("Cycle", true, false) != null)
	var separated := quick_bar != null and district_legend != null and not Rect2(quick_bar.global_position, quick_bar.size).intersects(Rect2(district_legend.global_position, district_legend.size))
	if quick_bar != null and district_legend != null:
		print("HUD_RECTS quick=", Rect2(quick_bar.global_position, quick_bar.size), " legend=", Rect2(district_legend.global_position, district_legend.size))
	_assert("快捷按钮与街区导航不重叠", separated)
	var game_date := scene.find_child("GameDate", true, false) as Label
	_assert("静态扩张称号替换为回合对应游戏日期", game_date != null and game_date.text.contains("游戏时间") and game_date.text.contains("2026.01.01") and not game_date.text.contains("扩张领先"))
	var rule := EndlessOperationsSystem.economic_cycle_rule_profile()
	_assert("经济周期为固定四阶段轮动且持续时长随机", not bool(rule.get("phase_order_random", true)) and bool(rule.get("duration_random", false)) and rule.get("duration_rounds", Vector2i.ZERO) == Vector2i(4, 7))
	var cycle_button := quick_bar.find_child("Cycle", true, false) as Button if quick_bar != null else null
	if cycle_button != null:
		cycle_button.emit_signal("pressed")
	await get_tree().process_frame
	var dialog := scene.find_child("EconomicCycleDialog", true, false)
	_assert("点击经济周期可打开规则明确的弹窗", dialog != null and _all_label_text(dialog).contains("固定轮动") and _all_label_text(dialog).contains("4–7"))
	print("V158_HUD_CYCLE passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _all_label_text(node: Node) -> String:
	var values: Array[String] = []
	for candidate in node.find_children("*", "Label", true, false):
		values.append((candidate as Label).text)
	return "\n".join(values)


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL %s" % label)
