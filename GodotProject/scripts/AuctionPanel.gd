extends Control

const UIStyles = preload("res://scripts/UIStyles.gd")
const Auctions = preload("res://scripts/AuctionSystem.gd")
const CharacterCard = preload("res://scripts/FinanceCharacterCard.gd")
const Decisions = preload("res://scripts/AIDecisionEngine.gd")
const AuctionNotices = preload("res://scripts/AuctionNoticeState.gd")

@onready var current_lot: PanelContainer = $Layout / Main / CurrentLot
@onready var lot_title: Label = $Layout / Main / CurrentLot / LotMargin / LotVBox / LotTitle
@onready var lot_metrics: Label = $Layout / Main / CurrentLot / LotMargin / LotVBox / LotMetrics
@onready var lot_status: Label = $Layout / Main / CurrentLot / LotMargin / LotVBox / LotStatus
@onready var bid_panel: PanelContainer = $Layout / Main / Bid
@onready var bid_player: Label = $Layout / Main / Bid / BidMargin / BidBody / Player
@onready var bid_amount: SpinBox = $Layout / Main / Bid / BidMargin / BidBody / Amount
@onready var bid_submit: Button = $Layout / Main / Bid / BidMargin / BidBody / Submit

var auction: Dictionary = {}
var participant_ids: Array[String] = []
var bidder_index: = 0
var modal_token: = 0
var session_finished: = false
var refresh_queued: = false
var eligibility_ack_pending: = false
var abstain_button: Button


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	modal_token = ModalManager.open_modal("auction", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "auction_scene_exit"))
	$Layout / Header / Back.pressed.connect(_return_to_city)
	bid_submit.pressed.connect(_submit)
	bid_amount.value_changed.connect( func(_value: float) -> void : _refresh_submit_copy())
	_build_abstain_button()
	_style()
	_apply_compact_layout()
	_load_auction()


func _build_bidder_gallery() -> void :
	for child in $Layout / Bidders.get_children():
		child.queue_free()
	var roles: = ["market", "bank", "startup"]
	for index in range(GameState.game_data.players.size()):
		var player: Dictionary = GameState.game_data.players[index]
		var card: = CharacterCard.new()
		var identity: = "玩家席" if bool(player.human) else "AI 竞买席"
		if not auction.is_empty() and str(player.id) == str(auction.get("seller_id", "")):
			identity = "出售方席位"
		var pressure: = "充足" if int(player.cash) >= 450 else "谨慎" if int(player.cash) >= 250 else "紧张"
		var rule_note: = "\n强势成交返利：待触发" if float(player.get("abilities", {}).get("auction_rebate_rate", 0.0)) > 0.0 and not bool(player.get("ability_state", {}).get("auction_rebate_used", false)) else ""
		card.setup(roles[index % roles.size()], "%s  %s" % [identity, str(player.name)], "现金 %s\n席位状态：等待暗标  现金压力 %s%s" % [UIStyles.money(int(player.cash)), pressure, rule_note], true)
		card.custom_minimum_size = Vector2(210, 176)
		card.set_meta("player_id", str(player.id))
		$Layout / Bidders.add_child(card)


func _load_auction() -> void :
	session_finished = false
	refresh_queued = false
	if TutorialDirector.active and TutorialDirector.current_step_id() == "auction_practice":
		auction = {"asset_id": "tutorial_lot", "land_id": "L01", "business_id": "", "seller_id": "city", "start_price": 100, "market_price": 180, "round": 1, "history": ["教学资产进入暗标拍卖"]}
		participant_ids = [str(GameState.active_player().get("id", "p1"))]
		bidder_index = 0
		_build_bidder_gallery()
		lot_title.text = "教学拍品  核心商圈经营权"
		lot_metrics.text = "资产估值 180万       起拍筹码 100万\n教学模式不会扣除正式现金"
		lot_status.text = "请输入不低于100万的暗标并锁定"
		_refresh_bidder()
		return
	if GameState.game_data.auctions.is_empty():
		session_finished = true
		lot_title.text = "本轮暂无待拍资产"
		lot_metrics.text = "银行收回、企业清算与城市随机低价土地专场形成拍品。\n返回城市继续经营，出现新拍品时会收到弹窗提醒。"
		lot_status.text = "拍卖席位暂时关闭"
		bid_panel.visible = false
		$Layout / Message.text = "拍卖委员会将在新资产进入清单时重新开场。"
		return
	auction = GameState.game_data.auctions[0]
	participant_ids = Auctions.eligible_bidder_ids(str(auction.asset_id))
	participant_ids.sort_custom( func(a: String, b: String) -> bool:
		var first: = GameState.player(a)
		var second: = GameState.player(b)
		if bool(first.get("human", false)) != bool(second.get("human", false)):
			return bool(first.get("human", false))
		return int(first.get("rank", 0)) < int(second.get("rank", 0)))
	bidder_index = 0
	_build_bidder_gallery()
	AuctionNotices.mark_seen(str(auction.get("asset_id", auction.get("land_id", ""))))
	_update_asset_text()
	var active_human: Dictionary = GameState.active_player()
	if not active_human.is_empty() and bool(active_human.get("human", false)) and not participant_ids.has(str(active_human.get("id", ""))):
		_show_eligibility_gate(active_human)
		return
	_refresh_bidder()


func _show_eligibility_gate(player: Dictionary) -> void :
	eligibility_ack_pending = true
	bid_panel.visible = true
	bid_player.text = "竞拍资格已冻结"
	bid_amount.value = 0
	bid_amount.editable = false
	bid_submit.text = "确认资格说明并观看结果"
	lot_status.text = "当前席位不可出价  拍品仍未揭晓"
	$Layout / Message.text = "%s 存在贷款逾期或未清偿逾期款，因此本场不能参与竞拍。确认后才会继续处理其他席位；若无合资格竞买人，再明确显示流拍。" % str(player.get("name", "当前玩家"))


func _update_asset_text() -> void :
	var land: Dictionary = GameState.game_data.lands.get(str(auction.land_id), {})
	var business: Dictionary = GameState.game_data.businesses.get(str(auction.get("business_id", "")), {})
	var lot_name: = str(land.get("district_name", "城市资产"))
	if not business.is_empty():
		lot_name += "  %s" % str(business.get("name", "运营企业"))
	var estimate: = int(land.get("price", 0)) + int(business.get("value", 0))
	var expected: = maxi(0, roundi(float(estimate) * 0.12))
	var latest: = str(auction.get("history", ["等待暗标"])[-1]) if not auction.get("history", []).is_empty() else "等待暗标"
	lot_title.text = "%s  %s" % [str(auction.land_id), lot_name]
	lot_metrics.text = "资产估值  %s       起拍筹码  %s\n预计经营价值  +%s/回合       暗标第 %d 轮" % [UIStyles.money(estimate), UIStyles.money(int(auction.start_price)), UIStyles.money(expected), int(auction.round)]
	lot_status.text = "当前最高价：密封未揭晓    待决定席位 %d    %s" % [maxi(0, participant_ids.size() - bidder_index), latest]


func _refresh_bidder() -> void :
	refresh_queued = false
	if session_finished or auction.is_empty() or not is_inside_tree():
		return
	if bidder_index >= participant_ids.size():
		var result: = Auctions.reveal(str(auction.asset_id))
		$Layout / Message.text = "揭晓：%s" % str(result.message)
		_show_bid_disclosure(result)
		_play_auction_outcome(result)
		if not bool(result.get("ok", false)):
			session_finished = true
			bid_panel.visible = false
			lot_status.text = "拍卖异常中止  可安全返回城市"
			return
		if bool(result.get("no_bid", false)):
			session_finished = true
			bid_panel.visible = false
			_update_asset_text()
			lot_status.text = "本场流拍  下次开场起拍价已下调  可返回城市"
			$Layout / Message.text = "本场无人出价，竞拍已安全结束；不会自动重复开场。"
			return
		if bool(result.get("tie", false)):
			bidder_index = 0
			_update_asset_text()
			_queue_refresh()
			return
		AudioManager.auction_hammer()
		session_finished = true
		bid_panel.visible = false
		return
	var player: Dictionary = GameState.player(participant_ids[bidder_index])
	_set_bidder_status(str(player.id), "轮到出价")
	bid_player.text = "请 %s 秘密出价" % str(player.name)
	bid_amount.min_value = 0
	bid_amount.max_value = int(player.cash)
	bid_amount.value = 0
	_refresh_submit_copy()
	$Layout / Message.text = "你的决定尚未提交，系统不会提前揭晓。输入0并确认代表主动放弃。"
	if not bool(player.human):
		_ai_bid(player)


func _submit() -> void :
	if eligibility_ack_pending:
		eligibility_ack_pending = false
		bid_amount.editable = true
		_refresh_bidder()
		return
	if session_finished or bidder_index < 0 or bidder_index >= participant_ids.size():
		return
	var player: Dictionary = GameState.player(participant_ids[bidder_index])
	var amount: = int(bid_amount.value)
	var result: = Auctions.submit_bid(str(auction.asset_id), str(player.id), amount)
	if not bool(result.ok):
		$Layout / Message.text = str(result.message)
		return
	if TutorialDirector.active:
		$Layout / Message.text = str(result.get("message", "教学暗标完成"))
		session_finished = true
		bid_panel.visible = false
		lot_status.text = "教学暗标已锁定  返回城市继续教程"
		return
	bid_amount.value = 0
	_set_bidder_status(str(player.id), "已退出" if amount <= 0 else "暗标已锁定")
	bidder_index += 1
	_update_asset_text()
	_refresh_bidder()


func _return_to_city() -> void :
	if TutorialDirector.active:
		TutorialDirector.return_to_city_from_auxiliary("auction_center")
	GameFlow.go("city")


func _abstain() -> void :
	if eligibility_ack_pending or session_finished:
		return
	bid_amount.value = 0
	_submit()


func _ai_bid(player: Dictionary) -> void :
	if session_finished:
		return
	var plan: Dictionary = Decisions.auction_bid(str(player.id), auction)
	var amount: = int(plan.get("amount", 0)) if str(plan.get("action", "abstain")) == "bid" else 0
	Auctions.submit_bid(str(auction.asset_id), str(player.id), amount)
	_set_bidder_status(str(player.id), "已退出" if amount <= 0 else "AI 暗标已锁定")
	bidder_index += 1
	_update_asset_text()
	_queue_refresh()


func _refresh_submit_copy() -> void :
	if bid_submit == null or bid_amount == null:
		return
	if eligibility_ack_pending:
		bid_submit.text = "确认资格说明并观看结果"
		return
	bid_submit.text = "确认放弃竞买" if int(bid_amount.value) <= 0 else "锁定暗标  %d万" % int(bid_amount.value)


func _show_bid_disclosure(result: Dictionary) -> void :
	var disclosure: Array = result.get("bid_disclosure", [])
	if disclosure.is_empty():
		return
	var lines: Array[String] = ["暗标揭晓  所有席位"]
	for item: Dictionary in disclosure:
		var player_name: = str(item.get("player_name", item.get("player_id", "席位")))
		var cash_bid: = int(item.get("cash_bid", 0))
		if cash_bid <= 0:
			lines.append("%s：主动放弃" % player_name)
			continue
		var bonus: = int(item.get("bid_bonus", 0))
		var effective: = int(item.get("effective_amount", cash_bid))
		var suffix: = "  中标" if str(item.get("player_id", "")) == str(result.get("winner_id", "")) else ""
		lines.append("%s：现金 %d万%s = 比较价 %d万%s" % [player_name, cash_bid, " + 技能 %d万" % bonus if bonus > 0 else "", effective, suffix])
	lot_status.text = "\n".join(lines)


func _queue_refresh() -> void :
	if session_finished or refresh_queued or not is_inside_tree():
		return
	refresh_queued = true
	call_deferred("_refresh_bidder")


func _set_bidder_status(player_id: String, status: String) -> void :
	for card: Control in $Layout / Bidders.get_children():
		if str(card.get_meta("player_id", "")) != player_id:
			continue
		var tags: = card.find_child("CharacterTags", true, false) as Label
		if tags:
			var first_line: = tags.text.split("\n")[0]
			tags.text = "%s\n席位状态：%s" % [first_line, status]


func _play_auction_outcome(result: Dictionary) -> void :
	var overlay: = $OutcomeOverlay as Control
	var outcome: = $OutcomeOverlay / AuctionOutcome as Label
	overlay.visible = true
	outcome.text = "流拍  筹码重置" if bool(result.get("no_bid", false)) else "同价加赛  进入下一轮" if bool(result.get("tie", false)) else "成交  %s" % str(result.get("message", "胜出席位确认"))
	outcome.scale = Vector2(0.68, 0.68)
	outcome.modulate.a = 1.0
	outcome.pivot_offset = outcome.size * 0.5
	var tween: = create_tween()
	tween.tween_property(outcome, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.72)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.28)
	tween.tween_callback( func() -> void : overlay.visible = false;overlay.modulate.a = 1.0)


func _style() -> void :
	var lot_style: = UIStyles.toy_panel(Color(0.025, 0.075, 0.095, 0.9), Color("b7893f"), 18, 12)
	current_lot.add_theme_stylebox_override("panel", lot_style)
	bid_panel.add_theme_stylebox_override("panel", UIStyles.toy_panel(Color(0.035, 0.105, 0.13, 0.94), Color("d6ad54"), 18, 12))
	$Layout / Message.add_theme_stylebox_override("normal", UIStyles.toy_card(Color("345f6c"), false))
	UIStyles.apply_toy_button($Layout / Header / Back, false, UIStyles.TOY_BLUE, 18)
	UIStyles.apply_toy_button(bid_submit, true, UIStyles.TOY_YELLOW, 18)
	if abstain_button != null:
		UIStyles.apply_toy_button(abstain_button, false, UIStyles.TOY_BLUE, 18)
	for button in [$Layout / Header / Back, bid_submit, abstain_button]:
		if button == null:
			continue
		button.mouse_entered.connect(AudioManager.hover)
	$Layout / Header / HeaderCopy / Kicker.add_theme_color_override("font_color", Color("d8b962"))
	$Layout / Header / HeaderCopy / HeaderTitle.add_theme_color_override("font_color", Color("f5ead0"))
	$Layout / Main / CurrentLot / LotMargin / LotVBox / LotKicker.add_theme_color_override("font_color", Color("d8b962"))
	lot_title.add_theme_color_override("font_color", Color("f5ead0"))
	lot_metrics.add_theme_color_override("font_color", Color("d9e5e7"))
	lot_status.add_theme_color_override("font_color", Color("efc66c"))
	$Layout / Main / Bid / BidMargin / BidBody / BidKicker.add_theme_color_override("font_color", Color("d8b962"))
	bid_player.add_theme_color_override("font_color", Color("f5ead0"))
	$Layout / Main / Bid / BidMargin / BidBody / BidHint.add_theme_color_override("font_color", Color("a9bec4"))
	$Layout / BiddersTitle.add_theme_color_override("font_color", Color("f0d07b"))
	$Layout / Message.add_theme_color_override("font_color", Color("e5eff0"))
	$OutcomeOverlay / AuctionOutcome.add_theme_color_override("font_color", Color("f2cb69"))
	$OutcomeOverlay / AuctionOutcome.add_theme_color_override("font_outline_color", Color("081820"))
	$OutcomeOverlay / AuctionOutcome.add_theme_constant_override("outline_size", 12)


func _build_abstain_button() -> void :
	if abstain_button != null:
		return
	var body: = $Layout / Main / Bid / BidMargin / BidBody as VBoxContainer
	abstain_button = Button.new()
	abstain_button.name = "Abstain"
	abstain_button.text = "弃权  不参与本轮"
	abstain_button.custom_minimum_size = Vector2(0, 48)
	abstain_button.pressed.connect(_abstain)
	body.add_child(abstain_button)


func _apply_compact_layout() -> void :
	if get_viewport_rect().size.y >= 820.0:
		return
	$Layout.offset_top = 12.0
	$Layout.offset_bottom = -12.0
	$Layout.add_theme_constant_override("separation", 6)
	$Layout / Header.custom_minimum_size.y = 48
	$Layout / Header / Hammer.custom_minimum_size = Vector2(50, 44)
	$Layout / Header / HeaderCopy / HeaderTitle.add_theme_font_size_override("font_size", 28)
	$Layout / Header / Back.custom_minimum_size = Vector2(142, 46)
	$Layout / Main.custom_minimum_size.y = 212
	$Layout / Main / CurrentLot / LotMargin.add_theme_constant_override("margin_top", 12)
	$Layout / Main / CurrentLot / LotMargin.add_theme_constant_override("margin_bottom", 12)
	$Layout / Main / CurrentLot / LotMargin / LotVBox / LotTitle.add_theme_font_size_override("font_size", 26)
	$Layout / Main / CurrentLot / LotMargin / LotVBox / LotMetrics.add_theme_font_size_override("font_size", 17)
	$Layout / Main / CurrentLot / LotMargin / LotVBox / LotStatus.add_theme_font_size_override("font_size", 14)
	$Layout / Main / Bid.custom_minimum_size.x = 380
	$Layout / Main / Bid / BidMargin.add_theme_constant_override("margin_top", 12)
	$Layout / Main / Bid / BidMargin.add_theme_constant_override("margin_bottom", 12)
	$Layout / Main / Bid / BidMargin / BidBody / Amount.custom_minimum_size.y = 48
	$Layout / Main / Bid / BidMargin / BidBody / Submit.custom_minimum_size.y = 48
	$Layout / BiddersTitle.custom_minimum_size.y = 22
	$Layout / BiddersTitle.add_theme_font_size_override("font_size", 16)
	$Layout / Bidders.custom_minimum_size.y = 184
	$Layout / Message.custom_minimum_size.y = 36
	$Layout / Message.add_theme_font_size_override("font_size", 15)
	for card: Control in $Layout / Bidders.get_children():
		card.custom_minimum_size = Vector2(190, 184)
		var stack: = card.get_child(0) as VBoxContainer
		stack.add_theme_constant_override("separation", 4)
		var portrait: = card.find_child("Portrait", true, false) as TextureRect
		var title: = card.find_child("CharacterTitle", true, false) as Label
		var tags: = card.find_child("CharacterTags", true, false) as Label
		if portrait != null:
			portrait.custom_minimum_size.y = 112
		if title != null:
			title.add_theme_font_size_override("font_size", 15)
		if tags != null:
			tags.add_theme_font_size_override("font_size", 12)
