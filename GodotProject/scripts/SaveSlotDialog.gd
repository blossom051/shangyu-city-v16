class_name SaveSlotDialog
extends CanvasLayer

signal slot_loaded(slot_id: String)
signal slot_saved(slot_id: String)

const Styles = preload("res://scripts/UIStyles.gd")

var dialog_mode := "load"
var grid: GridContainer
var status: Label
var confirm_bar: PanelContainer
var confirm_label: Label
var confirm_button: Button
var pending_action: Callable


func open(mode_value: String) -> void:
	dialog_mode = "save" if mode_value == "save" else "load"


func _ready() -> void:
	name = "SaveSlotDialog"
	layer = 2300
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.002, 0.012, 0.022, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24
	center.offset_right = -24
	center.offset_top = 22
	center.offset_bottom = -22
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "SaveCenter"
	panel.custom_minimum_size = Vector2(1040, 0)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("061923fb"), Color("64c7d3"), 30, 18))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	root.add_child(_header())
	var divider := HSeparator.new()
	divider.modulate = Color("3b6871")
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "SaveSlotScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	grid = GridContainer.new()
	grid.name = "SaveSlotGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(grid)
	_refresh_cards()

	confirm_bar = PanelContainer.new()
	confirm_bar.name = "SaveConfirmBar"
	confirm_bar.visible = false
	confirm_bar.add_theme_stylebox_override("panel", Styles.panel(Color("1b2a2f"), Color("e5b95e"), 16, 8))
	root.add_child(confirm_bar)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 12)
	confirm_bar.add_child(confirm_row)
	confirm_label = Styles.label("", 18, Color("f7e6b2"))
	confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_row.add_child(confirm_label)
	confirm_button = Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(150, 50)
	Styles.apply_toy_button(confirm_button, true, Color("e5b95e"), 18)
	confirm_button.pressed.connect(_execute_pending)
	confirm_row.add_child(confirm_button)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(120, 50)
	Styles.apply_toy_button(cancel, false, Color("8bb8c8"), 18)
	cancel.pressed.connect(_clear_pending)
	confirm_row.add_child(cancel)

	status = Styles.label("选择一个存档位。自动档会持续记录回合结算，手动档只在您确认时更新。", 18, Color("9ed6dc"))
	status.name = "SaveSlotStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size.y = 34
	root.add_child(status)


func _header() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var icon := Styles.label("▣", 48, Color("e3bd64"))
	icon.custom_minimum_size.x = 64
	row.add_child(icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(Styles.label("保存经营进度" if dialog_mode == "save" else "读取经营进度", 36, Color("fff0bd")))
	titles.add_child(Styles.label("1 个安全自动档  ·  8 个可命名手动档位", 19, Color("8ed7de")))
	var close := Button.new()
	close.name = "SaveSlotClose"
	close.text = "返回"
	close.custom_minimum_size = Vector2(138, 54)
	Styles.apply_toy_button(close, false, Color("65c7d2"), 18)
	close.pressed.connect(queue_free)
	row.add_child(close)
	return margin


func _refresh_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
	for summary: Dictionary in SaveSlots.list_slots():
		grid.add_child(_slot_card(summary))


func _slot_card(summary: Dictionary) -> Control:
	var slot_id := str(summary.get("id", ""))
	var automatic := bool(summary.get("automatic", false))
	var exists := bool(summary.get("exists", false))
	var corrupt := bool(summary.get("corrupt", false))
	var accent := Color("e2bb63") if automatic else Color("68c9d4")
	if corrupt:
		accent = Color("e67272")
	var panel := PanelContainer.new()
	panel.name = "SaveCard_%s" % slot_id
	panel.custom_minimum_size = Vector2(315, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("092631f5"), accent, 18, 9))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	top.add_child(Styles.label("自动" if automatic else "%02d" % int(summary.get("index", 0)), 19, accent))
	var name_edit := LineEdit.new()
	name_edit.name = "SlotName_%s" % slot_id
	name_edit.text = str(summary.get("display_name", "自动存档"))
	name_edit.editable = not automatic
	name_edit.max_length = 20
	name_edit.add_theme_font_size_override("font_size", 21)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_edit)
	if corrupt:
		box.add_child(Styles.label("⚠ 存档损坏，无法读取", 19, Color("ff8b8b")))
	elif not exists:
		var empty := Styles.label("空存档位", 24, Color("8fa9ae"))
		empty.custom_minimum_size.y = 112
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(empty)
	else:
		box.add_child(Styles.label(_mode_label(summary), 18, Color("9ed9df")))
		box.add_child(Styles.label("第 %d 回合  ·  游戏日期 %s" % [int(summary.get("round", 0)), str(summary.get("game_date", "--"))], 18, Color("e9eef0")))
		box.add_child(Styles.label("%s  ·  现金 %d万" % [str(summary.get("player_name", "财团")), int(summary.get("cash", 0))], 18, Color("e8c56b")))
		box.add_child(Styles.label("净资产 %d万  ·  土地 %d  ·  企业 %d" % [int(summary.get("asset", 0)), int(summary.get("land_count", 0)), int(summary.get("business_count", 0))], 17, Color("b9d0d4")))
		box.add_child(Styles.label("保存于 %s" % str(summary.get("saved_at", "--")), 15, Color("879ea4")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var primary := Button.new()
	primary.name = "SlotPrimary_%s" % slot_id
	primary.text = "保存到此" if dialog_mode == "save" else "读取此档"
	primary.custom_minimum_size = Vector2(0, 48)
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.disabled = automatic if dialog_mode == "save" else (not exists or corrupt)
	Styles.apply_toy_button(primary, true, accent, 18)
	primary.pressed.connect(func() -> void:
		if dialog_mode == "save":
			_request_save(slot_id, int(summary.get("index", 0)), name_edit.text, exists)
		else:
			_load(slot_id))
	actions.add_child(primary)
	if not automatic and exists:
		var rename := Button.new()
		rename.text = "改名"
		rename.custom_minimum_size = Vector2(72, 48)
		Styles.apply_toy_button(rename, false, Color("8aa9dc"), 16)
		rename.pressed.connect(func() -> void: _rename(int(summary.get("index", 0)), name_edit.text))
		actions.add_child(rename)
		var remove := Button.new()
		remove.text = "删除"
		remove.custom_minimum_size = Vector2(72, 48)
		Styles.apply_toy_button(remove, false, Color("dc7777"), 16)
		remove.pressed.connect(func() -> void: _request_delete(int(summary.get("index", 0)), str(summary.get("display_name", "手动存档"))))
		actions.add_child(remove)
	return panel


func _mode_label(summary: Dictionary) -> String:
	if bool(summary.get("endless", false)):
		return "永续经营模式"
	return "经营模式  ·  %s" % str(summary.get("mode", "solo"))


func _request_save(slot_id: String, index: int, display_name: String, overwrite: bool) -> void:
	var action := func() -> void: _save(index, display_name)
	if overwrite:
		_set_pending("确认覆盖 %s？原进度会被本局替换。" % slot_id, action)
	else:
		action.call()


func _save(index: int, display_name: String) -> void:
	var result := GameState.save_manual_slot(index, display_name)
	status.text = str(result.get("message", "保存失败"))
	if bool(result.get("ok", false)):
		AudioManager.success()
		slot_saved.emit("slot_%02d" % index)
		_refresh_cards()
	_clear_pending()


func _load(slot_id: String) -> void:
	var result := GameState.load_from_slot(slot_id)
	status.text = str(result.get("message", "读取失败"))
	if not bool(result.get("ok", false)):
		return
	AudioManager.success()
	slot_loaded.emit(slot_id)
	queue_free()


func _rename(index: int, display_name: String) -> void:
	var result := SaveSlots.rename_manual(index, display_name)
	status.text = str(result.get("message", "改名失败"))
	if bool(result.get("ok", false)):
		_refresh_cards()


func _request_delete(index: int, display_name: String) -> void:
	_set_pending("确认删除“%s”？删除后不能恢复。" % display_name, func() -> void:
		var result := SaveSlots.delete_manual(index)
		status.text = str(result.get("message", "删除失败"))
		if bool(result.get("ok", false)):
			_refresh_cards()
		_clear_pending())


func _set_pending(message: String, action: Callable) -> void:
	pending_action = action
	confirm_label.text = message
	confirm_bar.visible = true


func _execute_pending() -> void:
	if pending_action.is_valid():
		pending_action.call()


func _clear_pending() -> void:
	pending_action = Callable()
	confirm_bar.visible = false
