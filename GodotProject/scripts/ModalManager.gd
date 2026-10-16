extends Node

signal active_changed(modal_id: String)
signal modal_recovered(modal_id: String, reason: String)

const SURFACE_GROUP: = "managed_modal_surface"
const TRANSIENT_GROUP: = "managed_modal_owner"

var _generation: = 0
var _active: Dictionary = {}


func open_modal(
	modal_id: String, 
	owner: Node, 
	interactive_root: Control, 
	canvas_layer: CanvasLayer = null, 
	recovery: Callable = Callable()
) -> int:
	if modal_id.is_empty() or not is_instance_valid(owner) or not is_instance_valid(interactive_root):
		return 0
	_close_unmanaged_autoload_overlays(owner)
	if str(_active.get("id", "")) == modal_id and _active.get("owner") == owner:
		var previous_surface: = _active.get("surface") as Control
		if is_instance_valid(previous_surface) and previous_surface != interactive_root:
			previous_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
			previous_surface.visible = false
			previous_surface.remove_from_group(SURFACE_GROUP)
		interactive_root.add_to_group(SURFACE_GROUP)
		interactive_root.visible = true
		_active.surface = interactive_root
		_active.layer = canvas_layer
		_active.recovery = recovery
		_active.open_mouse_filter = interactive_root.mouse_filter
		return int(_active.get("token", 0))
	if not _active.is_empty():
		_force_close_active("replaced_by_%s" % modal_id)
	_cleanup_stale_surfaces(interactive_root, canvas_layer)
	_generation += 1
	var token: = _generation
	interactive_root.add_to_group(SURFACE_GROUP)
	interactive_root.visible = true
	owner.set_meta("modal_token", token)
	_active = {
		"id": modal_id, 
		"token": token, 
		"owner": owner, 
		"surface": interactive_root, 
		"layer": canvas_layer, 
		"recovery": recovery, 
		"open_mouse_filter": interactive_root.mouse_filter, 
		"opened_at": Time.get_ticks_msec(), 
	}
	if not bool(owner.get_meta("modal_exit_watch_connected", false)):
		owner.set_meta("modal_exit_watch_connected", true)
		owner.tree_exiting.connect(_on_owner_tree_exiting.bind(owner), CONNECT_ONE_SHOT)
	active_changed.emit(modal_id)
	return token


func close_modal(token: int, _reason: = "closed") -> void :
	if token <= 0 or int(_active.get("token", 0)) != token:
		return
	_deactivate_record(_active, false)
	_active.clear()
	active_changed.emit("")


func recover_active(reason: = "watchdog") -> bool:
	if _active.is_empty():
		return false
	var surface: = _active.get("surface") as Control
	var layer: = _active.get("layer") as CanvasLayer
	_cleanup_stale_surfaces(surface, layer)
	_stop_timers_except(_active.get("owner") as Node, null)
	var recovery: Callable = _active.get("recovery", Callable())
	if recovery.is_valid():
		recovery.call()
	if is_instance_valid(surface):
		surface.visible = true
		surface.mouse_filter = int(_active.get("open_mouse_filter", Control.MOUSE_FILTER_STOP)) as Control.MouseFilter
	var modal_id: = str(_active.get("id", ""))
	modal_recovered.emit(modal_id, reason)
	return true


func clear_all(reason: = "clear_all") -> void :
	if not _active.is_empty():
		_force_close_active(reason)
	_cleanup_stale_surfaces(null, null)


func is_active(modal_id: String = "") -> bool:
	if _active.is_empty():
		return false
	return modal_id.is_empty() or str(_active.get("id", "")) == modal_id


func is_blocked() -> bool:
	return not _active.is_empty()


func active_id() -> String:
	return str(_active.get("id", ""))


func owner_count() -> int:
	return 0 if _active.is_empty() else 1


func snapshot() -> Dictionary:
	if _active.is_empty():
		return {"active": false, "id": "", "token": 0, "age_msec": 0}
	return {
		"active": true, 
		"id": str(_active.get("id", "")), 
		"token": int(_active.get("token", 0)), 
		"age_msec": maxi(0, Time.get_ticks_msec() - int(_active.get("opened_at", Time.get_ticks_msec()))), 
	}


func _force_close_active(_reason: String) -> void :
	if _active.is_empty():
		return
	var record: = _active
	_active = {}
	_deactivate_record(record, true)
	active_changed.emit("")


func _deactivate_record(record: Dictionary, force_owner_close: bool) -> void :
	var surface: = record.get("surface") as Control
	if is_instance_valid(surface):
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.visible = false
		surface.remove_from_group(SURFACE_GROUP)
	var owner: = record.get("owner") as Node
	_stop_timers_except(owner, null)
	if force_owner_close and is_instance_valid(owner):
		if owner.has_method("on_modal_force_close"):
			owner.call_deferred("on_modal_force_close")
		elif owner.is_in_group(TRANSIENT_GROUP):
			owner.call_deferred("queue_free")


func _cleanup_stale_surfaces(current_surface: Control, current_layer: CanvasLayer) -> void :
	for value: Variant in get_tree().get_nodes_in_group(SURFACE_GROUP):
		var node: = value as Node
		if not is_instance_valid(node) or node == current_surface:
			continue
		if current_layer != null and current_layer.is_ancestor_of(node):
			continue
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			(node as Control).visible = false
		var stale_owner: = _surface_owner(node)
		if is_instance_valid(stale_owner) and stale_owner != current_layer:
			stale_owner.call_deferred("queue_free")


func _close_unmanaged_autoload_overlays(owner: Node) -> void :
	var feedback: = get_node_or_null("/root/GlobalFeedbackOverlay")
	if feedback != null and feedback != owner and bool(feedback.call("is_open")):
		feedback.call("close")
	var flow: = get_node_or_null("/root/GameFlow")
	if flow != null:
		var pause_overlay: = flow.get("pause_overlay") as CanvasLayer
		if is_instance_valid(pause_overlay) and pause_overlay.is_inside_tree() and pause_overlay != owner and pause_overlay.visible:
			pause_overlay.call("hide_menu")


func _surface_owner(surface: Node) -> Node:
	var cursor: = surface
	while cursor.get_parent() != null and not cursor is CanvasLayer:
		cursor = cursor.get_parent()
	return cursor


func _stop_timers_except(node: Node, except_timer: Timer) -> void :
	if not is_instance_valid(node):
		return
	if node is Timer and node != except_timer:
		(node as Timer).stop()
	for child: Node in node.get_children():
		_stop_timers_except(child, except_timer)


func _on_owner_tree_exiting(owner: Node) -> void :
	if _active.get("owner") == owner:
		close_modal(int(_active.get("token", 0)), "owner_tree_exiting")
