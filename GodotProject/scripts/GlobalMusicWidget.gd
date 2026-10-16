extends CanvasLayer

const Styles = preload("res://scripts/UIStyles.gd")
const MascotButton = preload("res://scripts/MusicMascotButton.gd")
const AlbumEmblem = preload("res://scripts/MusicAlbumEmblem.gd")

var root_control: Control
var mascot: Button
var panel: PanelContainer
var current_label: Label
var toggle: CheckButton
var volume: HSlider
var track_buttons: Dictionary = {}
var visibility_accumulator: = 0.0
const TRACK_ICON_PATHS: = {
	"swim": "res://assets/images/v131/music_icons/bay_stroll.png", 
	"dynamite": "res://assets/images/v131/music_icons/golden_rhythm.png", 
	"permission_to_dance": "res://assets/images/v131/music_icons/free_step.png", 
}


func _ready() -> void :
	layer = 86
	_build()
	AudioManager.music_track_changed.connect(_on_track_changed)
	if GameFlow.has_signal("scene_requested"):
		GameFlow.scene_requested.connect( func(_path: String) -> void : call_deferred("_refresh_visibility"))
	set_process(true)
	call_deferred("_refresh")
	call_deferred("_refresh_visibility")


func _process(delta: float) -> void :
	visibility_accumulator += delta
	if visibility_accumulator < 0.24:
		return
	visibility_accumulator = 0.0
	_refresh_visibility()


func _build() -> void :
	root_control = Control.new()
	root_control.name = "GlobalMusicControl"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	mascot = MascotButton.new()
	mascot.name = "MusicMascot"
	mascot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mascot.position = Vector2(0, 16)
	mascot.custom_minimum_size = Vector2(58, 58)
	mascot.size = Vector2(58, 58)
	mascot.tooltip_text = "城市电台"
	mascot.mouse_filter = Control.MOUSE_FILTER_STOP
	mascot.pressed.connect(_toggle_panel)
	root_control.add_child(mascot)

	panel = PanelContainer.new()
	panel.name = "MusicPlayerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(0, 86)
	panel.size = Vector2(440, 410)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _panel(Color(0.01, 0.045, 0.066, 0.985), Color("e7c468"), 18, 4, 24))
	root_control.add_child(panel)

	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)

	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var header: = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var emblem: = _album_emblem("radio", Color("e7c468"))
	emblem.custom_minimum_size = Vector2(66, 66)
	header.add_child(emblem)
	var identity: = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(_label("CITY RADIO", 12, Color("71d0de"), true))
	identity.add_child(_label("城市经营电台", 27, Color("fff1c8"), true))
	identity.add_child(_label("自选音乐 · 放入 music 文件夹后重启", 13, Color("a9bec5")))
	var close: = Button.new()
	close.text = "收起"
	close.custom_minimum_size = Vector2(76, 42)
	Styles.apply_toy_button(close, false, Color("49a9c5"), 14)
	close.pressed.connect(_toggle_panel)
	header.add_child(close)

	current_label = _label("", 16, Color("f4d57a"), true)
	current_label.name = "NowPlaying"
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_label.custom_minimum_size.y = 48
	current_label.add_theme_stylebox_override("normal", _panel(Color(0.03, 0.115, 0.145, 0.94), Color("4e8492"), 12, 1, 6))
	box.add_child(current_label)

	for track: Dictionary in AudioManager.BGM_TRACKS:
		var button: = _track_button(track)
		box.add_child(button)
		track_buttons[str(track.id)] = button

	var controls: = HBoxContainer.new()
	controls.name = "PlaybackControls"
	controls.add_theme_constant_override("separation", 14)
	box.add_child(controls)
	toggle = CheckButton.new()
	toggle.text = "背景音乐"
	toggle.custom_minimum_size.x = 124
	toggle.toggled.connect(_set_music_enabled)
	controls.add_child(toggle)
	var volume_label: = _label("音量", 14, Color("d4e3e6"), true)
	volume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(volume_label)
	volume = HSlider.new()
	volume.name = "MusicVolume"
	volume.min_value = 0.0
	volume.max_value = 0.65
	volume.step = 0.01
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value_changed.connect(_set_volume)
	controls.add_child(volume)


func _track_button(track: Dictionary) -> Button:
	var id: = str(track.id)
	var accent: = _track_color(id)
	var button: = Button.new()
	button.name = "Track_%s" % id
	button.custom_minimum_size = Vector2(0, 78)
	button.text = ""
	button.tooltip_text = "切换到 %s" % str(track.title)
	button.pressed.connect(_select_track.bind(id))
	button.mouse_entered.connect( func() -> void : AudioManager.hover())
	var row: = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 8
	row.offset_right = -12
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	button.add_child(row)
	var icon: = TextureRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.texture = load(str(TRACK_ICON_PATHS.get(id, ""))) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var copy: = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_label(str(track.title), 18, Color("fff0c5"), true))
	copy.add_child(_label(_track_feeling(id), 13, Color("b8ccd2")))
	row.add_child(copy)
	return button


func _album_emblem(kind: String, accent: Color) -> Control:
	var emblem: Control = AlbumEmblem.new()
	emblem.call("setup", kind, accent)
	return emblem


func _toggle_panel() -> void :
	if not _is_city_map_visible():
		panel.visible = false
		return
	panel.visible = not panel.visible
	AudioManager.click()
	_refresh()


func _select_track(track_id: String) -> void :
	AudioManager.select_bgm(track_id)
	AudioManager.click()
	_refresh()


func _set_music_enabled(value: bool) -> void :
	GameSettings.set_audio_switches(value, GameSettings.sfx_enabled)
	_refresh()


func _set_volume(value: float) -> void :
	GameSettings.set_audio(float(value), GameSettings.sfx_volume, GameSettings.muted)
	_refresh()


func _on_track_changed(_track_id: String, _title: String) -> void :
	_refresh()


func _refresh_visibility() -> void :
	var visible_on_map: = _is_city_map_visible()
	root_control.visible = visible_on_map
	if visible_on_map:
		_reposition_for_city()
	if not visible_on_map and panel != null:
		panel.visible = false


func _is_city_map_visible() -> bool:
	var scene: = get_tree().current_scene
	if scene == null:
		return false
	if GameFlow.get("suspended_city") != null:
		return false
	return scene.scene_file_path == "res://scenes/CityMap.tscn"


func _reposition_for_city() -> void :
	var viewport_size: = root_control.get_viewport_rect().size
	mascot.position = Vector2(maxf(12.0, viewport_size.x - mascot.size.x - 18.0), 16.0)
	var panel_x: = viewport_size.x - panel.size.x - 18.0
	var scene: = get_tree().current_scene
	var ranking: = scene.get_node_or_null("UI/Ranking") as Control if scene != null else null
	if ranking != null and ranking.visible:
		panel_x = ranking.get_global_rect().position.x - panel.size.x - 12.0
	var panel_target: = Vector2(panel_x, mascot.position.y + mascot.size.y + 10.0)
	panel.position = Vector2(maxf(12.0, panel_target.x), minf(panel_target.y, viewport_size.y - panel.size.y - 18.0))


func _refresh() -> void :
	if mascot == null:
		return
	_refresh_visibility()
	mascot.set_active(GameSettings.music_enabled and not GameSettings.muted and not AudioManager.BGM_TRACKS.is_empty())
	toggle.set_pressed_no_signal(GameSettings.music_enabled)
	volume.set_value_no_signal(GameSettings.bgm_volume)
	var profile: Dictionary = AudioManager.playlist_profile()
	var current_id: = str(profile.get("current_id", ""))
	var current_title: = "未添加背景音乐" if AudioManager.BGM_TRACKS.is_empty() else "准备播放"
	for track: Dictionary in profile.get("tracks", []):
		var selected: = str(track.id) == current_id
		if selected:
			current_title = "%s  正在播放：%s" % [str(track.symbol), str(track.title)]
		var button: = track_buttons.get(str(track.id)) as Button
		if button != null:
			var accent: = _track_color(str(track.id))
			button.add_theme_stylebox_override("normal", _panel(Color(accent, 0.44) if selected else Color(0.032, 0.105, 0.145, 0.92), accent, 14, 2 if selected else 1, 12 if selected else 5))
			button.add_theme_stylebox_override("hover", _panel(Color(accent, 0.36), accent.lightened(0.2), 14, 2, 14))
			button.add_theme_color_override("font_color", Color("fff0c5") if selected else Color("d7e6e8"))
	current_label.text = current_title


func _track_color(track_id: String) -> Color:
	match track_id:
		"swim":
			return Color("65d0d8")
		"dynamite":
			return Color("edc85f")
		"permission_to_dance":
			return Color("8fb4ff")
		_:
			return Color("71d0de")


func _track_feeling(track_id: String) -> String:
	match track_id:
		"swim":
			return "清爽海风  松弛漫游"
		"dynamite":
			return "明亮能量  自信推进"
		"permission_to_dance":
			return "轻快自由  流动节拍"
		_:
			return "城市电台"


func _label(text: String, size: int, color: Color, medium: = false) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if medium:
		label.add_theme_font_override("font", load("res://Themes/V9141BodyMediumFont.tres") as Font)
	return label


func _panel(fill: Color, border: Color, radius: int, border_width: int, shadow: int) -> StyleBoxFlat:
	var style: = Styles.panel(fill, border, radius, 8)
	style.set_border_width_all(border_width)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = shadow
	return style
