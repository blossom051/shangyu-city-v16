extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const CompanyCardScript = preload("res://scripts/CompanyCard.gd")
const ScreenDecorator = preload("res://scripts/V7ScreenDecorator.gd")
const ModePolicy = preload("res://scripts/GameModePolicy.gd")

var seat_index: = 0
var selections: Array[Dictionary] = []
var selected_company_id: = ""


func _ready() -> void :
	ScreenDecorator.decorate(self, "company")
	_apply_responsive_layout()
	$Background.modulate = Color.WHITE
	$Shade.color = Color(0.01, 0.04, 0.055, 0.1)
	$Layout / Footer / Back.pressed.connect( func() -> void : AudioManager.click();GameFlow.go("mode"))
	$Layout / Footer / Confirm.pressed.connect(_confirm)
	$Layout / Content / Dossier / Showcase / NameRow / EditName.pressed.connect(_open_name_editor)
	for button: Button in [$Layout / Footer / Back, $Layout / Footer / Confirm]:
		Styles.apply_toy_button(button, button == $Layout / Footer / Confirm, Color("ffd45e") if button == $Layout / Footer / Confirm else Color("55bce8"), 20)
		button.mouse_entered.connect(AudioManager.hover)
	Styles.apply_labels($Layout)
	$Layout / Header / CompanyGalleryHeader / Prompt.add_theme_color_override("font_color", Color("edf7ff"))
	$Layout / Header / CompanyGalleryHeader / Kicker.add_theme_color_override("font_color", Color("62d7e8"))
	$Layout / Header / RosterCounter.add_theme_color_override("font_color", Color("24b7ff"))
	var dossier_style: = Styles.panel(Color(0.018, 0.07, 0.1, 0.95), Color("d6ad54"), 20, 2)
	dossier_style.content_margin_left = 22
	dossier_style.content_margin_right = 22
	dossier_style.content_margin_top = 20
	dossier_style.content_margin_bottom = 20
	$Layout / Content / Dossier.add_theme_stylebox_override("panel", dossier_style)
	var carousel_style: = Styles.panel(Color(0.012, 0.045, 0.07, 0.93), Color("638d99"), 18, 2)
	carousel_style.content_margin_left = 14
	carousel_style.content_margin_right = 14
	carousel_style.content_margin_top = 10
	carousel_style.content_margin_bottom = 10
	$Layout / Carousel.add_theme_stylebox_override("panel", carousel_style)
	$Layout / Content / Dossier / Showcase / Name.add_theme_color_override("font_color", Color("edf7ff"))
	$Layout / Content / Dossier / Showcase / Type.add_theme_color_override("font_color", Styles.TOY_MUTED)
	$Layout / Content / Dossier / Showcase / Metrics / Strength / Label.add_theme_color_override("font_color", Color("49e09a"))
	$Layout / Content / Dossier / Showcase / Metrics / Risk / Label.add_theme_color_override("font_color", Color("ef6d7a"))
	$Layout / Content / Dossier / Showcase / AbilityContract.add_theme_color_override("font_color", Color("f4c95d"))
	$Layout / Content / Dossier / Showcase / Route.add_theme_color_override("font_color", Color("82d4df"))
	$Layout / Content / Dossier / Showcase / SignatureCards.add_theme_color_override("font_color", Color("c5d7dc"))
	$Layout / Content / Dossier / Showcase / DossierKicker.add_theme_font_override("font", load("res://Themes/V9141BodyMediumFont.tres"))
	$Layout / Content / Dossier / Showcase / DossierKicker.add_theme_color_override("font_color", Color("c7a85b"))
	$Layout / Content / Dossier / Showcase / Name.add_theme_font_override("font", load("res://Themes/V9141DisplayFont.tres"))
	for metric_path in ["Metrics/Strength/Value", "Metrics/Risk/Value"]:
		var metric: = $Layout / Content / Dossier / Showcase.get_node(metric_path) as Label
		metric.custom_minimum_size = Vector2(0, 88)
		metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metric.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		metric.clip_text = true
		metric.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		metric.add_theme_constant_override("line_spacing", 4)
		metric.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		metric.add_theme_stylebox_override("normal", Styles.panel(Color(0.01, 0.045, 0.062, 0.86), Color("3b6570"), 12, 1))
	$Layout / Content / Dossier / Showcase / ContractSeal.add_theme_font_override("font", load("res://Themes/V9141BodyMediumFont.tres"))
	$Layout / Content / Dossier / Showcase / ContractSeal.add_theme_color_override("font_color", Color("f2cf74"))
	$Layout / Content / Dossier / Showcase / ContractSeal.add_theme_stylebox_override("normal", Styles.panel(Color(0.08, 0.055, 0.018, 0.82), Color("d6ad54"), 12, 1))
	$Layout / Content / Dossier / Showcase / NameRow / NameInput.add_theme_color_override("font_color", Color("edf7ff"))
	$Layout / Content / Dossier / Showcase / NameRow / NameInput.add_theme_stylebox_override("normal", Styles.panel(Color(0.04, 0.13, 0.23, 0.96), Color("24b7ff"), 14, 2))
	Styles.apply_toy_button($Layout / Content / Dossier / Showcase / NameRow / EditName, false, Color("55bce8"), 20)
	$Layout / Footer / Confirm.text = "盖章签约并进入城市  →"
	_build_cards()
	_highlight_cards()
	_show_empty_state()
	_refresh_header()
	call_deferred("_show_tutorial")


func _apply_responsive_layout() -> void :
	var compact: = get_viewport_rect().size.x < 1500.0
	if not compact:
		return
	$Layout.offset_left = 24.0
	$Layout.offset_right = -24.0
	$Layout / Content / Hero.custom_minimum_size = Vector2(650.0, 0.0)
	$Layout / Content / Dossier.custom_minimum_size = Vector2(420.0, 0.0)
	$Layout / Header.custom_minimum_size.y = 56.0
	$Layout / Header / CompanyGalleryHeader / Kicker.hide()
	$Layout / Header / CompanyGalleryHeader / Prompt.add_theme_font_size_override("font_size", 30)
	$Layout / Content / Dossier / Showcase / Route.hide()
	$Layout / Content / Dossier / Showcase / SignatureCards.hide()
	$Layout / Content / Dossier / Showcase / NameRow.hide()
	$Layout / Content / Dossier / Showcase / ContractSeal.hide()
	$Layout / Carousel.custom_minimum_size.y = 158.0
	$Layout / Footer.custom_minimum_size.y = 50.0


func _show_tutorial() -> void :
	await get_tree().process_frame


func _build_cards() -> void :
	for child in $Layout / Carousel / CompanyCarousel / Companies.get_children():
		child.queue_free()
	for company: Dictionary in GameConfig.list("investment_companies"):
		var card: = Button.new()
		card.set_script(CompanyCardScript)
		card.setup(company, get_viewport_rect().size.x < 1500.0)
		card.set_meta("company_id", str(company.id))
		card.pressed.connect( func() -> void :
			AudioManager.click()
			selected_company_id = str(company.id)
			_highlight_cards()
			_show_company_detail(company))
		card.mouse_entered.connect( func() -> void :
			AudioManager.hover()
			_tween_scale(card, Vector2(1.025, 1.025)))
		card.mouse_exited.connect( func() -> void : _tween_scale(card, Vector2.ONE))
		$Layout / Carousel / CompanyCarousel / Companies.add_child(card)
	_highlight_cards()


func _show_empty_state() -> void :
	$Layout / Content / Hero.show_company({})
	$Layout / Content / Dossier / Showcase / Name.text = "等待选择财团"
	$Layout / Content / Dossier / Showcase / Type.text = "从下方八方势力轮盘调取总部档案"
	$Layout / Content / Dossier / Showcase / Metrics / Strength / Value.text = "待鉴定"
	$Layout / Content / Dossier / Showcase / Metrics / Risk / Value.text = "待鉴定"
	$Layout / Content / Dossier / Showcase / AbilityContract.text = "专属能力  等待调取"
	$Layout / Content / Dossier / Showcase / Route.text = "经营路线  等待选择"
	$Layout / Content / Dossier / Showcase / SignatureCards.text = "策略标签  等待载入"
	$Layout / Content / Dossier / Showcase / ContractSeal.text = "CONTRACT PENDING  等待选择财团"


func _highlight_cards() -> void :
	for card: Button in $Layout / Carousel / CompanyCarousel / Companies.get_children():
		var chosen: = str(card.get_meta("company_id")) == selected_company_id
		card.call("set_selected", chosen)
	$Layout / Footer / Confirm.disabled = selected_company_id.is_empty()

func _show_company_detail(company: Dictionary) -> void :
	$Layout / Content / Hero.show_company(company)
	$Layout / Content / Dossier / Showcase / Name.text = str(company.name)
	$Layout / Content / Dossier / Showcase / Type.text = "%s  注册资本 %s 万" % [company.get("type", "资本集团"), company.get("capital", 0)]
	$Layout / Content / Dossier / Showcase / PlaystyleMeter.value = 36.0 + float(absi(str(company.id).hash()) % 58)
	$Layout / Content / Dossier / Showcase / Metrics / Strength / Value.text = _focus_text(str(company.get("strength", "稳健扩张")), 42)
	$Layout / Content / Dossier / Showcase / Metrics / Risk / Value.text = _focus_text(str(company.get("weakness", "市场波动")), 42)
	$Layout / Content / Dossier / Showcase / AbilityContract.text = "◆ 专属能力  %s\n◷ 触发条件  %s" % [_focus_text(str(company.get("ability_text", "专属经营能力")), 46), _focus_text(_ability_timing(company), 34)]
	$Layout / Content / Dossier / Showcase / Route.text = "经营路线  %s" % _focus_text(str(company.get("playstyle", "资本经营")), 48)
	var signature_cards: Array = company.get("signature_cards", [])
	var signature_names: = signature_cards.map( func(card_id: Variant) -> String: return str(GameConfig.by_id("cards", str(card_id)).get("name", card_id)))
	$Layout / Content / Dossier / Showcase / SignatureCards.text = "代表策略  %s\n策略标签  %s" % [" / ".join(signature_names.slice(0, 2)), "  ".join(_localized_tags(company.get("signature_tags", [])).slice(0, 3))]
	$Layout / Content / Dossier / Showcase / ContractSeal.text = "◆  CONTRACT READY  董事会合约已备妥"
	$Layout / Content / Dossier / Showcase.scale = Vector2(0.985, 0.985)
	if GameSettings.reduce_motion:
		$Layout / Content / Dossier / Showcase.scale = Vector2.ONE
	else:
		var tween: = create_tween();tween.tween_property($Layout / Content / Dossier / Showcase, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _compact_metric(value: String) -> String:
	return value.split("，")[0].replace("首次", "")


func _focus_text(value: String, limit: int) -> String:
	var compact: = value.replace("。", "").strip_edges()
	return compact if compact.length() <= limit else compact.left(limit - 1) + "…"


func _localized_tags(tags: Array) -> Array[String]:
	const LABELS: = {
		"defense": "防守", "risk": "风险治理", "stability": "稳健经营", 
		"marketing": "品牌营销", "public_opinion": "舆情应对", "traffic": "客流增长", 
		"startup": "创业投资", "technology": "科技研发", "draw": "策略补给", 
		"finance": "融资", "bank": "银行", "debt": "债务管理", 
		"land": "土地", "district": "街区协同", "construction": "城市建设", 
		"operation": "企业经营", "talent": "人才管理", "attack": "竞争进攻", 
		"auction": "拍卖", "pressure": "对手施压", "card": "卡牌策略", "counter": "反制", 
	}
	var result: Array[String] = []
	for tag: Variant in tags:
		result.append(str(LABELS.get(str(tag), str(tag))))
	return result


func _ability_timing(company: Dictionary) -> String:
	var ability: Dictionary = company.get("abilities", {})
	if ability.has("event_guard_every"): return "每第 %d 回合补充护盾，直到下一次负面事件才消耗" % int(ability.event_guard_every)
	if ability.has("income_start_round"): return "第 %d 回合起，匹配行业自动结算" % int(ability.income_start_round)
	if ability.has("first_loan_interest_multiplier"): return "首份贷款与每次逾期结算"
	if ability.has("adjacency_income_multiplier"): return "相邻己方资产在回合结算时触发"
	if ability.has("stock_profit_multiplier"): return "经营收入与证券卖出时自动计算"
	if ability.has("auction_rebate_rate"): return "每局一次，正常中标并完整付款后触发"
	if ability.has("opening_red_ids"): return "开局发牌；每两次普通抽牌固定追加一张"
	return "匹配行业在每轮经营结算时自动触发"


func _confirm() -> void :
	if selected_company_id.is_empty():
		return
	await _play_contract_signing()
	AudioManager.enter_game()
	var mode: = ModePolicy.normalize_mode(str(GameFlow.setup.mode))
	var pick: = {
		"company_id": selected_company_id, 
		"human": ModePolicy.is_human_seat(mode, seat_index), 
		"custom_name": $Layout / Content / Dossier / Showcase / NameRow / NameInput.text.strip_edges() if seat_index == 0 else "", 
	}
	if mode in [ModePolicy.SOLO, ModePolicy.VERSUS_AI]:
		selections = ModePolicy.build_roster(
			mode, 
			pick, 
			int(GameFlow.setup.player_count), 
			GameConfig.list("investment_companies")
		)
		if mode == ModePolicy.VERSUS_AI:
			await _show_ai_arrival()
		GameFlow.confirm_companies(selections)
		return
	selections.append(pick)
	seat_index += 1
	if seat_index >= int(GameFlow.setup.player_count):
		GameFlow.confirm_companies(selections)
		return
	selected_company_id = _first_available_id()
	_refresh_header()
	_highlight_cards()


func _show_ai_arrival() -> void :
	var notice: = PanelContainer.new();notice.name = "AIArrival";notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER);notice.position = Vector2(-340, -180);notice.size = Vector2(680, 360);notice.add_theme_stylebox_override("panel", Styles.toy_panel());add_child(notice)
	var body: = VBoxContainer.new();body.alignment = BoxContainer.ALIGNMENT_CENTER;body.add_theme_constant_override("separation", 14);notice.add_child(body); var title: = Label.new();title.text = "其余 AI 财团已入场";title.horizontal_alignment = 1;title.add_theme_font_size_override("font_size", 30);title.add_theme_color_override("font_color", Styles.TOY_INK);body.add_child(title)
	for item: Dictionary in selections:
		if bool(item.human): continue
		var company: = GameConfig.by_id("investment_companies", str(item.company_id)); var row: = Label.new();row.text = "◆  %s  %s" % [company.name, company.type];row.horizontal_alignment = 1;row.add_theme_font_size_override("font_size", 19);row.add_theme_color_override("font_color", Color(str(company.color)));body.add_child(row)
	notice.scale = Vector2(0.85, 0.85); var tween: = create_tween();tween.tween_property(notice, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); await _owned_delay(0.9); if is_instance_valid(notice): notice.queue_free()


func _owned_delay(seconds: float) -> void :
	var timer: = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.001, seconds)
	add_child(timer)
	timer.start()
	await timer.timeout
	if is_instance_valid(timer):
		timer.queue_free()


func _first_available_id() -> String:
	var used: = selections.map( func(item: Dictionary) -> String: return str(item.company_id))
	for company: Dictionary in GameConfig.list("investment_companies"):
		if not used.has(str(company.id)):
			return str(company.id)
	return "hengyue"


func _refresh_header() -> void :
	var mode: = ModePolicy.normalize_mode(str(GameFlow.setup.mode))
	$Layout / Header / RosterCounter.text = "%s  第 %d 席 / 共 %d 席" % [
		ModePolicy.label(mode), 
		seat_index + 1, 
		int(GameFlow.setup.player_count), 
	]
	$Layout / Header / CompanyGalleryHeader / Prompt.text = "选择你的投资公司" if seat_index == 0 else "下一位董事选择财团"
	$Layout / Footer / Confirm.disabled = selected_company_id.is_empty()


func _open_name_editor() -> void :
	AudioManager.click()
	var editor: = AcceptDialog.new()
	editor.name = "CompanyNameEditor"
	editor.title = "董事会签章  更改财团名称"
	editor.ok_button_text = "确认刻印"
	editor.min_size = Vector2i(520, 220)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var intro: = Label.new()
	intro.text = "名称将刻入本局资本榜与全部策略战报"
	intro.add_theme_font_size_override("font_size", 17)
	box.add_child(intro)
	var field: = LineEdit.new()
	field.placeholder_text = "输入 1—12 个字符"
	field.max_length = 12
	field.text = $Layout / Content / Dossier / Showcase / NameRow / NameInput.text
	field.custom_minimum_size.y = 52
	box.add_child(field)
	editor.add_child(box)
	add_child(editor)
	editor.confirmed.connect( func() -> void :
		$Layout / Content / Dossier / Showcase / NameRow / NameInput.text = field.text.strip_edges()
		$Layout / Content / Dossier / Showcase / ContractSeal.text = "◉  名称已刻印  待签约"
	)
	editor.close_requested.connect(editor.queue_free)
	editor.popup_centered()
	field.grab_focus()


func _play_contract_signing() -> void :
	$Layout / Footer / Confirm.disabled = true
	$Layout / Content / Dossier / Showcase / ContractSeal.text = "◎  董事会合约签署中…"
	if not GameSettings.reduce_motion:
		var hero: = $Layout / Content / Hero
		var tween: = create_tween().set_parallel(true)
		tween.tween_property(hero, "scale", Vector2(1.018, 1.018), 0.18).set_trans(Tween.TRANS_BACK)
		tween.tween_property($Layout / Content / Dossier, "modulate", Color("fff0be"), 0.18)
		await tween.finished
		hero.scale = Vector2.ONE
		$Layout / Content / Dossier.modulate = Color.WHITE
	$Layout / Content / Dossier / Showcase / ContractSeal.text = "●  SIGNED  合约生效"
	await _owned_delay(0.32)


func _tween_scale(control: Control, target: Vector2) -> void :
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, 0.1)
