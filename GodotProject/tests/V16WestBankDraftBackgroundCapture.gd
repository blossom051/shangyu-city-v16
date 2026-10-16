extends Node

const Cards = preload("res://scripts/CardSystem.gd")
const DraftDialog = preload("res://scripts/RoundCardDraftDialog.gd")

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().size = Vector2i(1920, 1080)
	GameState.start_match("endless", 0, [{"company_id": "hengyue", "human": true}], 160927)
	var player: Dictionary = GameState.game_data.players[0]
	GameState.game_data.turn_order = [str(player.id)]
	GameState.game_data.active_order_index = 0
	GameState.game_data.round = 16
	player.cash = 12000
	player.asset_value = 6000
	player.risk = 20
	for index in range(6):
		var land_id: String = ["L09", "L10", "L11", "L12", "L29", "L30"][index]
		var business_id := "VISUAL-%d" % index
		var land: Dictionary = GameState.game_data.lands[land_id]
		land.owner_id = str(player.id)
		land.asset_state = "OWNED"
		land.state = "operating"
		land.business_id = business_id
		player.land_ids.append(land_id)
		player.business_ids.append(business_id)
		GameState.game_data.businesses[business_id] = {"id": business_id, "owner_id": str(player.id), "land_id": land_id, "type_id": "financial_office", "state": "operating", "value": 900}
	Cards.create_round_offer(str(player.id), 5)
	GameState.game_data.round_card_offers.erase(str(player.id))
	var dialog: RoundCardDraftDialog = DraftDialog.new()
	dialog.open_for_player(str(player.id))
	add_child(dialog)
	for _frame in range(12):
		await get_tree().process_frame
	await _save("selection")
	var offer: Array = Cards.round_offer(str(player.id))
	if offer.is_empty():
		printerr("V16_WEST_CARD_CAPTURE no west bank offer")
		get_tree().quit(2)
		return
	var card_id := str(offer[0])
	var button: Button = dialog.choice_buttons.get(card_id)
	dialog.call("_select_card", card_id, button)
	dialog.call("_confirm_card")
	for _frame in range(90):
		await get_tree().process_frame
	await _save("reveal")
	print("V16_WEST_CARD_CAPTURE complete card=%s" % card_id)
	get_tree().quit(0)

func _save(stage: String) -> void:
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../../.private-sale-recovery/west-card-%s.png" % stage)
	var err := get_viewport().get_texture().get_image().save_png(output)
	if err != OK:
		printerr("V16_WEST_CARD_CAPTURE save failed stage=%s error=%s" % [stage, error_string(err)])
