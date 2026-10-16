extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const CardScene = preload("res://scenes/CardView.tscn")
const CardVisualLanguage = preload("res://scripts/CardVisualLanguage.gd")
const MUSEUM_BACKGROUND = preload("res://assets/images/v12/collection/capital_collection_museum.png")

const FILTERS: = [
	["all", "全部馆藏"], ["blue", "蓝色  基础"], ["gold", "金色  进阶"], 
	["platinum", "铂金  强力"], ["red", "红色  王牌"], ["gilded", "曜金  典藏"], 
]
const WEST_FILTERS: = [["west_bank_all", "西岸展厅  42"], ["west_bank", "普通卡  39"], ["west_bank_advanced", "高级卡  3"]]
const RARITY_ORDER: = {"west_bank_advanced": 7, "west_bank": 6, "gilded": 5, "red": 4, "platinum": 3, "gold": 2, "blue": 1}

var active_filter: = "all"
var grid: GridContainer
var count_label: Label
var filter_buttons: Dictionary = {}
var detail_overlay: ColorRect
var gallery_scroll: ScrollContainer
var footer_label: Label


func _ready() -> void :
	_build_museum()
	_show_cards()


func _build_museum() -> void :
	var background: = TextureRect.new()
	background.texture = MUSEUM_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil: = ColorRect.new()
	veil.color = Color(0.005, 0.015, 0.025, 0.34)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var margin: = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 38)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)
	var layout: = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header: = HBoxContainer.new()
	header.custom_minimum_size.y = 76
	header.clip_contents = true
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(header)
	var titles: = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var kicker: = Label.new()
	kicker.text = "董事会永久馆藏"
	kicker.add_theme_font_size_override("font_size", 15)
	kicker.add_theme_color_override("font_color", Color("7bc8d4"))
	titles.add_child(kicker)
	var title: = Label.new()
	title.text = "资本典藏馆"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("f4dfad"))
	titles.add_child(title)
	count_label = Label.new()
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size.x = 270
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", Color("d9c27d"))
	header.add_child(count_label)
	var back: = Button.new()
	back.text = "返回首页"
	back.custom_minimum_size = Vector2(128, 50)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	Styles.apply_toy_button(back, false, Color("5eb8ca"), 18)
	back.pressed.connect( func() -> void : AudioManager.click();GameFlow.go("menu"))
	header.add_child(back)

	var wing_bar: = PanelContainer.new()
	wing_bar.add_theme_stylebox_override("panel", Styles.panel(Color(0.012, 0.045, 0.064, 0.94), Color(0.63, 0.48, 0.22, 0.82), 16, 2))
	layout.add_child(wing_bar)
	var wing_margin: = MarginContainer.new()
	wing_margin.add_theme_constant_override("margin_left", 20)
	wing_margin.add_theme_constant_override("margin_right", 20)
	wing_margin.add_theme_constant_override("margin_top", 10)
	wing_margin.add_theme_constant_override("margin_bottom", 10)
	wing_bar.add_child(wing_margin)
	var filter_rows := VBoxContainer.new()
	filter_rows.add_theme_constant_override("separation", 9)
	wing_margin.add_child(filter_rows)
	var filters: = HBoxContainer.new()
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	filters.add_theme_constant_override("separation", 12)
	filter_rows.add_child(filters)
	for spec: Array in FILTERS:
		var button: = Button.new()
		button.text = str(spec[1])
		button.custom_minimum_size = Vector2(174 if str(spec[0]) != "gilded" else 208, 48)
		button.pressed.connect(_set_filter.bind(str(spec[0])))
		filters.add_child(button)
		filter_buttons[str(spec[0])] = button
	var west_filters := HBoxContainer.new()
	west_filters.alignment = BoxContainer.ALIGNMENT_CENTER
	west_filters.add_theme_constant_override("separation", 14)
	filter_rows.add_child(west_filters)
	for spec: Array in WEST_FILTERS:
		var button := Button.new()
		button.text = str(spec[1])
		button.custom_minimum_size = Vector2(224, 50)
		button.pressed.connect(_set_filter.bind(str(spec[0])))
		west_filters.add_child(button)
		filter_buttons[str(spec[0])] = button

	var museum_case: = PanelContainer.new()
	museum_case.size_flags_vertical = Control.SIZE_EXPAND_FILL
	museum_case.add_theme_stylebox_override("panel", Styles.panel(Color(0.006, 0.025, 0.04, 0.92), Color("b3914d"), 22, 3))
	layout.add_child(museum_case)
	var case_margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		case_margin.add_theme_constant_override("margin_%s" % side, 24)
	museum_case.add_child(case_margin)
	gallery_scroll = ScrollContainer.new()
	gallery_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	case_margin.add_child(gallery_scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 34)
	gallery_scroll.add_child(grid)
	resized.connect(_refresh_grid_columns)
	call_deferred("_refresh_grid_columns")

	footer_label = Label.new()
	footer_label.text = "策展提示  点击展品可进入独立鉴赏室  六张曜金典藏卡合计出现率 5%"
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 16)
	footer_label.add_theme_color_override("font_color", Color("acc8cd"))
	layout.add_child(footer_label)
	_refresh_filter_styles()


func _show_cards() -> void :
	for child in grid.get_children():
		child.queue_free()
	var cards: Array = GameConfig.list("cards").filter( func(card: Dictionary) -> bool:
		if active_filter == "all":
			return true
		if active_filter == "west_bank_all":
			return str(card.get("series", "")) == "west_bank"
		return str(card.get("rarity", "")) == active_filter)
	cards.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("series", "")) == "west_bank" and str(b.get("series", "")) == "west_bank":
			return int(a.get("catalog_no", 999)) < int(b.get("catalog_no", 999))
		var rarity_a: = int(RARITY_ORDER.get(str(a.get("rarity", "")), 0))
		var rarity_b: = int(RARITY_ORDER.get(str(b.get("rarity", "")), 0))
		return str(a.get("id", "")) < str(b.get("id", "")) if rarity_a == rarity_b else rarity_a > rarity_b)
	for card: Dictionary in cards:
		var exhibit: = PanelContainer.new()
		exhibit.custom_minimum_size = Vector2(272, 414)
		var accent: = _rarity_color(str(card.get("rarity", "blue")))
		exhibit.add_theme_stylebox_override("panel", Styles.panel(CardVisualLanguage.collection_surface(str(card.get("rarity", "blue"))), Color(accent, 0.72), 18, 2))
		var exhibit_margin: = MarginContainer.new()
		exhibit_margin.add_theme_constant_override("margin_left", 14)
		exhibit_margin.add_theme_constant_override("margin_right", 14)
		exhibit_margin.add_theme_constant_override("margin_top", 12)
		exhibit_margin.add_theme_constant_override("margin_bottom", 12)
		exhibit.add_child(exhibit_margin)
		var exhibit_layout: = VBoxContainer.new()
		exhibit_layout.alignment = BoxContainer.ALIGNMENT_CENTER
		exhibit_layout.add_theme_constant_override("separation", 8)
		exhibit_margin.add_child(exhibit_layout)
		var accession: = Label.new()
		var accession_number := int(card.get("catalog_no", grid.get_child_count() + 1)) if str(card.get("series", "")) == "west_bank" else grid.get_child_count() + 1
		accession.text = "◆  %s展区  NO.%03d" % [_rarity_name(str(card.get("rarity", "blue"))).get_slice("  ", 0), accession_number]
		accession.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		accession.add_theme_font_size_override("font_size", 13)
		accession.add_theme_color_override("font_color", Color(accent, 0.94))
		exhibit_layout.add_child(accession)
		var view: = CardScene.instantiate() as CardView
		view.setup(card)
		view.custom_minimum_size = Vector2(238, 342)
		view.size = view.custom_minimum_size
		view.tooltip_text = "%s\n点击放大查看完整规则" % view.help_text()
		view.pressed.connect(_open_detail.bind(card))
		exhibit_layout.add_child(view)
		var plaque: = Label.new()
		plaque.text = "点击鉴赏  查看完整效果"
		plaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plaque.add_theme_font_size_override("font_size", 13)
		plaque.add_theme_color_override("font_color", Color("b9cbd0"))
		exhibit_layout.add_child(plaque)
		grid.add_child(exhibit)
	count_label.text = "当前展柜  %d 张  /  全馆  %d 张" % [cards.size(), GameConfig.list("cards").size()]
	if is_instance_valid(footer_label):
		footer_label.text = "西岸高级卡共3张  ·  每次西岸五选一合计出现率8%  ·  一次最多出现1张" if active_filter in ["west_bank_all", "west_bank", "west_bank_advanced"] else "策展提示  点击展品可进入独立鉴赏室  六张曜金典藏卡合计出现率 5%"
	call_deferred("_refresh_grid_columns")


func _refresh_grid_columns() -> void :
	if not is_instance_valid(grid):
		return
	var available: = maxf(900.0, size.x - 130.0)
	grid.columns = clampi(int(available / 304.0), 3, 5)


func _set_filter(filter_id: String) -> void :
	AudioManager.click()
	active_filter = filter_id
	_refresh_filter_styles()
	_show_cards()


func _refresh_filter_styles() -> void :
	for filter_id: String in filter_buttons:
		var button: = filter_buttons[filter_id] as Button
		var accent: = _rarity_color(filter_id)
		Styles.apply_toy_button(button, filter_id == active_filter, accent, 16)


func _open_detail(card: Dictionary) -> void :
	AudioManager.card_flip()
	if is_instance_valid(detail_overlay):
		detail_overlay.queue_free()
	detail_overlay = ColorRect.new()
	detail_overlay.color = Color(0.002, 0.008, 0.014, 0.92)
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_overlay.z_index = 500
	add_child(detail_overlay)
	var shell: = PanelContainer.new()
	shell.set_anchors_preset(Control.PRESET_CENTER)
	shell.offset_left = -540
	shell.offset_top = -350
	shell.offset_right = 540
	shell.offset_bottom = 350
	shell.add_theme_stylebox_override("panel", Styles.panel(Color(0.012, 0.048, 0.072, 0.99), _rarity_color(str(card.get("rarity", "blue"))), 24, 3))
	detail_overlay.add_child(shell)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	shell.add_child(margin)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 38)
	margin.add_child(row)
	var card_view: = CardScene.instantiate() as CardView
	card_view.setup(card)
	card_view.custom_minimum_size = Vector2(390, 546)
	card_view.size = card_view.custom_minimum_size
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(card_view)
	var details: = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 16)
	row.add_child(details)
	var badge: = Label.new()
	badge.text = _rarity_name(str(card.get("rarity", "blue")))
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", _rarity_color(str(card.get("rarity", "blue"))))
	details.add_child(badge)
	var name_label: = Label.new()
	name_label.text = str(card.get("name", "策略卡"))
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", Color("f3e7c8"))
	details.add_child(name_label)
	var rule: = Label.new()
	var probability_note := "\n\n高级卡合计出现率 8% · 每次西岸五选一最多出现1张" if str(card.get("rarity", "")) == "west_bank_advanced" else ""
	rule.text = "消耗 %d SP  %s\n\n%s\n\n关键词  ◆  %s%s" % [int(card.get("cost", 0)), _target_name(str(card.get("target", "self"))), str(card.get("description", "")), "  ".join(card.get("keywords", [])), probability_note]
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule.add_theme_font_size_override("font_size", 20)
	rule.add_theme_color_override("font_color", Color("d7e3e5"))
	rule.add_theme_constant_override("line_spacing", 7)
	details.add_child(rule)
	var close: = Button.new()
	close.text = "收入档案并返回展柜"
	close.custom_minimum_size.y = 58
	Styles.apply_toy_button(close, true, _rarity_color(str(card.get("rarity", "blue"))), 18)
	close.pressed.connect(_close_detail)
	details.add_child(close)
	if not GameSettings.reduce_motion:
		shell.scale = Vector2(0.92, 0.92)
		shell.pivot_offset = shell.size * 0.5
		create_tween().tween_property(shell, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_detail() -> void :
	AudioManager.click()
	if is_instance_valid(detail_overlay):
		detail_overlay.queue_free()
	detail_overlay = null


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(detail_overlay):
			_close_detail()
		else:
			GameFlow.go("menu")


func _rarity_color(rarity: String) -> Color:
	return {"all": Color("65b9c8"), "blue": Color("4f9bc8"), "gold": Color("d8ad50"), "platinum": Color("b8d2dc"), "red": Color("e15b62"), "gilded": Color("e7c46d"), "west_bank_all": Color("bd68ee"), "west_bank": Color("72e0e6"), "west_bank_advanced": Color("f06bdc")}.get(rarity, Color("65b9c8"))


func _rarity_name(rarity: String) -> String:
	return {"blue": "蓝色  基础", "gold": "金色  进阶", "platinum": "铂金  强力", "red": "红色  王牌", "gilded": "曜金典藏  超稀有", "west_bank": "西岸普通  霓虹策略", "west_bank_advanced": "西岸高级  稀有策略"}.get(rarity, rarity)


func _target_name(target: String) -> String:
	return {"self": "目标：己方财团", "district": "目标：一个城市商圈", "enemy": "目标：一名对手", "enemy_business": "目标：对手企业", "own_business": "目标：己方企业", "stock": "目标：证券标的", "available_land": "目标：待售土地"}.get(target, "目标：当前合法对象")
