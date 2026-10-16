class_name OpeningCardOffer
extends RefCounted


const PREMIUM_POSITIVE_IDS: Array[String] = ["o01", "f02", "r02", "r04"]
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const MatchRandom = preload("res://scripts/RandomSource.gd")


static func premium_positive_ids() -> Array[String]:
	return PREMIUM_POSITIVE_IDS.duplicate()


static func build_offer(company_id: String) -> Dictionary:
	var all_ids: Array[String] = []
	for card: Dictionary in GameConfig.list("cards"):
		if str(card.get("series", "")) == "west_bank":
			continue
		all_ids.append(str(card.id))
	MatchRandom.shuffle_in_place(all_ids)
	var premium_id: = ""
	var configured_ids: Array = CompanyRules.array_ability(company_id, "opening_red_ids")
	if not configured_ids.is_empty():
		var premium_pool: = PREMIUM_POSITIVE_IDS.filter( func(card_id: String) -> bool: return configured_ids.has(card_id))
		MatchRandom.shuffle_in_place(premium_pool)
		premium_id = premium_pool[0]
		all_ids.erase(premium_id)
	var pool: Array[String] = []
	if not premium_id.is_empty():
		pool.append(premium_id)
	for card_id: String in all_ids:
		if pool.size() >= 8:
			break
		pool.append(card_id)
	return {
		"pool": pool, 
		"premium_id": premium_id, 
		"locked_ids": [premium_id] if not premium_id.is_empty() else [], 
		"preselected_ids": [premium_id] if not premium_id.is_empty() else [], 
	}


static func build_auto_hand(company_id: String) -> Array[String]:
	var offer: = build_offer(company_id)
	var hand: Array[String] = []
	for card_id: String in offer.get("preselected_ids", []):
		hand.append(card_id)
	for card_id: String in offer.get("pool", []):
		if hand.size() >= 3:
			break
		if not hand.has(card_id):
			hand.append(card_id)
	return hand
