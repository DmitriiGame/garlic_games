extends Node
## Синтетические звуки из audio/. Играют только после первого касания.

var muted := false
var unlocked := false
var players := {}

const IDS: Array[String] = ["tap", "throw", "catch", "miss", "coin", "unlock"]


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
	for id in IDS:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://audio/%s.wav" % id)
		player.volume_db = -6.0
		add_child(player)
		players[id] = player


func unlock() -> void:
	unlocked = true


func play(id: String) -> void:
	if not unlocked or muted:
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
	if not muted:
		unlocked = true
		play("tap")
	return muted
