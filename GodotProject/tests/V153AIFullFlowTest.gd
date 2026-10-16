extends Node

const AI = preload("res://scripts/AIPlayer.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")
const OpeningCards = preload("res://scripts/OpeningCardOffer.gd")


func _ready() -> void:
	GameState.suppress_disk_save = true
	var selections: Array[Dictionary] = []
	for company_id in ["hengyue", "xingchao", "qiming", "jinding"]:
		selections.append({"company_id": company_id, "human": false})
	GameState.start_match("ai", 0, selections, 15350)
	for player: Dictionary in GameState.game_data.players:
		GameState.set_opening_hand(str(player.id), OpeningCards.build_auto_hand(str(player.company_id)))
	var consistency_failures := 0
	for _round_number in range(50):
		GameState.begin_round()
		for player_id: String in GameState.game_data.turn_order:
			var player := GameState.player(player_id)
			if not bool(player.get("eliminated", false)):
				AI.take_turn(player_id)
		var report := Settlement.settle_round()
		var consistency := Settlement.report_consistency(report)
		if not bool(consistency.get("ok", false)):
			consistency_failures += 1
			if consistency_failures <= 3:
				printerr("CONSISTENCY round=%d errors=%s" % [int(GameState.game_data.round), str(consistency.get("errors", []))])
	GameState.suppress_disk_save = false
	var max_price_ratio := 0.0
	for stock: Dictionary in GameState.game_data.stocks.values():
		max_price_ratio = maxf(max_price_ratio, float(stock.price) / maxf(1.0, float(stock.get("fundamental_price", stock.price))))
	var passed := int(GameState.game_data.round) == 50 and EndlessOperationsSystem.is_enabled() and not EndlessOperationsSystem.is_final_round() and consistency_failures == 0 and max_price_ratio <= 4.05
	print("V153_AI_FULL_FLOW rounds=%d players=%d consistency_failures=%d max_stock_ratio=%.2f final_phase=%s result=%s" % [int(GameState.game_data.round), GameState.game_data.players.size(), consistency_failures, max_price_ratio, str(GameState.game_data.phase), "PASS" if passed else "FAIL"])
	get_tree().quit(0 if passed else 1)
