class_name AuctionNoticeState
extends RefCounted


static func pending_notices(player_id: = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target_id: = player_id
	if target_id.is_empty():
		target_id = str(GameState.active_player().get("id", ""))
	var seen_by_player: = _seen_by_player()
	var seen: Array = seen_by_player.get_or_add(target_id, [])
	for auction: Dictionary in GameState.game_data.get("auctions", []):
		var key: = str(auction.get("asset_id", auction.get("land_id", "")))
		if key.is_empty() or seen.has(key):
			continue
		if not target_id.is_empty() and str(auction.get("seller_id", "")) == target_id:
			continue
		if auction.get("excluded_bidder_ids", []).has(target_id):
			continue
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(auction.get("land_id", "")), {})
		result.append({
			"key": key, 
			"asset_id": key, 
			"land_id": str(auction.get("land_id", "")), 
			"title": "银行抵押资产司法拍卖" if str(auction.get("source", "")) == "forced_collection" else "本轮新增竞拍事件", 
			"asset_name": "%s  %s" % [str(auction.get("land_id", "城市资产")), str(land.get("district_name", "城市资产"))], 
			"start_price": int(auction.get("start_price", 0)), 
			"round": int(auction.get("scheduled_round", GameState.game_data.get("round", 1))), 
		})
	return result


static func mark_seen(asset_id: String, player_id: = "") -> void :
	var target_id: = player_id
	if target_id.is_empty():
		target_id = str(GameState.active_player().get("id", ""))
	var seen: Array = _seen_by_player().get_or_add(target_id, [])
	if not seen.has(asset_id):
		seen.append(asset_id)


static func has_unread(player_id: = "") -> bool:
	return not pending_notices(player_id).is_empty()


static func _seen_by_player() -> Dictionary:
	var stored: Variant = GameState.game_data.get("auction_notices_seen", {})
	if stored is Dictionary:
		return stored
	var migrated: Dictionary = {}
	GameState.game_data.auction_notices_seen = migrated
	return migrated
