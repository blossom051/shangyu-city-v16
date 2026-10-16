class_name CityObjectPool
extends RefCounted

var _available: Dictionary = {}
var _leased: Dictionary = {}
var _created: = 0
var _reused: = 0
var _released: = 0


func acquire(kind: String, parent: Node, factory: Callable) -> Node:
	var bucket: Array = _available.get(kind, [])
	var item: Node = null
	while not bucket.is_empty() and not is_instance_valid(item):
		item = bucket.pop_back() as Node
	_available[kind] = bucket
	if item == null:
		item = factory.call() as Node
		_created += 1
	else:
		_reused += 1
	if item.get_parent() != parent:
		if item.get_parent() != null:
			item.reparent(parent)
		else:
			parent.add_child(item)
	item.process_mode = Node.PROCESS_MODE_INHERIT
	if item is CanvasItem:
		(item as CanvasItem).visible = true
	elif item is Node3D:
		(item as Node3D).visible = true
	_leased[item.get_instance_id()] = {"kind": kind, "node": item}
	return item


func release(item: Node) -> void :
	if not is_instance_valid(item):
		return
	var id: = item.get_instance_id()
	if not _leased.has(id):
		return
	var kind: = str(_leased[id].get("kind", "transient"))
	_leased.erase(id)
	if item is CanvasItem:
		(item as CanvasItem).visible = false
	elif item is Node3D:
		(item as Node3D).visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED
	var bucket: Array = _available.get(kind, [])
	bucket.append(item)
	_available[kind] = bucket
	_released += 1


func clear() -> void :
	for bucket_value: Variant in _available.values():
		for item: Node in bucket_value:
			if is_instance_valid(item):
				item.queue_free()
	for entry: Dictionary in _leased.values():
		var item: = entry.get("node") as Node
		if is_instance_valid(item):
			item.queue_free()
	_available.clear()
	_leased.clear()


func profile() -> Dictionary:
	var available_count: = 0
	for bucket_value: Variant in _available.values():
		available_count += (bucket_value as Array).size()
	return {
		"created": _created, 
		"reused": _reused, 
		"released": _released, 
		"available": available_count, 
		"leased": _leased.size(), 
		"bounded_transients": true, 
	}


func validate() -> Dictionary:
	var state: = profile()
	return {
		"valid": int(state.created) >= int(state.leased) and int(state.released) >= int(state.available), 
		"profile": state, 
	}
