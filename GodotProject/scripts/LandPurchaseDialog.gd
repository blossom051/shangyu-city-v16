class_name LandPurchaseDialog
extends Control

signal purchase_confirmed(player_id: String, land_id: String)

const Styles = preload("res://scripts/UIStyles.gd")
const Businesses = preload("res://scripts/BusinessSystem.gd")

var player_id: = ""
var land_id: = ""
var modal_layer: CanvasLayer
var interactive_root: Control
var modal_token: = 0


func open_purchase(next_player_id: String, next_land_id: String) -> void :
	player_id = next_player_id
	land_id = next_land_id


func _ready() -> void :
	name = "LandPurchaseDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("managed_modal_owner")
	modal_layer = CanvasLayer.new()
	modal_layer.name = "LandPurchaseLayer"
	modal_layer.layer = 1600
	add_child(modal_layer)
	interactive_root = Control.new()
	interactive_root.name = "LandPurchaseSurface"
	interactive_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interactive_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(interactive_root)
	_build()
	modal_token = ModalManager.open_modal("land_purchase", self, interactive_root, modal_layer)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "land_purchase_closed"))


func _build() -> void :
	var shade: = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.018, 0.03, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	interactive_root.add_child(shade)
	var panel: = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-410, -244)
	panel.size = Vector2(820, 488)
	panel.add_theme_stylebox_override("panel", Styles.panel(Color("071f2a"), Color("d9b657"), 28, 4))
	interactive_root.add_child(panel)
	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 26)
	panel.add_child(margin)
	var body: = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)
	var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
	var player: Dictionary = GameState.player(player_id)
	var quote: = Businesses.land_purchase_quote(player_id, land_id)
	_build_header(body, land)
	var divider: = HSeparator.new();body.add_child(divider)
	var flow_panel: = PanelContainer.new()
	flow_panel.name = "PurchaseFlow"
	flow_panel.add_theme_stylebox_override("panel", Styles.panel(Color("0a2833"), Color("3c7180"), 18, 1))
	body.add_child(flow_panel)
	var flow: = HBoxContainer.new()
	flow.alignment = BoxContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("separation", 13)
	flow_panel.add_child(flow)
	_add_flow_metric(flow, "land", "挂牌", Styles.money(int(quote.get("list_price", land.get("price", 0)))), Color("68c5d8"), "公开挂牌价格")
	_add_flow_arrow(flow)
	_add_flow_metric(flow, "cash", "应付", Styles.money(int(quote.get("total", land.get("price", 0)))), Color("f1c65f"), "确认后立即扣款", true)
	_add_flow_arrow(flow)
	_add_flow_metric(flow, "cash", "余额", Styles.money(int(player.get("cash", 0)) - int(quote.get("total", land.get("price", 0)))), Color("72d5c5"), "签约后的可用现金")
	_build_adjustment_status(body, quote)
	var premium_check := Businesses.premium_land_eligibility(player_id) if bool(land.get("premium_zone", false)) else {"ok": true}
	if bool(land.get("premium_zone", false)):
		var qualification := Label.new(); qualification.text = "西岸准入  %s" % str(premium_check.get("message", "")); qualification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; qualification.add_theme_font_size_override("font_size", 15); qualification.add_theme_color_override("font_color", Color("77d3ae") if bool(premium_check.get("ok", false)) else Color("ed7777")); body.add_child(qualification)
	var actions: = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 14)
	body.add_child(actions)
	var cancel: = Button.new()
	cancel.name = "CancelPurchase"
	cancel.text = "返回城市"
	cancel.custom_minimum_size = Vector2(170, 54)
	Styles.apply_toy_button(cancel, false, Styles.TOY_BLUE, 17)
	cancel.pressed.connect(queue_free)
	actions.add_child(cancel)
	var confirm: = Button.new()
	confirm.name = "ConfirmPurchase"
	confirm.text = "确认购买  %s" % Styles.money(int(quote.get("total", land.get("price", 0))))
	confirm.custom_minimum_size = Vector2(230, 56)
	confirm.disabled = not bool(premium_check.get("ok", false))
	confirm.tooltip_text = str(premium_check.get("message", ""))
	Styles.apply_toy_button(confirm, true, Styles.TOY_YELLOW, 18)
	confirm.pressed.connect(_confirm)
	actions.add_child(confirm)


func _build_header(parent: VBoxContainer, land: Dictionary) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var seal: = preload("res://scripts/LandContractSeal.gd").new()
	seal.custom_minimum_size = Vector2(92, 92)
	row.add_child(seal)
	var identity: = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	var kicker: = Label.new();kicker.text = "土地签约";kicker.add_theme_font_size_override("font_size", 13);kicker.add_theme_color_override("font_color", Color("6fc8d4"));identity.add_child(kicker)
	var title: = Label.new();title.text = str(land.get("district_name", "城市地块"));title.add_theme_font_size_override("font_size", 31);title.add_theme_color_override("font_color", Color("f5ead4"));identity.add_child(title)
	var parcel: = Label.new();parcel.text = "%s  城市产权" % land_id;parcel.add_theme_font_size_override("font_size", 17);parcel.add_theme_color_override("font_color", Color("80d6e0"));identity.add_child(parcel)
	row.add_child(identity)
	var status: = Label.new()
	status.text = "待签署"
	status.custom_minimum_size.x = 120
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color("72d5aa"))
	status.add_theme_stylebox_override("normal", Styles.panel(Color("0d352f"), Color("5eb993"), 16, 2))
	row.add_child(status)


func _add_flow_metric(parent: HBoxContainer, icon_key: String, label_text: String, value_text: String, color: Color, help_text: String, emphasized: = false) -> void :
	var item: = HBoxContainer.new()
	item.custom_minimum_size = Vector2(202 if emphasized else 190, 94)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 10)
	item.tooltip_text = help_text
	var texture: Texture2D = null
	if icon_key != "land":
		texture = VisualAssets.get_icon(icon_key)
	if texture != null:
		var icon: = TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(40 if emphasized else 36, 40 if emphasized else 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.add_child(icon)
	elif icon_key == "land":
		var parcel_seal: = preload("res://scripts/LandContractSeal.gd").new()
		parcel_seal.custom_minimum_size = Vector2(40, 40)
		parcel_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(parcel_seal)
	var text: = VBoxContainer.new()
	text.custom_minimum_size = Vector2(112, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	item.add_child(text)
	var label: = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("a9c0c6"))
	text.add_child(label)
	var value: = Label.new()
	value.text = value_text
	value.custom_minimum_size = Vector2(112, 34)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	value.add_theme_font_size_override("font_size", 28 if emphasized else 24)
	value.add_theme_color_override("font_color", color)
	text.add_child(value)
	parent.add_child(item)


func _add_flow_arrow(parent: HBoxContainer) -> void :
	var arrow: = Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 25)
	arrow.add_theme_color_override("font_color", Color("668994"))
	parent.add_child(arrow)


func _build_adjustment_status(parent: VBoxContainer, quote: Dictionary) -> void :
	var list_price: = int(quote.get("list_price", 0))
	var base_after_discounts: = int(quote.get("base_after_discounts", list_price))
	var surcharge: = int(quote.get("risk_surcharge", 0))
	var surcharge_rate: = float(quote.get("risk_surcharge_rate", 0.0))
	var row: = HBoxContainer.new()
	row.name = "PurchaseAdjustments"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	if base_after_discounts < list_price:
		_add_status_chip(row, "优惠  -%s" % Styles.money(list_price - base_after_discounts), Color("72d5c5"), "经营能力或卡牌带来的土地优惠")
	if surcharge > 0:
		var accent: = Color("e2b45e") if surcharge_rate < 0.1 else Color("e98562") if surcharge_rate < 0.18 else Color("dc5865")
		_add_status_chip(row, "信用附加费  +%s" % Styles.money(surcharge), accent, "当前风险档位使交易成本增加 %.0f%%" % (surcharge_rate * 100.0), "RiskSurcharge")
	else:
		_add_status_chip(row, "稳健  无附加费", Color("68c795"), "风险低于 40 时不收取信用附加费", "RiskStatus")
	_add_status_chip(row, "本轮可继续购地", Color("6eb8cf"), "购地次数不限，仍需满足现金、资格与地块状态")


func _add_status_chip(parent: HBoxContainer, text_value: String, accent: Color, help_text: String, node_name: = "") -> void :
	var chip: = Label.new()
	if not node_name.is_empty():
		chip.name = node_name
	chip.text = text_value
	chip.tooltip_text = help_text
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", accent)
	chip.add_theme_stylebox_override("normal", Styles.panel(Color(0.03, 0.1, 0.13, 0.92), Color(accent, 0.66), 13, 1))
	parent.add_child(chip)


func _confirm() -> void :
	purchase_confirmed.emit(player_id, land_id)
	queue_free()


func on_modal_force_close() -> void :
	queue_free()
