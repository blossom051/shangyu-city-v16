extends Control

const UIStyles = preload("res://scripts/UIStyles.gd")
const Startups = preload("res://scripts/StartupInvestmentSystem.gd")
const ScreenDecorator = preload("res://scripts/V7ScreenDecorator.gd")
const StartupProjectCard = preload("res://scripts/StartupProjectCard.gd")
const DueDiligenceDialog = preload("res://scripts/StartupDueDiligenceDialog.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	ScreenDecorator.decorate(self, "startup")
	$Layout / Projects.columns = 3
	$Layout / Header / Back.text = "返回城市"
	$Layout / Header / Back.pressed.connect(_return_to_city)
	_style()
	_build()


func _build() -> void :
	$Layout / Header / Cash.text = "可用现金  %s" % UIStyles.money(int(GameState.active_player().cash))
	var projects: = GameConfig.list("startup_projects").slice(0, 3) if TutorialDirector.active and TutorialDirector.current_step_id() == "startup_review" else Startups.projects_for_round()
	$Layout / Projects.columns = 4 if projects.size() >= 4 else 3
	if projects.is_empty():
		var next_round: = Startups.next_event_round()
		$Layout / Header / Title.text = "创业投资  项目预告"
		$Layout / Message.text = "本局项目投资已结束" if next_round < 0 else "下一批创投项目将在第 %d 回合开放" % next_round
		_refresh_portfolio()
		return
	$Layout / Header / Title.text = "创业投资  第 %d 回合项目投决" % int(GameState.game_data.round)
	var hinted_id: = _apply_company_hint(projects)
	for project: Dictionary in projects:
		var card: = Button.new()
		card.set_script(StartupProjectCard)
		card.setup(project)
		if str(project.id) == hinted_id:
			card.tooltip_text = _qiming_hint_text(project)
		if GameState.active_player().active_projects.any( func(item: Dictionary) -> bool: return str(item.project_id) == str(project.id)):
			card.set_invested()
		card.pressed.connect(_open_project_detail.bind(str(project.id), card))
		card.mouse_entered.connect(AudioManager.hover)
		$Layout / Projects.add_child(card)
	_refresh_portfolio()


func _apply_company_hint(projects: Array) -> String:
	var player: = GameState.active_player()
	var hint: = $Layout / CompanyHint as Label
	if player.is_empty() or not CompanyRules.bool_ability(str(player.company_id), "startup_hint", false) or projects.is_empty():
		hint.visible = false
		return ""
	var best: Dictionary = projects[0]
	var best_score: = - INF
	for project: Dictionary in projects:
		var cost: = float(project.get("cost", 0))
		var score: = float(project.get("base_success", 0.0)) * cost * float(project.get("financing_multiplier", 1.0)) - cost
		if score > best_score:
			best_score = score
			best = project
	hint.visible = true
	hint.text = "◆ 启明创投研判  %s\n%s" % [
		str(best.get("name", "候选项目")), 
		_qiming_hint_text(best), 
	]
	hint.add_theme_color_override("font_color", Color("79b8ff"))
	return str(best.get("id", ""))


func _qiming_hint_text(project: Dictionary) -> String:
	var cost: = int(project.get("cost", 0))
	var maximum_return: = roundi(float(cost) * float(project.get("financing_multiplier", 1.0)))
	return "基础成功率 %d%%  回报区间 0—%s  主要风险：失败损失本金并增加 8 风险（不保证成功）" % [
		roundi(float(project.get("base_success", 0.0)) * 100.0), 
		UIStyles.money(maximum_return), 
	]


func _open_project_detail(id: String, button: Button) -> void:
	if has_node("StartupDueDiligenceDialog"):
		return
	var dialog := DueDiligenceDialog.new()
	dialog.name = "StartupDueDiligenceDialog"
	dialog.open_for_project(str(GameState.active_player().id), id, button)
	dialog.investment_completed.connect(_apply_investment_result.bind(button))
	add_child(dialog)


func _apply_investment_result(result: Dictionary, button: Button) -> void :
	$Layout / Message.text = str(result.message)
	if bool(result.ok):
		AudioManager.success()
		button.set_invested()
		$Layout / Message.text = "投资确认  已扣 %s  剩余现金 %s  成功率 %d%%  %d 回合后揭晓  预期融资 %s" % [UIStyles.money(int(result.get("invested", 0))), UIStyles.money(int(result.get("cash_after", 0))), roundi(float(result.get("success_rate", 0.0)) * 100.0), int(result.get("remaining_rounds", 0)), UIStyles.money(int(result.get("expected_financing", 0)))]
		$Layout / Header / Cash.text = "可用现金  %s" % UIStyles.money(int(GameState.active_player().cash))
		_refresh_portfolio()


func _return_to_city() -> void :
	if TutorialDirector.active:
		TutorialDirector.return_to_city_from_auxiliary("startup_center")
	GameFlow.go("city")


func _refresh_portfolio() -> void :
	var player: Dictionary = GameState.active_player()
	var items: Array = player.get("active_projects", [])
	var active_count: = 0
	var invested_total: = 0
	for item: Dictionary in items:
		invested_total += int(item.get("cost", 0))
		if str(item.get("status", "active")) == "active":
			active_count += 1
	var next_round: = Startups.next_event_round()
	$Layout / Portfolio / Content / Header / Stats.text = "已投 %d  进行中 %d  累计 %s  %s" % [items.size(), active_count, UIStyles.money(invested_total), "本局项目已结束" if next_round < 0 else "下一批 第 %d 回合" % next_round]
	var cards: HBoxContainer = $Layout / Portfolio / Content / Cards
	for child: Node in cards.get_children():
		child.queue_free()
	if items.is_empty():
		cards.add_child(_pipeline_strip())
	else:
		var recent: = items.slice(maxi(0, items.size() - 3), items.size())
		for item: Dictionary in recent:
			cards.add_child(_portfolio_card(item))


func _portfolio_card(item: Dictionary) -> Control:
	var project: = GameConfig.by_id("startup_projects", str(item.project_id))
	var status: = str(item.get("status", "active"))
	var accent: = Color("e0b95c") if status == "active" else Color("5ed39c") if status == "success" else Color("e87982")
	var panel: = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyles.panel(Color("0b2834f2"), Color(accent, 0.78), 12, 4))
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var phase: = "尽调进行中  剩余 %d 回合" % int(item.get("remaining_rounds", 0)) if status == "active" else "投资退出  已形成收益" if status == "success" else "投资复盘  获得经验加成"
	column.add_child(_portfolio_label("%s  /  %s" % [str(item.get("project_id", "SP")).to_upper(), phase], 13, accent))
	column.add_child(_portfolio_label("%s  %s" % [str(project.get("name", "创业项目")), str(item.get("founder", "创始人"))], 20, Color("f2f5f3")))
	column.add_child(_portfolio_label("%s赛道  已投入 %s  预期融资 %s" % [str(item.get("sector", "consumer")).to_upper(), UIStyles.money(int(item.get("cost", 0))), UIStyles.money(int(item.get("expected_financing", 0)))], 14, Color("a9c1c7")))
	var progress: = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 15)
	progress.show_percentage = false
	progress.value = 100.0 if status != "active" else 35.0 if int(item.get("remaining_rounds", 1)) >= 2 else 68.0
	column.add_child(progress)
	var footer: = "成功概率 %d%%  当前估值 %s" % [roundi(float(item.get("success_rate", 0.0)) * 100.0), UIStyles.money(int(item.get("current_valuation", 0)))]
	column.add_child(_portfolio_label(footer, 14, accent))
	return panel


func _pipeline_strip() -> Control:
	var panel: = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyles.panel(Color("0b2834b8"), Color("4a7d86"), 12, 2))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 18); panel.add_child(row)
	for spec: Array in [["项目固定", "本轮不刷新", Color("e0b95c")], ["尽调 1—2 轮", "确认后扣款", Color("56b9b0")], ["真实结算", "联动估值与风险", Color("5fa7df")]]:
		var label := _portfolio_label("%s\n%s" % [str(spec[0]), str(spec[1])], 16, spec[2]); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	return panel


func _portfolio_label(value: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _style() -> void :
	UIStyles.apply_labels($Layout, UIStyles.TOY_INK)
	UIStyles.apply_button($Layout / Header / Back, false, UIStyles.TOY_BLUE, 18)
	$Layout / Header / Back.mouse_entered.connect(AudioManager.hover)
	$Layout / Header / Title.add_theme_color_override("font_color", Color("f1f4ef"))
	$Layout / Header / Cash.add_theme_color_override("font_color", Color("e2bd66"))
	$Layout / Portfolio.add_theme_stylebox_override("panel", UIStyles.panel(Color("0a2430d8"), Color("3f727b"), 14, 6))
	$Layout / Portfolio / Content / Header / Title.add_theme_color_override("font_color", Color("e7efed"))
	$Layout / Portfolio / Content / Header / Stats.add_theme_color_override("font_color", Color("8db4ba"))
	$Layout / Message.add_theme_color_override("font_color", Color("dce9e8"))
	$Layout / Message.text = "点击项目先查看尽调详情；同一项目每名玩家仅可投资一次。"
