extends CanvasLayer

const TutorialSandboxScript = preload("res://scripts/TutorialSandbox.gd")
const TutorialFlowStateScript = preload("res://scripts/TutorialFlowState.gd")
const Styles = preload("res://scripts/UIStyles.gd")
const MENTOR_PORTRAIT = preload("res://assets/images/v12/tutorial/business_mentor.png")

signal sandbox_visuals_changed

const BLOCKED_ACTIONS: = [
	"buy_land", "build_business", "talent_draw", "talent_resolve", "card_play", 
	"stock_trade", "direct_loan", "mortgage", "startup_invest", "auction_bid", "end_turn", 
]

var active: = false
var phase: = ""
var city_step: = 0
var focus_target: Control
var overlay: Control
var shades: Array[ColorRect] = []
var focus_border: Panel
var focus_blocker: ColorRect
var guide_card: PanelContainer
var title_label: Label
var body_label: Label
var progress_label: Label
var standalone_pending: = false
var standalone_session: = false
var previous_game_data: Dictionary = {}
var previous_suppress_disk_save: = false
var previous_tutorial_lock: = false
var pending_targets: Dictionary = {}
var exit_confirmation: Control
var arrow_label: Label
var objective_label: Label
var advance_mode_label: Label
var pulse_time: = 0.0
var abort_pending: = false
var target_retry_pending: = false
var sandbox: RefCounted = TutorialSandboxScript.new()
var flow_state: RefCounted = TutorialFlowStateScript.new()
var inline_actions: VBoxContainer
var inline_result_label: Label
var suspended_auxiliary: = ""
var pending_resume_action: = ""
var waiting_for_city_targets: = false

var city_steps: Array[Dictionary] = []
var modal_token: = 0


func _ready() -> void :
	layer = 950
	set_process(false)


func _exit_tree() -> void :
	cancel("app_exit")


func start_standalone_tutorial() -> void :
	if standalone_session or active or bool(sandbox.get("active")):
		cancel("restart_standalone_tutorial")
	previous_game_data = GameState.game_data.duplicate(true)
	previous_suppress_disk_save = bool(GameState.suppress_disk_save)
	previous_tutorial_lock = bool(GameState.tutorial_lock)
	standalone_session = true
	standalone_pending = true
	active = false
	phase = "pending_city"
	city_step = 0
	pending_targets.clear()
	GameState.suppress_disk_save = true
	GameState.tutorial_lock = true
	GameState.start_match("solo", 10, [{"company_id": "hengyue", "human": true}], 130815)
	GameState.suppress_disk_save = true
	GameState.tutorial_lock = true
	GameState.begin_round()
	GameFlow.go_smooth("city")


func is_standalone_pending() -> bool:
	return standalone_session and standalone_pending


func needs_city_target_attachment() -> bool:
	return is_standalone_pending() or (standalone_session and active and phase == "city" and waiting_for_city_targets)


func attach_city_targets(targets: Dictionary) -> void :
	var starting: = is_standalone_pending()
	if not starting and not (standalone_session and active and phase == "city" and waiting_for_city_targets):
		return
	pending_targets.clear()
	for key in targets:
		var target: = targets.get(key) as Control
		if target != null:
			pending_targets[str(key)] = {
				"weak": weakref(target), 
				"path": target.get_path(), 
			}
	if starting:
		standalone_pending = false
		active = true
		phase = "city"
		var active_player: Dictionary = GameState.active_player()
		var started: Dictionary = sandbox.call("begin", str(active_player.get("id", "p1")))
		if not bool(started.get("ok", false)):
			cancel("start_failed")
			_show_feedback("教程无法开始", "当前没有可用教学土地。你仍可正常保存、买地和结束回合。")
			return
		show_city_tour(pending_targets)
		return
	waiting_for_city_targets = false
	call_deferred("_resume_after_city_targets_ready")


func show_city_tour(targets: Dictionary) -> void :
	if not active or phase not in ["company", "city"]:
		return
	phase = "city"
	flow_state.call("start")
	city_step = int(flow_state.get("index"))
	city_steps.assign(guide_steps_profile())
	_show_city_step()


func skip() -> void :
	cancel("skip", true)


func _show_city_step() -> void :
	if waiting_for_city_targets or not suspended_auxiliary.is_empty():
		return
	var step: Dictionary = flow_state.call("current")
	city_step = int(flow_state.get("index"))
	if step.is_empty():
		complete()
		return
	var step_id: = str(step.get("id", ""))
	var target: = _resolve_target(str(step.get("target_key", "")))
	if target == null:
		_recover_or_abort_target()
		return
	_show(target, str(step.get("title", "")), str(step.get("body", "")))
	objective_label.text = str(step.get("objective", ""))
	_build_inline_actions(step_id)
	advance_mode_label.text = "完成高亮操作后自动进入下一站"


func notify_action(action_id: String) -> void :
	if not active or phase != "city":
		return
	var outcome: Dictionary = flow_state.call("submit_action", action_id)
	if not bool(outcome.get("accepted", false)):
		return
	if advance_mode_label != null:
		advance_mode_label.text = "目标完成  正在进入下一步"
	AudioManager.success()
	call_deferred("_finish_automatic_advance")


func _finish_automatic_advance() -> void :
	await get_tree().create_timer(0.28).timeout
	if not suspended_auxiliary.is_empty() or waiting_for_city_targets:
		return
	if active and phase == "city":
		_show_city_step()


func current_step_id() -> String:
	return str(flow_state.call("current_id"))


func route_action(action_id: String, payload: = {}) -> Dictionary:
	if not active:
		return _route_result(false, true, false, "", true)
	var canonical: String = str({
		"map": "select_land", "buy": "buy_land", "build": "build_business", 
	}.get(action_id, action_id))
	if phase != "city" or current_step_id().is_empty():
		return _blocked("请先完成当前教学步骤")
	var step_id: = current_step_id()
	match canonical:
		"select_land":
			if step_id != "select_land":
				return _blocked("请先完成当前教学步骤")
			var selected: Dictionary = sandbox.call("select_land", str(payload.get("land_id", "")))
			if bool(selected.get("ok", false)):
				notify_action("select_land")
				sandbox_visuals_changed.emit()
				return _route_result(true, true, true, str(selected.get("message", "已选择教学地块")), false, selected)
			return _blocked(str(selected.get("message", "请选择带有‘待售’标记的教学地块。")), true)
		"buy_land":
			if step_id != "land_decision":
				return _blocked("请先完成当前教学步骤")
			var purchase: Dictionary = sandbox.call("simulate_purchase", str(payload.get("land_id", sandbox.get("selected_land_id"))))
			if bool(purchase.get("ok", false)):
				notify_action("buy_land")
				sandbox_visuals_changed.emit()
				return _route_result(true, true, true, str(purchase.get("message", "模拟购入完成")), false, purchase)
			return _blocked(str(purchase.get("message", "模拟购入失败")), true)
		"build_business":
			if step_id != "build_cashflow":
				return _blocked("请先完成当前教学步骤")
			var build: Dictionary = sandbox.call("simulate_build", str(payload.get("type_id", "")), str(payload.get("land_id", sandbox.get("selected_land_id"))))
			if bool(build.get("ok", false)):
				notify_action("build_business")
				sandbox_visuals_changed.emit()
				return _route_result(true, true, true, str(build.get("message", "模拟建设完成")), false, build)
			return _blocked(str(build.get("message", "模拟建设失败")), true)
		"open_build":
			if step_id == "build_cashflow" and sandbox.call("owns_land", str(payload.get("land_id", ""))):
				return _route_result(true, true, true, "请选择教学企业", false)
			return _blocked("请先完成当前教学步骤")
		"talent_draw":
			if step_id != "assign_talent" or suspended_auxiliary != "talent_market":
				return _blocked("请先从高亮入口进入人才市场")
			var candidates: = GameConfig.list("talents")
			if candidates.is_empty():
				return _blocked("教学人才数据暂不可用")
			return _route_result(true, true, true, "教学候选人档案已翻开", false, {"cards": [(candidates[0] as Dictionary).duplicate(true)]})
		"talent_resolve":
			if step_id != "assign_talent" or suspended_auxiliary != "talent_market":
				return _blocked("请先完成当前教学步骤")
			if not bool(payload.get("keep", false)):
				return _blocked("教学步骤需要先招募候选人，再安排到企业")
			var talent_id: = str(payload.get("talent_id", ""))
			var talent_result: Dictionary = sandbox.call("recruit_demo_talent", talent_id)
			if bool(talent_result.get("ok", false)):
				return _route_result(true, true, true, "教学人才已签约；现在打开员工管理，把人才安排到教学企业。", false, talent_result.merged({"requires_assignment": true}))
			return _blocked(str(talent_result.get("message", "教学人才安排失败")))
		"talent_assign":
			if step_id != "assign_talent" or suspended_auxiliary != "talent_market":
				return _blocked("请先在人才市场招募教学人才")
			var assignment: Dictionary = sandbox.call("assign_demo_talent")
			if bool(assignment.get("ok", false)):
				notify_action("assign_talent")
				return _route_result(true, true, true, "教学人才已安排到教学企业；预计净收益已提升，正式员工库未变化。", false, assignment)
			return _blocked(str(assignment.get("message", "教学人才安排失败")))
		"card_play":
			if step_id != "play_strategy" or suspended_auxiliary != "card_hand":
				return _blocked("请先从高亮入口打开策略手牌")
			var card_result: Dictionary = sandbox.call("play_demo_strategy")
			if bool(card_result.get("ok", false)):
				notify_action("play_strategy")
				return _route_result(true, true, true, "教学策略已结算；正式手牌未消耗。", false, card_result.merged({"settlement": "教学净收益预测已更新", "effect_kind": "growth", "presentation": {"animation": "card_settlement"}}))
			return _blocked(str(card_result.get("message", "教学卡牌结算失败")))
		"direct_loan":
			if step_id != "finance_risk" or suspended_auxiliary != "city_bank":
				return _blocked("请先从高亮入口进入城市银行")
			var amount: = int(payload.get("amount", 0))
			if amount <= 0:
				return _blocked("请先选择一个融资额度")
			var finance: Dictionary = sandbox.call("simulate_financing", amount)
			if not bool(finance.get("ok", false)):
				return _blocked(str(finance.get("message", "教学融资失败")))
			notify_action("finance_risk")
			return _route_result(true, true, true, str(finance.get("message", "教学融资完成")), false, finance)
		"stock_trade":
			if step_id != "stock_market" or suspended_auxiliary != "stock_market":
				return _blocked("请先从高亮入口进入证券终端")
			var trade: Dictionary = sandbox.call("simulate_stock_trade", str(payload.get("stock_id", "")), int(payload.get("shares", 0)), bool(payload.get("buy", true)))
			if bool(trade.get("ok", false)):
				notify_action("stock_trade")
				return _route_result(true, true, true, str(trade.get("message", "教学证券交易完成")), false, trade)
			return _blocked(str(trade.get("message", "教学证券交易失败")))
		"startup_invest":
			if step_id != "startup_review" or suspended_auxiliary != "startup_center":
				return _blocked("请先从高亮入口进入创投中心")
			var startup: Dictionary = sandbox.call("simulate_startup", str(payload.get("project_id", "")))
			if bool(startup.get("ok", false)):
				notify_action("startup_invest")
				return _route_result(true, true, true, str(startup.get("message", "教学创投决策完成")), false, startup)
			return _blocked(str(startup.get("message", "教学创投失败")))
		"auction_bid":
			if step_id != "auction_practice" or suspended_auxiliary != "auction_center":
				return _blocked("请先从高亮入口进入拍卖中心")
			var bid: Dictionary = sandbox.call("simulate_auction", str(payload.get("asset_id", "")), int(payload.get("amount", 0)))
			if bool(bid.get("ok", false)):
				notify_action("auction_bid")
				return _route_result(true, true, true, str(bid.get("message", "教学暗标完成")), false, bid)
			return _blocked(str(bid.get("message", "教学暗标失败")))
		"end_turn":
			if step_id != "settle_practice":
				return _blocked("请先完成当前教学步骤")
			var settlement: Dictionary = sandbox.call("simulate_settlement")
			if bool(settlement.get("ok", false)):
				notify_action("settle_practice")
				return _route_result(true, true, true, "模拟结算：净现金流 +%d万，教学现金变为%d万；正式回合尚未结束。" % [int(settlement.get("net_cashflow", 0)), int(settlement.get("cash_after", 0))], false, settlement)
			return _blocked(str(settlement.get("message", "模拟结算失败")))
		"scene_navigation":
			var system_id: = str(payload.get("system", ""))
			var expected: String = str({"assign_talent": "talent", "play_strategy": "cards", "stock_market": "stocks", "finance_risk": "bank", "startup_review": "startup", "auction_practice": "auction", "first_round_plan": "news"}.get(step_id, ""))
			if system_id == expected:
				return _route_result(false, true, true, "进入教学系统", true)
			return _blocked("请点击当前金色高亮的系统入口")
		_:
			if canonical in BLOCKED_ACTIONS:
				return _blocked("请先完成当前教学步骤")
			return _blocked("基础教程期间暂不可执行该操作")


func tutorial_visual(land_id: String) -> Dictionary:
	return sandbox.call("land_visual", land_id) if bool(sandbox.get("active")) else {}


func demo_land_id() -> String:
	return str(sandbox.get("demo_land_id")) if bool(sandbox.get("active")) else ""


func sandbox_owns_land(land_id: String) -> bool:
	return bool(sandbox.call("owns_land", land_id))


func focus_build_choice(target: Control) -> void :
	if not active or phase != "city" or current_step_id() != "build_cashflow" or target == null:
		return
	focus_target = target
	title_label.text = "选择一家企业开始经营"
	objective_label.text = "点击高亮方案完成模拟开工"
	body_label.text = "选择已高亮的可用方案完成模拟开工。本操作不会扣除真实现金，也不会占用本回合建设次数。"
	_position_focus()


func tutorial_flow_profile() -> Array[String]:
	var result: Array[String] = []
	for step: Dictionary in guide_steps_profile():
		result.append(str(step.id))
	return result


func guide_steps_profile() -> Array[Dictionary]:
	return flow_state.call("profile")


func complete() -> void :
	cancel("complete", true)
	AudioManager.success()


func suspend_for_auxiliary(auxiliary_id: String) -> bool:
	if not active or phase != "city" or auxiliary_id.is_empty() or not suspended_auxiliary.is_empty():
		return false
	suspended_auxiliary = auxiliary_id
	if modal_token > 0:
		ModalManager.close_modal(modal_token, "tutorial_auxiliary_open")
		modal_token = 0
	_hide_overlay()
	return true


func resume_from_auxiliary(auxiliary_id: String, completed_action: = "") -> void :
	if not active or suspended_auxiliary != auxiliary_id:
		return
	suspended_auxiliary = ""
	_show_city_step()
	if not completed_action.is_empty():
		notify_action(completed_action)


func return_to_city_from_auxiliary(auxiliary_id: String, completed_action: = "") -> bool:
	if not active or suspended_auxiliary != auxiliary_id:
		return false
	suspended_auxiliary = ""
	pending_resume_action = completed_action
	waiting_for_city_targets = true
	return true


func _resume_after_city_targets_ready() -> void :
	await get_tree().process_frame
	if not active or phase != "city" or waiting_for_city_targets:
		return
	_show_city_step()
	var action: = pending_resume_action
	pending_resume_action = ""
	if not action.is_empty():
		notify_action(action)


func cancel(reason: String, mark_completed: = false) -> void :
	var return_home: = standalone_session and reason not in ["app_exit", "formal_new_game", "load_other_save"]
	if bool(sandbox.get("active")):
		sandbox.call("finish", reason)
	_hide_exit_confirmation()
	_hide_overlay()
	focus_target = null
	pending_targets.clear()
	city_steps.clear()
	city_step = 0
	flow_state.call("stop")
	target_retry_pending = false
	abort_pending = false
	suspended_auxiliary = ""
	pending_resume_action = ""
	waiting_for_city_targets = false
	active = false
	phase = ""
	standalone_pending = false
	if standalone_session:
		GameState.game_data = previous_game_data.duplicate(true)
		GameState.rng.seed = int(GameState.game_data.get("seed", 6007))
		GameState.suppress_disk_save = previous_suppress_disk_save
		GameState.tutorial_lock = previous_tutorial_lock
	else:
		GameState.suppress_disk_save = false
		GameState.tutorial_lock = false
	standalone_session = false
	previous_game_data.clear()
	ModalManager.close_modal(modal_token, reason)
	modal_token = 0
	if mark_completed:
		GameSettings.set_tutorial_completed(true)
	sandbox_visuals_changed.emit()
	GameState.force_refresh()
	if return_home:
		call_deferred("_return_to_home")


func _return_to_home() -> void :
	GameFlow.go("menu")


func on_modal_force_close() -> void :
	if not suspended_auxiliary.is_empty():
		return
	cancel("modal_replaced")


func request_exit_confirmation() -> void :
	if not active:
		return
	if exit_confirmation != null and is_instance_valid(exit_confirmation):
		exit_confirmation.visible = true
		return
	exit_confirmation = Control.new()
	exit_confirmation.name = "TutorialExitConfirmation"
	exit_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exit_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_confirmation.z_index = 1200
	add_child(exit_confirmation)
	var veil: = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.005, 0.015, 0.025, 0.78)
	exit_confirmation.add_child(veil)
	var panel: = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -150)
	panel.size = Vector2(600, 300)
	panel.add_theme_stylebox_override("panel", preload("res://scripts/UIStyles.gd").toy_panel())
	exit_confirmation.add_child(panel)
	var stack: = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	panel.add_child(stack)
	var title: = Label.new()
	title.text = "退出新手教程？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	stack.add_child(title)
	var body: = Label.new()
	body.text = "退出后会撤销全部教学演示并恢复正式对局。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 17)
	stack.add_child(body)
	var actions: = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	stack.add_child(actions)
	var continue_button: = Button.new()
	continue_button.name = "ContinueTutorial"
	continue_button.text = "继续教程"
	continue_button.custom_minimum_size = Vector2(190, 54)
	continue_button.pressed.connect(_hide_exit_confirmation)
	actions.add_child(continue_button)
	var exit_button: = Button.new()
	exit_button.name = "ExitTutorialToMenu"
	exit_button.text = "退出教程并返回主菜单"
	exit_button.custom_minimum_size = Vector2(250, 54)
	exit_button.pressed.connect( func() -> void :
		cancel("return_to_menu")
		var flow: = get_node_or_null("/root/GameFlow")
		if flow != null:
			flow.call("go", "menu"))
	actions.add_child(exit_button)


func _hide_exit_confirmation() -> void :
	if exit_confirmation != null and is_instance_valid(exit_confirmation):
		exit_confirmation.queue_free()
	exit_confirmation = null


func _show(target: Control, title: String, body: String) -> void :
	_build_overlay()
	focus_target = target
	_ensure_target_visible(target)
	title_label.text = title
	body_label.text = body
	var step_name: = current_step_id()
	progress_label.text = "启航线路  %s   第 %d / %d 站" % [_progress_dots(), city_step + 1, maxi(1, city_steps.size())]
	overlay.visible = true
	modal_token = ModalManager.open_modal("tutorial", self, overlay, self)
	set_process(true)
	_position_focus()
	call_deferred("_position_focus")


func _ensure_target_visible(target: Control) -> void :
	var ancestor: = target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(target)
			return
		ancestor = ancestor.get_parent()


func _build_overlay() -> void :
	if overlay != null:
		return
	overlay = Control.new()
	overlay.name = "TutorialCityGuide"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	for i in range(4):
		var shade: = ColorRect.new()
		shade.color = Color(0.008, 0.025, 0.038, 0.34)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		shade.gui_input.connect(_on_focus_blocker_input)
		overlay.add_child(shade)
		shades.append(shade)
	focus_blocker = ColorRect.new()
	focus_blocker.color = Color(0.008, 0.025, 0.038, 0.04)
	focus_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	focus_blocker.gui_input.connect(_on_focus_blocker_input)
	overlay.add_child(focus_blocker)
	focus_border = Panel.new()
	focus_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border: = StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = Color("e2bc5a")
	border.set_border_width_all(4)
	border.set_corner_radius_all(12)
	focus_border.add_theme_stylebox_override("panel", border)
	overlay.add_child(focus_border)
	arrow_label = Label.new()
	arrow_label.name = "TargetArrow"
	arrow_label.text = "➤"
	arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_label.add_theme_font_size_override("font_size", 40)
	arrow_label.add_theme_color_override("font_color", Color("f2c85d"))
	arrow_label.add_theme_color_override("font_outline_color", Color("06151d"))
	arrow_label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(arrow_label)
	guide_card = PanelContainer.new()
	guide_card.custom_minimum_size = Vector2(420, 0)
	guide_card.clip_contents = true
	var card_style: = StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.115, 0.135, 0.985)
	card_style.border_color = Color("e0b95b")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(22)
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 18
	card_style.content_margin_bottom = 14
	card_style.shadow_color = Color(0, 0, 0, 0.68)
	card_style.shadow_size = 24
	guide_card.add_theme_stylebox_override("panel", card_style)
	overlay.add_child(guide_card)
	var scroll: = ScrollContainer.new()
	scroll.name = "GuideScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_card.add_child(scroll)
	var stack: = VBoxContainer.new()
	stack.custom_minimum_size.x = 396
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	var mentor_header: = HBoxContainer.new()
	mentor_header.add_theme_constant_override("separation", 11)
	var mentor_thumb: = TextureRect.new();mentor_thumb.custom_minimum_size = Vector2(58, 58);mentor_thumb.texture = MENTOR_PORTRAIT;mentor_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;mentor_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED;mentor_header.add_child(mentor_thumb)
	var mentor_identity: = VBoxContainer.new();mentor_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL;mentor_header.add_child(mentor_identity)
	var mentor_label: = Label.new();mentor_label.text = "城市经营导师  陆衡";mentor_label.add_theme_font_size_override("font_size", 17);mentor_label.add_theme_color_override("font_color", Color("f2d27d"));mentor_identity.add_child(mentor_label)
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color("8fc9d2"))
	mentor_identity.add_child(progress_label)
	stack.add_child(mentor_header)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override("font_color", Color("f2d27d"))
	stack.add_child(title_label)
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 19)
	objective_label.add_theme_color_override("font_color", Color("ffffff"))
	objective_label.add_theme_color_override("font_outline_color", Color("0b2834"))
	objective_label.add_theme_constant_override("outline_size", 4)
	stack.add_child(objective_label)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(0, 36)
	body_label.max_lines_visible = 4
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color("edf4f5"))
	stack.add_child(body_label)
	inline_actions = VBoxContainer.new()
	inline_actions.name = "TutorialInlineActions"
	inline_actions.add_theme_constant_override("separation", 8)
	stack.add_child(inline_actions)
	inline_result_label = Label.new()
	inline_result_label.name = "TutorialInlineResult"
	inline_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inline_result_label.add_theme_font_size_override("font_size", 15)
	inline_result_label.add_theme_color_override("font_color", Color("74d8ad"))
	stack.add_child(inline_result_label)
	advance_mode_label = Label.new()
	advance_mode_label.add_theme_font_size_override("font_size", 15)
	advance_mode_label.add_theme_color_override("font_color", Color("75d6be"))
	stack.add_child(advance_mode_label)
	var actions: = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	stack.add_child(actions)
	var skip_button: = Button.new()
	skip_button.text = "跳过教程"
	skip_button.custom_minimum_size = Vector2(128, 38)
	skip_button.pressed.connect(skip)
	actions.add_child(skip_button)


func _process(_delta: float) -> void :
	pulse_time += _delta
	if active and (focus_target == null or not is_instance_valid(focus_target)) and not abort_pending:
		var target_key: = ""
		if city_step >= 0 and city_step < city_steps.size():
			target_key = str(city_steps[city_step].get("target_key", ""))
		focus_target = _resolve_target(target_key)
		if focus_target == null:
			_recover_or_abort_target()
			return
	if focus_border != null:
		focus_border.modulate.a = 0.72 + sin(pulse_time * 4.5) * 0.28
	_position_focus()


func _position_focus() -> void :
	if overlay == null or not overlay.visible or focus_target == null or not is_instance_valid(focus_target):
		return
	var viewport_size: = get_viewport().get_visible_rect().size
	var target_rect: = focus_target.get_global_rect().grow(10)
	target_rect.position.x = clampf(target_rect.position.x, 8.0, viewport_size.x - 24.0)
	target_rect.position.y = clampf(target_rect.position.y, 8.0, viewport_size.y - 24.0)
	target_rect.size.x = minf(target_rect.size.x, viewport_size.x - target_rect.position.x - 8.0)
	target_rect.size.y = minf(target_rect.size.y, viewport_size.y - target_rect.position.y - 8.0)
	_set_rect(shades[0], Rect2(0, 0, viewport_size.x, target_rect.position.y))
	_set_rect(shades[1], Rect2(0, target_rect.end.y, viewport_size.x, viewport_size.y - target_rect.end.y))
	_set_rect(shades[2], Rect2(0, target_rect.position.y, target_rect.position.x, target_rect.size.y))
	_set_rect(shades[3], Rect2(target_rect.end.x, target_rect.position.y, viewport_size.x - target_rect.end.x, target_rect.size.y))
	_set_rect(focus_border, target_rect)
	if focus_blocker != null:
		_set_rect(focus_blocker, target_rect)
		var operation_step: = false
		if city_step >= 0 and city_step < city_steps.size():
			operation_step = not str(city_steps[city_step].get("success_action", "")).is_empty()
		focus_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE if operation_step else Control.MOUSE_FILTER_STOP
	if arrow_label != null:
		arrow_label.position = Vector2(maxf(8.0, target_rect.position.x - 46.0 + sin(pulse_time * 5.0) * 5.0), target_rect.position.y + target_rect.size.y * 0.5 - 24.0)
	var card_size: = _guide_card_size()
	card_size.x = minf(card_size.x, viewport_size.x - 48.0)
	card_size.y = minf(card_size.y, viewport_size.y - 48.0)
	var card_pos: = Vector2(viewport_size.x - card_size.x - 24, viewport_size.y - card_size.y - 24) if target_rect.get_center().x < viewport_size.x * 0.5 else Vector2(24, viewport_size.y - card_size.y - 24)
	if target_rect.intersects(Rect2(card_pos, card_size)):
		card_pos.y = 24
	_set_rect(guide_card, Rect2(card_pos, card_size))


func _guide_card_size() -> Vector2:
	match current_step_id():
		"capital_goal": return Vector2(500, 520)
		"dashboard_drill": return Vector2(500, 480)
		"finance_risk": return Vector2(510, 500)
		"assign_talent", "play_strategy", "stock_market", "startup_review", "auction_practice", "settle_practice", "first_round_plan": return Vector2(500, 460)
		_: return Vector2(460, 390)


func _set_rect(control: Control, rect: Rect2) -> void :
	control.position = rect.position
	control.size = rect.size


func _progress_dots() -> String:
	var result: = ""
	for index in range(city_steps.size()):
		result += "●" if index <= city_step else "○"
	return result


func _build_inline_actions(step_id: String) -> void :
	if inline_actions == null:
		return
	for child in inline_actions.get_children():
		inline_actions.remove_child(child)
		child.free()
	inline_result_label.text = ""
	inline_actions.visible = step_id in ["capital_goal", "dashboard_drill"]
	inline_result_label.visible = inline_actions.visible
	match step_id:
		"capital_goal":
			inline_actions.add_child(_teaching_note("🏆 最高最终净值获胜", "现金 + 土地企业 + 投资资产 − 负债 − 风险惩罚", Color("e2b958")))
			inline_actions.add_child(_teaching_note("每轮经营闭环", "观察城市 → 配置资产 → 控制风险 → 读取结算", Color("67d5a6")))
			var understood: = _inline_button("UnderstandCapitalGoal", "我明白了  开始读取经营指标", Color("e2b958"), 58)
			understood.pressed.connect( func() -> void : notify_action("capital_goal"))
			inline_actions.add_child(understood)
			call_deferred("_scroll_inline_action_into_view", understood)
		"dashboard_drill":
			inline_actions.add_child(_teaching_note("真实信息页", "点击画面中的金色高亮按钮；查看完成后点“返回城市”", Color("63c8ef")))


func _scroll_inline_action_into_view(control: Control) -> void :
	await get_tree().process_frame
	var scroll: = guide_card.get_node_or_null("GuideScroll") as ScrollContainer if guide_card != null else null
	if scroll != null and is_instance_valid(control):
		scroll.ensure_control_visible(control)


func _inline_button(node_name: String, text_value: String, accent: Color, height: = 58) -> Button:
	var button: = Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(205, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("f5fbfb"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _inline_style(Color("0b2a38"), accent))
	button.add_theme_stylebox_override("hover", _inline_style(Color("124252"), accent.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _inline_style(Color("071d28"), accent))
	return button


func _teaching_note(title: String, explanation: String, accent: Color) -> PanelContainer:
	var panel: = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _inline_style(Color("082330"), Color(accent, 0.72)))
	var text: = Label.new()
	text.text = "%s\n%s" % [title, explanation]
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 15)
	text.add_theme_color_override("font_color", Color("edf7f7"))
	panel.add_child(text)
	return panel


func _inline_style(fill: Color, accent: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _assign_inline_talent(button: Button) -> void :
	var outcome: Dictionary = sandbox.call("assign_demo_talent")
	if not bool(outcome.get("ok", false)):
		return
	button.disabled = true
	button.text = "人才已安排  ✓   预计净收益 +%d万" % int(outcome.get("projected_net", 0))
	inline_result_label.text = "人才让预计净收益从 +%d万提高到 +%d万" % [int(outcome.get("base_net", 0)), int(outcome.get("projected_net", 0))]
	notify_action("assign_talent")


func _play_inline_strategy(button: Button) -> void :
	var outcome: Dictionary = sandbox.call("play_demo_strategy")
	if not bool(outcome.get("ok", false)):
		return
	button.disabled = true
	button.text = "策略已生效  ✓   本轮预测 +%d万" % int(outcome.get("projected_net", 0))
	inline_result_label.text = "卡牌只改变教学预测，正式手牌没有消耗"
	notify_action("play_strategy")


func _settle_inline(button: Button) -> void :
	var outcome: Dictionary = sandbox.call("simulate_settlement")
	if not bool(outcome.get("ok", false)):
		inline_result_label.text = str(outcome.get("message", "请先完成人才与卡牌训练"))
		return
	button.disabled = true
	button.text = "模拟净现金流  +%d万  ✓" % int(outcome.get("net_cashflow", 0))
	inline_result_label.text = "教学现金：800万 → %d万  正式对局未变化" % int(outcome.get("cash_after", 800))
	notify_action("settle_practice")


func _hide_overlay() -> void :
	if overlay != null:
		overlay.visible = false
	set_process(false)


func _resolve_target(target_key: String) -> Control:
	var descriptor: Dictionary = pending_targets.get(target_key, {})
	if descriptor.is_empty():
		return null
	var reference: = descriptor.get("weak") as WeakRef
	if reference != null:
		var live: = reference.get_ref() as Control
		if _target_usable(live):
			return live
	var path: NodePath = descriptor.get("path", NodePath(""))
	if not path.is_empty():
		var rebound: = get_node_or_null(path) as Control
		if _target_usable(rebound):
			descriptor["weak"] = weakref(rebound)
			pending_targets[target_key] = descriptor
			return rebound
	return null


func _target_usable(target: Control) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree():
		return false
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return false
	if target is BaseButton and (target as BaseButton).disabled:
		return false
	return true


func _recover_or_abort_target() -> void :
	if target_retry_pending or abort_pending:
		return
	target_retry_pending = true
	call_deferred("_retry_target_after_refresh")


func _retry_target_after_refresh() -> void :
	await get_tree().process_frame
	if not active or city_step < 0 or city_step >= city_steps.size():
		target_retry_pending = false
		return
	var target_key: = str(city_steps[city_step].get("target_key", ""))
	var recovered: = _resolve_target(target_key)
	target_retry_pending = false
	if recovered != null:
		focus_target = recovered
		_show_city_step()
		return
	_abort_tutorial("教学目标界面已发生变化且无法恢复，教程已安全退出；正式对局数据没有变化。")


func _on_focus_blocker_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_feedback("请先完成当前教学步骤", "当前区域仅用于查看信息，请使用教程卡的“下一步”继续。")
		get_viewport().set_input_as_handled()


func _abort_tutorial(message: String) -> void :
	if abort_pending:
		return
	abort_pending = true
	cancel("interrupted")
	_show_feedback("教程已安全退出", message)
	abort_pending = false


func _blocked(message: String, show_feedback: = true) -> Dictionary:
	if show_feedback:
		_show_feedback("操作已阻止", message)
	return _route_result(true, false, false, message, false)


func _route_result(handled: bool, ok: bool, simulated: bool, message: String, allow_real_action: bool, details: = {}) -> Dictionary:
	var result: = {
		"handled": handled, 
		"ok": ok, 
		"simulated": simulated, 
		"message": message, 
		"allow_real_action": allow_real_action, 
	}
	if details is Dictionary:
		result.merge(details, false)
	return result


func _show_feedback(title: String, message: String) -> void :
	if active and overlay != null and overlay.visible:
		if inline_result_label != null:
			inline_result_label.visible = true
			inline_result_label.text = "%s  %s" % [title, message]
			inline_result_label.add_theme_color_override("font_color", Color("f2c96b"))
			inline_result_label.pivot_offset = inline_result_label.size * 0.5
			inline_result_label.scale = Vector2(0.96, 0.96)
			var tween: = create_tween()
			tween.tween_property(inline_result_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	if has_node("/root/GlobalFeedbackOverlay"):
		get_node("/root/GlobalFeedbackOverlay").call("show_notice", title, message)
	elif body_label != null:
		body_label.text = message
