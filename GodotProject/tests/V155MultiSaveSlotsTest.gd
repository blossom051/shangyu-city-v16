extends Node

const SlotServiceScript = preload("res://scripts/SaveSlotService.gd")

var passed := 0
var failed := 0
var service: SaveSlotService
var test_root := "user://codex_v155_save_slots_test"
var test_legacy := "user://codex_v155_legacy_save_test.json"


func _ready() -> void:
	GameState.suppress_disk_save = true
	service = SlotServiceScript.new()
	service.configure_paths_for_tests(test_root, test_legacy)
	SaveSlots.configure_paths_for_tests(test_root, test_legacy)
	_cleanup()
	_test_fixed_slot_catalog()
	_test_auto_and_manual_round_trip()
	_test_rename_delete_and_guards()
	_test_corruption_isolation()
	_test_legacy_migration()
	_test_game_state_slot_restore()
	_test_ai_difficulty_round_trip()
	_cleanup()
	SaveSlots.configure_paths_for_tests(SaveSlotService.DEFAULT_STORAGE_ROOT, SaveSlotService.DEFAULT_LEGACY_PATH)
	service.free()
	print("V155_MULTI_SAVE_SLOTS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start(round_number: int, cash: int) -> Dictionary:
	GameState.start_match("solo", 0, [{"company_id": "hengyue", "human": true}], 15581 + round_number)
	var player := GameState.game_data.players[0] as Dictionary
	GameState.game_data.round = round_number
	player.cash = cash
	player.asset_value = cash + 300
	return GameState.snapshot()


func _test_fixed_slot_catalog() -> void:
	var slots := service.list_slots()
	_assert("固定提供 1 个自动档和 8 个手动档", slots.size() == 9)
	_assert("首位为自动档", str((slots[0] as Dictionary).get("id", "")) == "auto" and bool((slots[0] as Dictionary).get("automatic", false)))
	for index in range(1, 9):
		_assert("手动槽位 %02d 编号稳定" % index, str((slots[index] as Dictionary).get("id", "")) == "slot_%02d" % index)


func _test_auto_and_manual_round_trip() -> void:
	var round_2 := _start(2, 820)
	var auto_result := service.save_auto(round_2)
	var manual_result := service.save_manual(1, "西岸起步", round_2)
	_assert("自动档与手动档均可创建", bool(auto_result.get("ok", false)) and bool(manual_result.get("ok", false)))
	var round_7 := _start(7, 2360)
	service.save_auto(round_7)
	var loaded_auto := service.load_slot("auto")
	var loaded_manual := service.load_slot("slot_01")
	_assert("自动档更新到最新回合", int((loaded_auto.get("game_data", {}) as Dictionary).get("round", 0)) == 7)
	_assert("自动保存不会覆盖手动档", int((loaded_manual.get("game_data", {}) as Dictionary).get("round", 0)) == 2)
	var metadata: Dictionary = loaded_manual.get("metadata", {})
	_assert("手动档保存名称与经营摘要", str(metadata.get("display_name", "")) == "西岸起步" and int(metadata.get("cash", 0)) == 820 and int(metadata.get("asset", 0)) == 1120)


func _test_rename_delete_and_guards() -> void:
	var rename_result := service.rename_manual(1, "资本跃迁")
	_assert("手动档可重命名", bool(rename_result.get("ok", false)) and str((service.load_slot("slot_01").get("metadata", {}) as Dictionary).get("display_name", "")) == "资本跃迁")
	_assert("自动档拒绝重命名", not bool(service.rename_slot("auto", "不能改").get("ok", false)))
	_assert("自动档拒绝删除", not bool(service.delete_slot("auto").get("ok", false)))
	var delete_result := service.delete_manual(1)
	_assert("手动档可以删除", bool(delete_result.get("ok", false)) and not bool(service.slot_summary("slot_01").get("exists", true)))
	_assert("越界槽位被拒绝", not bool(service.save_manual(9, "错误", GameState.snapshot()).get("ok", false)))


func _test_corruption_isolation() -> void:
	var before := GameState.snapshot()
	var corrupt_path := service.slot_path("slot_03")
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{broken-json")
	file.close()
	var result := service.load_slot("slot_03")
	_assert("损坏档返回明确失败", not bool(result.get("ok", false)) and str(result.get("message", "")).contains("损坏"))
	_assert("读取损坏档不改变当前游戏", GameState.snapshot() == before)


func _test_legacy_migration() -> void:
	service.delete_slot("auto", true)
	var legacy_snapshot := _start(11, 4110)
	var legacy_file := FileAccess.open(test_legacy, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_snapshot))
	legacy_file.close()
	var migration := service.migrate_legacy_once()
	var migrated := service.load_slot("auto")
	_assert("旧单档迁移为自动档", bool(migration.get("ok", false)) and int((migrated.get("game_data", {}) as Dictionary).get("round", 0)) == 11)
	_assert("迁移后保留旧文件", FileAccess.file_exists(test_legacy))


func _test_game_state_slot_restore() -> void:
	var round_3 := _start(3, 1330)
	service.save_manual(2, "第三回合", round_3)
	var round_9 := _start(9, 3990)
	service.save_manual(3, "第九回合", round_9)
	var load_2 := GameState.load_from_slot("slot_02")
	_assert("GameState 可读取指定手动档", bool(load_2.get("ok", false)) and int(GameState.game_data.get("round", 0)) == 3 and int((GameState.game_data.players[0] as Dictionary).get("cash", 0)) == 1330)
	var load_3 := GameState.load_from_slot("slot_03")
	_assert("不同手动档可独立恢复", bool(load_3.get("ok", false)) and int(GameState.game_data.get("round", 0)) == 9 and int((GameState.game_data.players[0] as Dictionary).get("cash", 0)) == 3990)


func _test_ai_difficulty_round_trip() -> void:
	GameState.start_match("ai", 0, [{"company_id": "hengyue", "human": true}, {"company_id": "qinghe", "human": false}], 160926, "hard")
	var saved := service.save_manual(4, "困难人机", GameState.snapshot())
	GameState.game_data.ai_difficulty = "casual"
	var loaded := GameState.load_from_slot("slot_04")
	_assert("人机困难档可写入磁盘存档", bool(saved.get("ok", false)))
	_assert("从磁盘存档恢复原难度", bool(loaded.get("ok", false)) and str(GameState.game_data.get("ai_difficulty", "")) == "hard")


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
