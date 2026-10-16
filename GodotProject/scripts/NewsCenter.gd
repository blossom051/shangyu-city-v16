extends Control


const UIStyles = preload("res://scripts/UIStyles.gd")
const NewsModel = preload("res://scripts/CityNewsModel.gd")
const CityPulse = preload("res://scripts/NewspaperCityPulse.gd")
const BODY_FONT = preload("res://Themes/V9141BodyFont.tres")
const MEDIUM_FONT = preload("res://Themes/V9141BodyMediumFont.tres")

const PAPER: = Color("f1ead8")
const PAPER_LIGHT: = Color("fbf6e8")
const INK: = Color("20221f")
const MUTED: = Color("5d615c")
const RED: = Color("8f302c")
const GREEN: = Color("2c6653")
const GOLD: = Color("9a722d")
const BLUE: = Color("2d6f84")
const NIGHT: = Color("0a2530")

var issue: Dictionary = {}
var articles: Array[Dictionary] = []


func _ready() -> void :
	issue = NewsModel.build_issue()
	for item: Variant in issue.get("stories", []):
		if item is Dictionary:
			articles.append((item as Dictionary).duplicate(true))
	_build_page()


func readability_profile() -> Dictionary:
	var audit: Dictionary = NewsModel.privacy_audit(issue)
	return {
		"core_story_count": articles.size(), 
		"actionable_story_count": articles.filter( func(story: Dictionary) -> bool: return not str(story.get("watch", "")).is_empty()).size(), 
		"non_stock_story_count": articles.filter( func(story: Dictionary) -> bool: return str(story.get("section", "")) != "市场观察").size(), 
		"has_lead": has_node("Page/Main/Paper/Margin/Body/Columns/Lead"), 
		"has_quick_read": has_node("Page/Main/Rail/QuickRead"), 
		"has_city_desk": has_node("Page/Main/Paper/Margin/Body/Columns/CityDesk"), 
		"has_impact_labels": has_node("Page/Main/Paper/Margin/Body/Columns/Lead/StoryFacts/Impact"), 
		"privacy_ok": bool(audit.get("ok", false)), 
		"paper_outline_max": _paper_outline_max(), 
		"body_font_min": _paper_body_font_min(), 
		"has_city_pulse": has_node("Page/Main/Paper/Margin/Body/Columns/Lead/CityPulse"), 
		"has_public_schedule": has_node("Page/Main/Rail/PublicSchedule"), 
	}


func debug_newspaper_summary() -> Dictionary:
	var main: = get_node_or_null("Page/Main") as Control
	var paper: = get_node_or_null("Page/Main/Paper") as Control
	var rail: = get_node_or_null("Page/Main/Rail") as Control
	var width: = main.size.x if main else 0.0
	return {
		"has_masthead": has_node("Page/Header/Brand/Title"), 
		"has_columns": has_node("Page/Main/Paper/Margin/Body/Columns"), 
		"has_signal_chart": has_node("Page/Main/Paper/Margin/Body/Columns/Lead/CityPulse"), 
		"article_count": articles.size(), "placed_story_count": articles.size(), 
		"lead_story_count": 1 if not articles.is_empty() else 0, 
		"brief_story_count": maxi(0, articles.size() - 1), 
		"asset_story_count": articles.filter( func(item: Dictionary) -> bool: return str(item.get("section", "")) in ["土地市场", "产业观察"]).size(), 
		"risk_story_count": 0, 
		"data_card_count": 3, "summary_line_limit": 3, "body_font_min": _paper_body_font_min(), 
		"paper_ratio": 0.0 if width <= 0.0 or paper == null else paper.size.x / width, 
		"rail_ratio": 0.0 if width <= 0.0 or rail == null else rail.size.x / width, 
		"round": int(issue.get("round", 0)), 
		"archive_count": GameState.game_data.get("city_news_public_history", []).size(), 
	}


func _build_page() -> void :
	$Background.color = NIGHT
	var page: = VBoxContainer.new()
	page.name = "Page"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 22;page.offset_top = 12;page.offset_right = -22;page.offset_bottom = -14
	page.add_theme_constant_override("separation", 8)
	add_child(page)
	page.add_child(_header())
	var main: = HBoxContainer.new()
	main.name = "Main"
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	page.add_child(main)
	main.add_child(_paper())
	main.add_child(_rail())


func _header() -> Control:
	var header: = HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = 56
	var brand: = VBoxContainer.new()
	brand.name = "Brand"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var title: = _dark_label("商域晨报", 30, Color("f4ead1"), true)
	title.name = "Title"
	brand.add_child(title)
	brand.add_child(_dark_label("CITY BUSINESS JOURNAL  只报道城市公共变化", 12, Color("96b6bd")))
	var issue_label: = _dark_label("%s  %s" % [str(issue.get("edition", "城市版")), str(issue.get("date_line", ""))], 16, Color("dbc178"), true)
	issue_label.custom_minimum_size.x = 310
	issue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(issue_label)
	var back: = Button.new()
	back.text = "返回城市"
	back.custom_minimum_size = Vector2(116, 48)
	UIStyles.apply_toy_button(back, true, Color("d0a64e"), 16)
	back.pressed.connect(_return_to_city)
	header.add_child(back)
	return header


func _return_to_city() -> void :
	if TutorialDirector.active:
		TutorialDirector.return_to_city_from_auxiliary("news_center", "first_round_plan")
	GameFlow.go("city")


func _paper() -> Control:
	var paper: = PanelContainer.new()
	paper.name = "Paper"
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", _panel(PAPER, Color("b8aa86"), 10, 2, 8))
	var margin: = MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	paper.add_child(margin)
	var body: = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var masthead: = HBoxContainer.new()
	masthead.name = "Masthead"
	body.add_child(masthead)
	var mast_left: = _paper_label("城市  产业  土地  人才", 13, MUTED)
	mast_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(mast_left)
	var mast_title: = _paper_label("商 域 晨 报", 39, INK, true)
	mast_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	masthead.add_child(mast_title)
	var mast_right: = _paper_label("公共信息版", 13, RED, true)
	mast_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mast_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	masthead.add_child(mast_right)
	body.add_child(_rule(2, INK))
	body.add_child(_metric_strip())
	body.add_child(_rule(1, Color("9d8d69")))
	var columns: = HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	body.add_child(columns)
	columns.add_child(_lead())
	columns.add_child(_desk("CityDesk", "城市与产业", [1, 2]))
	columns.add_child(_desk("ActionDesk", "土地与人才", [3, 4]))
	if get_viewport_rect().size.y >= 900:
		body.add_child(_briefs())
	return paper


func _metric_strip() -> Control:
	var row: = HBoxContainer.new()
	row.name = "KeyMetrics"
	row.custom_minimum_size.y = 66
	row.add_theme_constant_override("separation", 12)
	var metrics: Array = issue.get("public_metrics", [])
	for index in metrics.size():
		var metric: Dictionary = metrics[index]
		var item: = VBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_constant_override("separation", 1)
		item.add_child(_paper_label(str(metric.get("label", "城市指标")), 13, MUTED, true))
		item.add_child(_paper_label(str(metric.get("value", "--")), 23, _metric_color(index), true))
		item.add_child(_paper_label(str(metric.get("trend", "")), 12, MUTED))
		row.add_child(item)
		if index < metrics.size() - 1:
			var separator: = VSeparator.new()
			separator.add_theme_constant_override("separation", 6)
			row.add_child(separator)
	return row


func _lead() -> Control:
	var story: Dictionary = articles[0] if not articles.is_empty() else {}
	var lead: = VBoxContainer.new()
	lead.name = "Lead"
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_stretch_ratio = 1.7
	lead.add_theme_constant_override("separation", 7)
	lead.add_child(_paper_label("头版  %s" % str(story.get("section", "城市")), 13, RED, true))
	var headline: = _paper_label(str(story.get("headline", "城市公共信息更新")), 26, INK, true)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.custom_minimum_size.y = 68
	headline.max_lines_visible = 2
	lead.add_child(headline)
	var pulse: = CityPulse.new()
	pulse.name = "CityPulse"
	pulse.custom_minimum_size = Vector2(0, 204 if get_viewport_rect().size.y >= 900 else 136)
	pulse.setup(issue.get("pulse", []))
	lead.add_child(pulse)
	var facts: = VBoxContainer.new()
	facts.name = "StoryFacts"
	facts.add_theme_constant_override("separation", 5)
	lead.add_child(facts)
	facts.add_child(_fact("发生", str(story.get("summary", "")), INK, "What"))
	facts.add_child(_fact("影响", str(story.get("signal", "")), RED, "Impact"))
	facts.add_child(_fact("关注", str(story.get("watch", "")), GREEN, "Action"))
	return lead


func _desk(node_name: String, title: String, indexes: Array[int]) -> Control:
	var desk: = VBoxContainer.new()
	desk.name = node_name
	desk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desk.add_theme_constant_override("separation", 8)
	desk.add_child(_paper_label(title, 19, INK, true))
	desk.add_child(_rule(2, INK))
	for index in indexes:
		if index >= articles.size():
			continue
		var story: Dictionary = articles[index]
		var item: = VBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		item.add_child(_paper_label(str(story.get("section", "城市")), 12, _tone_color(str(story.get("tone", "neutral"))), true))
		var title_label: = _paper_label(str(story.get("headline", "公共消息")), 18, INK, true)
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.max_lines_visible = 2
		item.add_child(title_label)
		var summary: = _paper_label(str(story.get("summary", "")), 16, MUTED, false, true)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.max_lines_visible = 3 if get_viewport_rect().size.y >= 900 else 2
		item.add_child(summary)
		var signal_label: = _paper_label("看点｜%s" % str(story.get("signal", "")), 16, GREEN, false, true)
		signal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		signal_label.max_lines_visible = 3 if get_viewport_rect().size.y >= 900 else 2
		item.add_child(signal_label)
		desk.add_child(item)
		if index != indexes[-1]:
			desk.add_child(_rule(1, Color("b9aa85")))
	return desk


func _fact(prefix: String, value: String, color: Color, node_name: String) -> Control:
	var row: = HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", 8)
	var badge: = _paper_label(prefix, 13, PAPER_LIGHT, true)
	badge.custom_minimum_size = Vector2(46, 28)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _panel(color, color, 4, 0, 0))
	row.add_child(badge)
	var text: = _paper_label(value, 16, INK, false, true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 3
	row.add_child(text)
	return row


func _briefs() -> Control:
	var row: = HBoxContainer.new()
	row.name = "PublicBriefs"
	row.custom_minimum_size.y = 86
	row.add_theme_constant_override("separation", 18)
	for index in range(5, mini(7, articles.size())):
		var story: Dictionary = articles[index]
		var item: = VBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(_paper_label("简讯  %s" % str(story.get("section", "公共事件")), 12, _tone_color(str(story.get("tone", "neutral"))), true))
		item.add_child(_paper_label(str(story.get("headline", "城市公共消息更新")), 17, INK, true))
		var summary: = _paper_label(str(story.get("summary", "")), 16, MUTED, false, true)
		summary.max_lines_visible = 2
		item.add_child(summary)
		row.add_child(item)
	return row


func _rail() -> Control:
	var rail: = VBoxContainer.new()
	rail.name = "Rail"
	rail.custom_minimum_size.x = 286
	rail.add_theme_constant_override("separation", 10)
	var quick: = _rail_panel("QuickRead", "本轮三条看点", RED)
	var quick_body: = quick.get_node("Body") as VBoxContainer
	for index in mini(3, issue.get("watch_list", []).size()):
		quick_body.add_child(_dark_label("%d  %s" % [index + 1, str(issue.get("watch_list", [])[index])], 15, Color("edf2e9"), index == 0))
	rail.add_child(quick)
	var schedule: = _rail_panel("PublicSchedule", "城市公共日程", GOLD)
	var schedule_body: = schedule.get_node("Body") as VBoxContainer
	for entry: Dictionary in issue.get("schedule", []):
		var line: = HBoxContainer.new()
		var label: = _dark_label(str(entry.get("label", "日程")), 14, Color("a8c1c5"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var value_label: = _dark_label(str(entry.get("value", "待定")), 14, Color("efd27c"), true)
		value_label.custom_minimum_size.x = 112
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value_label)
		schedule_body.add_child(line)
	rail.add_child(schedule)
	var thermometer: = _rail_panel("CityThermometer", "商圈温度计", BLUE)
	var thermometer_body: = thermometer.get_node("Body") as VBoxContainer
	for district: Dictionary in issue.get("pulse", []).slice(0, 5):
		thermometer_body.add_child(_heat_row(district))
	rail.add_child(thermometer)
	var note: = _dark_label("报纸只刊登城市公共变化\n财团经营数据请在经营驾驶舱查看", 13, Color("92acb1"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail.add_child(note)
	return rail


func _rail_panel(node_name: String, title: String, accent: Color) -> PanelContainer:
	var panel: = PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _panel(Color("0c303b"), Color(accent, 0.82), 10, 12, 4))
	var body: = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 7)
	body.add_child(_dark_label(title, 18, Color("f1d886"), true))
	body.add_child(_rule(2, accent))
	panel.add_child(body)
	return panel


func _heat_row(district: Dictionary) -> Control:
	var row: = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var top: = HBoxContainer.new()
	var name_label: = _dark_label(str(district.get("name", "城市街区")), 13, Color("dce8e7"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var heat_value: = _dark_label("%.0f" % float(district.get("heat", 100.0)), 13, Color("f1ca70"), true)
	heat_value.custom_minimum_size.x = 36
	heat_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	heat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(heat_value)
	row.add_child(top)
	var bar: = ProgressBar.new()
	bar.custom_minimum_size.y = 7
	bar.min_value = 70
	bar.max_value = 140
	bar.value = clampf(float(district.get("heat", 100.0)), 70.0, 140.0)
	bar.show_percentage = false
	var background: = StyleBoxFlat.new();background.bg_color = Color("173e48");background.set_corner_radius_all(4)
	var fill: = StyleBoxFlat.new();fill.bg_color = _heat_color(float(district.get("heat", 100.0)));fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row


func _paper_label(value: String, size_value: int, color: Color, medium: = false, body_text: = false) -> Label:
	var label: = Label.new()
	label.text = value
	label.add_theme_font_override("font", MEDIUM_FONT if medium else BODY_FONT)
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_text:
		label.set_meta("paper_body", true)
	return label


func _dark_label(value: String, size_value: int, color: Color, medium: = false) -> Label:
	var label: = _paper_label(value, size_value, color, medium)
	return label


func _paper_outline_max() -> int:
	var paper: = get_node_or_null("Page/Main/Paper")
	var maximum: = 0
	if paper == null:
		return 99
	for node: Node in paper.find_children("*", "Label", true, false):
		maximum = maxi(maximum, (node as Label).get_theme_constant("outline_size"))
	return maximum


func _paper_body_font_min() -> int:
	var paper: = get_node_or_null("Page/Main/Paper")
	var minimum: = 999
	if paper == null:
		return 0
	for node: Node in paper.find_children("*", "Label", true, false):
		if node.has_meta("paper_body"):
			minimum = mini(minimum, (node as Label).get_theme_font_size("font_size"))
	return 0 if minimum == 999 else minimum


func _metric_color(index: int) -> Color:
	return [BLUE, GREEN, GOLD, RED][index % 4]


func _tone_color(tone: String) -> Color:
	return {"hot": RED, "cool": BLUE, "business": GREEN, "property": GOLD, "talent": Color("76529a"), "event": RED, "decision": GREEN, "market": BLUE}.get(tone, MUTED)


func _heat_color(value: float) -> Color:
	var ratio: = clampf((value - 75.0) / 60.0, 0.0, 1.0)
	return Color("3889a0").lerp(Color("b94035"), ratio)


func _rule(height: int, color: Color) -> ColorRect:
	var rule: = ColorRect.new()
	rule.custom_minimum_size = Vector2(0, height)
	rule.color = color
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _panel(fill: Color, border: Color, radius: int, padding: int, shadow: int) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding;style.content_margin_right = padding
	style.content_margin_top = padding;style.content_margin_bottom = padding
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = shadow
	return style
