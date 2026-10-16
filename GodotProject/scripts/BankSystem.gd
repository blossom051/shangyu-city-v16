class_name BankSystem
extends RefCounted

const Auctions = preload("res://scripts/AuctionSystem.gd")
const RandomEvents = preload("res://scripts/RandomEventSystem.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const Economy = preload("res://scripts/EconomyMath.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const RepaymentPolicy = preload("res://scripts/LoanRepaymentPolicy.gd")
const CollateralSettlement = preload("res://scripts/CollateralSettlementService.gd")
const AssetStates = preload("res://scripts/AssetStateService.gd")
const CompetitionFeed = preload("res://scripts/CompetitiveEventFeed.gd")
const DIRECT_PRODUCTS: = [100, 200, 300]
const DIRECT_TERM_ROUNDS: = 6
const DIRECT_BASE_RATE: = 0.05
const MORTGAGE_BASE_RATE: = 0.04
const JUDICIAL_TRIGGER_MISSES: = 3
const JUDICIAL_RESIDUAL_DEADLINE: = 3


static func direct_loan_products() -> Array:
	return DIRECT_PRODUCTS.duplicate()


static func _remaining_repayment_rounds() -> int:
	return EndlessOperationsSystem.PLANNING_HORIZON if EndlessOperationsSystem.is_enabled() else maxi(0, int(GameState.game_data.get("round_limit", 0)) - int(GameState.game_data.get("round", 0)))


static func delinquency_ladder() -> Array[Dictionary]:
	return [
		{"stage": 1, "title": "首次逾期", "fee_rate": 0.03, "risk_add": 6, "income_multiplier": 0.9, "risk_floor": 24, "credit_frozen": true, "forced_disposal": false}, 
		{"stage": 2, "title": "连续两次逾期", "fee_rate": 0.05, "risk_add": 10, "income_multiplier": 0.75, "risk_floor": 42, "credit_frozen": true, "forced_disposal": false}, 
		{"stage": 3, "title": "司法催收", "fee_rate": 0.08, "risk_add": 15, "income_multiplier": 0.6, "risk_floor": 64, "credit_frozen": true, "forced_disposal": true}, 
	]


static func delinquency_consequence(overdue_count: int) -> Dictionary:
	var stage: = maxi(1, overdue_count)
	var result: Dictionary = delinquency_ladder()[mini(3, stage) - 1].duplicate(true)
	result.overdue_count = stage
	if stage > 3:
		result.fee_rate = minf(0.14, 0.08 + float(stage - 3) * 0.015)
		result.title = "持续司法催收（第%d次）" % stage
	return result


static func direct_loan_quote(player_id: String, amount: int) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty() or amount not in DIRECT_PRODUCTS:
		return {"allowed": false, "message": "无效快贷产品"}
	var limit: = refinance_limit(player_id)
	var available: = maxi(0, limit - int(player.debt))
	var rate: = _direct_rate(player)
	var action_available: = int(player.get("actions", {}).get("loan", 0)) < 1
	var remaining_repayment_rounds: = _remaining_repayment_rounds()
	var actual_term: = mini(DIRECT_TERM_ROUNDS, maxi(1, remaining_repayment_rounds))
	var quote: = RepaymentPolicy.origination_quote(amount, rate, actual_term, int(GameState.game_data.get("round", 0)))
	quote.merge({
		"allowed": amount <= available and action_available and remaining_repayment_rounds > 0, 
		"amount": amount, 
		"round_interest": int(quote.first_interest), 
		"round_payment": int(quote.first_payment), 
		"credit_ceiling": _credit_ceiling(player), 
		"available_credit": available, 
		"compressed_term": actual_term < DIRECT_TERM_ROUNDS, 
		"remaining_repayment_rounds": remaining_repayment_rounds, 
		"message": "最后一回合不开放新增信用融资" if remaining_repayment_rounds <= 0 else "可申请  赛程不足，已压缩为 %d 期" % actual_term if actual_term < DIRECT_TERM_ROUNDS and amount <= available and action_available else "可申请" if amount <= available and action_available else "本轮已使用过信用融资，下回合可再次申请" if not action_available else "可用额度不足", 
	}, true)
	return quote


static func direct_loan(player_id: String, amount: int) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("direct_loan", {"player_id": player_id, "amount": amount})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	if amount not in DIRECT_PRODUCTS:
		return _fail("无效额度")
	var player: = GameState.player(player_id)
	if player.is_empty():
		return _fail("玩家不存在")
	if int(player.get("actions", {}).get("loan", 0)) >= 1:
		return _fail("本轮已使用过信用融资；结清旧贷款后可在下一次可用融资行动中再次申请")
	var remaining_repayment_rounds: = _remaining_repayment_rounds()
	if remaining_repayment_rounds <= 0:
		return _fail("最后一回合不开放新增信用融资：已经没有完整还款回合")
	var limit: = refinance_limit(player_id)
	if int(player.debt) + amount > limit:
		return _fail("可用快贷额度不足：当前最多还能借 %d 万" % maxi(0, limit - int(player.debt)))
	var rate: = _direct_rate(player)
	var actual_term: = mini(DIRECT_TERM_ROUNDS, remaining_repayment_rounds)
	var origination: = RepaymentPolicy.origination_quote(amount, rate, actual_term, int(GameState.game_data.round))
	origination.compressed_term = actual_term < DIRECT_TERM_ROUNDS
	player.loans.append({
		"id": _next_loan_id(player, "D"), 
		"kind": "direct", 
		"principal": amount, 
		"rate": rate, 
		"original_principal": amount, 
		"term_rounds": actual_term, 
		"remaining_rounds": actual_term, 
		"overdue": 0, 
		"unpaid_interest": 0, 
		"unpaid_principal": 0, 
		"overdue_fee": 0, 
		"paid_interest": 0, 
		"maturity_due": false, 
		"origin_round": int(GameState.game_data.round), 
		"first_due_round": int(GameState.game_data.round) + 1, 
		"asset_id": ""
	})
	player.debt = int(player.debt) + amount
	player.actions.loan = int(player.get("actions", {}).get("loan", 0)) + 1
	GameState.apply_cash(player_id, amount, "直接借款")
	GameState._record(player_id, "direct_loan", origination.merged({"amount": amount}))
	_append_ledger(player_id, "获得银行融资", origination.merged({"amount": amount}))
	return _ok("到账 %d 万；预计总利息 %d 万，总还款 %d 万；第 %d 回合首期 %d 万" % [amount, int(origination.total_interest), int(origination.total_repayment), int(origination.first_due_round), int(origination.first_payment)], origination.merged({"amount": amount, "available_credit": maxi(0, limit - int(player.debt))}))


static func mortgage_quote(player_id: String, asset_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var collateral: = _collateral(asset_id)
	var remaining_repayment_rounds: = _remaining_repayment_rounds()
	if player.is_empty() or collateral.is_empty():
		return {"allowed": false, "message": "资产不可抵押"}
	var action_available: = int(player.get("actions", {}).get("loan", 0)) < 1
	var owned_and_clear: = str(collateral.owner_id) == player_id and not _is_collateral_locked(collateral) and not _has_collateral_loan(player, str(collateral.land_id))
	var amount: = roundi(float(collateral.value) * 0.8)
	var term: = mini(8, maxi(1, remaining_repayment_rounds))
	var quote: = RepaymentPolicy.origination_quote(amount, MORTGAGE_BASE_RATE, term, int(GameState.game_data.get("round", 0)))
	quote.merge({
		"allowed": action_available and owned_and_clear and remaining_repayment_rounds > 0, 
		"asset_id": asset_id, 
		"amount": amount, 
		"compressed_term": term < 8, 
		"remaining_repayment_rounds": remaining_repayment_rounds, 
		"message": "最后一回合不开放新增抵押融资" if remaining_repayment_rounds <= 0 else "本轮已办理过一次融资" if not action_available else "资产已被占用或已有抵押" if not owned_and_clear else "可申请  赛程不足，已压缩为 %d 期" % term if term < 8 else "可申请", 
	}, true)
	return quote


static func mortgage(player_id: String, asset_id: String) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("mortgage", {"player_id": player_id, "asset_id": asset_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var collateral: = _collateral(asset_id)
	var origination: = mortgage_quote(player_id, asset_id)
	if not bool(origination.get("allowed", false)):
		return _fail(str(origination.get("message", "资产不可抵押")))
	var amount: = int(origination.amount)
	var loan_id: = _next_loan_id(player, "M")
	var mortgage_term: = int(origination.term_rounds)
	player.loans.append({
		"id": loan_id, 
		"kind": "mortgage", 
		"principal": amount, 
		"rate": MORTGAGE_BASE_RATE, 
		"original_principal": amount, 
		"term_rounds": mortgage_term, 
		"remaining_rounds": mortgage_term, 
		"overdue": 0, 
		"unpaid_interest": 0, 
		"unpaid_principal": 0, 
		"overdue_fee": 0, 
		"paid_interest": 0, 
		"maturity_due": false, 
		"origin_round": int(GameState.game_data.round), 
		"first_due_round": int(GameState.game_data.round) + 1, 
		"asset_id": str(collateral.land_id), 
		"business_id": str(collateral.business_id)
	})
	player.debt = int(player.debt) + amount
	player.actions.loan = int(player.get("actions", {}).get("loan", 0)) + 1
	_mark_mortgaged(str(collateral.land_id), true)
	GameState.apply_cash(player_id, amount, "抵押贷款")
	GameState._record(player_id, "mortgage", origination.merged({
		"asset_id": str(collateral.land_id), 
		"business_id": str(collateral.business_id), 
		"amount": amount
	}))
	return _ok("抵押放款 %d 万；%d 期总利息 %d 万，总还款 %d 万；第 %d 回合首期 %d 万" % [amount, mortgage_term, int(origination.total_interest), int(origination.total_repayment), int(origination.first_due_round), int(origination.first_payment)], origination)


static func repay(player_id: String, loan_id: String) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("loan_repay", {"player_id": player_id, "loan_id": loan_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	var loan: = _find_loan(player, loan_id)
	if loan.is_empty():
		return _fail("贷款不存在")
	var quote: = payoff_quote(player_id, loan_id)
	var total_due: = int(quote.get("total_due", 0))
	if int(player.get("cash", 0)) < total_due:
		return _fail("现金不足：全部结清需要 %d 万" % total_due)
	var paid: = _apply_payment(player, loan, quote, total_due, false, true)
	GameState._record(player_id, "loan_repaid", {
		"loan_id": loan_id, "amount": int(paid.total), "principal": int(paid.principal), 
		"interest": int(paid.interest), "overdue_fee": int(paid.overdue_fee), 
		"partial": false, "early_payoff_penalty": int(quote.get("early_payoff_penalty", 0)), 
	})
	_append_ledger(player_id, "贷款提前全部结清", paid.merged({"loan_id": loan_id, "early_payoff_penalty": int(quote.get("early_payoff_penalty", 0))}))
	return _ok("提前结清完成：本金 %d 万 + 提前结清费用 %d 万 + 逾期费用 %d 万；贷款风险立即解除" % [int(paid.principal), int(paid.interest), int(paid.overdue_fee)], quote)


static func pay_current_installment(player_id: String, loan_id: String) -> Dictionary:
	var tutorial_route: Dictionary = TutorialDirector.route_action("loan_repay", {"player_id": player_id, "loan_id": loan_id})
	if bool(tutorial_route.get("handled", false)):
		return tutorial_route
	var player: = GameState.player(player_id)
	if player.is_empty():
		return _fail("玩家不存在")
	var loan: = _find_loan(player, loan_id)
	if loan.is_empty():
		return _fail("贷款不存在")
	if not is_loan_due(loan):
		return _fail("本轮免还，下回合起计算")
	if int(loan.get("installment_paid_round", -1)) == int(GameState.game_data.round):
		return _fail("本轮分期已缴清")
	var quote: = installment_quote(player_id, loan_id)
	if int(player.cash) < int(quote.total_due):
		return _fail("现金不足，结算时将形成逾期并冻结授信")
	var paid: = _apply_payment(player, loan, quote, int(quote.total_due), false, false)
	return _ok("本轮应还已缴清：本金 %d 万 + 利息 %d 万 + 逾期费用 %d 万" % [int(paid.principal), int(paid.interest), int(paid.overdue_fee)], quote)


static func settle_interest(player_id: String, allow_automatic_payment: = false) -> int:
	var player: = GameState.player(player_id)
	var total: = 0
	var crisis_triggered: = false
	var processed_any: = false
	var payment_events: Array[Dictionary] = []
	for loan: Dictionary in player.get("loans", []).duplicate():
		if str(loan.get("kind", "")) == "judicial_residual":
			_process_judicial_residual(player, loan, allow_automatic_payment)
			continue
		if not is_loan_due(loan):
			continue
		if int(loan.get("installment_paid_round", -1)) == int(GameState.game_data.round) or int(loan.get("settlement_processed_round", -1)) == int(GameState.game_data.round):
			continue
		var quote: = installment_quote(player_id, str(loan.id))
		processed_any = true
		var required_payment: = int(quote.get("total_due", 0))



		var paid_amount: = mini(int(player.get("cash", 0)), required_payment) if allow_automatic_payment else 0
		var paid: = _apply_payment(player, loan, quote, paid_amount, allow_automatic_payment, false)
		payment_events.append(paid.duplicate(true))
		total += int(paid.get("interest", 0))
		if paid_amount >= required_payment:
			continue
		crisis_triggered = true
		if not player.get("loans", []).has(loan):
			continue
		var overdue_count: = maxi(1, int(loan.get("overdue", 1)))
		var overdue_stage: = mini(3, overdue_count)
		var consequence: Dictionary = delinquency_consequence(overdue_count)
		var debt_penalty_multiplier: = CompanyRules.numeric_ability(str(player.get("company_id", "")), "debt_penalty_multiplier", 1.0)
		var arrears: = int(loan.get("unpaid_interest", 0)) + int(loan.get("unpaid_principal", 0))
		var fee_added: = maxi(1, ceili(float(maxi(1, arrears)) * float(consequence.get("fee_rate", 0.08)) * debt_penalty_multiplier))
		loan.overdue_fee = int(loan.get("overdue_fee", 0)) + fee_added
		loan.capitalized_overdue_fee = int(loan.get("capitalized_overdue_fee", 0)) + fee_added
		player.debt = int(player.get("debt", 0)) + fee_added
		var risk_added: = maxi(1, roundi(float(consequence.get("risk_add", 10)) * debt_penalty_multiplier))
		Risks.adjust(player_id, risk_added, str(consequence.get("title", "贷款逾期")), "银行逾期")
		player.cash_crisis = true
		player.credit_frozen_rounds = maxi(3 if overdue_stage >= 3 else 2, int(player.get("credit_frozen_rounds", 0)))
		player.missed_payments = int(player.get("missed_payments", 0)) + 1
		GameState._record(player_id, "loan_maturity_default" if bool(quote.get("maturity_due", false)) else "loan_overdue", {
			"loan_id": str(loan.id), "overdue": int(loan.get("overdue", 0)), 
			"unpaid_interest": int(loan.get("unpaid_interest", 0)), "unpaid_principal": int(loan.get("unpaid_principal", 0)), 
			"overdue_fee": int(loan.get("overdue_fee", 0)), "fee_added": fee_added, 
			"risk_added": risk_added, "income_multiplier": float(consequence.get("income_multiplier", 0.8)), "debt_penalty_multiplier": debt_penalty_multiplier, 
			"risk_floor": int(consequence.get("risk_floor", 30)), "capitalized_fee": fee_added, 
			"total_due": required_payment, "paid": paid_amount, 
		})
		if int(loan.get("overdue", 0)) >= JUDICIAL_TRIGGER_MISSES and str(loan.kind) == "mortgage":
			if _consume_foreclosure_guard(player):
				loan.overdue = JUDICIAL_TRIGGER_MISSES - 1
				GameState._record(player_id, "foreclosure_blocked", {"loan_id": str(loan.id)})
			else:
				_prepare_judicial_foreclosure(player, loan, str(loan.get("asset_id", "")))
				if not bool(player.get("human", false)):
					confirm_judicial_foreclosure(player_id, str(loan.get("id", "")))
		elif str(loan.kind) == "direct":
			_handle_direct_default(player, loan)
	if not crisis_triggered and player.get("loans", []).all( func(active: Dictionary) -> bool: return int(active.get("overdue", 0)) == 0):
		player.cash_crisis = false
		player.missed_payments = 0
		player.credit_frozen_rounds = maxi(0, int(player.get("credit_frozen_rounds", 0)) - 1)
	if processed_any:
		player.last_interest_paid = total
		player.last_loan_settlement = {
			"round": int(GameState.game_data.get("round", 0)), 
			"events": payment_events, 
			"lifecycle": loan_lifecycle(player_id), 
		}
		_append_ledger(player_id, "本回合贷款利息结算", {"paid": total, "cash_crisis": bool(player.cash_crisis), "summary": loan_summary(player_id)})
	return total


static func installment_quote(player_id: String, loan_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var loan: = _find_loan(player, loan_id)
	return {} if loan.is_empty() else _quote_for_loan(player_id, loan, false, false)


static func payoff_quote(player_id: String, loan_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var loan: = _find_loan(player, loan_id)
	return {} if loan.is_empty() else _quote_for_loan(player_id, loan, true, false)


static func payment_quote(loan: Dictionary) -> Dictionary:
	var owner_id: = _loan_owner_id(loan)
	return _quote_for_loan(owner_id, loan, false, true)


static func _quote_for_loan(player_id: String, loan: Dictionary, payoff: bool, force_due: bool) -> Dictionary:
	if str(loan.get("kind", "")) == "judicial_residual":
		var interest: = maxi(0, int(loan.get("unpaid_interest", 0)))
		var fee: = maxi(0, int(loan.get("overdue_fee", 0)))
		return {
			"loan_id": str(loan.get("id", "")), "interest": interest, 
			"required_principal": 0, "overdue_fee": fee, 
			"total_due": interest + fee, "maturity_due": true, 
			"judicial_residual": true, 
		}
	return RepaymentPolicy.quote(loan, _effective_rate(player_id, loan), int(GameState.game_data.get("round", 0)), payoff, force_due)


static func _scheduled_interest(starting_principal: int, periods: int, installment_principal: int, rate: float) -> int:
	return RepaymentPolicy.scheduled_interest(starting_principal, periods, installment_principal, rate)


static func is_loan_due(loan: Dictionary, round_number: int = -1) -> bool:
	if str(loan.get("kind", "")) == "judicial_residual":
		return true
	var current: = int(GameState.game_data.get("round", 0)) if round_number < 0 else round_number
	return RepaymentPolicy.is_due(loan, current)


static func loan_summary(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {}
	var next_interest: = 0
	var weighted_rate: = 0.0
	var principal_total: = 0
	var remaining_rounds: = 0
	var overdue_count: = 0
	var required_principal: = 0
	var total_due: = 0
	var overdue_fee_total: = 0
	var future_due_count: = 0
	for loan: Dictionary in player.get("loans", []):
		var principal: = int(loan.principal)
		var remaining: = maxi(0, int(loan.get("remaining_rounds", loan.get("term_rounds", 0))))
		principal_total += principal
		weighted_rate += float(principal) * float(loan.rate)
		remaining_rounds = maxi(remaining_rounds, remaining)
		if not is_loan_due(loan):
			future_due_count += 1
			continue
		var quote: = installment_quote(player_id, str(loan.id))
		next_interest += int(quote.get("interest", 0))
		if int(loan.get("overdue", 0)) > 0:
			overdue_count += 1
		required_principal += int(quote.required_principal)
		overdue_fee_total += int(quote.get("overdue_fee", 0))
		total_due += int(quote.total_due)
	return {
		"debt": int(player.debt), 
		"effective_rate": 0.0 if principal_total <= 0 else weighted_rate / float(principal_total), 
		"next_interest": next_interest, 
		"required_principal": required_principal, 
		"overdue_fee": overdue_fee_total, 
		"total_due": total_due, 
		"remaining_rounds": remaining_rounds, 
		"early_repay_amount": principal_total, 
		"overdue_count": overdue_count, 
		"cash_crisis": bool(player.get("cash_crisis", false)), 
		"refinance_limit": refinance_limit(player_id), 
		"credit_ceiling": _credit_ceiling(player), 
		"available_credit": maxi(0, refinance_limit(player_id) - int(player.debt)), 
		"credit_frozen_rounds": int(player.get("credit_frozen_rounds", 0)), 
		"missed_payments": int(player.get("missed_payments", 0)), 
		"operating_income_multiplier": operating_income_multiplier(player_id), 
		"future_due_count": future_due_count, 
	}


static func round_payment_notice(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {}
	var principal_due: = 0
	var interest_due: = 0
	var overdue_fee_due: = 0
	var max_overdue: = 0
	var lines: Array[String] = []
	for loan: Dictionary in player.get("loans", []):
		if not is_loan_due(loan):
			continue
		if int(loan.get("installment_paid_round", -1)) == int(GameState.game_data.round):
			continue
		var quote: = installment_quote(player_id, str(loan.id))
		principal_due += int(quote.required_principal)
		interest_due += int(quote.interest)
		overdue_fee_due += int(quote.get("overdue_fee", 0))
		max_overdue = maxi(max_overdue, int(loan.get("overdue", 0)))
		var kind_name: = "司法剩余息费" if str(loan.get("kind", "")) == "judicial_residual" else "组合资产抵押" if str(loan.get("kind", "")) == "mortgage" else "信用快贷"
		var consequence: = "三回合未清将破产" if kind_name == "司法剩余息费" else "第3次逾期发出司法拍卖告知" if kind_name == "组合资产抵押" else "第2次催收，第3次进入司法资产处置"
		lines.append("%s %s｜本金 %d 万 + 利息 %d 万 + 逾期费用 %d 万 = %d 万｜剩余本金 %d 万｜已逾期 %d 次｜%s" % [kind_name, str(loan.get("id", "")), int(quote.required_principal), int(quote.interest), int(quote.get("overdue_fee", 0)), int(quote.total_due), int(loan.get("principal", 0)), int(loan.get("overdue", 0)), consequence])
	var total_due: = principal_due + interest_due + overdue_fee_due
	var shortfall: = maxi(0, total_due - int(player.cash))
	var consequence_text: = "本期不会自动扣款。请先到银行点击“缴纳本期”；直接继续结算将记为逾期。"
	if shortfall > 0:
		consequence_text += " 当前现金还差 %d 万，可先筹资或结清部分资产。" % shortfall
	consequence_text += " 首次逾期加收3%、风险+6；第2次加收5%、风险+10；第3次加收8%、风险+15并进入司法执行。抵押本金核销后，剩余息费仍须在3回合内结清。"
	return {
		"player_id": player_id, 
		"cash": int(player.cash), 
		"principal_due": principal_due, 
		"interest_due": interest_due, 
		"overdue_fee_due": overdue_fee_due, 
		"total_due": total_due, 
		"shortfall": shortfall, 
		"max_overdue": max_overdue, 
		"consequence": consequence_text, 
		"loan_lines": "\n".join(lines), 
	}


static func final_debt_notice(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {}
	var unpaid_interest: = 0
	var overdue_fee: = 0
	var total_debt: = 0
	for loan: Dictionary in player.get("loans", []):
		var quote: = payoff_quote(player_id, str(loan.id))
		unpaid_interest += int(quote.get("interest", 0))
		overdue_fee += int(quote.get("overdue_fee", 0))
		total_debt += int(quote.get("total_due", 0))

	var property_book: = 0
	for land_id: String in player.get("land_ids", []):
		var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
		if land.is_empty() or str(land.get("owner_id", "")) != player_id:
			continue
		property_book += int(land.get("price", 0))
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(str(land.get("business_id", "")), {})
		if not business.is_empty() and str(business.get("owner_id", "")) == player_id:
			property_book += int(business.get("value", 0))
	var stock_book: = _stock_book_value(player)
	var project_book: = _project_book_value(player)
	var property_recovery: = roundi(float(property_book) * 0.55)
	var stock_recovery: = roundi(float(stock_book) * 0.7)
	var project_recovery: = roundi(float(project_book) * 0.45)
	var cash_shortfall: = maxi(0, total_debt - int(player.get("cash", 0)))
	var projected_residual: = maxi(0, cash_shortfall - property_recovery - stock_recovery - project_recovery)
	return {
		"player_id": player_id, 
		"cash": int(player.get("cash", 0)), 
		"principal_debt": int(player.get("debt", 0)), 
		"unpaid_interest": unpaid_interest, 
		"overdue_fee": overdue_fee, 
		"total_debt": total_debt, 
		"cash_shortfall": cash_shortfall, 
		"requires_liquidation": total_debt > int(player.get("cash", 0)), 
		"property_book": property_book, 
		"property_recovery": property_recovery, 
		"stock_book": stock_book, 
		"stock_recovery": stock_recovery, 
		"project_book": project_book, 
		"project_recovery": project_recovery, 
		"projected_residual": projected_residual, 
	}


static func finalize_player_debt(player_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return {}
	var notice: = final_debt_notice(player_id)
	var debt_before: = int(notice.get("total_debt", 0))
	var cash_before: = int(player.get("cash", 0))
	var cash_applied: = mini(cash_before, debt_before)
	if cash_applied > 0:
		GameState.apply_cash(player_id, - cash_applied, "终局偿还贷款")
	var remaining: = debt_before - cash_applied
	var property_book: = 0
	var property_recovery: = 0
	var stock_book: = 0
	var stock_recovery: = 0
	var project_book: = 0
	var project_recovery: = 0
	var liquidation_surplus: = 0
	var asset_liquidation: = remaining > 0
	var disposed_lands: Array[String] = []
	var disposed_businesses: Array[String] = []
	if remaining > 0:
		for land_id: String in player.get("land_ids", []).duplicate():
			var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
			if land.is_empty() or str(land.get("owner_id", "")) != player_id:
				continue
			property_book += int(land.get("price", 0))
			disposed_lands.append(land_id)
			var business: Dictionary = GameState.game_data.get("businesses", {}).get(str(land.get("business_id", "")), {})
			if not business.is_empty() and str(business.get("owner_id", "")) == player_id:
				property_book += int(business.get("value", 0))
				disposed_businesses.append(str(business.id))
				business.owner_id = ""
				business.state = "acquired"
				business.mortgaged = false
			land.owner_id = ""
			land.state = "government_locked"
			land.mortgaged = false
		property_recovery = roundi(float(property_book) * 0.55)
		stock_book = _stock_book_value(player)
		stock_recovery = roundi(float(stock_book) * 0.7)
		project_book = _project_book_value(player)
		project_recovery = roundi(float(project_book) * 0.45)
		var liquidation_total: = property_recovery + stock_recovery + project_recovery
		var liquidation_applied: = mini(remaining, liquidation_total)
		remaining -= liquidation_applied
		liquidation_surplus = maxi(0, liquidation_total - liquidation_applied)
		if liquidation_surplus > 0:
			GameState.apply_cash(player_id, liquidation_surplus, "终局低价处置剩余款")
		player.land_ids.clear()
		player.business_ids.clear()
		player.stocks.clear()
		player.active_projects.clear()
		player.enterprise_valuation = 0
	player.debt = remaining
	player.loans.clear()
	if remaining > 0:
		player.loans.append({
			"id": "FINAL", 
			"kind": "final_shortfall", 
			"principal": remaining, 
			"rate": 0.0, 
			"remaining_rounds": 0, 
			"overdue": 1, 
			"asset_id": "", 
		})
	var result: = {
		"player_id": player_id, 
		"debt_before": debt_before, 
		"cash_before": cash_before, 
		"cash_applied": cash_applied, 
		"property_book": property_book, 
		"property_recovery": property_recovery, 
		"stock_book": stock_book, 
		"stock_recovery": stock_recovery, 
		"project_book": project_book, 
		"project_recovery": project_recovery, 
		"liquidation_surplus": liquidation_surplus, 
		"residual_debt": remaining, 
		"disposed_lands": disposed_lands, 
		"disposed_businesses": disposed_businesses, 
		"forced_settlement": debt_before > 0, 
		"asset_liquidation": asset_liquidation, 
		"settlement_status": "no_debt" if debt_before <= 0 else "residual_debt" if remaining > 0 else "assets_cleared" if asset_liquidation else "cash_cleared", 
	}
	GameState._record(player_id, "final_debt_liquidation", result.duplicate(true))
	return result


static func loan_lifecycle(player_id: String) -> Array[Dictionary]:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return []
	var result: Array[Dictionary] = []
	for loan: Dictionary in player.get("loans", []):
		var overdue: = int(loan.get("overdue", 0))
		var status: = "正常还款"
		if overdue > 0:
			status = "逾期 %d 次" % overdue
		if bool(loan.get("foreclosure_started", false)) or bool(loan.get("forced_collection_started", false)):
			status += "  资产处置中"
		elif bool(loan.get("collection_started", false)):
			status += "  催收中"
		result.append({
			"loan_id": str(loan.get("id", "")), 
			"kind": str(loan.get("kind", "")), 
			"status": status, 
			"overdue": overdue, 
			"principal": int(loan.get("principal", 0)), 
			"unpaid_interest": int(loan.get("unpaid_interest", 0)), 
			"overdue_fee": int(loan.get("overdue_fee", 0)), 
			"asset_id": str(loan.get("collection_asset_id", loan.get("asset_id", ""))), 
		})
	return result


static func _find_loan(player: Dictionary, loan_id: String) -> Dictionary:
	if player.is_empty():
		return {}
	for loan: Dictionary in player.get("loans", []):
		if str(loan.get("id", "")) == loan_id:
			return loan
	return {}


static func _effective_rate(player_id: String, loan: Dictionary) -> float:
	var talent_discount: = Talents.assigned_interest_discount(player_id) if not player_id.is_empty() else 0.0
	var event_modifier: = RandomEvents.loan_rate_modifier(player_id) if not player_id.is_empty() else 0.0
	var multiplier: = 1.0
	var player: = GameState.player(player_id)
	for effect: Dictionary in player.get("effects", []):
		if str(effect.get("kind", "")) == "bank_interest_multiplier":
			multiplier *= float(effect.get("value", 1.0))
	return maxf(0.0, float(loan.get("rate", 0.0)) + event_modifier - talent_discount) * multiplier


static func _apply_payment(player: Dictionary, loan: Dictionary, quote: Dictionary, amount: int, automatic: bool, payoff: bool) -> Dictionary:
	var player_id: = str(player.get("id", ""))
	var loan_id: = str(loan.get("id", ""))
	var original_principal: = maxi(1, int(loan.get("original_principal", loan.get("principal", 1))))
	var paid_total: = clampi(amount, 0, int(quote.get("total_due", 0)))
	var overdue_before: = int(loan.get("overdue", 0))
	if paid_total > 0:
		GameState.apply_cash(player_id, - paid_total, "贷款全部结清" if payoff else "自动贷款结算" if automatic else "主动缴纳贷款本息")
	var interest_due: = int(quote.get("interest", 0))
	var required_principal: = int(quote.get("required_principal", 0))
	var fee_due: = int(quote.get("overdue_fee", 0))
	var paid_interest: = mini(paid_total, interest_due)
	var paid_principal: = mini(required_principal, maxi(0, paid_total - paid_interest))
	var paid_fee: = mini(fee_due, maxi(0, paid_total - paid_interest - paid_principal))
	loan.principal = maxi(0, int(loan.get("principal", 0)) - paid_principal)
	var capitalized_fee_before: = maxi(0, int(loan.get("capitalized_overdue_fee", 0)))
	var paid_capitalized_fee: = mini(capitalized_fee_before, paid_fee)
	loan.capitalized_overdue_fee = capitalized_fee_before - paid_capitalized_fee
	player.debt = maxi(0, int(player.get("debt", 0)) - paid_principal - paid_capitalized_fee)
	loan.paid_interest = int(loan.get("paid_interest", 0)) + paid_interest
	loan.unpaid_interest = maxi(0, interest_due - paid_interest)
	loan.unpaid_principal = maxi(0, required_principal - paid_principal)
	loan.overdue_fee = maxi(0, fee_due - paid_fee)
	var fully_paid_quote: = paid_total >= int(quote.get("total_due", 0))
	if not payoff:
		loan.settlement_processed_round = int(GameState.game_data.get("round", 0))
		loan.remaining_rounds = maxi(0, int(loan.get("remaining_rounds", loan.get("term_rounds", 1))) - 1)
		if fully_paid_quote:
			loan.unpaid_interest = 0
			loan.unpaid_principal = 0
			loan.overdue_fee = 0
			loan.overdue = 0
			loan.installment_paid_round = int(GameState.game_data.get("round", 0))
		else:
			loan.overdue = int(loan.get("overdue", 0)) + 1
		if int(loan.get("remaining_rounds", 0)) <= 0 and int(loan.get("principal", 0)) > 0:
			loan.maturity_due = true
	var settled: = int(loan.get("principal", 0)) <= 0 and int(loan.get("unpaid_interest", 0)) <= 0 and int(loan.get("unpaid_principal", 0)) <= 0 and int(loan.get("overdue_fee", 0)) <= 0
	if settled:
		if str(loan.get("kind", "")) == "mortgage":
			_mark_mortgaged(str(loan.get("asset_id", "")), false)
		player.get("loans", []).erase(loan)
		_refresh_credit_state(player)
	var paid: = {
		"loan_id": loan_id, "principal": paid_principal, "interest": paid_interest, 
		"overdue_fee": paid_fee, "total": paid_total, "automatic": automatic, 
		"overdue_before": overdue_before, "overdue_after": int(loan.get("overdue", 0)), 
		"arrears_cleared": overdue_before > 0 and fully_paid_quote, 
		"settled": settled, 
	}
	var risk_relief: = RepaymentPolicy.risk_relief(original_principal, paid_principal, payoff and settled, overdue_before > 0 and fully_paid_quote)
	paid.risk_relief = risk_relief
	if paid_total > 0:
		GameState._record(player_id, "loan_installment_paid", paid.duplicate(true))
		if risk_relief > 0:
			Risks.adjust(player_id, - risk_relief, "提前全部结清  贷款风险解除" if payoff and settled else "按期还款  负债压力下降", "银行还款")
	if overdue_before > 0 and fully_paid_quote:
		GameState._record(player_id, "loan_delinquency_cleared", {"loan_id": loan_id, "previous_overdue": overdue_before, "automatic": automatic})
	return paid


static func refinance_limit(player_id: String) -> int:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 0
	if bool(player.get("cash_crisis", false)) or int(player.get("credit_frozen_rounds", 0)) > 0:
		return 0
	if player.get("loans", []).any( func(loan: Dictionary) -> bool: return str(loan.get("kind", "")) == "judicial_residual" or int(loan.get("overdue", 0)) > 0 or int(loan.get("unpaid_interest", 0)) > 0 or int(loan.get("overdue_fee", 0)) > 0):
		return 0
	return _credit_ceiling(player)


static func operating_income_multiplier(player_id: String) -> float:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 1.0
	var max_overdue: = 0
	for loan: Dictionary in player.get("loans", []):
		max_overdue = maxi(max_overdue, JUDICIAL_TRIGGER_MISSES if str(loan.get("kind", "")) == "judicial_residual" else int(loan.get("overdue", 0)))
	if max_overdue > 0:
		return float(delinquency_consequence(max_overdue).get("income_multiplier", 0.8))
	var ceiling: = maxi(1, _credit_ceiling(player))
	if float(player.debt) / float(ceiling) >= 0.8:
		return 0.9
	return 1.0


static func _credit_ceiling(player: Dictionary) -> int:
	var base: = int(CompanyRules.numeric_ability(str(player.company_id), "loan_limit", 300.0))
	var risk_penalty: = Risks.credit_penalty(int(player.risk))
	return maxi(0, base - risk_penalty)


static func _stock_book_value(player: Dictionary) -> int:
	var total: = 0.0
	for stock_id: String in player.get("stocks", {}):
		var holding: Dictionary = player.stocks[stock_id]
		var stock: Dictionary = GameState.game_data.get("stocks", {}).get(stock_id, {})
		total += Economy.stock_position_value(float(stock.get("price", 0.0)), int(holding.get("shares", 0)))
	return roundi(total)


static func _project_book_value(player: Dictionary) -> int:
	var total: = int(player.get("enterprise_valuation", 0))
	for item: Dictionary in player.get("active_projects", []):
		if str(item.get("status", "")) == "active" and not bool(item.get("resolved", false)):
			total += int(item.get("current_valuation", 0))
	return total


static func _direct_rate(player: Dictionary) -> float:
	var prior_direct: int = player.get("loans", []).filter( func(loan: Dictionary) -> bool: return str(loan.get("kind", "")) == "direct").size()
	var base_rate: = DIRECT_BASE_RATE + float(prior_direct) * 0.015 + Risks.rate_surcharge(int(player.risk))
	if prior_direct == 0:
		base_rate *= CompanyRules.numeric_ability(str(player.company_id), "first_loan_interest_multiplier", 1.0)
	return clampf(base_rate, 0.02, 0.12)


static func project_success_modifier(player_id: String) -> float:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return 0.0
	var modifier: = -0.15 if bool(player.get("cash_crisis", false)) else 0.0
	var asset_base: = maxf(1.0, float(player.get("asset_value", 1)))
	var debt_ratio: = float(player.debt) / asset_base
	if debt_ratio >= 0.6:
		modifier -= 0.1
	elif debt_ratio >= 0.35:
		modifier -= 0.05
	return modifier


static func pitch_success_modifier(player_id: String) -> float:

	return project_success_modifier(player_id)


static func mortgageable_assets(player_id: String) -> Array[Dictionary]:
	var player: = GameState.player(player_id)
	var result: Array[Dictionary] = []
	for land_id: String in player.get("land_ids", []):
		var collateral: = _collateral(land_id)
		if collateral.is_empty() or _is_collateral_locked(collateral):
			continue
		if _has_collateral_loan(player, str(collateral.land_id)):
			continue
		result.append({
			"id": str(collateral.land_id), 
			"label": str(collateral.label), 
			"value": int(collateral.value), 
			"business_id": str(collateral.business_id)
		})
	return result


static func settle_acquired_asset(player_id: String, asset_id: String, available_amount: = 2147483647) -> int:
	var player: = GameState.player(player_id)
	var collateral: = _collateral(asset_id)
	var land_id: = str(collateral.get("land_id", asset_id))
	var closure: = CollateralSettlement.close_after_disposal(player, land_id, maxi(0, int(available_amount)), "资产收购清算")
	var applied_total: = int(closure.get("recovered", 0))
	_mark_mortgaged(land_id, false)
	if applied_total > 0:
		GameState._record(player_id, "mortgage_cleared_by_acquisition", {
			"asset_id": land_id, 
			"total_applied": applied_total, 
			"residual_debt": int(player.get("debt", 0)), 
		})
	return applied_total


static func pending_judicial_notices(human_only: = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for alert: Dictionary in GameState.game_data.get("forced_collection_alerts", []):
		if str(alert.get("status", "")) != "judicial_notice" or bool(alert.get("acknowledged", false)):
			continue
		var player: = GameState.player(str(alert.get("player_id", "")))
		if human_only and (player.is_empty() or not bool(player.get("human", false))):
			continue
		result.append(alert)
	return result


static func confirm_judicial_foreclosure(player_id: String, loan_id: String) -> Dictionary:
	var player: = GameState.player(player_id)
	var loan: = _find_loan(player, loan_id)
	if player.is_empty() or loan.is_empty():
		return _fail("司法执行对象不存在")
	if not bool(loan.get("judicial_notice_pending", false)) and bool(loan.get("foreclosure_started", false)):
		return _ok("司法拍卖已经启动")
	var asset_id: = str(loan.get("collection_asset_id", loan.get("asset_id", "")))
	if asset_id.is_empty():
		return _fail("没有可执行的抵押资产")
	_foreclose(player, loan)
	for alert: Dictionary in GameState.game_data.get("forced_collection_alerts", []):
		if str(alert.get("player_id", "")) == player_id and str(alert.get("loan_id", "")) == loan_id and str(alert.get("status", "")) == "judicial_notice":
			alert.acknowledged = true
			alert.status = "auction_started"
	return _ok("司法拍卖已启动", {"asset_id": asset_id, "loan_id": loan_id})


static func has_judicial_bankruptcy_due(player_id: String) -> bool:
	var player: = GameState.player(player_id)
	if player.is_empty():
		return false
	var current_round: = int(GameState.game_data.get("round", 0))
	return player.get("loans", []).any( func(loan: Dictionary) -> bool:
		if str(loan.get("kind", "")) != "judicial_residual" or _judicial_residual_total(loan) <= 0:
			return false
		var start_round: = int(loan.get("judicial_residual_started_round", current_round))
		var due_round: = int(loan.get("judicial_residual_due_round", start_round + JUDICIAL_RESIDUAL_DEADLINE))
		return bool(loan.get("bankruptcy_pending", false)) or current_round >= due_round)


static func _foreclose(player: Dictionary, loan: Dictionary) -> void :
	var asset_id: = str(loan.asset_id)
	if asset_id.is_empty():
		asset_id = str(loan.get("collection_asset_id", ""))
	if not asset_id.is_empty():
		Auctions.create_for_asset(asset_id, "forced_collection", str(player.id))
	loan.collection_asset_id = str(_collateral(asset_id).get("land_id", asset_id))
	loan.foreclosure_started = true
	loan.judicial_notice_pending = false
	GameState._record(str(player.id), "foreclosure_started", {
		"asset_id": asset_id, 
		"loan_id": str(loan.get("id", "")), 
		"outstanding_total": int(payoff_quote(str(player.id), str(loan.get("id", ""))).get("total_due", 0)), 
	})
	CompetitionFeed.publish("foreclosure", str(player.id), "%s的抵押资产进入强制拍卖" % str(player.get("name", "财团")), {"asset_id": asset_id, "loan_id": str(loan.get("id", ""))})


static func _handle_direct_default(player: Dictionary, loan: Dictionary) -> void :
	var overdue: = int(loan.get("overdue", 0))
	if overdue >= 2 and not bool(loan.get("collection_started", false)):
		loan.collection_started = true
		_append_ledger(str(player.id), "信用快贷进入催收", {"loan_id": str(loan.id), "principal": int(loan.principal), "overdue_fee": int(loan.get("overdue_fee", 0))})
		GameState._record(str(player.id), "direct_loan_collection", {"loan_id": str(loan.id), "overdue": overdue, "overdue_fee": int(loan.get("overdue_fee", 0))})
	if overdue < JUDICIAL_TRIGGER_MISSES or bool(loan.get("forced_collection_started", false)) or bool(loan.get("judicial_notice_pending", false)):
		return
	var candidates: Array[Dictionary] = []
	for land_id: String in player.get("land_ids", []):
		var collateral: = _collateral(land_id)
		if collateral.is_empty() or str(collateral.get("owner_id", "")) != str(player.id):
			continue
		if str(collateral.land.get("state", "")) in ["auction", "government_locked"]:
			continue
		if _has_collateral_loan(player, str(collateral.land_id)):
			continue
		candidates.append(collateral)
	candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a.value) > int(b.value))
	if candidates.is_empty():
		_append_ledger(str(player.id), "信用快贷强制催收：无资产可处置", {"loan_id": str(loan.id), "overdue": overdue})
		GameState._record(str(player.id), "direct_collection_insolvency_review", {"loan_id": str(loan.id)})
		return
	var asset: Dictionary = candidates[0]
	loan.collection_asset_id = str(asset.land_id)
	_prepare_judicial_foreclosure(player, loan, str(asset.land_id))
	if not bool(player.get("human", false)):
		confirm_judicial_foreclosure(str(player.get("id", "")), str(loan.get("id", "")))


static func _prepare_judicial_foreclosure(player: Dictionary, loan: Dictionary, asset_id: String) -> void :
	if bool(loan.get("judicial_notice_pending", false)) or bool(loan.get("foreclosure_started", false)):
		return
	loan.collection_asset_id = str(_collateral(asset_id).get("land_id", asset_id))
	loan.judicial_notice_pending = true
	loan.forced_collection_started = true
	_queue_forced_collection_alert(player, loan, asset_id)
	_append_ledger(str(player.id), "连续三期逾期  等待司法执行确认", {"loan_id": str(loan.get("id", "")), "asset_id": loan.collection_asset_id})
	GameState._record(str(player.id), "judicial_foreclosure_notice", {"loan_id": str(loan.get("id", "")), "asset_id": loan.collection_asset_id, "overdue": int(loan.get("overdue", 0))})


static func _queue_forced_collection_alert(player: Dictionary, loan: Dictionary, asset_id: String) -> void :
	var queue: Array = GameState.game_data.get_or_add("forced_collection_alerts", [])
	var key: = "%s:%s:%d" % [str(player.get("id", "")), str(loan.get("id", "")), int(GameState.game_data.get("round", 0))]
	if queue.any( func(item: Dictionary) -> bool: return str(item.get("key", "")) == key):
		return
	var collateral: = _collateral(asset_id)
	queue.append({
		"key": key, 
		"player_id": str(player.get("id", "")), 
		"player_name": str(player.get("name", "财团")), 
		"loan_id": str(loan.get("id", "")), 
		"asset_id": str(collateral.get("land_id", asset_id)), 
		"asset_name": str(collateral.get("label", "城市资产 %s" % asset_id)), 
		"overdue_count": int(loan.get("overdue", 0)), 
		"risk": int(player.get("risk", 0)), 
		"outstanding_total": int(payoff_quote(str(player.get("id", "")), str(loan.get("id", ""))).get("total_due", 0)), 
		"round": int(GameState.game_data.get("round", 0)), 
		"status": "judicial_notice", 
		"acknowledged": false, 
	})


static func _process_judicial_residual(player: Dictionary, loan: Dictionary, allow_automatic_payment: bool) -> void :
	var current_round: = int(GameState.game_data.get("round", 0))
	var start_round: = int(loan.get("judicial_residual_started_round", current_round))
	var due_round: = int(loan.get("judicial_residual_due_round", start_round + JUDICIAL_RESIDUAL_DEADLINE))
	loan.judicial_residual_due_round = due_round
	if int(loan.get("residual_processed_round", -1)) == current_round or current_round <= start_round:
		return
	var quote: = _quote_for_loan(str(player.get("id", "")), loan, false, true)
	if allow_automatic_payment and int(player.get("cash", 0)) >= int(quote.get("total_due", 0)):
		_apply_payment(player, loan, quote, int(quote.get("total_due", 0)), true, false)
		return
	loan.residual_processed_round = current_round
	loan.residual_rounds = maxi(int(loan.get("residual_rounds", 0)) + 1, current_round - start_round)
	player.cash_crisis = true
	player.credit_frozen_rounds = maxi(JUDICIAL_RESIDUAL_DEADLINE + 1, int(player.get("credit_frozen_rounds", 0)))
	Risks.adjust(str(player.get("id", "")), 8, "司法剩余息费未清", "银行司法追偿")
	GameState._record(str(player.get("id", "")), "judicial_residual_overdue", {
		"loan_id": str(loan.get("id", "")), "residual_rounds": int(loan.residual_rounds), 
		"deadline": JUDICIAL_RESIDUAL_DEADLINE, "interest": int(loan.get("unpaid_interest", 0)), 
		"overdue_fee": int(loan.get("overdue_fee", 0)), 
	})
	if current_round >= due_round or int(loan.residual_rounds) >= JUDICIAL_RESIDUAL_DEADLINE:
		loan.bankruptcy_pending = true


static func _judicial_residual_total(loan: Dictionary) -> int:
	return maxi(0, int(loan.get("unpaid_interest", 0))) + maxi(0, int(loan.get("overdue_fee", 0))) + maxi(0, int(loan.get("unpaid_principal", 0)))


static func _refresh_credit_state(player: Dictionary) -> void :
	var distressed: bool = player.get("loans", []).any( func(active: Dictionary) -> bool:
		return str(active.get("kind", "")) == "judicial_residual" or int(active.get("overdue", 0)) > 0 or int(active.get("unpaid_interest", 0)) > 0 or int(active.get("overdue_fee", 0)) > 0)
	if not distressed:
		player.cash_crisis = false
		player.missed_payments = 0
		player.credit_frozen_rounds = 0


static func _collateral(asset_id: String) -> Dictionary:
	var land: Dictionary = GameState.game_data.lands.get(asset_id, {})
	var business: Dictionary = GameState.game_data.businesses.get(asset_id, {})
	if not business.is_empty():
		land = GameState.game_data.lands.get(str(business.land_id), {})
	if land.is_empty():
		return {}
	var business_id: = str(land.get("business_id", ""))
	if business.is_empty() and not business_id.is_empty():
		business = GameState.game_data.businesses.get(business_id, {})
	var owner_id: = str(land.get("owner_id", ""))
	if not business.is_empty() and str(business.get("owner_id", "")) != owner_id:
		return {}
	var value: = int(land.get("price", 0)) + int(business.get("value", 0))
	var label: = "土地 %s" % str(land.id)
	if not business.is_empty():
		label = "%s  %s（整体资产）" % [str(land.id), str(business.name)]
	return {
		"land_id": str(land.id), 
		"business_id": str(business.get("id", "")), 
		"owner_id": owner_id, 
		"value": value, 
		"label": label, 
		"land": land, 
		"business": business
	}


static func _is_collateral_locked(collateral: Dictionary) -> bool:
	var land: Dictionary = collateral.land
	var business: Dictionary = collateral.business
	if bool(land.get("mortgaged", false)) or str(land.get("state", "")) in ["auction", "government_locked"]:
		return true
	return not business.is_empty() and (bool(business.get("mortgaged", false)) or str(business.get("state", "")) in ["auction", "closed", "acquired"])


static func _has_collateral_loan(player: Dictionary, land_id: String) -> bool:
	for loan: Dictionary in player.get("loans", []):
		if str(loan.kind) != "mortgage":
			continue
		var loan_collateral: = _collateral(str(loan.asset_id))
		if str(loan_collateral.get("land_id", loan.asset_id)) == land_id:
			return true
	return false


static func _mark_mortgaged(asset_id: String, value: bool) -> void :
	var collateral: = _collateral(asset_id)
	if collateral.is_empty():
		return
	var land: Dictionary = collateral.land
	var business: Dictionary = collateral.business
	land.mortgaged = value
	if value and str(land.state) in ["owned_empty", "operating", "loss_watch"]:
		land.previous_state = str(land.state)
		AssetStates.transition(land, AssetStates.MORTGAGED, str(land.get("owner_id", "")))
	elif not value and str(land.state) == "mortgaged":
		AssetStates.transition(land, AssetStates.OWNED, str(land.get("owner_id", "")), str(land.get("previous_state", "operating" if not business.is_empty() else "owned_empty")))
	if not business.is_empty():
		business.mortgaged = value


static func _consume_foreclosure_guard(player: Dictionary) -> bool:
	for guard: Dictionary in player.get("guards", []).duplicate():
		if str(guard.effect) == "block_foreclosure":
			player.guards.erase(guard)
			return true
	return false


static func _next_loan_id(player: Dictionary, prefix: String) -> String:
	var index: int = player.get("loans", []).size() + 1
	var candidate: = "%s%d" % [prefix, index]
	while player.get("loans", []).any( func(loan: Dictionary) -> bool: return str(loan.id) == candidate):
		index += 1
		candidate = "%s%d" % [prefix, index]
	return candidate


static func _loan_owner_id(target_loan: Dictionary) -> String:
	for player: Dictionary in GameState.game_data.get("players", []):
		for loan: Dictionary in player.get("loans", []):
			if is_same(loan, target_loan):
				return str(player.id)
	return ""


static func _append_ledger(player_id: String, title: String, details: Dictionary) -> void :
	GameState.game_data.get_or_add("battle_ledger", []).append({"round": int(GameState.game_data.get("round", 0)), "category": "loan", "player_id": player_id, "title": title, "details": details.duplicate(true)})


static func _ok(message: String, details: = {}) -> Dictionary:
	var result: = {"ok": true, "message": message}
	result.merge(details, true)
	return result


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
