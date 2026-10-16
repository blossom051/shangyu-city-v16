extends Control

const UIStyles = preload("res://scripts/UIStyles.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const TalentCard = preload("res://scenes/TalentCardView.tscn")
const TalentRedGlow = preload("res://scripts/TalentRedGlow.gd")
const ArcaneFX = preload("res://scripts/CapitalArcaneFX.gd")
const EmployeeDialog = preload("res://scripts/EmployeeManagementDialog.gd")
const SummonStage = preload("res://scripts/TalentSummonStage.gd")
const PORTRAIT_ATLAS = preload("res://assets/ui/talents/talent_portrait_atlas.png")

var offered_red_ids: Array = []
var red_showcase_queue: Array[Dictionary] = []
var red_showcase_active: = false
var modal_token: = 0


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	modal_token = ModalManager.open_modal("talent_draw", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "talent_scene_exit"))
	$Layout / Main.move_child($Layout / Main / Rail, 0)
	$Layout / Header / Back.text = "返回城市"
	var draw_cost: Dictionary = GameConfig.dict_value("balance").get("talent_draw_cost", {"single": 60, "five": 270})
	$Layout / Main / Rail / Controls / Single.text = "单抽  %d 万" % int(draw_cost.single)
	$Layout / Main / Rail / Controls / Five.text = "五连抽  %d 万" % int(draw_cost.five)
	$Layout / Main / Rail / Controls / RedExchange.text = "红色人才 3 选 1"
	$Layout / Main / Primary / CardsScroll / Cards.add_theme_constant_override("separation", 12)
	$Layout / Header / Back.pressed.connect(_return_to_city)
	$Layout / Main / Rail / Controls / Single.pressed.connect( func() -> void : _draw_talents(1))
	$Layout / Main / Rail / Controls / Five.pressed.connect( func() -> void : _draw_talents(5))
	$Layout / Main / Rail / Controls / RedExchange.pressed.connect(_show_red_choices)
	$Layout / Main / Primary / BatchActions / RecruitAll.pressed.connect(_resolve_all.bind(true))
	$Layout / Main / Primary / BatchActions / ConvertAll.pressed.connect(_resolve_all.bind(false))
	_style()
	_refresh_header()
	_restore_pending_or_lobby()
	if TutorialDirector.active and TutorialDirector.current_step_id() == "assign_talent":
		$Layout / Message.text = "教学演练：点击“单抽”，翻开候选人后选择招募；本次不扣正式现金。"
		$Layout / Main / Rail / Controls / Five.disabled = true
		$Layout / Main / Rail / Controls / RedExchange.disabled = true


func _return_to_city() -> void :
	if TutorialDirector.active:
		TutorialDirector.return_to_city_from_auxiliary("talent_market")
	GameFlow.go("city")


func _draw_talents(count: int) -> void :
	var active: = GameState.active_player()
	var result: = Talents.draw(str(active.id), count)
	$Layout / Message.text = str(result.get("message", "人才抽取未完成"))
	if not bool(result.ok):
		_show_draw_failure(result, count)
		_refresh_header()
		_refresh_batch_actions()
		return
	_clear($Layout / Main / Primary / CardsScroll / Cards)
	AudioManager.talent_summon()
	await _play_summon_sequence(count, Color("62c6e8"))
	_play_stage_arcane(Color("62c6e8"), 1.14 if count == 5 else 0.84)
	AudioManager.talent_flip()
	$Layout / Message.text = "人才档案舱已启动  正在核验 %d 份候选人档案" % count
	var reveal_index: = 0
	for talent: Dictionary in result.cards:
		var view: = TalentCard.instantiate()
		view.setup(talent)
		view.resolved.connect(_resolve)
		view.showcase_requested.connect(_queue_red_showcase)
		$Layout / Main / Primary / CardsScroll / Cards.add_child(view)
		view.reveal_with_delay((0.04 if GameSettings.reduce_motion else 0.52) + float(reveal_index) * (0.04 if GameSettings.reduce_motion else 0.16))
		reveal_index += 1
	_refresh_header()
	_refresh_batch_actions()


func _show_draw_failure(result: Dictionary, count: int) -> void :
	var title: = "无法继续抽取"
	var body: = str(result.get("message", "请稍后再试"))
	if str(result.get("code", "")) == "insufficient_funds":
		title = "资金不足"
		body = "当前现金：%d 万\n本次需要：%d 万\n还差：%d 万" % [int(result.get("cash", 0)), int(result.get("cost", 0)), int(result.get("shortfall", 0))]
	elif str(result.get("code", "")) == "pending":
		title = "尚有待处理人才"
		body = "请先处理本次抽到的人才，再继续抽取。"
	GlobalFeedbackOverlay.show_notice(title, body)
	var button: = $Layout / Main / Rail / Controls / Single if count == 1 else $Layout / Main / Rail / Controls / Five
	var original_scale: Vector2 = button.scale
	var tween: = button.create_tween()
	tween.tween_property(button, "scale", original_scale * 0.96, 0.06)
	tween.tween_property(button, "scale", original_scale, 0.1)


func _resolve(talent_id: String, keep: bool, source_view: Control) -> void :
	var active: = GameState.active_player()
	var result: = Talents.resolve(str(active.id), talent_id, keep)
	$Layout / Message.text = str(result.message)
	if is_instance_valid(source_view) and source_view.has_method("apply_resolution_result"):
		source_view.call("apply_resolution_result", result, keep)
	if str(result.get("code", "")) == "capacity_full":
		_open_employee_roster()
	if bool(result.get("ok", false)) and bool(result.get("requires_assignment", false)):
		_open_tutorial_employee_assignment(talent_id)
	_refresh_header()
	_refresh_batch_actions()


func _resolve_all(keep: bool) -> void :
	var active: = GameState.active_player()
	var result: = Talents.resolve_all(str(active.id), keep)
	$Layout / Message.text = str(result.get("message", "批量处理完成"))
	if bool(result.get("ok", false)):
		_clear($Layout / Main / Primary / CardsScroll / Cards)
		_show_lobby()
		AudioManager.success()
	_refresh_header()
	_refresh_batch_actions()


func _show_red_choices() -> void :
	var active: = GameState.active_player()
	var choices: = Talents.red_choices(str(active.id))
	if choices.is_empty():
		$Layout / Message.text = "红色积分未满 100"
		return
	_clear($Layout / Main / Primary / CardsScroll / Cards)
	await _play_summon_sequence(3, Color("e65d68"))
	_play_stage_arcane(Color("e65d68"), 1.28)
	offered_red_ids = choices.map( func(t: Dictionary) -> String: return str(t.id))
	var reveal_index: = 0
	for talent: Dictionary in choices:
		var view: = TalentCard.instantiate()
		view.setup_choice(talent)
		view.choice_selected.connect(_choose_red.bind(view))
		$Layout / Main / Primary / CardsScroll / Cards.add_child(view)
		view.reveal_with_delay((0.04 if GameSettings.reduce_motion else 0.48) + float(reveal_index) * (0.04 if GameSettings.reduce_motion else 0.18))
		reveal_index += 1
	AudioManager.red_talent()


func _choose_red(talent_id: String, source_view: Control) -> void :
	var active: = GameState.active_player()
	if Talents.choose_red(str(active.id), talent_id, offered_red_ids):
		AudioManager.red_talent()
		$Layout / Message.text = "已选择红色人才：%s" % GameConfig.by_id("talents", talent_id).name
		await play_red_showcase(source_view, "积分兑换  红色人才")
		_clear($Layout / Main / Primary / CardsScroll / Cards)
		_refresh_header()


func _queue_red_showcase(source_view: Control) -> void :
	red_showcase_queue.append({"view": source_view, "label": "稀有降临  红色人才"})
	if not red_showcase_active:
		call_deferred("_drain_red_showcases")


func _drain_red_showcases() -> void :
	if red_showcase_active:
		return
	red_showcase_active = true
	while not red_showcase_queue.is_empty():
		var item: Dictionary = red_showcase_queue.pop_front()
		var source_view: = item.get("view") as Control
		if is_instance_valid(source_view):
			await play_red_showcase(source_view, str(item.get("label", "红色人才")))
	red_showcase_active = false


func play_red_showcase(source_view: Control, caption: = "稀有降临  红色人才") -> void :
	if not is_instance_valid(source_view) or get_tree() == null:
		return
	var stage: = Control.new()
	stage.name = "RedTalentShowcase"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.z_index = 500
	add_child(stage)
	var veil: = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.025, 0.04, 0.72)
	stage.add_child(veil)
	var glow: = Control.new()
	glow.set_script(TalentRedGlow)
	glow.size = Vector2(560, 560)
	glow.position = get_viewport_rect().size * 0.5 - glow.size * 0.5
	glow.call("setup", Color("ef5d5d"))
	stage.add_child(glow)
	var showcase: Control = TalentCard.instantiate()
	showcase.setup((source_view.get("talent") as Dictionary).duplicate(true))
	showcase.show_front_immediately()
	showcase.get_node("Body/Actions").visible = false
	showcase.size = Vector2(236, 348)
	showcase.custom_minimum_size = showcase.size
	showcase.pivot_offset = showcase.size * 0.5
	showcase.position = source_view.get_global_rect().position
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(showcase)
	source_view.modulate.a = 0.0
	var target: = get_viewport_rect().size * 0.5 - showcase.size * 0.5
	var flight_time: = 0.08 if GameSettings.reduce_motion else 0.28
	var flight: = create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	flight.tween_property(showcase, "position", target, flight_time)
	flight.tween_property(showcase, "scale", Vector2(1.12, 1.12), flight_time)
	flight.tween_property(glow, "modulate:a", 1.0, flight_time)
	await flight.finished
	showcase.position = target
	showcase.scale = Vector2(1.12, 1.12)
	var title: = Label.new()
	title.position = Vector2(target.x - 180, target.y + showcase.size.y * 1.14 + 24)
	title.size = Vector2(showcase.size.x + 360, 54)
	title.text = caption
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffe49a"))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.01, 0.02, 0.92))
	title.add_theme_constant_override("outline_size", 5)
	stage.add_child(title)
	await _owned_delay(0.18 if GameSettings.reduce_motion else 0.78)
	var finish: = create_tween().set_parallel(true)
	finish.tween_property(showcase, "modulate:a", 0.0, 0.22)
	finish.tween_property(showcase, "scale", Vector2(1.22, 1.22), 0.22)
	finish.tween_property(glow, "modulate:a", 0.0, 0.26)
	finish.tween_property(title, "modulate:a", 0.0, 0.22)
	await finish.finished
	if is_instance_valid(source_view):
		source_view.modulate.a = 1.0
	stage.queue_free()


func _owned_delay(seconds: float) -> void :
	var timer: = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.001, seconds)
	add_child(timer)
	timer.start()
	await timer.timeout
	if is_instance_valid(timer):
		timer.queue_free()


func _refresh_header() -> void :
	var active: = GameState.active_player()
	if active.is_empty():
		return
	$Layout / Header / Title.text = "资本星辉殿堂  %s" % active.name
	$Layout / Header / Cash.text = "可用现金  %d 万    红色猎聘进度  %d / 100" % [active.cash, active.red_points]
	$Layout / Main / Rail / Controls / RedExchange.disabled = int(active.red_points) < 100
	$Layout / Main / Rail / Controls / RedProgress.value = mini(100, int(active.red_points))
	$Layout / Main / Rail / Controls / RedProgress.tooltip_text = "红色积分 %d；兑换只扣 100，溢出积分保留" % int(active.red_points)
	var counts: = {"blue": 0, "platinum": 0, "gold": 0, "red": 0}
	for talent_id: String in active.talent_ids:
		var talent: = GameConfig.by_id("talents", talent_id)
		var quality: = str(talent.get("quality", "blue"))
		counts[quality] = int(counts.get(quality, 0)) + 1
	var live_limit: = Talents.roster_limit(str(active.id))
	var capacity_bonus: = live_limit - Talents.ROSTER_LIMIT
	$Layout / Main / Rail / Account / Collection.text = "员工编制  %d / %d  基础 %d%s\n蓝 %d  铂金 %d  金 %d  红 %d" % [active.talent_ids.size(), live_limit, Talents.ROSTER_LIMIT, "  +扩编 %d" % capacity_bonus if capacity_bonus > 0 else "", counts.blue, counts.platinum, counts.gold, counts.red]
	var recent: Array[String] = []
	for entry: Dictionary in GameState.game_data.log:
		if str(entry.get("player_id", "")) == str(active.id) and str(entry.get("kind", "")) == "talent_resolve":
			var entry_data: Dictionary = entry.get("data", {})
			var talent: = GameConfig.by_id("talents", str(entry_data.get("talent_id", "")))
			recent.append(str(talent.get("name", "人才")))
	$Layout / Main / Rail / Account / History.text = "最近抽取\n%s" % ("暂无记录" if recent.is_empty() else "  ".join(recent.slice(maxi(0, recent.size() - 4))))
	_refresh_roster(str(active.id))
	_refresh_batch_actions()


func _refresh_batch_actions() -> void :
	var active: = GameState.active_player()
	if active.is_empty():
		return
	var pending: Array = active.get("pending_talents", [])
	var convert_points: = 0
	var balance: = GameConfig.dict_value("balance")
	for talent_id: String in pending:
		var quality: = str(GameConfig.by_id("talents", talent_id).get("quality", "blue"))
		convert_points += int(balance.red_points_convert.get(quality, 0))
	var free_slots: = int(Talents.capacity_summary(str(active.id)).free)
	$Layout / Main / Primary / BatchActions / BatchHint.text = "员工库 %d/%d  空位 %d  待处理 %d" % [active.talent_ids.size(), Talents.roster_limit(str(active.id)), free_slots, pending.size()]
	var missing_slots: = maxi(0, pending.size() - free_slots)
	$Layout / Main / Primary / BatchActions / RecruitAll.text = "需先释放 %d 个名额" % missing_slots if missing_slots > 0 else "一键招募 %d 人" % pending.size()
	$Layout / Main / Primary / BatchActions / ConvertAll.text = "一键转化  +%d 分" % convert_points
	$Layout / Main / Primary / BatchActions / RecruitAll.disabled = pending.is_empty() or missing_slots > 0
	$Layout / Main / Primary / BatchActions / RecruitAll.tooltip_text = "打开员工管理并辞退员工，释放编制后再招募" if missing_slots > 0 else "招募全部待处理候选人"
	$Layout / Main / Primary / BatchActions / ConvertAll.disabled = pending.is_empty()


func _refresh_roster(player_id: String) -> void :
	_clear($Layout / Main / Primary / Roster / Scroll / Rows)
	var roster: = Talents.roster(player_id)
	$Layout / Main / Primary / Roster.visible = true
	$Layout / Main / Primary / Roster / Scroll.visible = false
	var idle: = roster.filter( func(item: Dictionary) -> bool: return str(item.status) == "idle").size()
	$Layout / Main / Primary / Roster / Summary.text = "员工团队  %d 位  空闲 %d  已安排 %d" % [roster.size(), idle, roster.size() - idle]
	var manage: = $Layout / Main / Primary / Roster.get_node_or_null("ManageEmployees") as Button
	if manage == null:
		manage = Button.new()
		manage.name = "ManageEmployees"
		manage.text = "员工管理  查看详情 / 安排 / 调岗 / 辞退"
		manage.custom_minimum_size = Vector2(0, 58)
		UIStyles.apply_toy_button(manage, true, Color("d6ad54"), 17)
		manage.pressed.connect(_open_employee_roster)
		$Layout / Main / Primary / Roster.add_child(manage)


func _open_employee_management(talent_id: String) -> void :
	if has_node("EmployeeManagementDialog"):
		return
	var active: = GameState.active_player()
	var dialog: = EmployeeDialog.new()
	dialog.open_embedded_for_talent(str(active.id), talent_id)
	dialog.changed.connect( func(result: Dictionary) -> void :
		$Layout / Message.text = str(result.get("message", "员工状态已更新"))
		_refresh_header()
	)
	add_child(dialog)


func _open_employee_roster() -> void :
	if has_node("EmployeeManagementDialog"):
		return
	var dialog: = EmployeeDialog.new()
	dialog.open_embedded_roster(str(GameState.active_player().get("id", "")))
	dialog.changed.connect( func(result: Dictionary) -> void :
		$Layout / Message.text = str(result.get("message", "员工状态已更新"))
		_refresh_header())
	add_child(dialog)


func _open_tutorial_employee_assignment(talent_id: String) -> void :
	if has_node("EmployeeManagementDialog"):
		return
	var dialog: = EmployeeDialog.new()
	dialog.open_embedded_tutorial(str(GameState.active_player().get("id", "")), talent_id)
	dialog.changed.connect( func(result: Dictionary) -> void :
		$Layout / Message.text = str(result.get("message", "教学人才已安排")))
	add_child(dialog)


func _show_lobby() -> void :
	_clear($Layout / Main / Primary / CardsScroll / Cards)
	var sample_talents: Array = GameConfig.list("talents")
	var steps: = [["城市运营总监", "蓝色人才池", "稳定经营与基础收益，适合快速补足企业岗位", Color("58a8c6")], ["资本战略合伙人", "金色 / 铂金人才池", "强化关键企业，人才贡献会单独进入每轮战报", Color("d0a94f")], ["首席增长官", "红色传奇猎聘", "进度满 100 后展示三张真实人才卡，由你选择一位", Color("d95a5f")]]
	for index in range(steps.size()):
		var step: Array = steps[index]
		var panel: = PanelContainer.new()
		panel.custom_minimum_size = Vector2(292, 324)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UIStyles.toy_card(step[3], false))
		var content: = VBoxContainer.new()
		content.add_theme_constant_override("separation", 7)
		panel.add_child(content)
		var portrait: = TextureRect.new()
		portrait.name = "ExecutivePreview"
		portrait.texture = _portrait_texture(str(sample_talents[index % sample_talents.size()].get("id", "t01"))) if not sample_talents.is_empty() else PORTRAIT_ATLAS
		portrait.custom_minimum_size = Vector2(0, 174)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(portrait)
		var title: = Label.new()
		title.text = str(step[0])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 21)
		content.add_child(title)
		var role: = Label.new();role.text = str(step[1]);role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;role.add_theme_font_size_override("font_size", 15);role.add_theme_color_override("font_color", step[3]);content.add_child(role)
		var detail: = Label.new()
		detail.text = str(step[2])
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 14)
		content.add_child(detail)
		$Layout / Main / Primary / CardsScroll / Cards.add_child(panel)


func _portrait_texture(talent_id: String) -> Texture2D:
	var index: = clampi(int(talent_id.trim_prefix("t")) - 1, 0, 19)
	var cell_width: = float(PORTRAIT_ATLAS.get_width()) / 5.0
	var cell_height: = float(PORTRAIT_ATLAS.get_height()) / 4.0
	var atlas: = AtlasTexture.new()
	atlas.atlas = PORTRAIT_ATLAS
	atlas.region = Rect2(float(index % 5) * cell_width, float(index / 5) * cell_height, cell_width, cell_height)
	return atlas


func _restore_pending_or_lobby() -> void :
	var active: = GameState.active_player()
	var pending: Array = active.get("pending_talents", [])
	if pending.is_empty():
		_show_lobby()
		return
	_clear($Layout / Main / Primary / CardsScroll / Cards)
	$Layout / Message.text = "上次抽取尚未结算：请完成保留或转化，结果不会丢失。"
	for talent_id: Variant in pending.duplicate():
		var talent: = GameConfig.by_id("talents", str(talent_id))
		if talent.is_empty():
			continue
		var view: = TalentCard.instantiate()
		view.setup(talent)
		view.resolved.connect(_resolve)
		view.showcase_requested.connect(_queue_red_showcase)
		$Layout / Main / Primary / CardsScroll / Cards.add_child(view)
		view.show_front_immediately()


func _style() -> void :
	for button in [$Layout / Header / Back, $Layout / Main / Rail / Controls / Single, $Layout / Main / Rail / Controls / Five, $Layout / Main / Rail / Controls / RedExchange, $Layout / Main / Primary / BatchActions / RecruitAll, $Layout / Main / Primary / BatchActions / ConvertAll]:
		UIStyles.apply_toy_button(button, false, UIStyles.TOY_BLUE, 18)
		button.mouse_entered.connect(AudioManager.hover)
	for label in [$Layout / Header / Title, $Layout / Header / Cash, $Layout / Message, $Layout / Main / Rail / Account / Collection, $Layout / Main / Rail / Account / History, $Layout / Main / Primary / Roster / Summary]:
		label.add_theme_color_override("font_color", Color("e8f0f1"))
	$Layout / Header / Title.add_theme_color_override("font_color", Color("f1d681"))
	$Layout / Message.add_theme_stylebox_override("normal", UIStyles.panel(Color(0.025, 0.09, 0.14, 0.88), Color(0.36, 0.67, 0.78, 0.72), 14, 6))
	$Layout / Main / Rail / Account / Collection.add_theme_stylebox_override("normal", UIStyles.panel(Color(0.02, 0.075, 0.115, 0.9), Color(0.34, 0.6, 0.7, 0.65), 14, 8))
	$Layout / Main / Rail / Account / History.add_theme_stylebox_override("normal", UIStyles.panel(Color(0.02, 0.065, 0.1, 0.86), Color(0.73, 0.58, 0.26, 0.62), 14, 8))
	var progress_bg: = StyleBoxFlat.new();progress_bg.bg_color = Color("0a2332");progress_bg.set_corner_radius_all(12)
	var progress_fill: = StyleBoxFlat.new();progress_fill.bg_color = Color("d64f5c");progress_fill.set_corner_radius_all(12);progress_fill.shadow_color = Color(0.85, 0.22, 0.3, 0.38);progress_fill.shadow_size = 8
	$Layout / Main / Rail / Controls / RedProgress.add_theme_stylebox_override("background", progress_bg)
	$Layout / Main / Rail / Controls / RedProgress.add_theme_stylebox_override("fill", progress_fill)
	$Layout / Message.text = "选择召募方式，档案将在中央星辉台依次翻开；保留后可安排到已建成企业。"
	$Layout / Main / Rail / Controls.alignment = BoxContainer.ALIGNMENT_CENTER
	for button in [$Layout / Main / Rail / Controls / Single, $Layout / Main / Rail / Controls / Five, $Layout / Main / Rail / Controls / RedExchange]:
		button.custom_minimum_size = Vector2(252, 80)
	var draw_cost: Dictionary = GameConfig.dict_value("balance").get("talent_draw_cost", {"single": 60, "five": 270})
	$Layout / Main / Rail / Controls / Single.call("set_portal_label", "单次召募", "%d 万  开启一份契约" % int(draw_cost.single), Color("59c9ee"), 1)
	$Layout / Main / Rail / Controls / Five.call("set_portal_label", "五重共鸣", "%d 万  连续开启五份" % int(draw_cost.five), Color("e5bd59"), 5)
	$Layout / Main / Rail / Controls / RedExchange.call("set_portal_label", "赤焰三选一", "100 红色积分  明牌选择", Color("ed5c68"), 3)


func _clear(node: Node) -> void :
	for child in node.get_children():
		child.queue_free()


func _play_stage_arcane(accent: Color, strength: float) -> void :
	var stage: = $Layout / Main / Primary as Control
	var fx: = ArcaneFX.new()
	add_child(fx)
	var rect: = stage.get_global_rect()
	fx.play_rect(rect, accent, strength)


func _play_summon_sequence(count: int, accent: Color) -> void :
	var stage: = SummonStage.new()
	stage.name = "TalentSummonStage"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	stage.play(count, accent)
	await _owned_delay(0.08 if GameSettings.reduce_motion else 0.72)
