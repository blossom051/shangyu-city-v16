class_name EmployeeManagementDialog
extends Control

signal changed(result: Dictionary)

const Businesses = preload("res://scripts/BusinessSystem.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const Styles = preload("res://scripts/UIStyles.gd")
const PORTRAIT_ATLAS = preload("res://assets/ui/talents/talent_portrait_atlas.png")

var player_id: = ""
var business_id: = ""
var slot: = -1
var talent_id: = ""
var mode: = "slot"
var content: VBoxContainer
var message: Label
var dismiss_armed: = false
var roster_filter: = "all"
var modal_token: = 0
var embedded_in_parent_modal: = false


func _ready() -> void :
	name = "EmployeeManagementDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 420
	if not embedded_in_parent_modal:
		add_to_group("managed_modal_owner")
		modal_token = ModalManager.open_modal("employee_management", self, self)
		tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "employee_management_closed"))
	_build_shell()
	_refresh()


func open_for_slot(next_player_id: String, next_business_id: String, next_slot: int) -> void :
	player_id = next_player_id
	business_id = next_business_id
	slot = next_slot
	mode = "slot"


func open_for_talent(next_player_id: String, next_talent_id: String) -> void :
	player_id = next_player_id
	talent_id = next_talent_id
	mode = "talent"


func open_embedded_for_talent(next_player_id: String, next_talent_id: String) -> void :
	embedded_in_parent_modal = true
	open_for_talent(next_player_id, next_talent_id)


func open_roster(next_player_id: String) -> void :
	player_id = next_player_id
	mode = "roster"


func open_embedded_roster(next_player_id: String) -> void :
	embedded_in_parent_modal = true
	open_roster(next_player_id)


func open_tutorial(next_player_id: String, next_talent_id: String) -> void :
	player_id = next_player_id
	talent_id = next_talent_id
	mode = "tutorial"


func open_embedded_tutorial(next_player_id: String, next_talent_id: String) -> void :
	embedded_in_parent_modal = true
	open_tutorial(next_player_id, next_talent_id)


func _build_shell() -> void :
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.035, 0.055, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var viewport_size: = get_viewport_rect().size
	var panel_size: = Vector2(minf(860.0, viewport_size.x - 70.0), minf(700.0, viewport_size.y - 56.0))
	panel.position = - panel_size * 0.5
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", Styles.toy_panel())
	add_child(panel)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var header: = HBoxContainer.new()
	stack.add_child(header)
	var title: = Label.new()
	title.name = "Title"
	title.text = "员工管理中心"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Styles.TOY_INK)
	header.add_child(title)
	var close: = Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(110, 46)
	Styles.apply_toy_button(close, false, Styles.TOY_BLUE, 17)
	close.pressed.connect(queue_free)
	header.add_child(close)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", Styles.TOY_MUTED)
	stack.add_child(message)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)


func _refresh() -> void :
	if content == null:
		return
	for child in content.get_children():
		child.queue_free()
	dismiss_armed = false
	if mode == "slot":
		_build_slot_choices()
	elif mode == "roster":
		_build_roster_overview()
	elif mode == "tutorial":
		_build_tutorial_assignment()
	else:
		_build_talent_destinations()


func _build_roster_overview() -> void :
	var roster: = Talents.roster(player_id)
	var idle: = roster.filter( func(item: Dictionary) -> bool: return str(item.status) == "idle").size()
	var capacity: Dictionary = Talents.capacity_summary(player_id)
	var capacity_bonus: = int(capacity.limit) - Talents.ROSTER_LIMIT
	message.text = "编制  %d / %d　 　基础 %d%s　 　空闲 %d　 　在岗 %d" % [int(capacity.used), int(capacity.limit), Talents.ROSTER_LIMIT, " + 扩编 %d" % capacity_bonus if capacity_bonus > 0 else "", idle, roster.size() - idle]
	message.tooltip_text = "基础员工上限 12；使用人才扩编类卡牌后，上限会立即增加。"
	message.add_theme_font_size_override("font_size", 20)
	message.add_theme_color_override("font_color", Color("f0d278") if int(capacity.free) <= 1 else Color("79d8bd"))
	var filters: = HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	content.add_child(filters)
	for spec: Array in [["all", "全部"], ["idle", "空闲"], ["assigned", "已安排"]]:
		var filter_button: = Button.new()
		filter_button.text = str(spec[1])
		filter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Styles.apply_toy_button(filter_button, roster_filter == str(spec[0]), Color("d6ad54") if roster_filter == str(spec[0]) else Color("4d8ca7"), 16)
		filter_button.pressed.connect( func() -> void : roster_filter = str(spec[0]);_refresh())
		filters.add_child(filter_button)
	var visible_items: = roster.filter( func(item: Dictionary) -> bool: return roster_filter == "all" or str(item.status) == roster_filter)
	if visible_items.is_empty():
		var empty: = Label.new()
		empty.text = "当前筛选条件下没有员工"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Styles.TOY_MUTED)
		content.add_child(empty)
		return
	for item: Dictionary in visible_items:
		_add_employee_card(item, func() -> void :
			talent_id = str(item.id)
			mode = "talent_from_roster"
			_refresh())


func _build_tutorial_assignment() -> void :
	var talent: = GameConfig.by_id("talents", talent_id)
	message.text = "%s 已完成教学招募\n下一步：把员工安排到刚刚建成的教学企业，安排后技能才会生效。" % str(talent.get("name", "教学人才"))
	_add_action_button("教学企业  经营岗位 1｜当前：空闲岗位\n安排后预计净收益 +14 万", Color("5bc8d8"), func() -> void :
		_apply(TutorialDirector.route_action("talent_assign", {"talent_id": talent_id, "business_id": "tutorial_business", "slot": 0})))


func _build_slot_choices() -> void :
	var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
	message.text = "%s  员工位%d｜请选择具体员工。已安排人员可在此替换或撤回。" % [str(business.get("name", business_id)), slot + 1]
	var current_id: = str(business.get("employees", ["", ""])[slot])
	if not current_id.is_empty():
		_add_action_button("撤回当前员工  %s" % str(GameConfig.by_id("talents", current_id).get("name", current_id)), Color("d49a5b"), func() -> void : _apply(Businesses.unassign_talent(player_id, business_id, slot)))
	for item: Dictionary in Talents.roster(player_id):
		var selectable: = str(item.status) == "idle" or str(item.id) == current_id
		_add_employee_card(item, func() -> void : _choose_employee(str(item.id)), not selectable)


func _build_talent_destinations() -> void :
	var talent: = GameConfig.by_id("talents", talent_id)
	var roster_item: Dictionary = {}
	for item: Dictionary in Talents.roster(player_id):
		if str(item.id) == talent_id:
			roster_item = item
			break
	message.text = "选择去向"
	message.add_theme_font_size_override("font_size", 18)
	_add_employee_profile(talent, roster_item)
	if mode == "talent_from_roster":
		_add_action_button("← 返回员工总览", Color("4d8ca7"), func() -> void : mode = "roster";_refresh())
	if str(roster_item.get("status", "idle")) == "assigned":
		_add_action_button("撤回待岗", Color("d49a5b"), func() -> void : _apply(Businesses.unassign_talent(player_id, str(roster_item.assignment_id), int(roster_item.assignment_slot))))
	for owned_business_id: String in GameState.player(player_id).get("business_ids", []):
		var business: Dictionary = GameState.game_data.businesses.get(owned_business_id, {})
		if str(business.get("state", "")) != "operating":
			continue
		for target_slot in range(2):
			var occupant_id: = str(business.get("employees", ["", ""])[target_slot])
			var occupant_name: = "空闲岗位" if occupant_id.is_empty() else str(GameConfig.by_id("talents", occupant_id).get("name", occupant_id))
			_add_action_button("%s  员工位%d｜当前：%s" % [str(business.get("name", owned_business_id)), target_slot + 1, occupant_name], Color("5aa9d6"), func() -> void : _assign_talent_to(owned_business_id, target_slot))
	var cost: = Talents.dismissal_cost(talent_id)
	_add_action_button("开除员工｜补偿 %d 万  招聘加价 2 回合" % cost, Color("d8656b"), _request_dismiss)


func _choose_employee(next_talent_id: String) -> void :
	_apply(Businesses.replace_talent(player_id, business_id, next_talent_id, slot))


func _assign_talent_to(next_business_id: String, next_slot: int) -> void :
	var roster_item: Dictionary = {}
	for item: Dictionary in Talents.roster(player_id):
		if str(item.id) == talent_id:
			roster_item = item
			break
	if str(roster_item.get("status", "idle")) == "assigned":
		var withdrawal: = Businesses.unassign_talent(player_id, str(roster_item.assignment_id), int(roster_item.assignment_slot))
		if not bool(withdrawal.ok):
			_apply(withdrawal)
			return
	_apply(Businesses.replace_talent(player_id, next_business_id, talent_id, next_slot))


func _request_dismiss() -> void :
	if not dismiss_armed:
		dismiss_armed = true
		message.text = "开除会永久失去该员工，并支付离职补偿；未来 2 回合招聘每人加价 10 万。再次点击红色按钮确认。"
		return
	var result: = Talents.dismiss(player_id, talent_id)
	message.text = str(result.get("message", "操作完成"))
	changed.emit(result)
	if bool(result.get("ok", false)):
		queue_free()


func _apply(result: Dictionary) -> void :
	message.text = str(result.get("message", "操作完成"))
	message.add_theme_color_override("font_color", Color("3e9a72") if bool(result.get("ok", false)) else Color("c64f59"))
	changed.emit(result)
	if bool(result.get("ok", false)):
		if mode == "tutorial":
			queue_free()
		else:
			_refresh()


func _add_action_button(label: String, color: Color, action: Callable, disabled: = false) -> void :
	var button: = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 76)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = disabled
	Styles.apply_toy_button(button, false, color, 16)
	button.pressed.connect(action)
	content.add_child(button)


func _add_employee_card(item: Dictionary, action: Callable, disabled: = false) -> void :
	var button: = Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 112)
	button.clip_contents = true
	button.disabled = disabled
	button.tooltip_text = "%s\n%s\n%s" % [str(item.get("name", "员工")), str(item.get("effect_text", "")), str(item.get("status_text", "空闲"))]
	Styles.apply_toy_button(button, false, Color(str(item.get("quality_color", "4d8ca7"))), 16)
	button.pressed.connect(action)
	content.add_child(button)
	var row: = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	button.add_child(row)
	var portrait: = TextureRect.new()
	portrait.texture = _portrait_texture(str(item.get("id", "t01")), str(item.get("quality", "blue")))
	portrait.custom_minimum_size = Vector2(84, 84)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var info: = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label: = Label.new()
	name_label.text = "%s　 　%s" % [str(item.get("name", "员工")), str(item.get("quality_name", "人才"))]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(str(item.get("quality_color", "f0f3f4"))))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var skill_label: = Label.new()
	skill_label.text = "%s｜%s" % [str(item.get("role", "经营")), str(item.get("effect_text", ""))]
	skill_label.add_theme_font_size_override("font_size", 15)
	skill_label.add_theme_color_override("font_color", Color("dce9eb"))
	skill_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(skill_label)
	var status_label: = Label.new()
	status_label.text = str(item.get("status_text", "空闲  可安排"))
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("6fd6ad") if str(item.get("status", "idle")) == "idle" else Color("efc967"))
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(status_label)
	var arrow: = Label.new()
	arrow.text = "›"
	arrow.custom_minimum_size = Vector2(36, 0)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 34)
	arrow.add_theme_color_override("font_color", Color("d7bd70"))
	row.add_child(arrow)


func _add_employee_profile(talent: Dictionary, roster_item: Dictionary) -> void :
	var profile: = PanelContainer.new()
	profile.custom_minimum_size = Vector2(0, 132)
	profile.add_theme_stylebox_override("panel", Styles.panel(Color(0.025, 0.09, 0.13, 0.96), Color(str(roster_item.get("quality_color", "5aa9d6"))), 16, 5))
	content.add_child(profile)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	profile.add_child(row)
	var portrait: = TextureRect.new()
	portrait.texture = _portrait_texture(str(talent.get("id", "t01")), str(talent.get("quality", "blue")))
	portrait.custom_minimum_size = Vector2(104, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var info: = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var name_label: = Label.new()
	name_label.text = "%s　%s" % [str(talent.get("name", "员工")), _quality_name(str(talent.get("quality", "blue")))]
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(str(roster_item.get("quality_color", "f3ead1"))))
	info.add_child(name_label)
	var role_label: = Label.new()
	role_label.text = "%s｜%s" % [str(talent.get("role", "经营")), str(talent.get("effect", ""))]
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_label.add_theme_font_size_override("font_size", 16)
	role_label.add_theme_color_override("font_color", Color("dbe8ea"))
	info.add_child(role_label)
	var status_label: = Label.new()
	status_label.text = "当前：%s" % str(roster_item.get("status_text", "空闲"))
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("6fd6ad"))
	info.add_child(status_label)


func _portrait_texture(talent_id_value: String, quality: String) -> Texture2D:
	var external: = VisualAssets.get_talent_portrait(quality, talent_id_value)
	if external:
		return external
	var index: = clampi(int(talent_id_value.trim_prefix("t")) - 1, 0, 19)
	var cell_width: = float(PORTRAIT_ATLAS.get_width()) / 5.0
	var cell_height: = float(PORTRAIT_ATLAS.get_height()) / 4.0
	var atlas: = AtlasTexture.new()
	atlas.atlas = PORTRAIT_ATLAS
	atlas.region = Rect2(float(index % 5) * cell_width, float(index / 5) * cell_height, cell_width, cell_height)
	return atlas


func _quality_name(quality: String) -> String:
	return {"blue": "蓝色", "platinum": "铂金", "gold": "金色", "red": "红色"}.get(quality, quality)
