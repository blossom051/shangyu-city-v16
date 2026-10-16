class_name AssetActionConfirmDialog
extends CanvasLayer

signal confirmed

const Styles = preload("res://scripts/UIStyles.gd")

var heading := "确认操作"
var detail := ""
var confirm_text := "确认"
var danger := false
var modal_token := 0


func configure(title: String, description: String, action_text: String, is_dangerous: bool = false) -> void:
	heading = title
	detail = description
	confirm_text = action_text
	danger = is_dangerous


func _ready() -> void:
	layer = 2300
	var surface := Control.new(); surface.name = "Surface"; surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surface.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(surface)
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.005, 0.02, 0.035, 0.78); surface.add_child(shade)
	var panel := PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-300, -170); panel.size = Vector2(600, 340); panel.add_theme_stylebox_override("panel", Styles.panel(Color("071e2af8"), Color("e46e72") if danger else Color("d8b45c"), 22, 24)); surface.add_child(panel)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 18); panel.add_child(stack)
	var title := Styles.label(heading, 29, Color("f1d681")); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(title)
	var copy := Styles.label(detail, 18, Color("dce8e8")); copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; copy.size_flags_vertical = Control.SIZE_EXPAND_FILL; copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(copy)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 14); stack.add_child(row)
	var cancel := Button.new(); cancel.text = "取消"; cancel.custom_minimum_size = Vector2(150, 54); Styles.apply_toy_button(cancel, false, Styles.TOY_BLUE, 18); cancel.pressed.connect(queue_free); row.add_child(cancel)
	var accept := Button.new(); accept.name = "ConfirmAction"; accept.text = confirm_text; accept.custom_minimum_size = Vector2(220, 54); Styles.apply_toy_button(accept, true, Color("e46e72") if danger else Styles.TOY_YELLOW, 18); accept.pressed.connect(func() -> void: confirmed.emit(); queue_free()); row.add_child(accept)
	modal_token = ModalManager.open_modal("asset_action_confirm", self, surface, self)
	tree_exiting.connect(func() -> void: ModalManager.close_modal(modal_token, "asset_action_confirm_closed"))


func on_modal_force_close() -> void:
	queue_free()
