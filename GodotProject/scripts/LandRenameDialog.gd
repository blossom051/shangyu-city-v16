class_name LandRenameDialog
extends Control

signal land_name_saved(result: Dictionary)

const Styles = preload("res://scripts/UIStyles.gd")
const LandNames = preload("res://scripts/LandNamingService.gd")

var player_id: = ""
var land_id: = ""
var name_input: LineEdit
var feedback: Label
var modal_token: = 0


func open_for_land(next_player_id: String, next_land_id: String) -> void :
	player_id = next_player_id
	land_id = next_land_id


func _ready() -> void :
	name = "LandRenameDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 820
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("land_rename", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "land_rename_closed"))
	_build()
	name_input.grab_focus()
	name_input.select_all()


func on_modal_force_close() -> void :
	queue_free()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _build() -> void :
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.02, 0.035, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270, -160)
	panel.size = Vector2(540, 320)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071f2b"), Color("d6ad54"), 24, 3))
	add_child(panel)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	stack.add_child(Styles.label("编辑地名", 30, Color("f3d27b")))
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	stack.add_child(Styles.label("%s  %s" % [land_id, str(land.get("district_name", "城市地块"))], 17, Color("9fc6cf")))
	name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "中文5字以内 / 英文6字母以内"
	name_input.text = str(land.get("custom_name", ""))
	name_input.max_length = 6
	name_input.custom_minimum_size = Vector2(0, 58)
	name_input.add_theme_font_size_override("font_size", 23)
	name_input.text_submitted.connect( func(_value: String) -> void : _submit())
	stack.add_child(name_input)
	feedback = Styles.label("名称会以本组颜色显示在建筑上方", 15, Color("a9bcc2"))
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(feedback)
	var actions: = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var cancel: = Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(132, 50)
	Styles.apply_button(cancel, false, Color("4b7884"), 18)
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	var confirm: = Button.new()
	confirm.text = "保存名称"
	confirm.custom_minimum_size = Vector2(158, 50)
	Styles.apply_button(confirm, true, Color("d6ad54"), 18)
	confirm.pressed.connect(_submit)
	actions.add_child(confirm)


func _submit() -> void :
	var result: = LandNames.rename(player_id, land_id, name_input.text)
	if not bool(result.get("ok", false)):
		feedback.text = str(result.get("message", "名称不可用"))
		feedback.add_theme_color_override("font_color", Color("ef7777"))
		name_input.grab_focus()
		return
	AudioManager.confirm()
	land_name_saved.emit(result)
	queue_free()
