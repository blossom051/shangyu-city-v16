class_name WestBankInstitutionDialog
extends CanvasLayer

const Styles = preload("res://scripts/UIStyles.gd")
const Institutions = preload("res://scripts/WestBankInstitutionSystem.gd")
const INSTITUTION_SCENES = preload("res://assets/ui/west_bank/institution_scenes_atlas_v154.png")

var landmark_id := ""
var player_id := ""
var options_host: BoxContainer
var receipt: Label
var confirm_button: Button
var pending_option_id := ""


func open(value: String, active_player_id: String) -> void:
	landmark_id = value
	player_id = active_player_id


func _ready() -> void:
	layer = 2100
	_build()


func _build() -> void:
	var profile := Institutions.profile(landmark_id)
	var accent := Color(str(profile.get("accent", "67d8e5")))
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color = Color(0.002, 0.012, 0.024, 0.9); shade.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(shade)
	var panel := PanelContainer.new(); panel.name = "InstitutionConsole"; panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-610, -390); panel.size = Vector2(1220, 780); panel.add_theme_stylebox_override("panel", Styles.panel(Color("061824fa"), accent, 30, 0)); shade.add_child(panel)
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 0); panel.add_child(root)
	var hero := TextureRect.new(); hero.custom_minimum_size.y = 230; hero.texture = _scene_texture(profile); hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; hero.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hero)
	var hero_veil := ColorRect.new(); hero_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hero_veil.color = Color(0.0, 0.025, 0.045, 0.48); hero_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE; hero.add_child(hero_veil)
	var hero_margin := MarginContainer.new(); hero_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hero_margin.add_theme_constant_override("margin_left", 34); hero_margin.add_theme_constant_override("margin_right", 30); hero_margin.add_theme_constant_override("margin_top", 24); hero_margin.add_theme_constant_override("margin_bottom", 22); hero.add_child(hero_margin)
	var header := HBoxContainer.new(); hero_margin.add_child(header)
	var emblem := Styles.label(str(profile.get("icon", "◆")), 62, accent); emblem.custom_minimum_size.x = 90; emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; header.add_child(emblem)
	var title_box := VBoxContainer.new(); title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_box.add_theme_constant_override("separation", 5); header.add_child(title_box)
	title_box.add_child(Styles.label(str(profile.get("name", "西岸机构")), 42, Color("fff0bd")))
	title_box.add_child(Styles.label(str(profile.get("role", "专业服务")), 21, accent))
	var brief := Styles.label(str(profile.get("brief", "")), 19, Color("e0e9e8")); brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title_box.add_child(brief)
	var close := Button.new(); close.text = "返回城市"; close.custom_minimum_size = Vector2(155, 54); Styles.apply_toy_button(close, false, Styles.TOY_BLUE, 17); close.pressed.connect(queue_free); header.add_child(close)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 28); margin.add_theme_constant_override("margin_right", 28); margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_bottom", 22); root.add_child(margin)
	var lower := VBoxContainer.new(); lower.add_theme_constant_override("separation", 14); margin.add_child(lower)
	var command_deck := HBoxContainer.new(); command_deck.custom_minimum_size.y = 355; command_deck.add_theme_constant_override("separation", 18); lower.add_child(command_deck)
	command_deck.add_child(_context_board(profile, accent))
	options_host = _make_options_host(str(profile.get("layout", "macro"))); options_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL; options_host.size_flags_vertical = Control.SIZE_EXPAND_FILL; options_host.add_theme_constant_override("separation", 12); command_deck.add_child(options_host)
	_refresh_options(profile, accent)
	var action_bar := HBoxContainer.new(); action_bar.add_theme_constant_override("separation", 12); lower.add_child(action_bar)
	receipt = Styles.label("先查看方案，再点击确认执行；成本、风险与冷却都会进入真实账本。", 18, Color("d8c27a")); receipt.name = "InstitutionReceipt"; receipt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; receipt.custom_minimum_size.y = 72; receipt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; receipt.add_theme_stylebox_override("normal", Styles.panel(Color("0a2b36"), Color("8d7846"), 16, 12)); action_bar.add_child(receipt)
	confirm_button = Button.new(); confirm_button.name = "InstitutionConfirm"; confirm_button.text = "确认执行"; confirm_button.custom_minimum_size = Vector2(190, 72); confirm_button.visible = false; Styles.apply_toy_button(confirm_button, true, accent, 18); confirm_button.pressed.connect(_confirm_selected); action_bar.add_child(confirm_button)


func _scene_texture(profile: Dictionary) -> Texture2D:
	var coords: Array = profile.get("scene_region", [0, 0, 836, 470])
	var atlas := AtlasTexture.new(); atlas.atlas = INSTITUTION_SCENES; atlas.region = Rect2(float(coords[0]), float(coords[1]), float(coords[2]), float(coords[3])); return atlas


func _make_options_host(layout: String) -> BoxContainer:
	if layout in ["club", "liquidity"]:
		return HBoxContainer.new()
	return VBoxContainer.new()


func _context_board(profile: Dictionary, accent: Color) -> Control:
	var panel := PanelContainer.new(); panel.custom_minimum_size.x = 285; panel.add_theme_stylebox_override("panel", Styles.panel(Color("082733ed"), accent.darkened(0.28), 18, 18))
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 12); panel.add_child(box)
	box.add_child(Styles.label("实时决策席", 22, Color("edf3f2")))
	var metrics := _context_metrics(str(profile.get("layout", "macro")))
	for metric: Array in metrics:
		var item := VBoxContainer.new(); item.add_theme_constant_override("separation", 2); box.add_child(item)
		item.add_child(Styles.label(str(metric[0]), 18, Color("a9bdc1")))
		item.add_child(Styles.label(str(metric[1]), 28, metric[2] as Color))
	var note := Styles.label("本机构方案独立冷却，不占用城市建设次数。", 18, Color("bed0d3")); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(note)
	return panel


func _context_metrics(layout: String) -> Array:
	var player := GameState.player(player_id)
	var cycle := EndlessOperationsSystem.current_cycle()
	var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
	match layout:
		"roadshow":
			return [["资本阶段", "已挂牌" if str(record.get("status", "")) == "listed" else "上市筹备", Color("8bb8ff")], ["市场信心", "%d / 100" % int(record.get("market_confidence", 0)), Color("68d2b0")], ["路演加成", "+%d%%" % roundi(float(player.get("ipo_roadshow_bonus", 0.0)) * 100.0), Color("e3bf67")]]
		"club":
			var phase := str(cycle.get("phase", "recovery")); var odds := 72 if phase == "boom" else (58 if phase == "recovery" else (43 if phase == "overheat" else 36))
			return [["当前周期", "%s期" % str(cycle.get("name", "常态")), Color("b69af1")], ["进取命中率", "%d%%" % odds, Color("e3bf67")], ["本组风险", "%d / 100" % int(player.get("risk", 0)), Color("e87982")]]
		"liquidity":
			return [["可用现金", Styles.money(int(player.get("cash", 0))), Color("e8c56b")], ["本组风险", "%d / 100" % int(player.get("risk", 0)), Color("e87982")], ["安全边际", "%d%%" % maxi(0, 100 - int(player.get("risk", 0))), Color("68d2b0")]]
		_:
			return [["当前周期", "%s期" % str(cycle.get("name", "常态")), Color("67d8e5")], ["距周期切换", "%d 回合" % maxi(0, int(cycle.get("ends_round", 0)) - int(GameState.game_data.get("round", 0))), Color("e3bf67")], ["本组风险", "%d / 100" % int(player.get("risk", 0)), Color("e87982")]]


func _option_row(option: Dictionary, accent: Color, compact: bool = false) -> Control:
	var button := Button.new(); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.size_flags_vertical = Control.SIZE_EXPAND_FILL; button.custom_minimum_size = Vector2(0, 122); button.text = ""; button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Styles.apply_toy_button(button, false, accent, 18)
	var body := VBoxContainer.new(); body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.offset_left = 18; body.offset_right = -18; body.offset_top = 14; body.offset_bottom = -14; body.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_theme_constant_override("separation", 7); button.add_child(body)
	var icon_map := {"macro_brief":"◉", "policy_hedge":"⌁", "institution_roadshow":"◈", "investor_day":"◎", "wealth_defensive":"◇", "wealth_growth":"▲", "wealth_salon":"✦", "liquidity_facility":"↯", "debt_buffer":"⬡"}
	var heading := HBoxContainer.new(); body.add_child(heading)
	var emblem := Styles.label(str(icon_map.get(str(option.get("id", "")), "◆")), 30, accent); emblem.custom_minimum_size.x = 44; heading.add_child(emblem)
	var option_title := Styles.label(str(option.get("name", "机构服务")), 27, Color("fff7dc")); option_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; option_title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if compact else TextServer.AUTOWRAP_OFF; option_title.custom_minimum_size.y = 66 if compact else 0; heading.add_child(option_title)
	var remaining := Institutions.cooldown_left(player_id, landmark_id, option)
	var status := "冷却 %d 回合" % remaining if remaining > 0 else ("费用 %d万" % int(option.get("cost", 0)) if int(option.get("cost", 0)) > 0 else "可用")
	var badge := Styles.label(status, 19, Color("ff9189") if remaining > 0 else Color("ffe18a")); badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if compact:
		badge.custom_minimum_size.y = 30
		body.add_child(badge)
	else:
		heading.add_child(badge)
	var effect := Styles.label(str(option.get("effect", "")), 20, Color("d5e1e3")); effect.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY; effect.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(effect)
	body.add_child(Styles.label("点击查看完整结果  →", 18, accent.lightened(0.12)))
	button.disabled = remaining > 0
	button.pressed.connect(_preview.bind(option))
	return button


func _refresh_options(profile: Dictionary, accent: Color) -> void:
	for child in options_host.get_children(): child.queue_free()
	var compact := str(profile.get("layout", "macro")) in ["club", "liquidity"]
	for option: Dictionary in profile.get("options", []): options_host.add_child(_option_row(option, accent, compact))


func _preview(option: Dictionary) -> void:
	pending_option_id = str(option.get("id", ""))
	receipt.text = "待确认｜%s｜%s｜冷却 %d 回合" % [str(option.get("name", "机构服务")), "费用 %d 万" % int(option.get("cost", 0)) if int(option.get("cost", 0)) > 0 else "无前置费用", int(option.get("cooldown", 0))]
	receipt.add_theme_color_override("font_color", Color("ffe18a"))
	confirm_button.visible = true


func _confirm_selected() -> void:
	if pending_option_id.is_empty():
		return
	var result := Institutions.execute(player_id, landmark_id, pending_option_id)
	receipt.text = ("委托完成｜" if bool(result.get("ok", false)) else "暂未执行｜") + str(result.get("message", ""))
	receipt.add_theme_color_override("font_color", Color("70d3aa") if bool(result.get("ok", false)) else Color("ef827d"))
	pending_option_id = ""
	confirm_button.visible = false
	var profile := Institutions.profile(landmark_id)
	_refresh_options(profile, Color(str(profile.get("accent", "67d8e5"))))
