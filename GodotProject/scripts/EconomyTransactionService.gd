class_name EconomyTransactionService
extends RefCounted


static func record(transaction_id: String, player_id: String, operation: String, before: Dictionary, delta: Dictionary, after: Dictionary, related_asset_ids: = [], related_loan_ids: = [], public_event: = {}) -> Dictionary:
	var ledger: Dictionary = GameState.game_data.get_or_add("economic_transactions", {})
	if ledger.has(transaction_id):
		var cached: Dictionary = ledger[transaction_id].duplicate(true)
		cached["reused"] = true
		return cached
	var receipt: = {
		"transaction_id": transaction_id, 
		"round_id": int(GameState.game_data.get("round", 0)), 
		"player_id": player_id, 
		"operation": operation, 
		"before": before.duplicate(true), 
		"delta": delta.duplicate(true), 
		"after": after.duplicate(true), 
		"related_asset_ids": related_asset_ids.duplicate(), 
		"related_loan_ids": related_loan_ids.duplicate(), 
		"public_event": public_event.duplicate(true), 
		"reused": false, 
	}
	ledger[transaction_id] = receipt.duplicate(true)
	return receipt
