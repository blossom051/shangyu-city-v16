class_name CardBalanceEvaluator
extends RefCounted


const BANDS: = {
	"blue": Vector2(40.0, 59.0), 
	"gold": Vector2(70.0, 89.0), 
	"platinum": Vector2(105.0, 129.0), 
	"red": Vector2(160.0, 199.0), 
	"gilded": Vector2(210.0, 245.0), 
	"west_bank": Vector2(120.0, 140.0),
}


static func audit_card(card: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var rarity: = str(card.get("rarity", ""))
	var declared_power: = float(card.get("power", -1.0))
	var power: = estimated_power(card)
	if not BANDS.has(rarity):
		issues.append("unknown rarity")
	else:
		var band: Vector2 = BANDS[rarity]
		if power < band.x or power > band.y:
			issues.append("computed power %.1f is outside %s band %.0f-%.0f" % [power, rarity, band.x, band.y])
	if absf(declared_power - power) > 20.0:
		issues.append("declared power %.1f differs from computed power %.1f" % [declared_power, power])
	if str(card.get("effect", "")).is_empty() or str(card.get("description", "")).is_empty():
		issues.append("missing effect or description")
	if int(card.get("duration", 0)) < 0:
		issues.append("negative duration")
	if rarity == "red" and power < 160.0:
		issues.append("red card is not a trump effect")
	return {"ok": issues.is_empty(), "issues": issues, "power": power, "declared_power": declared_power, "rarity": rarity}


static func rarity_bands(cards: Array) -> Dictionary:
	var result: = {}
	for rarity: String in BANDS:
		var powers: Array[float] = []
		for card: Dictionary in cards:
			if str(card.get("rarity", "")) == rarity:
				powers.append(float(card.get("power", -1.0)))
		powers.sort()
		result[rarity] = {
			"minimum": powers[0] if not powers.is_empty() else - INF, 
			"maximum": powers[-1] if not powers.is_empty() else INF, 
			"count": powers.size(), 
		}
	return result


static func estimated_power(card: Dictionary) -> float:
	if str(card.get("series", "")) == "west_bank":
		return float(card.get("power", 130.0))
	var value: = float(card.get("value", 0.0))
	var secondary: = float(card.get("secondary_value", 0.0))
	var duration: = maxi(1, int(card.get("duration", 0)))
	match str(card.get("effect", "")):
		"price_war": return (1.0 - value) * 200.0 + 24.0
		"public_opinion_strike": return value * 3.0 + (1.0 - secondary) * 220.0 + 28.0
		"supply_disruption": return (value - 1.0) * 100.0 + 9.0
		"channel_takeover": return value * 0.72 + 28.0
		"poach_talent": return 155.0 + secondary * 2.0
		"legal_shield": return 42.0 + float(card.get("guards", []).size()) * 8.0
		"pr_repair": return value * 4.0 + 20.0
		"stable_operation": return 46.0
		"anti_poaching": return 84.0 + duration * 10.0
		"counter_trap": return 100.0 + value * 2.5 + 40.0
		"opinion_backlash": return 50.0 + value * 3.0
		"legal_counter": return 25.0 + value * 0.7
		"viral_marketing": return (value - 1.0) * 100.0 * duration + 62.0
		"membership_growth": return (value - 1.0) * 100.0 * duration + 50.0
		"service_upgrade": return (value - 1.0) * 260.0 + secondary * 5.0 + 9.0
		"cost_optimization": return (1.0 - value) * 100.0 * duration + 38.0
		"bargain_buy": return value * 0.55 + (1.0 - float(card.get("discount", 1.0))) * 400.0 + 20.0
		"market_rally", "market_rumor": return absf(value) * 800.0 + 50.0
		"hedged_exit": return value * 200.0 + secondary * 4.0 + float(card.get("cap", 0)) * 0.5 + 1.0
		"construction_accelerate": return value * 50.0 + (secondary - 1.0) * 150.0 + 22.0
		"construction_delay": return value * 48.0 + (1.0 - secondary) * 100.0 + 10.0
		"rent_collection": return value + 15.0
		"account_freeze": return value * 0.8 + secondary * 3.0 + 36.0
		"district_ad_screen": return absf(value) * 3.0 + 22.0
		"district_joint_operation": return (value - 1.0) * 200.0 * duration + secondary * 1.5 + float(card.get("cap", 0)) * 0.25
		"block_entrance": return (1.0 - value) * 100.0 + secondary * 0.3 + 35.0
		"district_festival": return value * 2.0 * duration + 40.0
		"news_clarification": return value * 4.0 + 12.0
		"talent_discount": return (1.0 - value) * 80.0 + 8.0
		"auction_bid_bonus": return value * 0.6 + 34.0
		"startup_success_bonus": return value * 400.0 + 22.0
		"land_discount": return (1.0 - value) * 300.0 + 20.0
		"portfolio_dividend": return value * 400.0 + float(card.get("cap", 0)) * 0.6
		"bank_interest_relief": return (1.0 - value) * 100.0 + 28.0
		"talent_capacity": return value * 22.0 + 36.0
		"startup_accelerate": return value * 46.0 + 40.0
		"build_discount": return (1.0 - value) * 180.0 + 40.0
		"debt_restructure": return value * 0.6 + secondary * 1.5 + 70.0
		"auction_payment_credit": return value * 0.82 + 34.0
		"executive_search": return 112.0
		"startup_portfolio_boost": return value * 280.0 + float(card.get("round_delta", 0)) * 24.0 + float(card.get("valuation_bonus", 0)) * 0.35 + 58.0
		"land_acquisition": return (1.0 - value) * 280.0 + 56.0
		"auction_takeover": return value + secondary * 0.5 + 62.0
		"land_grant": return 196.0
		"strategy_draw": return value * 34.0 - 14.0
		"red_strategy_draft": return 188.0
		"gilded_gold_vault": return 216.0
		"gilded_royal_privilege": return 220.0
		"gilded_chosen_talent": return 232.0
		"gilded_total_blockade": return 238.0
		"gilded_business_storm": return 228.0
		"gilded_golden_wave": return 224.0
	return -1.0
