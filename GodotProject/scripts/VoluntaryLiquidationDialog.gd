class_name VoluntaryLiquidationDialog
extends Control

signal liquidation_completed(summary: Dictionary, solo: bool)

const Styles = preload("res://scripts/UIStyles.gd")
const Insolvency = preload("res://scripts/InsolvencySystem.gd")
const SummaryVisual = preload("res://scripts/LiquidationSummaryVisual.gd")

var player_id := ""
var modal_token := 0
var surface: PanelContainer


func open_for_player(next_player_id: String) -> void:
	player_id = next_player_id


func _ready() -> void:
	name = "VoluntaryLiquidationDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 950
	add_to_group("managed_modal_owner")
	modal_token = ModalManager.open_modal("voluntary_liquidation", self, self)
	tree_exiting.connect(func() -> void: ModalManager.close_modal(modal_token, "voluntary_liquidation_closed"))
	_build_shell()
	_show_confirmation()


func on_modal_force_close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.003, 0.012, 0.022, 0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	surface = PanelContainer.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	surface.position = Vector2(-560, -405)
	surface.size = Vector2(1120, 810)
	surface.add_theme_stylebox_override("panel", Styles.panel(Color("061a27"), Color("c94b55"), 28, 3))
	add_child(surface)


func _clear_surface() -> void:
	for child in surface.get_children():
		child.queue_free()


func _show_confirmation() -> void:
	_clear_surface()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 34)
	surface.add_child(margin)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 22); margin.add_child(stack)
	var title_row := HBoxContainer.new(); title_row.add_theme_constant_override("separation", 20); stack.add_child(title_row)
	var warning := Label.new(); warning.text = "!"; warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; warning.custom_minimum_size = Vector2(72, 72); warning.add_theme_font_size_override("font_size", 48); warning.add_theme_color_override("font_color", Color("ff6a70")); warning.add_theme_stylebox_override("normal", Styles.panel(Color("39161d"), Color("db515b"), 18, 3)); title_row.add_child(warning)
	var title_box := VBoxContainer.new(); title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(title_box)
	title_box.add_child(Styles.label("申请破产清算", 38, Color("f4d9d9")))
	title_box.add_child(Styles.label("主动结束本次永续经营", 18, Color("cba8aa")))
	stack.add_child(Styles.label("确认后将结算本组土地、企业、证券与上市公司记录，并立即结束整局。即使同场还有 AI 财团，也不会继续自动运行回合。", 19, Color("d3e0e1")))
	var player := GameState.player(player_id)
	stack.add_child(_metric_row([["净资产", int(player.get("asset_value", 0)), "万"], ["现金", int(player.get("cash", 0)), "万"], ["负债", int(player.get("debt", 0)), "万"], ["经营回合", int(GameState.game_data.get("round", 0)), "轮"]]))
	var divider := HSeparator.new(); divider.modulate = Color("5d7e87"); stack.add_child(divider)
	stack.add_child(Styles.label("这是不可逆操作，需要再次确认。", 18, Color("ee8a8f")))
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_END; actions.add_theme_constant_override("separation", 14); stack.add_child(actions)
	var cancel := Button.new(); cancel.text = "继续经营"; cancel.custom_minimum_size = Vector2(180, 56); Styles.apply_button(cancel, false, Color("4f8793"), 19); cancel.pressed.connect(queue_free); actions.add_child(cancel)
	var confirm := Button.new(); confirm.text = "确认清算"; confirm.custom_minimum_size = Vector2(190, 56); Styles.apply_button(confirm, true, Color("d4515b"), 19); confirm.pressed.connect(_confirm_liquidation); actions.add_child(confirm)


func _confirm_liquidation() -> void:
	var result := Insolvency.voluntary_liquidate(player_id)
	if not bool(result.get("ok", false)):
		queue_free()
		return
	_show_summary(result.get("summary", {}))


func _show_summary(summary: Dictionary) -> void:
	_clear_surface()
	surface.add_theme_stylebox_override("panel", Styles.panel(Color("061a27"), Color("d6b75e"), 28, 3))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 30)
	surface.add_child(margin)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 16); margin.add_child(stack)
	var heading := HBoxContainer.new(); stack.add_child(heading)
	var heading_copy := VBoxContainer.new(); heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(heading_copy)
	heading_copy.add_child(Styles.label("本局经营总览", 38, Color("f2d27a")))
	heading_copy.add_child(Styles.label("%s  ·  第 %d 回合结束航程" % [str(summary.get("company_name", "本组财团")), int(summary.get("rounds", 0))], 19, Color("b6cbd0")))
	var grade := Styles.label(str(summary.get("grade", "B")), 52, Color("ffe18a")); grade.custom_minimum_size = Vector2(88, 72); grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; grade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; grade.add_theme_stylebox_override("normal", Styles.panel(Color("17323b"), Color("d6b75e"), 22, 3)); heading.add_child(grade)
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 24); stack.add_child(body)
	var visual := SummaryVisual.new(); visual.custom_minimum_size = Vector2(500, 445); visual.configure(summary); body.add_child(visual)
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation", 15); body.add_child(right)
	var verdict := Styles.label(str(summary.get("verdict", "完成一局经营探索")), 22, Color("76d3b0")); verdict.name = "CareerVerdict"; verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; verdict.custom_minimum_size.y = 66; verdict.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; verdict.add_theme_stylebox_override("normal", Styles.panel(Color("0c2d34"), Color("4ea789"), 18, 2)); right.add_child(verdict)
	right.add_child(_metric_row([["最终净资产", int(summary.get("asset", 0)), "万"], ["峰值净资产", int(summary.get("peak_asset", 0)), "万"], ["累计经营净额", int(summary.get("total_net", 0)), "万"]]))
	right.add_child(_metric_row([["土地", int(summary.get("lands", 0)), "块"], ["企业", int(summary.get("businesses", 0)), "家"], ["人才", int(summary.get("talents", 0)), "人"]]))
	right.add_child(Styles.label("经营里程碑与同场位置", 23, Color("72c7d2")))
	var milestone_row := HFlowContainer.new(); milestone_row.add_theme_constant_override("h_separation", 10); milestone_row.add_theme_constant_override("v_separation", 10); right.add_child(milestone_row)
	for milestone: String in summary.get("milestones", []):
		var chip := Styles.label(milestone, 16, Color("e9d48d")); chip.add_theme_stylebox_override("normal", Styles.panel(Color("102f39"), Color("6b8790"), 14, 1)); milestone_row.add_child(chip)
	var ranking_texts: Array[String] = []
	var rank_index := 1
	for competitor: Dictionary in summary.get("rankings", []):
		if rank_index > 3: break
		ranking_texts.append("%d  %s  %d万%s" % [rank_index, str(competitor.get("name", "财团")), int(competitor.get("asset", 0)), "（你）" if bool(competitor.get("human", false)) else ""])
		rank_index += 1
	var ranking := Styles.label("同场资产榜｜%s" % "　".join(ranking_texts), 16, Color("c7d8db")); ranking.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; right.add_child(ranking)
	var best_text := "最佳经营轮次  第 %d 回合  %+d万" % [int(summary.get("best_round", 0)), int(summary.get("best_round_net", 0))]
	right.add_child(Styles.label(best_text, 20, Color("70d0ad")))
	var finish := Button.new(); finish.text = "确认总结"; finish.custom_minimum_size = Vector2(210, 58); Styles.apply_button(finish, true, Color("d6b75e"), 19); finish.pressed.connect(_finish.bind(summary)); stack.add_child(finish)


func _metric_row(specs: Array) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	for spec: Array in specs:
		var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel", Styles.panel(Color("0b2935"), Color("527f89"), 16, 1)); var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(box)
		var key := Styles.label(str(spec[0]), 15, Color("98b1b6")); key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(key)
		var value := Styles.label("%d%s" % [int(spec[1]), str(spec[2])], 25, Color("f1d57f")); value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(value)
		row.add_child(card)
	return row


func _finish(summary: Dictionary) -> void:
	liquidation_completed.emit(summary, true)
	queue_free()
