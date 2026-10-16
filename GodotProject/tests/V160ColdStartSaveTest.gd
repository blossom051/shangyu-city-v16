extends Node

const TEST_ROOT := "user://codex_v160_cold_start_save_test"
const TEST_LEGACY := "user://codex_v160_cold_start_legacy_test.json"

func _ready() -> void:
	GameState.suppress_disk_save = true
	SaveSlots.configure_paths_for_tests(TEST_ROOT, TEST_LEGACY)
	var args := OS.get_cmdline_user_args()
	if args.has("--v160-write"):
		GameState.start_match("ai", 0, [{"company_id": "hengyue", "human": true}, {"company_id": "qinghe", "human": false}], 160926, "hard")
		GameState.game_data.round = 7
		GameState.player("p1").cash = 1234
		var saved := SaveSlots.save_manual(8, "冷启动验收", GameState.snapshot())
		print("V160_COLD_START_WRITE result=%s" % ("PASS" if bool(saved.get("ok", false)) else "FAIL"))
		get_tree().quit(0 if bool(saved.get("ok", false)) else 1)
	elif args.has("--v160-read"):
		var loaded := GameState.load_from_slot("slot_08")
		var okay := bool(loaded.get("ok", false)) and str(GameState.game_data.get("ai_difficulty", "")) == "hard" and int(GameState.game_data.get("round", 0)) == 7 and int(GameState.player("p1").get("cash", 0)) == 1234
		print("V160_COLD_START_READ result=%s" % ("PASS" if okay else "FAIL"))
		if okay:
			SaveSlots.delete_manual(8)
		get_tree().quit(0 if okay else 1)
	else:
		GameState.start_match("ai", 0, [{"company_id": "hengyue", "human": true}, {"company_id": "qinghe", "human": false}], 160926, "hard")
		var saved := SaveSlots.save_manual(8, "冷启动验收", GameState.snapshot())
		GameState.game_data.ai_difficulty = "casual"
		var loaded := GameState.load_from_slot("slot_08")
		var okay := bool(saved.get("ok", false)) and bool(loaded.get("ok", false)) and str(GameState.game_data.get("ai_difficulty", "")) == "hard"
		print("V160_COLD_START_DEFAULT result=%s" % ("PASS" if okay else "FAIL"))
		if okay:
			SaveSlots.delete_manual(8)
		get_tree().quit(0 if okay else 1)
