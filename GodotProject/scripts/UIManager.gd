class_name UIManager
extends RefCounted

static func clear(node: Node) -> void :
	for child in node.get_children(): child.queue_free()

static func money(value: int) -> String:
	return "%s%d 万" % ["+" if value > 0 else "", value]

static func short_state(value: String) -> String:
	return {"available": "待售", "owned_empty": "已购空地", "constructing": "施工中", "operating": "经营中", "loss_watch": "亏损观察", "auction": "拍卖"}.get(value, value)
