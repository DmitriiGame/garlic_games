extends Node
## Эффекты на шине SFX, музыка на шине Music. Ползунки — user://settings.cfg.
## На вебе потоки идут через AudioServer (playback Stream): sample-граф
## молчит, если шины появились после старта драйвера. AudioContext на Android
## будит html/head_include, из touchend и pointerup.

const MUSIC_PATH := "res://audio/music/main.ogg"
const MUSIC_TRIM_DB := -10.0
const CROSSFADE := 3.2
const FADE_IN := 1.8
const PLAYBACK_STREAM := 1

var muted: bool = false
var volume: float = 0.4
var music_volume: float = 0.4
var heard_input: bool = false
var players: Dictionary = {}
var ducked: bool = false

var _music: Array[AudioStreamPlayer] = []
var _music_lead := 0
var _music_on := false
var _cross := false
var _cross_t := 0.0
var _fade := 0.0
var _duck := 1.0


func _ready() -> void:
	_load_settings()
	_ensure_buses()
	_apply_bus()
	if not OS.has_feature("web"):
		_ensure_music()


func _process(delta: float) -> void:
	if not _music_on or _music.size() < 2:
		return
	_fade = minf(1.0, _fade + delta / FADE_IN)
	var duck_goal := 0.2 if ducked else 1.0
	_duck = move_toward(_duck, duck_goal, delta / 0.55)
	var lead := _music[_music_lead]
	var other := _music[1 - _music_lead]
	if not lead.playing:
		if _cross and other.playing:
			lead.volume_db = _mix_db(0.0)
			other.volume_db = _mix_db(1.0)
			_music_lead = 1 - _music_lead
			_cross = false
			return
		_start_player(lead)
		_cross = false
	var remain := _music_length() - lead.get_playback_position()
	if not _cross and remain <= CROSSFADE:
		_start_player(other)
		_cross = true
		_cross_t = 0.0
	var lead_amt := 1.0
	var other_amt := 0.0
	if _cross:
		_cross_t += delta
		var t := clampf(_cross_t / CROSSFADE, 0.0, 1.0)
		lead_amt = 1.0 - t
		other_amt = t
		if t >= 1.0:
			lead.stop()
			_music_lead = 1 - _music_lead
			_cross = false
	lead.volume_db = _mix_db(lead_amt)
	other.volume_db = _mix_db(other_amt)


func note_input() -> void:
	heard_input = true
	_ensure_buses()
	_apply_bus()
	_ensure_music()


func play(id: String, gain_db: float = 0.0) -> void:
	if id == "":
		return
	if OS.has_feature("web") and not heard_input:
		return
	if muted or volume <= 0.001:
		return
	var player := _player(id)
	if player == null:
		return
	player.volume_db = gain_db
	player.play()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_bus()
	_save()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus()
	_save()
	_ensure_music()


func set_duck(on: bool) -> void:
	ducked = on


func toggle_mute() -> bool:
	muted = not muted
	_apply_bus()
	_save()
	if not muted:
		_ensure_music()
	return muted


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	muted = bool(cfg.get_value("audio", "muted", false))
	var has_music := cfg.has_section_key("audio", "music")
	var has_version := cfg.has_section_key("audio", "v")
	volume = _read_unit(cfg, "volume", volume)
	if has_music:
		music_volume = _read_unit(cfg, "music", music_volume)
	else:
		# Старый единственный ползунок управлял всем.
		music_volume = volume if volume > 0.001 else 0.4
	# Ползунки нового титра могли записать 0 при создании, без кнопки «Тихо».
	if not has_version and not muted and volume <= 0.001 and music_volume <= 0.001:
		volume = 0.4
		music_volume = 0.4


func _read_unit(cfg: ConfigFile, key: String, fallback: float) -> float:
	if not cfg.has_section_key("audio", key):
		return fallback
	var number := float(cfg.get_value("audio", key))
	if is_nan(number) or is_inf(number):
		return fallback
	if number < 0.0:
		number = db_to_linear(number)
	if number > 1.0 and number <= 100.0:
		number /= 100.0
	return clampf(number, 0.0, 1.0)


func _ensure_buses() -> void:
	_bus("SFX")
	_bus("Music")


func _bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index


func _apply_bus() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, -80.0 if muted else 0.0)
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx >= 0:
		if volume <= 0.001:
			AudioServer.set_bus_volume_db(sfx, -80.0)
		else:
			AudioServer.set_bus_volume_db(sfx, linear_to_db(volume * 0.45))
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		if music_volume <= 0.001:
			AudioServer.set_bus_volume_db(music, -80.0)
		else:
			AudioServer.set_bus_volume_db(music, linear_to_db(music_volume * 0.45) + MUSIC_TRIM_DB)


func _make_player(stream: AudioStream, bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.playback_type = PLAYBACK_STREAM
	player.bus = bus_name
	add_child(player)
	return player


func _player(id: String) -> AudioStreamPlayer:
	if players.has(id):
		return players[id]
	var path := "res://audio/%s.ogg" % id
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	var player := _make_player(stream, "SFX")
	players[id] = player
	return player


func _ensure_music() -> void:
	if _music_on or muted or music_volume <= 0.001:
		return
	if OS.has_feature("web") and not heard_input:
		return
	if not ResourceLoader.exists(MUSIC_PATH) and not FileAccess.file_exists(MUSIC_PATH):
		return
	var stream: AudioStream = load(MUSIC_PATH)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_ensure_buses()
	_apply_bus()
	for _i in 2:
		var player := _make_player(stream, "Music")
		player.volume_db = -80.0
		_music.append(player)
	_music_lead = 0
	_fade = 0.0
	_duck = 1.0
	_cross = false
	_start_player(_music[0])
	_music_on = true


func _start_player(player: AudioStreamPlayer) -> void:
	player.stop()
	player.play()


func _music_length() -> float:
	if _music.is_empty() or _music[0].stream == null:
		return 180.0
	var length := _music[0].stream.get_length()
	return length if length > 1.0 else 180.0


func _mix_db(amount: float) -> float:
	var lin := maxf(0.0008, amount * _fade * _duck)
	return linear_to_db(lin)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "v", 2)
	cfg.save("user://settings.cfg")
