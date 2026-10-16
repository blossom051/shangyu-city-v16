class_name CardEffectContract
extends RefCounted

const IMMEDIATE_EFFECTS: Array[String] = [
	"channel_takeover", "poach_talent", "bargain_buy", "market_rally", "market_rumor", 
	"hedged_exit", "construction_accelerate", "construction_delay", "rent_collection", 
	"account_freeze", "news_clarification", "portfolio_dividend", "talent_capacity", 
	"debt_restructure", "executive_search", "startup_accelerate", "startup_portfolio_boost", 
	"land_acquisition", "land_grant", "pr_repair", "strategy_draw", "red_strategy_draft", 
	"gilded_gold_vault", "gilded_royal_privilege", "gilded_chosen_talent", 
	"gilded_total_blockade", "gilded_business_storm", "gilded_golden_wave", 
]
const NEXT_ACTION_EFFECTS: Array[String] = [
	"talent_discount", "auction_bid_bonus", "startup_success_bonus", "land_discount", 
	"bank_interest_relief", "build_discount", "auction_payment_credit", "auction_takeover", 
]
const REACTIVE_EFFECTS: Array[String] = [
	"legal_shield", "stable_operation", "anti_poaching", "counter_trap", 
	"opinion_backlash", "legal_counter", 
]


static func contract_for(card: Dictionary) -> Dictionary:
	var effect: = str(card.get("effect", ""))
	var timing: = "round_settlement"
	if effect in IMMEDIATE_EFFECTS:
		timing = "immediate"
	elif effect in NEXT_ACTION_EFFECTS:
		timing = "next_action"
	elif effect in REACTIVE_EFFECTS:
		timing = "on_trigger"
	return {
		"card_id": str(card.get("id", "")), 
		"effect": effect, 
		"target": str(card.get("target", "")), 
		"timing": timing, 
		"duration": int(card.get("duration", 0)), 
		"animation": animation_for(card), 
		"receipt_required": true, 
	}


static func animation_for(card: Dictionary) -> String:
	var category: = str(card.get("category", card.get("group", "")))
	var effect: = str(card.get("effect", ""))
	if effect in REACTIVE_EFFECTS:
		return "shield_counter"
	return {
		"stock": "stock_ticker_pulse", 
		"finance": "stock_ticker_pulse", 
		"bank": "bank_stamp_transfer", 
		"auction": "auction_hammer_bid", 
		"land": "parcel_title_deed", 
		"talent": "talent_spotlight", 
		"startup": "innovation_timeline", 
		"construction": "construction_crane_progress", 
		"district": "district_route_pulse", 
		"news": "newspaper_headline", 
		"public_opinion": "newspaper_headline", 
		"operation": "enterprise_cashflow", 
	}.get(category, "card_settlement")


static func audit(cards: Array) -> Array[String]:
	var issues: Array[String] = []
	var banned_terms: Array[String] = ["控制力", "确定性上涨冲击", "有效出价", "削弱客流", "同步增强"]
	for card: Dictionary in cards:
		var card_id: = str(card.get("id", ""))
		var contract: = contract_for(card)
		if str(contract.effect).is_empty() or str(contract.target).is_empty():
			issues.append("%s 缺少效果或目标" % card_id)
		if str(contract.animation).is_empty() or str(contract.timing).is_empty():
			issues.append("%s 缺少结算动画或生效时点" % card_id)
		var description: = str(card.get("description", ""))
		for term: String in banned_terms:
			if description.contains(term):
				issues.append("%s 仍含模糊词：%s" % [card_id, term])
	return issues
