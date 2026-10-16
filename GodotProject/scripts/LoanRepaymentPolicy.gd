class_name LoanRepaymentPolicy
extends RefCounted

const EARLY_PAYOFF_INTEREST_PREMIUM: = 1.1


static func origination_quote(principal: int, rate: float, term_rounds: int, origin_round: int) -> Dictionary:
	var safe_principal: = maxi(0, principal)
	var safe_term: = maxi(1, term_rounds)
	var installment_principal: = ceili(float(safe_principal) / float(safe_term))
	var total_interest: = scheduled_interest(safe_principal, safe_term, installment_principal, rate)
	var first_interest: = ceili(float(safe_principal) * rate)
	return {
		"principal": safe_principal, 
		"rate": rate, 
		"term_rounds": safe_term, 
		"round_principal": installment_principal, 
		"first_interest": first_interest, 
		"first_payment": mini(safe_principal, installment_principal) + first_interest, 
		"first_due_round": origin_round + 1, 
		"total_interest": total_interest, 
		"total_repayment": safe_principal + total_interest, 
	}


static func quote(loan: Dictionary, effective_rate: float, current_round: int, payoff: bool, force_due: = false) -> Dictionary:
	var principal: = maxi(0, int(loan.get("principal", 0)))
	var periods: = maxi(1, int(loan.get("remaining_rounds", loan.get("term_rounds", 1))))
	var due_now: = force_due or is_due(loan, current_round)
	var already_paid: = int(loan.get("installment_paid_round", -1)) == current_round
	var maturity_due: = bool(loan.get("maturity_due", false)) or periods <= 1
	var original_principal: = maxi(principal, int(loan.get("original_principal", principal)))
	var installment_principal: = ceili(float(original_principal) / float(maxi(1, int(loan.get("term_rounds", periods)))))
	var historical_principal: = mini(principal, maxi(0, int(loan.get("unpaid_principal", 0))))
	var current_principal: = 0
	if due_now and not already_paid:
		current_principal = principal if maturity_due else mini(principal, installment_principal)
	var required_principal: = principal if payoff else mini(principal, historical_principal + current_principal)
	var historical_interest: = maxi(0, int(loan.get("unpaid_interest", 0)))
	var current_interest: = ceili(float(principal) * effective_rate) if due_now and not already_paid else 0
	var overdue_fee: = maxi(0, int(loan.get("overdue_fee", 0)))
	var future_periods: = maxi(0, periods - (1 if due_now and not already_paid else 0))
	var future_principal: = maxi(0, principal - current_principal) if due_now and not already_paid else principal
	var future_interest: = scheduled_interest(future_principal, future_periods, installment_principal, effective_rate)
	var early_payoff_penalty: = ceili(float(future_interest) * EARLY_PAYOFF_INTEREST_PREMIUM) if payoff else 0
	var interest_due: = historical_interest + current_interest + early_payoff_penalty
	var plan_total: = principal + historical_interest + current_interest + future_interest + overdue_fee
	return {
		"loan_id": str(loan.get("id", "")), 
		"remaining_principal": principal, 
		"required_principal": required_principal, 
		"current_principal_due": current_principal, 
		"historical_unpaid_principal": historical_principal, 
		"current_interest": current_interest, 
		"historical_unpaid_interest": historical_interest, 
		"scheduled_future_interest": future_interest, 
		"early_payoff_penalty": early_payoff_penalty, 
		"early_payoff_interest": early_payoff_penalty, 
		"interest": interest_due, 
		"overdue_fee": overdue_fee, 
		"total_due": required_principal + interest_due + overdue_fee, 
		"original_plan_remaining_total": plan_total, 
		"periods_left": periods, 
		"due_now": due_now, 
		"maturity_due": maturity_due, 
		"payoff": payoff, 
	}


static func scheduled_interest(starting_principal: int, periods: int, installment_principal: int, rate: float) -> int:
	var rolling: = maxi(0, starting_principal)
	var total: = 0
	for _period in range(maxi(0, periods)):
		if rolling <= 0:
			break
		total += ceili(float(rolling) * rate)
		rolling = maxi(0, rolling - maxi(1, installment_principal))
	return total


static func is_due(loan: Dictionary, current_round: int) -> bool:
	if loan.has("first_due_round"):
		return current_round >= int(loan.get("first_due_round", current_round))
	if loan.has("origin_round"):
		return current_round > int(loan.get("origin_round", current_round - 1))
	return true


static func risk_relief(original_principal: int, principal_paid: int, payoff: bool, arrears_cleared: bool) -> int:
	if principal_paid <= 0:
		return 0
	var proportional: = ceili(float(principal_paid) / float(maxi(1, original_principal)) * 8.0)
	if payoff:
		proportional += 4
	if arrears_cleared:
		proportional += 3
	return clampi(proportional, 1, 15)
