extends Node

var _cache: Dictionary = {}

func play(sfx_id: String, pitch: float = 1.0) -> void:
	if not _cache.has(sfx_id):
		var path := "res://assets/audio/%s.ogg" % sfx_id
		if not ResourceLoader.exists(path):
			path = "res://assets/audio/%s.wav" % sfx_id
			if not ResourceLoader.exists(path):
				return
		var stream: AudioStream = load(path)
		if stream == null:
			return
		_cache[sfx_id] = stream

	var player := AudioStreamPlayer2D.new()
	player.stream = _cache[sfx_id]
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
