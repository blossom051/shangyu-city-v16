extends Node

const Businesses = preload("res://scripts/BusinessSystem.gd")
const Cheats = preload("res://scripts/EndlessCheatSystem.gd")
const Institutions = preload("res://scripts/WestBankInstitutionSystem.gd")
const EligibilityDialog = preload("res://scripts/WestBankEligibilityDialog.gd")

const LANDMARKS := ["AuroraSpire", "HarborTwin", "TerraceHQ", "PearlFinance"]

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.suppress_disk_save = true
	_test_unqualified_service_gate()
	await _test_locked_dialog()
	_test_qualified_access()
	_test_cheat_and_standard_mode()
	print("V155_WEST_BANK_LANDMARK_ELIGIBILITY passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _start(endless := true, seed_value := 15591) -> Dictionary:
	GameState.start_match("solo", 0 if endless else 12, [{"company_id": "hengyue", "human": true}], seed_value)
	var player := GameState.game_data.players[0] as Dictionary
	player.cash = 5000
	player.asset_value = 900
	player.risk = 20
	GameState.game_data.round = 2
	return player


func _test_unqualified_service_gate() -> void:
	var player := _start(true, 15591)
	var player_id := str(player.id)
	var access := Businesses.premium_land_eligibility(player_id)
	var progress: Dictionary = access.get("progress", {})
	_assert("未达标玩家不具备西岸资格", not bool(access.get("ok", false)))
	_assert("锁定结果携带四项实时进度", progress.keys().size() == 4 and int((progress.get("round", {}) as Dictionary).get("current", -1)) == 2 and int((progress.get("asset", {}) as Dictionary).get("target", -1)) == 1200)
	for landmark_id: String in LANDMARKS:
		var before := GameState.snapshot()
		var result := Institutions.execute(player_id, landmark_id, _first_option(landmark_id))
		_assert("%s 未解锁不可执行" % landmark_id, not bool(result.get("ok", false)) and str(result.get("message", "")).contains("西岸"))
		_assert("%s 拦截不改变状态" % landmark_id, GameState.snapshot() == before)


func _test_qualified_access() -> void:
	var player := _start(true, 15592)
	var player_id := str(player.id)
	GameState.game_data.round = 6
	player.asset_value = 1200
	player.risk = 55
	for index in range(3):
		var business_id := "LANDMARK-ACCESS-%d" % index
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {
			"id": business_id,
			"owner_id": player_id,
			"state": "operating",
			"value": 400,
			"employees": ["", ""],
		}
	_assert("满足购地条件后机构资格同步解锁", bool(Institutions.eligibility(player_id).get("ok", false)))
	for landmark_id: String in LANDMARKS:
		var result := Institutions.execute(player_id, landmark_id, _first_option(landmark_id))
		_assert("%s 达标后可执行" % landmark_id, bool(result.get("ok", false)))


func _test_locked_dialog() -> void:
	var player := _start(true, 15595)
	var player_id := str(player.id)
	var dialog := EligibilityDialog.new()
	dialog.open("HarborTwin", player_id, Institutions.eligibility(player_id))
	add_child(dialog)
	await get_tree().process_frame
	_assert("锁定面板使用单一资格控制台", dialog.find_child("EligibilityConsole", true, false) != null)
	_assert("锁定面板显示四项条件", dialog.find_child("EligibilityConditionRail", true, false) != null and dialog.find_children("EligibilityCondition_*", "VBoxContainer", true, false).size() == 4)
	_assert("锁定面板仅提供返回而无执行入口", dialog.find_child("EligibilityClose", true, false) != null and dialog.find_child("InstitutionConfirm", true, false) == null)
	dialog.queue_free()
	await get_tree().process_frame


func _test_cheat_and_standard_mode() -> void:
	var endless_player := _start(true, 15593)
	var endless_id := str(endless_player.id)
	var activated := Cheats.activate(endless_id, "money")
	_assert("money 同步解锁西岸机构", bool(activated.get("ok", false)) and bool(Institutions.eligibility(endless_id).get("ok", false)))
	var cheat_result := Institutions.execute(endless_id, "AuroraSpire", _first_option("AuroraSpire"))
	_assert("money 后机构服务可执行", bool(cheat_result.get("ok", false)))

	var standard_player := _start(false, 15594)
	var standard_id := str(standard_player.id)
	for landmark_id: String in LANDMARKS:
		var result := Institutions.execute(standard_id, landmark_id, _first_option(landmark_id))
		_assert("普通模式 %s 始终锁定" % landmark_id, not bool(result.get("ok", false)))


func _first_option(landmark_id: String) -> String:
	var options: Array = Institutions.profile(landmark_id).get("options", [])
	return "" if options.is_empty() else str((options[0] as Dictionary).get("id", ""))


func _assert(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s" % label)
