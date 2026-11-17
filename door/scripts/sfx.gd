extends Node
## Короткие синтезированные звуки. Файлы лежат в audio/ и генерируются tools/make_sfx.py.

var muted: bool = false
var players: Dictionary = {}

const IDS: Array[String] = ["tap", "good", "bad", "death", "win", "knock", "whoosh"]


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
	for id in IDS:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://audio/%s.wav" % id)
		player.volume_db = -4.0
		add_child(player)
		players[id] = player


func play(id: String) -> void:
	if muted:
		return
	var player: AudioStreamPlayer = players.get(id)
	if player == null or player.stream == null:
		return
	player.play()


func toggle_mute() -> bool:
	muted = not muted
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "muted", muted)
	cfg.save("user://settings.cfg")
	return muted
