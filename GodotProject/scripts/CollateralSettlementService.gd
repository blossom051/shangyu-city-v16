class_name CollateralSettlementService
extends RefCounted

const CompetitionFeed = preload("res://scripts/CompetitiveEventFeed.gd")


static func close_after_disposal(owner: Dictionary, land_id: String, proceeds: int, reason: = "抵押资产处置") -> Dictionary:
	if owner.is_empty() or land_id.is_empty():
		return {"ok": false, "message": "缺少抵押清算对象"}
	var loan: = _matching_loan(owner, land_id)
	if loan.is_empty():
		return {"ok": true, "already_closed": true, "recovered": 0, "shortfall_absorbed": 0, "surplus_returned": 0}
	var transaction_id: = "collateral_close:%s:%s:%s" % [str(owner.get("id", "")), land_id, str(loan.get("id", ""))]
	var ledger: Dictionary = GameState.game_data.get_or_add("economic_transactions", {})
	if ledger.has(transaction_id):
		var cached: Dictionary = ledger[transaction_id].duplicate(true)
		cached["reused"] = true
		return cached
	var principal: = maxi(0, int(loan.get("principal", 0)))
	var interest: = maxi(0, int(loan.get("unpaid_interest", 0)))
	var overdue_fee: = maxi(0, int(loan.get("overdue_fee", 0)))
	var total_due: = principal + interest + overdue_fee


	var recovered: = mini(maxi(0, proceeds), principal)
	var shortfall: = maxi(0, principal - recovered)
	var surplus: = maxi(0, proceeds - principal)
	owner.debt = maxi(0, int(owner.get("debt", 0)) - principal)
	loan.original_kind = str(loan.get("kind", "mortgage"))
	loan.kind = "judicial_residual"
	loan.principal = 0
	loan.unpaid_principal = 0
	loan.rate = 0.0
	loan.asset_id = ""
	loan.foreclosure_started = false
	loan.forced_collection_started = false
	loan.judicial_notice_pending = false
	loan.remaining_rounds = 3
	loan.residual_rounds = 0
	loan.judicial_residual_started_round = int(GameState.game_data.get("round", 0))
	loan.judicial_residual_due_round = int(GameState.game_data.get("round", 0)) + 3
	loan.residual_processed_round = -1
	loan.bankruptcy_pending = false
	loan.overdue = 0
	if interest + overdue_fee <= 0:
		owner.loans.erase(loan)
	if surplus > 0:
		GameState.apply_cash(str(owner.get("id", "")), surplus, "%s余款返还" % reason)
	var result: = {
		"ok": true, 
		"transaction_id": transaction_id, 
		"player_id": str(owner.get("id", "")), 
		"loan_id": str(loan.get("id", "")), 
		"asset_id": land_id, 
		"total_due": total_due, 
		"recovered": recovered, 
		"shortfall_absorbed": shortfall, 
		"surplus_returned": surplus, 
		"principal_cleared": principal, 
		"residual_interest": interest, 
		"residual_overdue_fee": overdue_fee, 
		"residual_total": interest + overdue_fee, 
		"residual_deadline_rounds": 3, 
		"loan_cleared": interest + overdue_fee <= 0, 
		"reused": false, 
	}
	ledger[transaction_id] = result.duplicate(true)
	_update_alert(owner, land_id, result)
	GameState._record(str(owner.get("id", "")), "foreclosure_principal_cleared", result.duplicate(true))
	CompetitionFeed.publish("foreclosure_closed", str(owner.get("id", "")), "%s的抵押本金已核销，剩余息费%d万进入三回合追偿" % [str(owner.get("name", "财团")), interest + overdue_fee], result)
	return result


static func _matching_loan(owner: Dictionary, land_id: String) -> Dictionary:
	for loan: Dictionary in owner.get("loans", []):
		var collection_id: = str(loan.get("collection_asset_id", ""))
		var asset_id: = str(loan.get("asset_id", ""))
		if collection_id == land_id or _land_id_for_asset(asset_id) == land_id:
			return loan
	return {}


static func _land_id_for_asset(asset_id: String) -> String:
	if GameState.game_data.get("lands", {}).has(asset_id):
		return asset_id
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(asset_id, {})
	return str(business.get("land_id", asset_id))


static func _update_alert(owner: Dictionary, land_id: String, result: Dictionary) -> void :
	var alerts: Array = GameState.game_data.get_or_add("forced_collection_alerts", [])
	var matched: = false
	for alert: Dictionary in alerts:
		if str(alert.get("player_id", "")) != str(owner.get("id", "")) or str(alert.get("asset_id", "")) != land_id:
			continue
		alert.merge(result, true)
		alert.status = "settled"
		alert.message = "抵押资产已处置，本金核销；剩余利息%d万、逾期费用%d万须在3回合内结清。" % [int(result.residual_interest), int(result.residual_overdue_fee)]
		alert.acknowledged = false
		matched = true
	if not matched:
		alerts.append({
			"key": "closure:%s:%s" % [str(owner.get("id", "")), land_id], 
			"player_id": str(owner.get("id", "")), 
			"player_name": str(owner.get("name", "财团")), 
			"asset_id": land_id, 
			"round": int(GameState.game_data.get("round", 0)), 
			"acknowledged": false, 
			"status": "settled", 
			"message": "抵押资产已处置，本金核销；剩余息费须在3回合内结清。", 
			"loan_cleared": bool(result.loan_cleared), 
			"principal_cleared": int(result.principal_cleared), 
			"residual_interest": int(result.residual_interest), 
			"residual_overdue_fee": int(result.residual_overdue_fee), 
			"residual_total": int(result.residual_total), 
			"recovered": int(result.recovered), 
			"shortfall_absorbed": int(result.shortfall_absorbed), 
			"surplus_returned": int(result.surplus_returned), 
		})
