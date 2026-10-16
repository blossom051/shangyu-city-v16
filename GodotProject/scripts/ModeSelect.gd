extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const ModeTileScript = preload("res://scripts/ModeTile.gd")
const ScreenDecorator = preload("res://scripts/V7ScreenDecorator.gd")
const ModePolicy = preload("res://scripts/GameModePolicy.gd")
const SeasonDial = preload("res://scripts/CapitalSeasonDial.gd")
const DurationEstimator = preload("res://scripts/SessionDurationEstimator.gd")
const Difficulty = preload("res://scripts/AIDifficultyPolicy.gd")

var mode: = ModePolicy.SOLO
var rounds: = 16
var player_count: = 1
var competitive_player_count: = 4
var ai_difficulty := Difficulty.STANDARD


func _ready() -> void :
	ScreenDecorator.decorate(self, "mode")
	_apply_responsive_layout()
	$Background.modulate = Color.WHITE
	$Shade.color = Color(0.01, 0.04, 0.055, 0.16)
	_setup_mode_tile($Content / Config / Modes / Single, "单人经营", "自由练习城市经营", Color("45a8c4"), ModePolicy.SOLO)
	_setup_mode_tile($Content / Config / Modes / AI, "人机对战", "与 AI 财团争夺第一", Color("805ad5"), ModePolicy.VERSUS_AI)
	_setup_mode_tile($Content / Config / Modes / Multi, "本地董事会", "同屏轮流资本对决", Color("d2a84b"), ModePolicy.LOCAL_MULTI)
	$Footer / Back.pressed.connect( func() -> void : AudioManager.click();GameFlow.go("menu"))
	$Footer / Next.pressed.connect(_next)
	Styles.apply_toy_button($Footer / Back, false, Color("55bce8"), 18)
	Styles.apply_toy_button($Footer / Next, true, Color("ffd45e"), 18)
	$Footer / Back.mouse_entered.connect(AudioManager.hover)
	$Footer / Next.mouse_entered.connect(AudioManager.hover)
	Styles.apply_labels(self)
	$Header / Title.text = "配置本局资本竞赛"
	$Header / Kicker.text = "NEW SESSION  城市资本局"
	$Header / Title.add_theme_color_override("font_color", Color("edf7ff"))
	$Header / Kicker.add_theme_color_override("font_color", Color("48c8e8"))
	$Content / Config / ModeLabel.text = "选择竞赛形式"
	$Footer / Next.text = "确认赛制并进入签约  →"
	_build_enhanced_controls()
	_refresh()


func _apply_responsive_layout() -> void :
	var compact: = get_viewport_rect().size.x < 1500.0
	if not compact:
		return
	$Content / TableArt.hide()
	$Content / TableArt.custom_minimum_size = Vector2.ZERO
	$Content / Config.custom_minimum_size = Vector2.ZERO
	$Content.offset_left = 28.0
	$Content.offset_right = -28.0
	$Content.offset_top = 108.0
	$Content.offset_bottom = -92.0
	$Content / Config.add_theme_constant_override("separation", 10)
	$Content / Config / ModeLabel.hide()
	$Header.offset_left = 32.0
	$Header.offset_right = -32.0
	$Header.offset_top = 22.0
	$Header.offset_bottom = 100.0
	$Footer.offset_left = 32.0
	$Footer.offset_right = -32.0
	$Footer.offset_top = -78.0
	$Footer.offset_bottom = -18.0
	$Header / Title.add_theme_font_size_override("font_size", 34)


func _setup_mode_tile(tile: Button, title: String, subtitle: String, color: Color, value: String) -> void :
	tile.set_script(ModeTileScript)
	tile.setup(title, subtitle, color, value)
	if get_viewport_rect().size.x < 1500.0:
		tile.custom_minimum_size.y = 150.0
	tile.pressed.connect(_set_mode.bind(value))
	tile.mouse_entered.connect( func() -> void : AudioManager.hover();_tween_tile(tile, Vector2(1.025, 1.025)))
	tile.mouse_exited.connect( func() -> void : _tween_tile(tile, Vector2.ONE))


func _build_enhanced_controls() -> void :
	$Content / Config / RoundsLabel.hide()
	$Content / Config / Rounds.hide()
	$Content / Config / SeatsLabel.hide()
	$Content / Config / Seats.hide()
	var insert_at: = $Content / Config / Modes.get_index() + 1
	var rules: = Label.new()
	rules.name = "ModeRules"
	rules.text = "最终净值夺冠        每轮 3 点策略        主动进攻每轮 1 次"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules.custom_minimum_size.y = 42
	if get_viewport_rect().size.x < 1500.0:
		rules.custom_minimum_size.y = 34
	rules.add_theme_font_size_override("font_size", 14)
	rules.add_theme_color_override("font_color", Color("e4cd83"))
	rules.add_theme_stylebox_override("normal", Styles.panel(Color(0.025, 0.09, 0.11, 0.9), Color("766c48"), 14, 1))
	$Content / Config.add_child(rules)
	$Content / Config.move_child(rules, insert_at)
	insert_at += 1
	var difficulty_box := VBoxContainer.new()
	difficulty_box.name = "AIDifficultyChooser"
	difficulty_box.add_child(_label("AI 对手难度（各档资源相同）", 16, Color("e7c45d")))
	var difficulty_row := HBoxContainer.new()
	difficulty_row.name = "Choices"
	for level in [Difficulty.CASUAL, Difficulty.STANDARD, Difficulty.HARD]:
		var choice := Button.new()
		choice.name = level
		choice.text = Difficulty.label(level)
		choice.tooltip_text = {"casual": "偶尔放弃行动，部分选择不取最高分；资源与其他档相同。", "standard": "按现有估值与风险规则经营；资源与其他档相同。", "hard": "更重视长期收益、现金安全和对手威胁；资源与其他档相同。"}[level]
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size.y = 42
		choice.pressed.connect(func() -> void: ai_difficulty = level; AudioManager.click(); _refresh())
		difficulty_row.add_child(choice)
	difficulty_box.add_child(difficulty_row)
	$Content / Config.add_child(difficulty_box)
	$Content / Config.move_child(difficulty_box, insert_at)
	insert_at += 1
	var dial: = SeasonDial.new()
	dial.season_changed.connect( func(value: int) -> void : rounds = value;AudioManager.click();_refresh())
	$Content / Config.add_child(dial)
	$Content / Config.move_child(dial, insert_at)
	insert_at += 1
	var seats: = VBoxContainer.new()
	seats.name = "BoardSeatChooser"
	seats.add_theme_constant_override("separation", 7)
	var seat_header: = HBoxContainer.new()
	var seat_title: = _label("参赛董事席位", 16, Color("e7c45d"))
	seat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_header.add_child(seat_title)
	var seat_hint: = _label("点击数字配置 2—8 席", 13, Color("a9c3ca"))
	seat_header.add_child(seat_hint)
	seats.add_child(seat_header)
	var row: = HBoxContainer.new()
	row.name = "SeatTokens"
	row.add_theme_constant_override("separation", 8)
	for index in range(8):
		var seat: = Button.new()
		seat.name = "DirectorSeat%d" % (index + 1)
		seat.text = str(index + 1)
		seat.custom_minimum_size = Vector2(0, 48)
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat.set_meta("seat_count", index + 1)
		seat.pressed.connect(_select_seat.bind(index + 1))
		seat.mouse_entered.connect(AudioManager.hover)
		row.add_child(seat)
	seats.add_child(row)
	$Content / Config.add_child(seats)
	$Content / Config.move_child(seats, insert_at)
	insert_at += 1
	var brief: = PanelContainer.new()
	brief.name = "SessionBrief"
	brief.add_theme_stylebox_override("panel", Styles.panel(Color(0.018, 0.075, 0.105, 0.93), Color("d6ad54"), 16, 2))
	var box: = VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 4)
	brief.add_child(box)
	box.add_child(_label("本局胜负目标", 14, Color("f0cb70")))
	box.add_child(_label("限定回合结束时，以最终净值争夺城市资本第一名", 17, Color("eef6f5")))
	var value: = _label("", 14, Color("74d5d5"));value.name = "Value";box.add_child(value)
	var opponents: = _label("", 13, Color("a8bec5"));opponents.name = "Opponents";box.add_child(opponents)
	$Content / Config.add_child(brief)
	$Content / Config.move_child(brief, insert_at)


func _refresh() -> void :
	$Content / Config / AIDifficultyChooser.visible = mode == ModePolicy.VERSUS_AI
	for choice: Button in $Content / Config / AIDifficultyChooser / Choices.get_children():
		Styles.apply_toy_button(choice, choice.name == ai_difficulty, Color("e7c45d") if choice.name == ai_difficulty else Color("52727c"), 15)
	$Content / TableArt.configure(mode, rounds, player_count)
	for tile: ModeTile in [$Content / Config / Modes / Single, $Content / Config / Modes / AI, $Content / Config / Modes / Multi]:
		tile.set_selected((tile == $Content / Config / Modes / Single and mode == ModePolicy.SOLO) or (tile == $Content / Config / Modes / AI and mode == ModePolicy.VERSUS_AI) or (tile == $Content / Config / Modes / Multi and mode == ModePolicy.LOCAL_MULTI))
		tile.set_session_context(rounds, competitive_player_count)
	var dial: = $Content / Config / CapitalSeasonDial as CapitalSeasonDial
	dial.set_session_context(mode, player_count)
	dial.set_rounds(rounds)
	_refresh_board_seats()
	var duration: Dictionary = DurationEstimator.estimate(mode, rounds, player_count)
	$Content / Config / SessionBrief / Box / Value.text = "%s  %s  %d 个席位" % [ModePolicy.label(mode), "无限回合" if rounds == 0 else duration.label, player_count]
	$Content / Config / SessionBrief / Box.get_child(1).text = "持续经营，直到破产或主动结束本局" if rounds == 0 else "限定回合结束时，以最终净值争夺城市资本第一名"
	$Content / Config / SessionBrief / Box / Opponents.text = "你控制 1 席" if mode == ModePolicy.SOLO else ("你控制 1 席  %s AI %d 席" % [Difficulty.label(ai_difficulty), maxi(0, player_count - 1)] if mode == ModePolicy.VERSUS_AI else "%d 位玩家同屏轮流" % player_count)
	$Footer / Summary.text = "%s  永续经营  %d 家财团" % [ModePolicy.label(mode), player_count] if rounds == 0 else "%s  %d 回合  %d 家财团  %s" % [ModePolicy.label(mode), rounds, player_count, duration.label]


func _refresh_board_seats() -> void :
	var row: = $Content / Config / BoardSeatChooser / SeatTokens
	for index in range(row.get_child_count()):
		var seat: = row.get_child(index) as Button
		var active: = index < player_count
		seat.disabled = mode == ModePolicy.SOLO or index == 0
		Styles.apply_toy_button(seat, active, Color("e7c45d") if active else Color("52727c"), 14)
	$Content / Config / BoardSeatChooser.visible = mode != ModePolicy.SOLO


func _set_mode(next_mode: String) -> void :
	if mode != ModePolicy.SOLO:
		competitive_player_count = player_count
	mode = ModePolicy.normalize_mode(next_mode)
	player_count = 1 if mode == ModePolicy.SOLO else clampi(competitive_player_count, 2, 8)
	AudioManager.click()
	_refresh()


func _select_seat(count: int) -> void :
	if mode == ModePolicy.SOLO:
		return
	player_count = clampi(count, 2, 8)
	competitive_player_count = player_count
	AudioManager.click()
	_refresh()


func _next() -> void :
	$Footer / Next.disabled = true
	AudioManager.enter_game()
	$Content / TableArt.call("_play_table_transition")
	$Footer / Next.text = "资本路线点亮中…"
	await _owned_delay(0.1 if GameSettings.reduce_motion else 0.68)
	GameFlow.configure(mode, rounds, player_count, ai_difficulty)
	GameFlow.go("company")


func _owned_delay(seconds: float) -> void :
	var timer: = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.001, seconds)
	add_child(timer)
	timer.start()
	await timer.timeout
	if is_instance_valid(timer):
		timer.queue_free()


func _tween_tile(tile: Control, target: Vector2) -> void :
	if GameSettings.reduce_motion:
		tile.scale = target
		return
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", target, 0.12)


func _label(text: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
