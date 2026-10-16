extends Node

const RandomEvents = preload("res://scripts/RandomEventSystem.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	GameState.reset()
	GameState.game_data.round = 1
	GameState.game_data.players = [{
		"id": "p1",
		"name": "启明创投",
		"company_id": "c01",
		"human": true,
		"business_ids": ["B-L11", "B-L12", "B-L16"],
		"effects": [],
	}]
	GameState.game_data.businesses = {}
	for land_id in ["L11", "L12", "L16"]:
		var business := {
			"id": "B-%s" % land_id,
			"owner_id": "p1",
			"land_id": land_id,
			"type_id": "financial_office",
			"name": "金融办公中心",
			"state": "constructing",
			"remaining_rounds": 3,
			"effects": [],
		}
		ConstructionProgressService.initialize_project(business, 1, 3)
		GameState.game_data.businesses["B-%s" % land_id] = business

	# 真实问题：每轮的延期 +1 与施工推进 -1 相互抵消，项目可永久停留在 3 回合。
	for round_index in range(10):
		GameState.game_data.round = round_index + 1
		RandomEvents.generate_round(["v10_risk_04"])
		for business: Dictionary in GameState.game_data.businesses.values():
			if str(business.get("state", "")) == "constructing":
				ConstructionProgressService.advance(business, round_index + 1)

	for land_id in ["L11", "L12", "L16"]:
		var business: Dictionary = GameState.game_data.businesses["B-%s" % land_id]
		_assert_equal("%s 最迟应当完工" % land_id, int(business.get("remaining_rounds", -1)), 0)

	print("CONSTRUCTION_DEADLINE_TESTS passed=%d failed=%d total=%d" % [passed, failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		printerr("FAIL  %s expected=%s actual=%s" % [label, str(expected), str(actual)])
