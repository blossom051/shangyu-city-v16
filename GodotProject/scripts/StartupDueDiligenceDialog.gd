class_name StartupDueDiligenceDialog
extends CanvasLayer

signal investment_completed(result: Dictionary)

const Styles = preload("res://scripts/UIStyles.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const FOUNDER_ATLAS = preload("res://assets/images/v12/startup_founders_atlas.png")

var player_id := ""
var project_id := ""
var source_button: Button
var preview: Dictionary = {}
var modal_token := 0
var confirm_button: Button
var message_label: Label


func open_for_project(target_player_id: String, target_project_id: String, source: Button = null) -> void:
	player_id = target_player_id
	project_id = target_project_id
	source_button = source
	preview = Startups.investment_preview(player_id, project_id)


func _ready() -> void:
	layer = 2200
	_build()
	modal_token = ModalManager.open_modal("startup_due_diligence", self, get_node("Surface"), self)
	tree_exiting.connect(func() -> void: ModalManager.close_modal(modal_token, "startup_due_diligence_closed"))


func on_modal_force_close() -> void:
	queue_free()


func confirm_investment() -> Dictionary:
	var result := Startups.invest(player_id, project_id)
	if bool(result.get("ok", false)):
		investment_completed.emit(result)
	return result


func _confirm() -> void:
	confirm_button.disabled = true
	var result := confirm_investment()
	if not bool(result.get("ok", false)):
		confirm_button.disabled = false
		message_label.text = str(result.get("message", "当前无法投资"))
		return
	AudioManager.success()
	queue_free()


func _build() -> void:
	var surface := Control.new()
	surface.name = "Surface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(surface)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.02, 0.035, 0.82)
	surface.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "DueDiligencePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var viewport := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(1040.0, viewport.x - 48.0), minf(710.0, viewport.y - 40.0))
	panel.position = -panel_size * 0.5
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071e2af8"), Color("d8b45c"), 24, 22))
	surface.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)
	var project: Dictionary = preview.get("project", {})
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Styles.label("项目尽调  %s" % str(project.get("name", "创业项目")), 31, Color("f4e6bd"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "返回"
	close.custom_minimum_size = Vector2(110, 44)
	Styles.apply_toy_button(close, false, Styles.TOY_BLUE, 17)
	close.pressed.connect(queue_free)
	header.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(380, 0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = _founder_texture(project_id)
	body.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	body.add_child(info)
	_add_text(info, "%s  %s" % [str(project.get("founder", "创始人")), str(project.get("founder_role", "创业者"))], 19, Color("71c8d5"))
	_add_text(info, str(project.get("founder_tagline", "")), 23, Color("edf3f2"))
	_add_text(info, str(project.get("summary", "")), 17, Color("adc3c7"))
	var cycle: Dictionary = preview.get("cycle", {})
	var cycle_modifier := float(preview.get("success_breakdown", {}).get("cycle", 0.0))
	_add_investment_memo(info, cycle)
	var direction := "成功率 +%d%%" % roundi(cycle_modifier * 100.0) if cycle_modifier >= 0.0 else "成功率 %d%%" % roundi(cycle_modifier * 100.0)
	_add_text(info, "周期影响  %s   包装风险表示项目可能在尽调后暴露重大问题" % direction, 15, Color("b9c8c8"))
	message_label = Styles.label("首次点击仅查看详情；确认后才扣除投资款。", 16, Color("f0d27d"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(message_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	var cancel := Button.new()
	cancel.text = "暂不投资"
	cancel.custom_minimum_size = Vector2(170, 54)
	Styles.apply_toy_button(cancel, false, Styles.TOY_BLUE, 18)
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmInvestment"
	confirm_button.text = "确认投资  %s" % Styles.money(int(preview.get("cost", 0)))
	confirm_button.custom_minimum_size = Vector2(250, 54)
	confirm_button.disabled = not bool(preview.get("ok", false)) or int(preview.get("cash_after", -1)) < 0
	Styles.apply_toy_button(confirm_button, true, Styles.TOY_YELLOW, 18)
	confirm_button.pressed.connect(_confirm)
	actions.add_child(confirm_button)


func _founder_texture(id: String) -> Texture2D:
	var index := clampi(int(id.trim_prefix("sp")) - 1, 0, 5)
	var cell := Vector2(float(FOUNDER_ATLAS.get_width()) / 3.0, float(FOUNDER_ATLAS.get_height()) / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = FOUNDER_ATLAS
	atlas.region = Rect2(Vector2(float(index % 3) * cell.x, float(index / 3) * cell.y), cell)
	return atlas


func _add_investment_memo(parent: VBoxContainer, cycle: Dictionary) -> void:
	var memo := VBoxContainer.new()
	memo.add_theme_constant_override("separation", 8)
	parent.add_child(memo)
	var divider := ColorRect.new(); divider.custom_minimum_size = Vector2(0, 2); divider.color = Color("d8b45c99"); memo.add_child(divider)
	var primary := HBoxContainer.new(); primary.add_theme_constant_override("separation", 18); memo.add_child(primary)
	for spec: Array in [["投入", Styles.money(int(preview.get("cost", 0))), Color("e87982")], ["成功率", "%d%%" % roundi(float(preview.get("success_rate", 0.0)) * 100.0), Color("63d6a3")], ["尽调", "%d 回合" % int(preview.get("duration", 1)), Color("72bfd8")]]:
		var stack := VBoxContainer.new(); stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL; primary.add_child(stack)
		var key := Styles.label(str(spec[0]), 13, Color("8faab0")); key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(key)
		var value := Styles.label(str(spec[1]), 23, spec[2]); value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stack.add_child(value)
	var probability := ProgressBar.new(); probability.custom_minimum_size = Vector2(0, 12); probability.show_percentage = false; probability.value = float(preview.get("success_rate", 0.0)) * 100.0; memo.add_child(probability)
	var secondary := Styles.label("预期融资 %s    周期 %s    包装风险 %d%%" % [Styles.money(int(preview.get("expected_financing", 0))), str(cycle.get("name", "常态")), roundi(float(preview.get("fraud_rate", 0.0)) * 100.0)], 15, Color("b9c8c8"))
	secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memo.add_child(secondary)


func _add_text(parent: VBoxContainer, value: String, size: int, color: Color) -> void:
	var label := Styles.label(value, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
