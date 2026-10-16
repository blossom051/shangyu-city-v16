class_name CardSystem
extends RefCounted

const CardRules = preload("res://scripts/CardEngine.gd")

static func draw_cards(player_id: String, count: int) -> Dictionary:
	return CardRules.draw_cards(player_id, count)

static func legal_targets(player_id: String, card_id: String) -> Array[Dictionary]:
	return CardRules.legal_targets(player_id, card_id)

static func play(player_id: String, card_id: String, target_id: String, response_choice: = "PROMPT") -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("card_play", {"player_id": player_id, "card_id": card_id, "target_id": target_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	return CardRules.play(player_id, card_id, target_id, response_choice)

static func discard(player_id: String, card_id: String) -> bool:
	return CardRules.discard(player_id, card_id)


static func discard_for_points(player_id: String, card_id: String) -> Dictionary:
	return CardRules.discard_for_points(player_id, card_id)

static func create_round_offer(player_id: String, count: = 5) -> Array[String]:
	return CardRules.create_round_offer(player_id, count)

static func round_offer(player_id: String) -> Array:
	return CardRules.round_offer(player_id)

static func round_offer_kind(player_id: String) -> String:
	return CardRules.round_offer_kind(player_id)

static func west_bank_round_offer(player_id: String) -> Array:
	return CardRules.west_bank_round_offer(player_id)

static func choose_round_card(player_id: String, card_id: String) -> Dictionary:
	return CardRules.choose_round_card(player_id, card_id)

static func auto_choose_round_card(player_id: String) -> Dictionary:
	return CardRules.auto_choose_round_card(player_id)

static func can_end_turn(player_id: String) -> Dictionary:
	return CardRules.can_end_turn(player_id)

static func pending_notices(player_id: String) -> Array:
	return CardRules.pending_notices(player_id)

static func acknowledge_notices(player_id: String) -> void :
	CardRules.acknowledge_notices(player_id)
