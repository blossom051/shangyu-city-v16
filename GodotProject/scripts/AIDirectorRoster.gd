class_name AIDirectorRoster
extends Control

const Styles = preload("res://scripts/UIStyles.gd")
const ModePolicy = preload("res://scripts/GameModePolicy.gd")
const PORTRAITS = preload("res://assets/images/v12/setup/ai_directors_atlas.png")
const HOST_PORTRAIT = preload("res://assets/images/v12/tutorial/business_mentor.png")

const NAMES: = ["陆衡", "顾城", "林悦", "周衍", "沈川", "叶岚", "许禾", "程曦"]
const ROLES: = ["本席董事", "城市投资人", "零售女董事", "金融顾问", "物流掌舵人", "品牌合伙人", "社区商业经理", "科技创业者"]
const SLOGANS: = [
	"看清目标，稳住现金流，我们一起把城市经营好！", 
	"把每一步走稳，城市会给耐心的人回报！", 
	"让好生意照亮街区，也照亮我们的排名！", 
	"看清数字、保持节奏，机会总会出现！", 
	"路通、货畅、伙伴齐心，稳稳向前！", 
	"让创意变成客流，让客流变成好成绩！", 
	"一起把社区经营好，长期价值自然会来！", 
	"保持好奇、快速行动，把新机会做成新增长！", 
]

var mode: = ModePolicy.SOLO
var rounds: = 16
var player_count: = 1
var roster: GridContainer
var heading: Label
var note: Label
var speech: PanelContainer
var speech_title: Label
var speech_body: Label
var last_visible_count: = -1


func _ready() -> void :
	clip_contents = true
	_build()


func configure(next_mode: String, next_rounds: int, next_player_count: int) -> void :
	mode = ModePolicy.normalize_mode(next_mode)
	rounds = next_rounds
	player_count = next_player_count
	if roster == null:
		_build()
	var visible_count: = 1 if mode == ModePolicy.SOLO else maxi(1, player_count - 1) if mode == ModePolicy.VERSUS_AI else player_count
	_refresh_copy()
	_rebuild_roster(visible_count)
	if visible_count > last_visible_count and last_visible_count >= 0:
		_show_slogan(visible_count - 1)
	elif last_visible_count < 0:
		_show_slogan(visible_count - 1)
	last_visible_count = visible_count


func _build() -> void :
	for child in get_children():
		child.queue_free()
	var shell: = VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 18
	shell.offset_top = 10
	shell.offset_right = -18
	shell.offset_bottom = -10
	shell.add_theme_constant_override("separation", 10)
	add_child(shell)
	heading = _label("", 27, Color("f5df9b"))
	heading.add_theme_constant_override("outline_size", 6)
	heading.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	shell.add_child(heading)
	note = _label("", 15, Color("d5e4e1"))
	note.add_theme_constant_override("outline_size", 5)
	note.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	shell.add_child(note)
	roster = GridContainer.new()
	roster.name = "AIDirectorGrid"
	roster.columns = 4
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster.add_theme_constant_override("h_separation", 10)
	roster.add_theme_constant_override("v_separation", 10)
	shell.add_child(roster)
	speech = PanelContainer.new()
	speech.name = "DirectorSlogan"
	speech.custom_minimum_size.y = 84
	speech.add_theme_stylebox_override("panel", Styles.panel(Color(0.025, 0.08, 0.09, 0.96), Color("e4bd5b"), 20, 3))
	var bubble: = VBoxContainer.new()
	bubble.add_theme_constant_override("separation", 4)
	speech.add_child(bubble)
	speech_title = _label("", 17, Color("f4cf72"))
	bubble.add_child(speech_title)
	speech_body = _label("", 15, Color("f1f4ea"))
	speech_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(speech_body)
	shell.add_child(speech)
	_refresh_copy()
	_rebuild_roster(1)


func _refresh_copy() -> void :
	if heading == null:
		return
	if mode == ModePolicy.VERSUS_AI:
		heading.text = "AI 商业精英入席"
		note.text = "每增加一个席位，就会有一位商业对手加入并亮出口号"
	elif mode == ModePolicy.LOCAL_MULTI:
		heading.text = "本地董事会入席"
		note.text = "选择几名玩家，左侧就展示几位商业精英董事代表"
	else:
		heading.text = "城市经营练习席"
		note.text = "一名董事独立经营，随时可以返回挑战多人竞赛"


func _rebuild_roster(count: int) -> void :
	for child in roster.get_children():
		roster.remove_child(child)
		child.free()
	for index in range(count):
		roster.add_child(_director_card(index))
	speech.visible = true


func _director_card(index: int) -> Control:
	var panel: = PanelContainer.new()
	panel.name = "AIDirector%d" % (index + 1)
	panel.custom_minimum_size = Vector2(134, 192)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Styles.panel(Color(0.02, 0.075, 0.08, 0.95), Color("d1ad55") if index == last_visible_count else Color("5d8f91"), 17, 2))
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var portrait: = TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 124)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = _portrait(index)
	box.add_child(portrait)
	var player_tag: = "玩家 %d" % (index + 1) if mode == ModePolicy.LOCAL_MULTI else "本席" if mode == ModePolicy.SOLO else "AI 对手"
	var name_label: = _label("%s  %s" % [NAMES[index % NAMES.size()], player_tag], 15, Color("f5d77f"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var role_label: = _label(ROLES[index % ROLES.size()], 11, Color("c9d8d4"))
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(role_label)
	panel.mouse_entered.connect( func() -> void : _show_slogan(index);_audio_hover())
	return panel


func _portrait(index: int) -> Texture2D:
	if index == 0:
		return HOST_PORTRAIT
	var atlas: = AtlasTexture.new()
	atlas.atlas = PORTRAITS
	var portrait_index: = (index - 1) % 7
	var cell: = Vector2(float(PORTRAITS.get_width()) / 4.0, float(PORTRAITS.get_height()) / 2.0)
	atlas.region = Rect2(Vector2(float(portrait_index % 4) * cell.x, float(portrait_index / 4) * cell.y), cell)
	return atlas


func _show_slogan(index: int) -> void :
	index = clampi(index, 0, NAMES.size() - 1)
	speech.visible = true
	speech_title.text = "%s  %s 已入席" % [NAMES[index], ROLES[index]]
	speech_body.text = "“%s”" % SLOGANS[index]
	speech.modulate = Color.WHITE
	speech.scale = Vector2(0.97, 0.97)
	if not _reduce_motion():
		var tween: = create_tween()
		tween.tween_property(speech, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_table_transition() -> void :
	var tween: = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color("fff2bd"), 0.32)
	tween.tween_property(self, "scale", Vector2(1.015, 1.015), 0.32).set_trans(Tween.TRANS_QUAD)


func _label(text: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _audio_hover() -> void :
	if not is_inside_tree():
		return
	var audio: = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("hover")


func _reduce_motion() -> bool:
	if not is_inside_tree():
		return false
	var settings: = get_node_or_null("/root/GameSettings")
	return bool(settings.get("reduce_motion")) if settings != null else false
