class_name CompetitiveEventFeed
extends RefCounted


static func publish(category: String, player_id: String, title: String, details: = {}, visibility: = "public") -> Dictionary:
	var feed: Array = GameState.game_data.get_or_add("competition_feed", [])
	var event: = {
		"id": "CE-%d-%04d" % [int(GameState.game_data.get("round", 0)), feed.size() + 1], 
		"round": int(GameState.game_data.get("round", 0)), 
		"category": category, 
		"player_id": player_id, 
		"player_name": str(GameState.player(player_id).get("name", player_id)) if not player_id.is_empty() else "城市市场", 
		"title": title, 
		"details": details.duplicate(true), 
		"visibility": visibility, 
	}
	feed.append(event)
	if feed.size() > 80:
		feed.pop_front()
	return event
