extends Node

const TARGET_ASPECT: float = 9.0 / 16.0

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_size_changed)
	adapt_window_for_platform()

func adapt_window_for_platform() -> void:
	match OS.get_name():
		"Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD":
			_fit_desktop()
		_:
			_fit_mobile()

func _fit_desktop() -> void:
	var screen_id := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_id)
	var h: int = int(usable.size.y * 0.82)
	h -= h % 2
	var w: int = int(round(h * TARGET_ASPECT))
	w -= w % 2
	var size := Vector2i(w, h)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)

func _fit_mobile() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_window_size_changed() -> void:
	pass
