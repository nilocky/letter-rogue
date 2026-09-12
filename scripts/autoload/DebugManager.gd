extends Node
## Debug autoload: backtick overlay, F12 screenshot, time-scale, scene routing.
## No-ops outside debug builds.

const OVERLAY_SCENE_PATH := "res://scenes/debug/DebugOverlay.tscn"

signal overlay_state_changed(open: bool)

var _overlay: Control = null


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_QUOTELEFT:
				toggle_overlay()
			KEY_F12:
				screenshot()


func toggle_overlay() -> void:
	if is_overlay_open():
		close_overlay()
	else:
		open_overlay()


func open_overlay() -> void:
	if _overlay != null:
		return
	_overlay = load(OVERLAY_SCENE_PATH).instantiate()
	get_tree().root.add_child(_overlay)
	overlay_state_changed.emit(true)


func close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null
	overlay_state_changed.emit(false)


func is_overlay_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)


func screenshot() -> void:
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var path := "%s/debug_%s.png" % [dir, stamp]
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[debug] screenshot -> %s" % path)


func set_time_scale(v: float) -> void:
	Engine.time_scale = clampf(v, 0.0, 4.0)


func route_to(state: String) -> void:
	var root: Node = get_node_or_null("/root/GameRoot")
	if root and root.has_method("route_to"):
		root.route_to(state)


func inject_state(cfg: Dictionary) -> void:
	var root: Node = get_node_or_null("/root/GameRoot")
	if root and root.has_method("inject_state"):
		root.inject_state(cfg)


func trigger_mechanic(id: String) -> void:
	var root: Node = get_node_or_null("/root/GameRoot")
	if root and root.has_method("trigger_mechanic"):
		root.trigger_mechanic(id)