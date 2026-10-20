class_name AudioService
extends Node

## 极简音效池：走路脚步与挥手 whoosh。没有鼠标音效。
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _pitch_variation: float = 0.06


func setup() -> void:
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	for sound_name in ["sfx_step_01", "sfx_wave_whoosh", "sfx_wave"]:
		var path := "res://assets/sfx/%s.ogg" % sound_name
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)


func play(sound_name: String, volume_db: float = -10.0) -> void:
	if not _streams.has(sound_name):
		return
	var player: AudioStreamPlayer = null
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _players[0]
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-_pitch_variation, _pitch_variation)
	player.play()
