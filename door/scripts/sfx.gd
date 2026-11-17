extends Node
## Мягкие звуки. Файлы — res://audio/<id>.ogg, громкость общая и невысокая.

var muted: bool = false
var volume: float = 0.4
var heard_input: bool = false
var players: Dictionary = {}


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	_apply_bus()


func note_input() -> void:
	heard_input = true


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


func toggle_mute() -> bool:
	muted = not muted
	_apply_bus()
	_save()
	return muted


func _apply_bus() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if muted or volume <= 0.001:
		AudioServer.set_bus_volume_db(bus, -80.0)
		return
	# Потолок ниже 0 дБ: сами файлы тоже тихие, клиппинга не будет.
	AudioServer.set_bus_volume_db(bus, linear_to_db(volume * 0.45))


func _player(id: String) -> AudioStreamPlayer:
	if players.has(id):
		return players[id]
	var path := "res://audio/%s.ogg" % id
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	players[id] = player
	return player


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "volume", volume)
	cfg.save("user://settings.cfg")
