class_name EconomyDebugAudit
extends RefCounted


static func emit_round(report: Dictionary) -> void :
	if not OS.is_debug_build():
		return
	for player: Dictionary in GameState.game_data.get("players", []):
		var player_id: = str(player.get("id", ""))
		var item: Dictionary = report.get("players", {}).get(player_id, {})
		print("[DEBUG-ECONOMY] round=%d player=%s opening_cash=%d business=%+d traffic=%+d stock=%+d interest=-%d ending_cash=%d asset_change=%+d debt_change=%+d rank=%d rank_change=%+d" % [
			int(report.get("round", 0)), player_id, int(item.get("cash_before", 0)), int(item.get("business_income", 0)), 
			int(item.get("traffic_income", 0)) + int(item.get("control_income", 0)) - int(item.get("competition_cost", 0)), 
			int(item.get("stock_pnl", 0)), int(item.get("interest", 0)), int(item.get("cash_after", 0)), 
			int(item.get("asset_change", 0)), int(item.get("debt_change", 0)), int(item.get("rank_after", 0)), int(item.get("rank_change", 0)), 
		])
