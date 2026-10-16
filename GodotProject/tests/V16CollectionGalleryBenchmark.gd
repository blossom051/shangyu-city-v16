extends Node


func _ready() -> void:
	await get_tree().process_frame
	var packed := load("res://scenes/CardCollectionGallery.tscn") as PackedScene
	var started := Time.get_ticks_usec()
	var gallery := packed.instantiate() as Control
	var instantiated_usec := Time.get_ticks_usec() - started
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	started = Time.get_ticks_usec()
	get_tree().root.add_child(gallery)
	var ready_usec := Time.get_ticks_usec() - started
	var grid := gallery.get("grid") as GridContainer
	print("GALLERY_BENCHMARK all_count=%d instantiate_ms=%.1f ready_ms=%.1f" % [grid.get_child_count(), instantiated_usec / 1000.0, ready_usec / 1000.0])
	started = Time.get_ticks_usec()
	await get_tree().process_frame
	print("GALLERY_BENCHMARK first_frame_ms=%.1f" % [(Time.get_ticks_usec() - started) / 1000.0])
	started = Time.get_ticks_usec()
	gallery.call("_set_filter", "west_bank_all")
	var filter_usec := Time.get_ticks_usec() - started
	await get_tree().process_frame
	print("GALLERY_BENCHMARK west_count=%d filter_ms=%.1f" % [grid.get_child_count(), filter_usec / 1000.0])
	var registry := load("res://scripts/CardArtRegistry.gd")
	started = Time.get_ticks_usec()
	for card: Dictionary in GameConfig.list("cards"):
		registry.resolve(card)
	var art_usec := Time.get_ticks_usec() - started
	print("GALLERY_BENCHMARK art_resolve_ms=%.1f" % [art_usec / 1000.0])
	gallery.queue_free()
	await get_tree().process_frame
	var second := packed.instantiate() as Control
	second.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	started = Time.get_ticks_usec()
	get_tree().root.add_child(second)
	var second_ready_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	await get_tree().process_frame
	print("GALLERY_BENCHMARK second_ready_ms=%.1f second_frame_ms=%.1f" % [second_ready_usec / 1000.0, (Time.get_ticks_usec() - started) / 1000.0])
	get_tree().quit()
