extends Node

const DialogScript = preload("res://scripts/SaveSlotDialog.gd")

var passed := 0
var failed := 0
var test_root := "user://codex_v155_save_ui_test"
var test_legacy := "user://codex_v155_save_ui_legacy.json"


func _ready() -> void:
	SaveSlots.configure_paths_for_tests(test_root, test_legacy)
	_cleanup()
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15588)
	GameState.game_data.round = 8
	SaveSlots.save_auto(GameState.snapshot())
	SaveSlots.save_manual(1, "西岸发展档", GameState.snapshot())
	await _test_mode("load")
	await _test_mode("save")
	_cleanup()
	SaveSlots.configure_paths_for_tests(SaveSlotService.DEFAULT_STORAGE_ROOT, SaveSlotService.DEFAULT_LEGACY_PATH)
	print("V155_SAVE_SLOT_UI passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_mode(mode: String) -> void:
	var dialog := DialogScript.new()
	dialog.open(mode)
	add_child(dialog)
	await get_tree().process_frame
	var grid := dialog.find_child("SaveSlotGrid", true, false) as GridContainer
	_assert("%s 模式显示九个槽位" % mode, grid != null and grid.get_child_count() == 9)
	_assert("%s 模式包含自动档和八个手动档" % mode, dialog.find_child("SaveCard_auto", true, false) != null and dialog.find_child("SaveCard_slot_08", true, false) != null)
	var auto_primary := dialog.find_child("SlotPrimary_auto", true, false) as Button
	_assert("%s 模式自动档权限正确" % mode, auto_primary != null and (auto_primary.disabled if mode == "save" else not auto_primary.disabled))
	_assert("%s 模式主要信息字号清晰" % mode, _minimum_label_font(dialog) >= 15)
	dialog.queue_free()
	await get_tree().process_frame


func _minimum_label_font(node: Node) -> int:
	var minimum := 999
	for value: Node in node.find_children("*", "Label", true, false):
		minimum = mini(minimum, (value as Label).get_theme_font_size("font_size"))
	return minimum


func _cleanup() -> void:
	for slot_id in ["auto", "slot_01", "slot_02", "slot_03", "slot_04", "slot_05", "slot_06", "slot_07", "slot_08"]:
		for suffix in [".json", ".json.tmp", ".json.bak"]:
			var path := "%s/%s%s" % [test_root, slot_id, suffix]
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(test_legacy):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_legacy))


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
