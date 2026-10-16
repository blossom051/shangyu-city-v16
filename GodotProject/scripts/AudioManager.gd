extends Node

signal music_track_changed(track_id: String, title: String)

const AUDIO_ROOT: = "res://assets/audio/generated/"
# The public edition contains no bundled background music.
var BGM_TRACKS: Array[Dictionary] = []
const SFX_FILE_NAMES: = {
	"card_play": "card_felt_commit_v11.wav", 
	"talent_summon": "talent_contract_signature_v11.wav", 
	"talent_flip": "talent_dossier_turn_v11.wav", 
}
const SFX_KINDS: = [
	"ui_hover", "ui_confirm", "ui_cancel", "buy_land", "land_bid", "auction_hammer", 
	"build_start", "build_complete", "business_upgrade", "income", "large_expense", 
	"stock_buy", "stock_sell", "stock_surge", "stock_crash", "bank_loan", "bank_repay", 
	"talent_summon", "talent_flip", "rare_talent", "card_draw", "card_play", "attack_hit", 
	"defense_success", "risk_warning", "rank_up", "rank_down", "round_start", 
	"round_settlement", "victory", 
]
const SFX_COOLDOWN_MS: = {
	"ui_hover": 90, "ui_confirm": 130, "ui_cancel": 130, "buy_land": 280, "land_bid": 180, 
	"auction_hammer": 650, "build_start": 300, "build_complete": 420, "business_upgrade": 480, 
	"income": 220, "large_expense": 260, "stock_buy": 180, "stock_sell": 180, 
	"stock_surge": 550, "stock_crash": 550, "bank_loan": 420, "bank_repay": 420, 
	"talent_summon": 450, "talent_flip": 300, "rare_talent": 750, "card_draw": 240, 
	"card_play": 320, "attack_hit": 300, "defense_success": 360, "risk_warning": 700, 
	"rank_up": 650, "rank_down": 650, "round_start": 750, "round_settlement": 900, "victory": 1600, 
}
const SFX_SEMANTIC_GAIN: = {
	"ui_hover": 0.34, "ui_confirm": 0.58, "ui_cancel": 0.52, "buy_land": 0.72, "land_bid": 0.58, 
	"auction_hammer": 0.74, "build_start": 0.68, "build_complete": 0.72, "business_upgrade": 0.72, 
	"income": 0.62, "large_expense": 0.58, "stock_buy": 0.55, "stock_sell": 0.55, 
	"stock_surge": 0.66, "stock_crash": 0.62, "bank_loan": 0.66, "bank_repay": 0.62, 
	"talent_summon": 0.56, "talent_flip": 0.48, "rare_talent": 0.74, "card_draw": 0.58, 
	"card_play": 0.52, "attack_hit": 0.7, "defense_success": 0.66, "risk_warning": 0.62, 
	"rank_up": 0.66, "rank_down": 0.6, "round_start": 0.66, "round_settlement": 0.7, "victory": 0.78, 
}
const GROUP_COOLDOWN_MS: = {"funds": 180, "market_alarm": 420}

var music_players: Array[AudioStreamPlayer] = []
var active_music_index: = -1
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_voice: = 0
var bgm_volume: = 0.24
var sfx_volume: = 0.18
var muted: = false
var music_enabled: = true
var sfx_enabled: = true
var current_bgm: = ""
var music_tween: Tween
var streams: Dictionary = {}
var current_kind: = "global"
var current_track_index: = -1
var sfx_requests: = 0
var blocked_sfx_requests: = 0
var last_sfx_kind: = ""
var last_sfx_msec: Dictionary = {}
var last_group_msec: Dictionary = {}
var debug_virtual_audio: = false
var virtual_music_playing: = false


func _ready() -> void :
	var probe_mode: = OS.get_cmdline_user_args().has("--startup-probe")
	if DisplayServer.get_name() == "headless" or probe_mode:
		return
	_setup_audio_players()
	_load_streams()
	play_random_bgm()


func _exit_tree() -> void :
	if music_tween != null and music_tween.is_valid(): music_tween.kill()
	music_tween = null
	for player in music_players:
		if is_instance_valid(player): player.stop();player.stream = null
	for player in sfx_players:
		if is_instance_valid(player): player.stop();player.stream = null
	streams.clear();current_bgm = ""


func _load_streams() -> void :
	for kind: String in SFX_KINDS:
		var key: = "sfx_%s" % kind
		var path: = AUDIO_ROOT + str(SFX_FILE_NAMES.get(kind, key + ".wav"))
		if ResourceLoader.exists(path): streams[key] = load(path)
	var folder: String = ProjectSettings.globalize_path("res://music") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("music")
	_load_custom_music(folder)


func _load_custom_music(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder): return
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		var path: String = folder.path_join(file)
		var stream: AudioStream = null
		match file.get_extension().to_lower():
			"mp3": stream = AudioStreamMP3.load_from_file(path)
			"ogg": stream = AudioStreamOggVorbis.load_from_file(path)
			"wav": stream = AudioStreamWAV.load_from_file(path)
		if stream == null: continue
		var key: String = "custom_" + file.sha256_text()
		if streams.has(key): continue
		streams[key] = stream
		BGM_TRACKS.append({"id": key, "title": file.get_basename(), "subtitle": "自行添加的音乐", "file": file, "symbol": "♪"})


func play_bgm(kind: String = "") -> void :

	if not kind.is_empty() and _track_index(kind) >= 0:
		select_bgm(kind)
	elif current_track_index < 0:
		play_random_bgm()
	else:
		_switch_bgm_index(current_track_index)


func play_random_bgm() -> void :
	if BGM_TRACKS.is_empty(): return
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	_switch_bgm_index(rng.randi_range(0, BGM_TRACKS.size() - 1), true)


func select_bgm(track_id: String) -> void :
	var index: = _track_index(track_id)
	if index >= 0:
		_switch_bgm_index(index, true)


func sync_city_time(_normalized_time: float) -> void :

	if current_track_index < 0:
		play_random_bgm()


func _switch_bgm_index(index: int, force_restart: = false) -> void :
	if BGM_TRACKS.is_empty(): return
	current_kind = "global"
	index = posmod(index, BGM_TRACKS.size())
	var track: Dictionary = BGM_TRACKS[index]
	var key: = str(track.id)
	if debug_virtual_audio:
		current_track_index = index
		current_bgm = key
		virtual_music_playing = not muted and music_enabled
		music_track_changed.emit(key, str(track.title))
		return
	if not streams.has(key): return
	if current_bgm == key and not force_restart:
		if not muted and music_enabled and active_music_index >= 0 and not music_players[active_music_index].playing: music_players[active_music_index].play()
		return
	current_track_index = index
	current_bgm = key
	music_track_changed.emit(key, str(track.title))
	if music_players.is_empty(): return
	var old_index: = active_music_index
	active_music_index = 0 if active_music_index < 0 else (active_music_index + 1) % music_players.size()
	var next: = music_players[active_music_index];next.stream = streams[key];next.volume_db = -50.0
	if muted or not music_enabled: return
	next.play()
	if music_tween != null and music_tween.is_valid(): music_tween.kill()
	music_tween = create_tween().set_parallel(true)
	music_tween.tween_property(next, "volume_db", linear_to_db(maxf(0.001, bgm_volume)), 1.8).set_trans(Tween.TRANS_SINE)
	if old_index >= 0 and old_index != active_music_index:
		var old: = music_players[old_index]
		music_tween.tween_property(old, "volume_db", -50.0, 1.4).set_trans(Tween.TRANS_SINE)
		music_tween.chain().tween_callback(old.stop)


func set_bgm_volume(value: float) -> void : bgm_volume = clampf(value, 0.0, 1.0);_apply_volume()
func set_sfx_volume(value: float) -> void : sfx_volume = clampf(value, 0.0, 1.0);_apply_volume()


func set_muted(value: bool) -> void :
	muted = value;_apply_volume()
	if debug_virtual_audio: virtual_music_playing = not muted and music_enabled and not current_bgm.is_empty();return
	if muted:
		for player in music_players: player.stop()
	elif music_enabled and active_music_index >= 0 and not current_bgm.is_empty(): music_players[active_music_index].play()


func set_music_enabled(value: bool) -> void :
	music_enabled = value;_apply_volume()
	if debug_virtual_audio: virtual_music_playing = not muted and music_enabled and not current_bgm.is_empty();return
	if not music_enabled:
		for player in music_players: player.stop()
	elif not muted and active_music_index >= 0 and not current_bgm.is_empty(): music_players[active_music_index].play()


func set_sfx_enabled(value: bool) -> void : sfx_enabled = value;_apply_volume()

func hover() -> void : _play_sfx("ui_hover")
func click() -> void : _play_sfx("ui_confirm")
func cancel() -> void : _play_sfx("ui_cancel")
func enter_game() -> void : _play_sfx("ui_confirm")
func buy_land() -> void : _play_sfx("buy_land")
func land_bid() -> void : _play_sfx("land_bid")
func auction_hammer() -> void : _play_sfx("auction_hammer")
func build_start() -> void : _play_sfx("build_start")
func build_complete() -> void : _play_sfx("build_complete")
func business_upgrade() -> void : _play_sfx("business_upgrade")
func money_up() -> void : _play_sfx("income")
func money_down() -> void : _play_sfx("large_expense")
func stock_buy() -> void : _play_sfx("stock_buy")
func stock_sell() -> void : _play_sfx("stock_sell")
func stock_surge() -> void : _play_sfx("stock_surge")
func stock_crash() -> void : _play_sfx("stock_crash")
func stock_trade(buy: = true) -> void : _play_sfx("stock_buy" if buy else "stock_sell")
func bank_loan() -> void : _play_sfx("bank_loan")
func bank_repay() -> void : _play_sfx("bank_repay")
func talent_summon() -> void : _play_sfx("talent_summon")
func talent_flip() -> void : _play_sfx("talent_flip")
func red_talent() -> void : _play_sfx("rare_talent")
func card_draw() -> void : _play_sfx("card_draw")
func card_flip() -> void : _play_sfx("card_draw")
func card_play() -> void : _play_sfx("card_play")
func attack_hit() -> void : _play_sfx("attack_hit")
func guard() -> void : _play_sfx("defense_success")
func risk_warning() -> void : _play_sfx("risk_warning")
func rank_change(delta: = 1) -> void : _play_sfx("rank_up" if delta >= 0 else "rank_down")
func round_start() -> void : _play_sfx("round_start")
func settlement() -> void : _play_sfx("round_settlement")
func victory() -> void : _play_sfx("victory")
func success() -> void : build_complete()


func _play_sfx(kind: String) -> void :
	if not kind in SFX_KINDS or muted or not sfx_enabled: return
	var now: = Time.get_ticks_msec()
	if last_sfx_msec.has(kind) and now - int(last_sfx_msec[kind]) < int(SFX_COOLDOWN_MS.get(kind, 200)):
		blocked_sfx_requests += 1;return
	var group: = _sfx_group(kind)
	if not group.is_empty() and last_group_msec.has(group) and now - int(last_group_msec[group]) < int(GROUP_COOLDOWN_MS.get(group, 180)):
		blocked_sfx_requests += 1;return
	last_sfx_msec[kind] = now
	if not group.is_empty(): last_group_msec[group] = now
	last_sfx_kind = kind
	if debug_virtual_audio: sfx_requests += 1;return
	var key: = "sfx_%s" % kind
	if not streams.has(key) or sfx_players.is_empty(): return
	var player: = _next_sfx_player()
	if player == null: return
	sfx_requests += 1;player.stream = streams[key];player.pitch_scale = 1.0;_apply_volume()
	player.volume_db = linear_to_db(maxf(0.001, sfx_volume * float(SFX_SEMANTIC_GAIN.get(kind, 0.62))));player.play()


func _sfx_group(kind: String) -> String:
	if kind in ["income", "large_expense", "bank_loan", "bank_repay", "stock_buy", "stock_sell"]: return "funds"
	if kind in ["stock_surge", "stock_crash", "risk_warning", "rank_up", "rank_down"]: return "market_alarm"
	return ""


func _apply_volume() -> void :
	for i in range(music_players.size()): music_players[i].volume_db = linear_to_db(0.001 if muted or not music_enabled or i != active_music_index else maxf(0.001, bgm_volume))
	for player in sfx_players:
		if is_instance_valid(player): player.volume_db = linear_to_db(0.001 if muted or not sfx_enabled else maxf(0.001, sfx_volume))


func _on_music_finished(index: int) -> void :
	if BGM_TRACKS.is_empty(): return
	if index != active_music_index or muted or not music_enabled or current_bgm.is_empty(): return
	_switch_bgm_index((current_track_index + 1) % BGM_TRACKS.size(), true)


func _setup_audio_players() -> void :
	if not music_players.is_empty() and sfx_players.size() >= 4: return
	_ensure_bus("Music");_ensure_bus("SFX")
	for i in range(4):
		var voice: = AudioStreamPlayer.new();voice.name = "SFXVoice%d" % (i + 1);voice.bus = "SFX";sfx_players.append(voice);add_child(voice)
	for i in range(2):
		var player: = AudioStreamPlayer.new();player.name = "MusicPlayer%d" % (i + 1);player.bus = "Music";music_players.append(player);add_child(player);player.finished.connect(_on_music_finished.bind(i))


func _ensure_bus(bus_name: String) -> void :
	if AudioServer.get_bus_index(bus_name) >= 0: return
	AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func debug_initialize_audio() -> void :
	_setup_audio_players();debug_virtual_audio = true;virtual_music_playing = false


func playlist_profile() -> Dictionary:
	return {"tracks": BGM_TRACKS.duplicate(true), "current_id": current_bgm, "current_index": current_track_index, "default_volume": 0.24}


func capture_music_continuity() -> Dictionary:
	var position: = 0.0
	if not debug_virtual_audio and active_music_index >= 0 and active_music_index < music_players.size():
		var player: = music_players[active_music_index]
		if is_instance_valid(player):
			position = player.get_playback_position()
	return {"track_id": current_bgm, "position": position, "captured_msec": Time.get_ticks_msec()}


func restore_music_continuity(snapshot: Dictionary) -> void :
	if snapshot.is_empty() or str(snapshot.get("track_id", "")) != current_bgm:
		return
	if Time.get_ticks_msec() - int(snapshot.get("captured_msec", 0)) > 5000:
		return
	if debug_virtual_audio or active_music_index < 0 or active_music_index >= music_players.size():
		return
	var player: = music_players[active_music_index]
	if not is_instance_valid(player):
		return
	var expected: = float(snapshot.get("position", 0.0)) + float(Time.get_ticks_msec() - int(snapshot.get("captured_msec", 0))) / 1000.0
	var current: = player.get_playback_position()
	if current + 0.45 < expected:
		player.seek(expected)
	if not player.playing and not muted and music_enabled:
		player.play(expected)


func _track_index(track_id: String) -> int:
	for index in range(BGM_TRACKS.size()):
		if str(BGM_TRACKS[index].id) == track_id:
			return index
	return -1

func preview_sfx() -> void : _play_sfx("ui_confirm")


func _next_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if is_instance_valid(player) and not player.playing:
			next_sfx_voice = (sfx_players.find(player) + 1) % sfx_players.size();return player
	if sfx_players.is_empty(): return null
	var player: = sfx_players[next_sfx_voice % sfx_players.size()];next_sfx_voice = (next_sfx_voice + 1) % sfx_players.size();return player


func audio_state_profile() -> Dictionary:
	var music_playing: = virtual_music_playing if debug_virtual_audio else false
	if not debug_virtual_audio:
		for player: AudioStreamPlayer in music_players: music_playing = music_playing or player.playing
	return {"music_enabled": music_enabled, "sfx_enabled": sfx_enabled, "music_playing": music_playing, "sfx_allowed": not muted and sfx_enabled, "sfx_requests": sfx_requests, "blocked_sfx_requests": blocked_sfx_requests, "last_sfx_kind": last_sfx_kind, "sfx_catalog": SFX_KINDS.duplicate(), "bgm_volume": bgm_volume, "sfx_volume": sfx_volume, "confirm_gain": float(SFX_SEMANTIC_GAIN.ui_confirm), "music_bus": music_players[0].bus if not music_players.is_empty() else "", "sfx_bus": sfx_players[0].bus if not sfx_players.is_empty() else "", "sfx_voice_count": sfx_players.size(), "current_kind": current_kind, "current_bgm": current_bgm, "funds_throttle_ms": int(GROUP_COOLDOWN_MS.funds)}
