class_name BalanceSimulation
extends RefCounted

const AI = preload("res://scripts/AIPlayer.gd")
const Settlement = preload("res://scripts/TurnSettlement.gd")
const Auctions = preload("res://scripts/AuctionSystem.gd")
const Decisions = preload("res://scripts/AIDecisionEngine.gd")
const OpeningCards = preload("res://scripts/OpeningCardOffer.gd")

const COMPANY_IDS: = ["hengyue", "xingchao", "qiming", "jinding", "wangang", "qinghe", "chiyan", "yunshan"]
const QUALITY_IDS: = ["blue", "platinum", "gold", "red"]
const CARD_GROUPS: = ["attack", "defense", "operation", "finance", "district"]


static func run(round_lengths: = [8, 12, 16], seed_count: = 80) -> Dictionary:
	return run_seed_range(round_lengths, 0, seed_count)


static func run_seed_range(round_lengths: Array, seed_start: int, seed_count: int) -> Dictionary:
	var result: = _empty_result(round_lengths, seed_count)
	GameState.suppress_disk_save = true
	for rounds_value: Variant in round_lengths:
		var rounds: = int(rounds_value)
		for seed_index in range(seed_start, seed_start + seed_count):
			var seed: = 970000 + rounds * 100 + seed_index
			_run_match(rounds, seed, seed_index, result)
	GameState.suppress_disk_save = false
	_finalize_metrics(result)
	return result


static func _run_match(rounds: int, match_seed: int, seat_rotation: int, aggregate: Dictionary) -> void :
	var ordered_ids: Array = COMPANY_IDS.duplicate()
	for _step in range(seat_rotation % COMPANY_IDS.size()):
		ordered_ids.push_back(ordered_ids.pop_front())
	var selections: Array[Dictionary] = []
	for company_id: String in ordered_ids:
		selections.append({"company_id": company_id, "human": false})
	GameState.start_match("ai", rounds, selections, match_seed)
	for player: Dictionary in GameState.game_data.players:
		GameState.set_opening_hand(str(player.id), OpeningCards.build_auto_hand(str(player.company_id)))
	for _round_index in range(rounds):
		GameState.begin_round()
		for player_id: String in GameState.game_data.turn_order:
			AI.take_turn(player_id)
		var report: = Settlement.settle_round()
		var round_check: Dictionary = Settlement.report_consistency(report)
		if not bool(round_check.get("ok", false)):
			aggregate.consistency_errors += 1
			aggregate.consistency_details.append({"seed": match_seed, "round_limit": rounds, "round": int(GameState.game_data.round), "phase": "round", "errors": round_check.get("errors", []).duplicate()})
		_resolve_auctions()
	var pre_final_players: Array = GameState.game_data.players.duplicate(true)
	var final_report: = Settlement.finalize_match()
	var final_check: Dictionary = Settlement.report_consistency(final_report)
	if not bool(final_check.get("ok", false)):
		aggregate.consistency_errors += 1
		aggregate.consistency_details.append({"seed": match_seed, "round_limit": rounds, "round": int(GameState.game_data.round), "phase": "final", "errors": final_check.get("errors", []).duplicate()})
	_collect_match(rounds, pre_final_players, final_report, aggregate)


static func _resolve_auctions() -> void :
	for auction: Dictionary in GameState.game_data.auctions.duplicate():
		for _auction_round in 2:
			if not GameState.game_data.auctions.has(auction):
				break
			for player: Dictionary in GameState.game_data.players:
				var decision: = Decisions.auction_bid(str(player.id), auction)
				var bid: = int(decision.get("amount", 0)) if not bool(decision.get("abstain", true)) else 0
				Auctions.submit_bid(str(auction.asset_id), str(player.id), bid)
			var reveal: = Auctions.reveal(str(auction.asset_id))
			if not bool(reveal.get("tie", false)):
				break


static func _collect_match(rounds: int, players_before_final: Array, final_report: Dictionary, aggregate: Dictionary) -> void :
	var schedule: Dictionary = aggregate.schedules[str(rounds)]
	schedule.games += 1
	var ever_debt_ids: Dictionary = {}
	var usage_by_player: Dictionary = {}
	for entry: Dictionary in GameState.game_data.log:
		var player_id: = str(entry.get("player_id", ""))
		var kind: = str(entry.get("kind", ""))
		if not usage_by_player.has(player_id):
			usage_by_player[player_id] = {}
		if kind in ["direct_loan", "mortgage", "loan_overdue", "loan_maturity_default"]:
			ever_debt_ids[player_id] = true
			usage_by_player[player_id].loan = true
		elif kind == "play_card": usage_by_player[player_id].card = true
		elif kind == "stock_trade": usage_by_player[player_id].stock = true
		elif kind == "startup_invest": usage_by_player[player_id].startup = true
		elif kind in ["talent_draw", "talent_resolve", "assign_talent"]: usage_by_player[player_id].talent = true
	var ordered: Array = players_before_final.duplicate()
	ordered.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		var a_value: = int(final_report.players.get(str(a.id), {}).get("final_value", a.asset_value))
		var b_value: = int(final_report.players.get(str(b.id), {}).get("final_value", b.asset_value))
		return a_value > b_value
	)
	for rank_index in range(ordered.size()):
		var player: Dictionary = ordered[rank_index]
		var company_id: = str(player.company_id)
		var company: Dictionary = aggregate.companies[company_id]
		var final_value: = int(final_report.players.get(str(player.id), {}).get("final_value", player.asset_value))
		company.games += 1
		company.rank_sum += rank_index + 1
		company.value_sum += final_value
		company.min_value = mini(int(company.min_value), final_value)
		company.max_value = maxi(int(company.max_value), final_value)
		if rank_index == 0:
			company.wins += 1
			schedule.winners[company_id] = int(schedule.winners.get(company_id, 0)) + 1
		var final_player: Dictionary = final_report.players.get(str(player.id), {})
		company.cash_sum += int(final_player.get("cash_after", 0))
		company.property_sum += int(final_player.get("property_value", 0))
		company.stock_sum += int(final_player.get("stock_value", 0))
		company.project_sum += int(final_player.get("project_value", 0))
		company.enterprise_sum += int(final_player.get("enterprise_value", 0))
		company.debt_sum += int(final_player.get("debt_before", 0))
		company.risk_penalty_sum += int(final_player.get("risk_penalty", 0))
		schedule.player_samples += 1
		schedule.value_sum += final_value
		schedule.min_value = mini(int(schedule.min_value), final_value)
		schedule.max_value = maxi(int(schedule.max_value), final_value)
		schedule.risk_sum += int(player.risk)
		if ever_debt_ids.has(str(player.id)):
			schedule.debt_players += 1
		if int(final_player.get("residual_debt", 0)) > 0:
			schedule.residual_debt_players += 1
		aggregate.usage.player_samples += 1
		aggregate.usage.land_count += player.get("land_ids", []).size()
		aggregate.usage.business_count += player.get("business_ids", []).size()
		aggregate.usage.talent_count += player.get("talent_ids", []).size()
		var player_usage: Dictionary = usage_by_player.get(str(player.id), {})
		for system_name: String in ["talent", "stock", "loan", "card", "startup"]:
			if bool(player_usage.get(system_name, false)):
				aggregate.usage["%s_players" % system_name] = int(aggregate.usage["%s_players" % system_name]) + 1
		var occupied_districts: = {}
		for land_id: String in player.get("land_ids", []):
			var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
			if not land.is_empty(): occupied_districts[str(land.get("district", ""))] = true
		aggregate.usage.occupied_districts += occupied_districts.size()
		for key: String in aggregate.composition.keys():
			aggregate.composition[key] = int(aggregate.composition[key]) + int(final_player.get(key, 0))
	_collect_talents(players_before_final, aggregate)
	_collect_logs(aggregate)


static func _collect_talents(players: Array, aggregate: Dictionary) -> void :
	var contribution_by_talent: Dictionary = {}
	for player: Dictionary in players:
		for history: Dictionary in player.get("round_history", []):
			var summary: Dictionary = history.get("summary", {})
			for line: Dictionary in summary.get("lines", []):
				for employee: Dictionary in line.get("employee_contributions", []):
					var talent_id: = str(employee.get("id", ""))
					contribution_by_talent[talent_id] = int(contribution_by_talent.get(talent_id, 0)) + int(employee.get("total_value", 0))
	for talent_id: String in contribution_by_talent:
		var quality: = str(GameConfig.by_id("talents", talent_id).get("quality", "blue"))
		aggregate.talents[quality].contribution += int(contribution_by_talent[talent_id])


static func _collect_logs(aggregate: Dictionary) -> void :
	var scheduled_assets: Dictionary = {}
	var crisis_players: Dictionary = {}
	for entry: Dictionary in GameState.game_data.log:
		var kind: = str(entry.get("kind", ""))
		var data: Dictionary = entry.get("data", {})
		var player_id: = str(entry.get("player_id", ""))
		match kind:
			"scheduled_auction_started":
				aggregate.auctions.triggered += 1
				aggregate.auctions.saleable_random_auctions += 1
				scheduled_assets[str(data.get("land_id", ""))] = true
			"auction_started":
				aggregate.auctions.triggered += 1
			"auction_won":
				aggregate.auctions.sold += 1
				var land_id: = str(data.get("land_id", ""))
				if scheduled_assets.has(land_id):
					aggregate.auctions.sold_random_auctions += 1
				var book: = int(GameState.game_data.lands.get(land_id, {}).get("price", 0))
				if book > 0:
					aggregate.auctions.sale_ratio_sum += float(data.get("amount", 0)) / float(book)
					aggregate.auctions.sale_ratio_samples += 1
			"auction_no_bid":
				aggregate.auctions.no_bid += 1
			"auction_bid_locked":
				aggregate.auctions.bid_count += 1
			"play_card":
				aggregate.cards.played += 1
				var card: = GameConfig.by_id("cards", str(data.get("card_id", "")))
				var group: = _card_group(card)
				aggregate.cards.groups[group] = int(aggregate.cards.groups.get(group, 0)) + 1
			"opening_cards":
				var opening_count: int = data.get("cards", []).size()
				aggregate.cards.received += opening_count
				aggregate.cards.sources.opening = int(aggregate.cards.sources.opening) + opening_count
			"card_acquired":
				aggregate.cards.received += 1
				var source: = str(data.get("source", "unknown"))
				aggregate.cards.sources[source] = int(aggregate.cards.sources.get(source, 0)) + 1
				if bool(data.get("converted", false)):
					aggregate.cards.converted += 1
			"talent_draw":
				var result_ids: Array = data.get("results", [])
				var draw_cost: = 60 if int(data.get("count", 1)) == 1 else 270
				var per_card_cost: = float(draw_cost) / float(maxi(1, result_ids.size()))
				for talent_id: String in result_ids:
					var quality: = str(GameConfig.by_id("talents", talent_id).get("quality", "blue"))
					aggregate.talents[quality].drawn += 1
					aggregate.talents[quality].estimated_cost += per_card_cost
			"talent_resolve":
				var talent: = GameConfig.by_id("talents", str(data.get("talent_id", "")))
				var quality: = str(talent.get("quality", "blue"))
				if bool(data.get("keep", false)):
					aggregate.talents[quality].recruited += 1
				else:
					aggregate.talents[quality].converted += 1
			"red_talent_choice":
				var red_talent: = GameConfig.by_id("talents", str(data.get("talent_id", "")))
				aggregate.talents[str(red_talent.get("quality", "red"))].recruited += 1
			"stock_trade":
				if bool(data.get("buy", false)):
					aggregate.stocks.buys += 1
					aggregate.stocks.buy_cash += int(data.get("cash", 0))
				else:
					aggregate.stocks.sells += 1
					aggregate.stocks.sell_cash += int(data.get("cash", 0))
					aggregate.stocks.realized_profit += int(data.get("realized_profit", 0))
			"startup_invest":
				aggregate.startups.investments += 1
				aggregate.startups.invested_cash += int(data.get("cost", 0))
			"startup_resolved":
				if str(data.get("outcome", "")) == "success":
					aggregate.startups.successes += 1
				else:
					aggregate.startups.failures += 1
				aggregate.startups.cash_return += int(data.get("cash_return", 0))
				aggregate.startups.valuation += int(data.get("valuation", 0))
			"direct_loan", "mortgage":
				aggregate.loans.count += 1
				aggregate.loans.principal += int(data.get("amount", 0))
			"loan_installment_paid":
				aggregate.loans.interest_paid += int(data.get("interest", 0))
			"loan_overdue", "loan_maturity_default":
				aggregate.loans.defaults += 1
				crisis_players[player_id] = true
			"company_ability_triggered":
				var ability: = str(data.get("ability", "unknown"))
				aggregate.company_abilities[ability] = int(aggregate.company_abilities.get(ability, 0)) + 1
	for player: Dictionary in GameState.game_data.players:
		if bool(player.get("cash_crisis", false)):
			crisis_players[str(player.id)] = true
	aggregate.cash_crises.players += crisis_players.size()


static func _card_group(card: Dictionary) -> String:
	var type: = str(card.get("type", "operation"))
	if type == "attack":
		return "attack"
	if type in ["defense", "counter"]:
		return "defense"
	if type == "finance":
		return "finance"
	if type == "district":
		return "district"
	return "operation"


static func _finalize_metrics(result: Dictionary) -> void :
	var total_games: = int(result.total_games)
	for company_id: String in result.companies:
		var company: Dictionary = result.companies[company_id]
		company.win_rate = float(company.wins) / float(maxi(1, total_games))
		company.average_rank = float(company.rank_sum) / float(maxi(1, company.games))
		company.average_value = float(company.value_sum) / float(maxi(1, company.games))
	for schedule_key: String in result.schedules:
		var schedule: Dictionary = result.schedules[schedule_key]
		schedule.average_value = float(schedule.value_sum) / float(maxi(1, schedule.player_samples))
		schedule.debt_rate = float(schedule.debt_players) / float(maxi(1, schedule.player_samples))
		schedule.residual_debt_rate = float(schedule.residual_debt_players) / float(maxi(1, schedule.player_samples))
		schedule.average_risk = float(schedule.risk_sum) / float(maxi(1, schedule.player_samples))
	for quality: String in result.talents:
		var talent: Dictionary = result.talents[quality]
		talent.average_contribution = float(talent.contribution) / float(maxi(1, talent.recruited))
		talent.unit_cost_return = float(talent.contribution) / maxf(1.0, float(talent.estimated_cost))
	var composition_total: = 0
	for value: Variant in result.composition.values():
		composition_total += maxi(0, int(value))
	result.composition["shares"] = {}
	for key: String in ["cash_after", "property_value", "stock_value", "project_value", "enterprise_value"]:
		result.composition.shares[key] = float(result.composition[key]) / float(maxi(1, composition_total))
	result.auctions.sale_rate = float(result.auctions.sold_random_auctions) / float(maxi(1, result.auctions.saleable_random_auctions))
	result.auctions.average_sale_discount = float(result.auctions.sale_ratio_sum) / float(maxi(1, result.auctions.sale_ratio_samples))
	result.auctions.average_bids = float(result.auctions.bid_count) / float(maxi(1, result.auctions.triggered))
	result.cards.use_rate = float(result.cards.played) / float(maxi(1, result.cards.received))
	result.startups.success_rate = float(result.startups.successes) / float(maxi(1, int(result.startups.successes) + int(result.startups.failures)))
	result.startups.return_rate = float(result.startups.cash_return + result.startups.valuation - result.startups.invested_cash) / float(maxi(1, result.startups.invested_cash))
	var scheduled_player_rounds: = 0
	for rounds_value: Variant in result.round_lengths:
		scheduled_player_rounds += int(rounds_value) * int(result.seeds_per_length) * int(result.players_per_game)
	result.startups.participation_per_12_rounds = float(result.startups.investments) * 12.0 / float(maxi(1, scheduled_player_rounds))
	var usage_samples: = float(maxi(1, int(result.usage.player_samples)))
	result.usage.average_lands = float(result.usage.land_count) / usage_samples
	result.usage.average_businesses = float(result.usage.business_count) / usage_samples
	result.usage.average_talents = float(result.usage.talent_count) / usage_samples
	result.usage.average_occupied_districts = float(result.usage.occupied_districts) / usage_samples
	for system_name: String in ["talent", "stock", "loan", "card", "startup"]:
		result.usage["%s_participation_rate" % system_name] = float(result.usage["%s_players" % system_name]) / usage_samples
	result.thresholds = _thresholds(result)


static func _thresholds(result: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []
	for company_id: String in result.companies:
		var rate: = float(result.companies[company_id].win_rate)
		var games: = int(result.companies[company_id].games)
		var lower_guard: = 0.03 if games >= 240 else 0.02
		var upper_guard: = 0.3 if games >= 240 else 0.32
		if rate > upper_guard or rate < lower_guard:
			issues.append("%s win_rate %.3f" % [company_id, rate])
		elif rate > 0.2 or rate < 0.05:
			warnings.append("%s investigate_win_rate %.3f; outside the 5%%-20%% design observation band" % [company_id, rate])
	var debt_8: = float(result.schedules.get("8", {}).get("debt_rate", 0.0))
	if debt_8 < 0.35 or debt_8 > 0.8:
		issues.append("8_round_ever_debt %.3f" % debt_8)
	if int(result.auctions.saleable_random_auctions) >= 20 and (float(result.auctions.sale_rate) < 0.55 or float(result.auctions.sale_rate) > 0.9):
		issues.append("random_auction_sale_rate %.3f" % float(result.auctions.sale_rate))
	var startup_participation: = float(result.startups.get("participation_per_12_rounds", 0.0))
	if startup_participation < 0.15 or startup_participation > 0.8:
		issues.append("startup_participation_per_12_rounds %.3f" % startup_participation)
	if float(result.cards.use_rate) < 0.0 or float(result.cards.use_rate) > 1.0:
		issues.append("card_use_rate %.3f" % float(result.cards.use_rate))
	for quality: String in QUALITY_IDS:
		if int(result.talents[quality].drawn) <= 0 or int(result.talents[quality].recruited) <= 0:
			issues.append("talent_%s_missing_real_use" % quality)
	if int(result.consistency_errors) > 0:
		issues.append("consistency_errors %d" % int(result.consistency_errors))
	return {"passed": issues.is_empty() and int(result.consistency_errors) == 0, "issues": issues, "warnings": warnings}


static func _empty_result(round_lengths: Array, seed_count: int) -> Dictionary:
	var companies: = {}
	for company_id: String in COMPANY_IDS:
		companies[company_id] = {
			"games": 0, "wins": 0, "rank_sum": 0, "value_sum": 0, 
			"cash_sum": 0, "property_sum": 0, "stock_sum": 0, "project_sum": 0, 
			"enterprise_sum": 0, "debt_sum": 0, "risk_penalty_sum": 0, 
			"min_value": 2147483647, "max_value": -2147483648, 
		}
	var schedules: = {}
	for rounds_value: Variant in round_lengths:
		schedules[str(int(rounds_value))] = {
			"games": 0, "player_samples": 0, "winners": {}, "value_sum": 0, 
			"min_value": 2147483647, "max_value": -2147483648, 
			"debt_players": 0, "residual_debt_players": 0, "risk_sum": 0, 
		}
	var talents: = {}
	for quality: String in QUALITY_IDS:
		talents[quality] = {"drawn": 0, "recruited": 0, "converted": 0, "contribution": 0, "estimated_cost": 0.0}
	var card_groups: = {}
	for group: String in CARD_GROUPS:
		card_groups[group] = 0
	return {
		"version": GameState.CURRENT_SAVE_VERSION, 
		"round_lengths": round_lengths.duplicate(), 
		"seeds_per_length": seed_count, 
		"total_games": round_lengths.size() * seed_count, 
		"players_per_game": 8, 
		"companies": companies, 
		"schedules": schedules, 
		"composition": {"cash_after": 0, "property_value": 0, "stock_value": 0, "project_value": 0, "enterprise_value": 0}, 
		"talents": talents, 
		"auctions": {"triggered": 0, "sold": 0, "no_bid": 0, "bid_count": 0, "saleable_random_auctions": 0, "sold_random_auctions": 0, "sale_ratio_sum": 0.0, "sale_ratio_samples": 0}, 
		"cards": {"received": 0, "played": 0, "converted": 0, "sources": {"opening": 0}, "groups": card_groups}, 
		"company_abilities": {}, 
		"stocks": {"buys": 0, "sells": 0, "buy_cash": 0, "sell_cash": 0, "realized_profit": 0}, 
		"startups": {"investments": 0, "successes": 0, "failures": 0, "invested_cash": 0, "cash_return": 0, "valuation": 0}, 
		"loans": {"count": 0, "principal": 0, "interest_paid": 0, "defaults": 0}, 
		"cash_crises": {"players": 0}, 
		"usage": {"player_samples": 0, "land_count": 0, "business_count": 0, "talent_count": 0, "occupied_districts": 0, "talent_players": 0, "stock_players": 0, "loan_players": 0, "card_players": 0, "startup_players": 0}, 
		"consistency_errors": 0, 
		"consistency_details": [], 
	}


static func to_markdown(result: Dictionary) -> String:
	var lines: Array[String] = [
		"# 商域之城：资本版图 V9.18 平衡模拟报告", 
		"", 
		"- 赛程：%s 回合" % " / ".join(result.round_lengths.map( func(value: Variant) -> String: return str(value))), 
		"- 每种赛程种子数：%d" % int(result.seeds_per_length), 
		"- 总局数：%d；每局 AI 财团：%d" % [int(result.total_games), int(result.players_per_game)], 
		"- 阈值结论：%s" % ("通过" if bool(result.thresholds.passed) else "未通过"), 
		"", 
		"## 财团结果", 
		"", 
		"| 财团 | 胜率 | 平均名次 | 平均净值 | 最低 / 最高 |", 
		"|---|---:|---:|---:|---:|", 
	]
	for company_id: String in COMPANY_IDS:
		var item: Dictionary = result.companies[company_id]
		var name: = str(GameConfig.by_id("investment_companies", company_id).get("name", company_id))
		lines.append("| %s | %.1f%% | %.2f | %.0f | %d / %d |" % [name, float(item.win_rate) * 100.0, float(item.average_rank), float(item.average_value), int(item.min_value), int(item.max_value)])
	lines.append_array(["", "## 赛程风险", "", "| 回合 | 平均净值 | 负债率 | 残余负债率 | 平均风险 |", "|---:|---:|---:|---:|---:|"])
	for rounds_value: Variant in result.round_lengths:
		var rounds_key: = str(rounds_value)
		var schedule: Dictionary = result.schedules[rounds_key]
		lines.append("| %s | %.0f | %.1f%% | %.1f%% | %.1f |" % [rounds_key, float(schedule.average_value), float(schedule.debt_rate) * 100.0, float(schedule.residual_debt_rate) * 100.0, float(schedule.average_risk)])
	lines.append_array(["", "## 系统使用", ""])
	lines.append("- 随机土地拍卖：可售 %d 次，成交 %d 次，成交率 %.1f%%，平均成交价 / 账面价 %.1f%%。" % [int(result.auctions.saleable_random_auctions), int(result.auctions.sold_random_auctions), float(result.auctions.sale_rate) * 100.0, float(result.auctions.average_sale_discount) * 100.0])
	lines.append("- 卡牌：获得 %d 张，使用 %d 次，使用率 %.1f%%；类别 %s。" % [int(result.cards.received), int(result.cards.played), float(result.cards.use_rate) * 100.0, str(result.cards.groups)])
	lines.append("- 人才品质：%s。" % str(result.talents))
	lines.append("- 证券：%s；创投：%s；贷款：%s；公司能力触发：%s。" % [str(result.stocks), str(result.startups), str(result.loans), str(result.company_abilities)])
	lines.append("- 终局价值构成：%s。" % str(result.composition.shares))
	lines.append("")
	lines.append("## 异常")
	lines.append("")
	if result.thresholds.issues.is_empty():
		lines.append("未发现超过书面规格阈值的异常。")
	else:
		for issue: String in result.thresholds.issues:
			lines.append("- %s" % issue)
	if not result.thresholds.get("warnings", []).is_empty():
		lines.append("")
		lines.append("## 统计观察")
		lines.append("")
		lines.append("目标带为 5%–25%；3%–30% 作为有限样本统计护栏。落在两者之间时保留警示，不伪装成精准平衡结论。")
		for warning: String in result.thresholds.warnings:
			lines.append("- %s" % warning)
	return "\n".join(lines) + "\n"
