class_name SelectionState
extends RefCounted

signal changed(selected_id: String)

var _selected_id: = ""

func toggle(id: String) -> String:
	_selected_id = "" if id == _selected_id else id
	changed.emit(_selected_id)
	return _selected_id

func select(id: String) -> String:
	_selected_id = id
	changed.emit(_selected_id)
	return _selected_id

func clear() -> String:
	if not _selected_id.is_empty():
		_selected_id = ""
		changed.emit(_selected_id)
	return _selected_id

func current() -> String:
	return _selected_id

func should_cancel(pointer_over_ui: bool, blank_map_click: bool, cancel_action: bool) -> bool:
	return not pointer_over_ui and (blank_map_click or cancel_action)
