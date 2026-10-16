class_name EndlessCheatDialog
extends Control

signal cheat_applied(result: Dictionary)

const Styles = preload("res://scripts/UIStyles.gd")
const Cheats = preload("res://scripts/EndlessCheatSystem.gd")

var player_id := ""
var code_input: LineEdit
var feedback: Label
var modal_token := 0


func open_for_player(next_player_id: String) -> void:
	player_id = next_player_id


func _ready() -> void:
	name = "EndlessCheatDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 940
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("endless_cheat", self, self)
	tree_exiting.connect(func() -> void: ModalManager.close_modal(modal_token, "endless_cheat_closed"))
	_build()
	code_input.grab_focus()


func on_modal_force_close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.018, 0.032, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310, -190)
	panel.size = Vector2(620, 380)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071f2b"), Color("e0b85c"), 26, 3))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	stack.add_child(Styles.label("永续模式指令台", 32, Color("f3d27b")))
	stack.add_child(Styles.label("输入作弊码后，当前财团获得 1 亿资金并解除本局经营限制。", 17, Color("b8cbd0")))
	code_input = LineEdit.new()
	code_input.name = "CheatCodeInput"
	code_input.placeholder_text = "输入作弊码"
	code_input.secret = true
	code_input.custom_minimum_size = Vector2(0, 62)
	code_input.add_theme_font_size_override("font_size", 25)
	code_input.text_submitted.connect(func(_value: String) -> void: _submit())
	stack.add_child(code_input)
	feedback = Styles.label("按 Enter 确认  Esc 关闭", 15, Color("91aab0"))
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(feedback)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(138, 52)
	Styles.apply_button(cancel, false, Color("4b7884"), 18)
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "启用"
	confirm.custom_minimum_size = Vector2(158, 52)
	Styles.apply_button(confirm, true, Color("d6ad54"), 18)
	confirm.pressed.connect(_submit)
	actions.add_child(confirm)


func _submit() -> void:
	var result := Cheats.activate(player_id, code_input.text)
	if not bool(result.get("ok", false)):
		feedback.text = str(result.get("message", "作弊码无效"))
		feedback.add_theme_color_override("font_color", Color("ef7777"))
		code_input.select_all()
		code_input.grab_focus()
		return
	cheat_applied.emit(result)
	queue_free()
