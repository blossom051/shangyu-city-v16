extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const Bank = preload("res://scripts/BankSystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const Gauge = preload("res://scripts/WealthGauge.gd")
const CharacterCard = preload("res://scripts/FinanceCharacterCard.gd")

@onready var layout: VBoxContainer = $Safe / Columns / MainShell / Scroll / Layout
@onready var advisor: VBoxContainer = $Safe / Columns / AdvisorShell / Advisor

var gauges: Dictionary = {}
var product_buttons: Dictionary = {}
var selected_direct_amount: = 0
var flow_cards: Dictionary = {}
var mortgage_cards: VBoxContainer
var selected_asset_id: = ""
var loans_host: VBoxContainer
var message_label: Label
var confirm_direct: Button
var modal_token: = 0

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	modal_token = ModalManager.open_modal("bank_wealth_center", self, self)
	tree_exiting.connect( func() -> void : ModalManager.close_modal(modal_token, "bank_scene_exit"))
	_build_interface();_refresh();resized.connect(_apply_responsive_layout);_apply_responsive_layout()

func _build_interface() -> void :
	$Safe / Columns / MainShell.add_theme_stylebox_override("panel", Styles.panel(Color("071b28e8"), Color("4b8698"), 22, 2))
	$Safe / Columns / AdvisorShell.add_theme_stylebox_override("panel", Styles.panel(Color("081d2ae8"), Color("d6ad54"), 22, 2))
	var header: = HBoxContainer.new();header.name = "Header";header.add_theme_constant_override("separation", 12);layout.add_child(header)
	var title: = Styles.label("城市银行", 34, Color("e6c66d"));title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;header.add_child(title)
	var status: = Styles.label("", 16, Color("a8c4ca"));status.name = "CreditStatus";header.add_child(status)
	var back: = Button.new();back.name = "Back";back.text = "返回城市";back.custom_minimum_size = Vector2(142, 50);Styles.apply_toy_button(back, false, Color("55bce8"), 17);back.pressed.connect(_return_to_city);header.add_child(back)
	var strip: = HBoxContainer.new();strip.name = "WealthStatusStrip";strip.add_theme_constant_override("separation", 10);layout.add_child(strip)
	for spec: Array in [["cash", "water"], ["debt", "ring"], ["credit", "ring"], ["risk", "scale"]]:
		var gauge: = Gauge.new();gauge.name = str(spec[0]).capitalize();gauge.custom_minimum_size = Vector2(205, 92);gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL;strip.add_child(gauge);gauges[str(spec[0])] = gauge
	layout.add_child(_section_title("信用融资方案", "选择后立即看到资金水位、首期支出和授信压力"))
	var products: = HBoxContainer.new();products.name = "FinancingProducts";products.add_theme_constant_override("separation", 12);layout.add_child(products)
	for amount: int in Bank.direct_loan_products():
		var button: = Button.new();button.name = "Loan%d" % amount;button.custom_minimum_size = Vector2(210, 112);button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;button.pressed.connect(_select_direct.bind(amount));products.add_child(button);product_buttons[amount] = button
	var flow_panel: = PanelContainer.new();flow_panel.name = "CashflowWaterfall";flow_panel.add_theme_stylebox_override("panel", Styles.panel(Color("0b2a36"), Color("4e8a96"), 16, 1));layout.add_child(flow_panel)
	var flow: = HBoxContainer.new();flow.add_theme_constant_override("separation", 8);flow_panel.add_child(flow)
	for key: String in ["before", "arrival", "payment", "remaining"]:
		var card: = VBoxContainer.new();card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar: = ProgressBar.new();bar.show_percentage = false;bar.custom_minimum_size = Vector2(0, 18);card.add_child(bar)
		var label: = Styles.label("", 15, Color("dce9e9"));label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;card.add_child(label);flow.add_child(card);flow_cards[key] = {"bar": bar, "label": label}
	confirm_direct = Button.new();confirm_direct.text = "请先选择融资方案";confirm_direct.custom_minimum_size = Vector2(0, 54);confirm_direct.pressed.connect(_confirm_direct);layout.add_child(confirm_direct);Styles.apply_toy_button(confirm_direct, true, Color("d6ad54"), 18)
	layout.add_child(_section_title("资产抵押台", "土地与企业按真实估值生成资产卡，不再使用文字下拉框"))
	mortgage_cards = VBoxContainer.new();mortgage_cards.name = "MortgageAssetCards";mortgage_cards.add_theme_constant_override("separation", 8);layout.add_child(mortgage_cards)
	layout.add_child(_section_title("贷款账户", "本金环  期数时间轴  当前应付  逾期阶段"))
	loans_host = VBoxContainer.new();loans_host.name = "LoanAccounts";loans_host.add_theme_constant_override("separation", 10);layout.add_child(loans_host)
	message_label = Styles.label("", 15, Color("e4cc87"));message_label.name = "ActionReceipt";message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;message_label.custom_minimum_size.y = 48;message_label.add_theme_stylebox_override("normal", Styles.panel(Color("0c2834"), Color("745f36"), 12, 1));layout.add_child(message_label)
	var character: = CharacterCard.new();character.setup("bank", "私人银行顾问  顾谨", "现金流  |  授信  |  违约防线", true);advisor.add_child(character)
	advisor.add_child(_section_title("信用健康", "从现金、负债与风险实时计算"))
	var health: = Gauge.new();health.name = "HealthGauge";health.custom_minimum_size = Vector2(0, 118);advisor.add_child(health);gauges.health = health
	advisor.add_child(_section_title("逾期路线图", "越过下一阶段前优先处理本期应付"))
	for spec: Array in [["01", "首次逾期", "加收 3%  风险 +6", Color("d8b35b")], ["02", "连续两次", "加收 5%  风险 +10", Color("df875e")], ["03", "第三次逾期", "司法拍卖  剩余息费限 3 回合", Color("d85b65")]]: advisor.add_child(_timeline_card(spec))
	var advice: = Styles.label("", 15, Color("cde0e2"));advice.name = "CurrentAdvice";advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;advisor.add_child(advice)

func _refresh() -> void :
	var player: = GameState.active_player();
	if player.is_empty(): return
	var summary: = Bank.loan_summary(str(player.id)); var ceiling: = maxi(1, int(summary.get("credit_ceiling", 1))); var risk: = int(player.get("risk", 0)); var grade: = _credit_grade(int(player.debt), ceiling, risk)
	(layout.get_node("Header/CreditStatus") as Label).text = "信用 %s  风险 %d  %s" % [grade, risk, str(Risks.profile(str(player.id)).get("tier", "稳健"))]
	(gauges.cash as WealthGauge).setup("water", "现金水位", float(player.cash), 1200.0, Color("54b9d7"), Styles.money(int(player.cash)))
	(gauges.debt as WealthGauge).setup("ring", "负债环", float(player.debt), float(ceiling), Color("e27f62"), Styles.money(int(player.debt)))
	(gauges.credit as WealthGauge).setup("ring", "授信占用", float(player.debt), float(ceiling), Color("64c99c"), "%d%%" % roundi(float(player.debt) / float(ceiling) * 100.0))
	(gauges.risk as WealthGauge).setup("scale", "风险刻度", float(risk), 100.0, Color("dfb85d") if risk < 60 else Color("e56567"), str(risk))
	var health_score: = clampi(100 - roundi(float(player.debt) / float(ceiling) * 55.0) - risk / 2, 0, 100);(gauges.health as WealthGauge).setup("ring", "信用健康", float(health_score), 100.0, Color("69d0a4") if health_score >= 60 else Color("e18960"), "%d / 100" % health_score)
	for amount: int in product_buttons:
		var quote: = Bank.direct_loan_quote(str(player.id), amount); var button: = product_buttons[amount] as Button
		button.text = "%s  %d期%s\n首期 %s   总息 %s\n授信压力 %d%%" % [Styles.money(amount), int(quote.get("term_rounds", 0)), "  压缩" if bool(quote.get("compressed_term", false)) else "", Styles.money(int(quote.get("round_payment", 0))), Styles.money(int(quote.get("total_interest", 0))), roundi(float(int(player.debt) + amount) / float(ceiling) * 100.0)]
		button.disabled = not bool(quote.get("allowed", false));Styles.apply_toy_button(button, amount == selected_direct_amount, Color("d6ad54") if amount == selected_direct_amount else Color("498ba2"), 15)
	_refresh_cashflow(player);_refresh_mortgages(player);_refresh_loans(player)
	var overdue: = int(summary.get("overdue_count", 0));(advisor.get_node("CurrentAdvice") as Label).text = "当前建议：%s" % ("先支付逾期款，避免进入下一阶段。" if overdue > 0 else "现金覆盖下一期应付后，再考虑新增融资。" if int(summary.get("total_due", 0)) > 0 else "暂无到期压力，可保留授信用于高回报资产。")

func _refresh_cashflow(player: Dictionary) -> void :
	var amount: = selected_direct_amount; var quote: = Bank.direct_loan_quote(str(player.id), amount) if amount > 0 else {}; var payment: = int(quote.get("round_payment", 0)); var remaining: = int(player.cash) + amount - payment; var max_value: = maxf(1.0, float(maxi(int(player.cash) + amount, 1)))
	var specs: = {"before": ["融资前\n%s" % Styles.money(int(player.cash)), int(player.cash), Color("4f9db5")], "arrival": ["到账\n+%s" % Styles.money(amount), amount, Color("66c99b")], "payment": ["首期偿还\n-%s" % Styles.money(payment), payment, Color("dc8b62")], "remaining": ["预计余量\n%s" % Styles.money(remaining), maxi(0, remaining), Color("d8b75e")]}
	for key: String in specs:
		var entry: Dictionary = flow_cards[key]; var spec: Array = specs[key];(entry.label as Label).text = str(spec[0]);(entry.bar as ProgressBar).max_value = max_value;(entry.bar as ProgressBar).value = float(spec[1]);(entry.bar as ProgressBar).add_theme_stylebox_override("fill", Styles.panel(spec[2], spec[2].lightened(0.2), 6, 1))
	confirm_direct.disabled = amount <= 0 or not bool(quote.get("allowed", false));confirm_direct.text = "确认融资 %s  首期 %s" % [Styles.money(amount), Styles.money(payment)] if amount > 0 else "请先选择融资方案"

func _refresh_mortgages(player: Dictionary) -> void :
	for child in mortgage_cards.get_children(): child.queue_free()
	var assets: = Bank.mortgageable_assets(str(player.id))
	if assets.is_empty(): mortgage_cards.add_child(_empty_state("暂无可抵押资产", "购入土地或建成企业后，将在这里生成可视资产卡。"));return
	for asset: Dictionary in assets:
		var quote: = Bank.mortgage_quote(str(player.id), str(asset.id)); var button: = Button.new();button.custom_minimum_size = Vector2(0, 84);button.text = "%s    估值 %s    可贷 %s\n%d期  首期 %s  %s" % [str(asset.label), Styles.money(int(asset.value)), Styles.money(int(quote.get("amount", 0))), int(quote.get("term_rounds", 0)), Styles.money(int(quote.get("first_payment", 0))), "再次点击确认抵押" if selected_asset_id == str(asset.id) else "点击选择"];button.pressed.connect(_select_mortgage.bind(str(asset.id)));Styles.apply_toy_button(button, selected_asset_id == str(asset.id), Color("d6ad54") if selected_asset_id == str(asset.id) else Color("4f8c72"), 15);mortgage_cards.add_child(button)

func _refresh_loans(player: Dictionary) -> void :
	for child in loans_host.get_children(): child.queue_free()
	if player.loans.is_empty(): loans_host.add_child(_empty_state("贷款账户为空", "当前没有本金、利息或逾期负担；信用额度保持可用。"));return
	for loan: Dictionary in player.loans: loans_host.add_child(_loan_card(player, loan))

func _loan_card(player: Dictionary, loan: Dictionary) -> Control:
	var card: = PanelContainer.new();card.add_theme_stylebox_override("panel", Styles.panel(Color("0b2a36"), Color("e06f68") if int(loan.get("overdue", 0)) > 0 else Color("4d91a7"), 16, 2)); var box: = VBoxContainer.new();box.add_theme_constant_override("separation", 8);card.add_child(box)
	var due: = Bank.is_loan_due(loan); var quote: = Bank.installment_quote(str(player.id), str(loan.id)) if due else Bank.payment_quote(loan); var payoff: = Bank.payoff_quote(str(player.id), str(loan.id))
	box.add_child(Styles.label("%s  本金 %s  %s" % [_loan_kind(str(loan.kind)), Styles.money(int(loan.principal)), "逾期 %d 期" % int(loan.get("overdue", 0)) if int(loan.get("overdue", 0)) > 0 else "正常履约"], 20, Color("f0dc9a")))
	var progress: = ProgressBar.new();progress.show_percentage = false;progress.max_value = maxi(1, int(loan.get("term_rounds", 1)));progress.value = maxi(0, int(loan.get("term_rounds", 0)) - int(quote.get("periods_left", 0)));progress.custom_minimum_size.y = 16;box.add_child(progress)
	box.add_child(Styles.label("期数 %d/%d  本期本金 %s  利息 %s  逾期费用 %s  合计 %s" % [int(progress.value), int(progress.max_value), Styles.money(int(quote.get("required_principal", 0))), Styles.money(int(quote.get("interest", 0))), Styles.money(int(quote.get("overdue_fee", 0))), Styles.money(int(quote.get("total_due", 0)))], 15, Color("c9dadd")))
	var actions: = HBoxContainer.new(); var installment: = Button.new();installment.text = "支付本期 %s" % Styles.money(int(quote.get("total_due", 0)));installment.disabled = not due or int(player.cash) < int(quote.get("total_due", 0));installment.size_flags_horizontal = Control.SIZE_EXPAND_FILL;installment.pressed.connect(_pay_installment.bind(str(loan.id)));Styles.apply_toy_button(installment, false, Color("54a7c2"), 15);actions.add_child(installment)
	var full: = Button.new();full.text = "提前结清 %s" % Styles.money(int(payoff.get("total_due", 0)));full.disabled = int(player.cash) < int(payoff.get("total_due", 0));full.size_flags_horizontal = Control.SIZE_EXPAND_FILL;full.pressed.connect(_repay.bind(str(loan.id)));Styles.apply_toy_button(full, true, Color("d6ad54"), 15);actions.add_child(full);box.add_child(actions);return card

func _select_direct(amount: int) -> void : selected_direct_amount = amount;AudioManager.click();_refresh()
func _confirm_direct() -> void :
	if selected_direct_amount > 0: _present(Bank.direct_loan(str(GameState.active_player().id), selected_direct_amount), "融资申请失败")
func _select_mortgage(asset_id: String) -> void :
	if selected_asset_id == asset_id: _present(Bank.mortgage(str(GameState.active_player().id), asset_id), "抵押申请失败")
	else: selected_asset_id = asset_id;AudioManager.click();_refresh()
func _pay_installment(loan_id: String) -> void : _present(Bank.pay_current_installment(str(GameState.active_player().id), loan_id), "本期还款失败")
func _repay(loan_id: String) -> void : _present(Bank.repay(str(GameState.active_player().id), loan_id), "提前结清失败")
func _present(result: Dictionary, fallback: String) -> void :
	message_label.text = str(result.get("message", fallback))
	if bool(result.get("ok", false)): AudioManager.bank_repay();selected_asset_id = "";selected_direct_amount = 0
	else: GlobalFeedbackOverlay.show_notice(fallback, message_label.text)
	_refresh()
func _return_to_city() -> void :
	if TutorialDirector.active: TutorialDirector.return_to_city_from_auxiliary("city_bank")
	GameFlow.go("city")
func _apply_responsive_layout() -> void :
	if is_node_ready():



		$Safe / Columns / AdvisorShell.visible = get_viewport_rect().size.x >= 1450.0
func dashboard_profile() -> Dictionary: return {"visual_modules": 5, "has_option_button": false, "has_cashflow_waterfall": true, "has_asset_cards": true}
func _credit_grade(debt: int, ceiling: int, risk: int) -> String:
	var pressure: = float(debt) / float(maxi(1, ceiling)) + float(risk) / 180.0;return "A" if pressure < 0.35 else "B" if pressure < 0.65 else "C" if pressure < 0.9 else "D"
func _loan_kind(value: String) -> String: return {"direct": "信用融资", "mortgage": "资产抵押", "judicial_residual": "司法剩余息费", "temporary_finance": "到期融资", "operating_shortfall": "经营周转"}.get(value, value)
func _section_title(title: String, note: String) -> Control:
	var box: = VBoxContainer.new();box.add_child(Styles.label(title, 23, Color("e6c66d")));box.add_child(Styles.label(note, 13, Color("9ebbc2")));return box
func _timeline_card(spec: Array) -> Control:
	var panel: = PanelContainer.new();panel.add_theme_stylebox_override("panel", Styles.panel(Color("0a2734"), spec[3], 12, 1));panel.add_child(Styles.label("%s  %s\n%s" % [spec[0], spec[1], spec[2]], 14, Color("e3ecec")));return panel
func _empty_state(title: String, note: String) -> Control:
	var panel: = PanelContainer.new();panel.add_theme_stylebox_override("panel", Styles.panel(Color("0a2734"), Color("4f7782"), 14, 1)); var label: = Styles.label("◇  %s\n%s" % [title, note], 15, Color("b8cdd1"));label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;panel.add_child(label);return panel
