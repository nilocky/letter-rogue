extends Node

var _failures: int = 0


func _ready() -> void:
	get_window().size = Vector2i(1080, 1920)
	await get_tree().process_frame
	_test_length_multiplier()
	_test_validate_word()
	_test_no_skip_turn()
	_test_eventbus_signals()
	await _test_game_root_signals()
	if _failures == 0:
		print("VERIFY OK")
		get_tree().quit(0)
	else:
		print("VERIFY FAILED: %d" % _failures)
		get_tree().quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


func _test_length_multiplier() -> void:
	if not WordService.has_method("length_multiplier"):
		_check(false, "WordService.length_multiplier exists")
		return
	_check(WordService.length_multiplier(1) == 1.0, "len 1 mult 1.0")
	_check(WordService.length_multiplier(2) == 1.0, "len 2 mult 1.0")
	_check(WordService.length_multiplier(3) == 1.0, "len 3 mult 1.0")
	_check(WordService.length_multiplier(4) == 1.3, "len 4 mult 1.3")


func _test_validate_word() -> void:
	if not CombatService.has_method("validate_word"):
		_check(false, "CombatService.validate_word exists")
		return
	var slots1: Array = [{"cap": {"letter": "A"}, "letter": "A"}]
	var r1: Dictionary = CombatService.validate_word(slots1)
	_check(r1.get("ok", false), "1-letter word is valid")

	var slots2: Array = [
		{"cap": {"letter": "X"}, "letter": "X"},
		{"cap": {"letter": "Z"}, "letter": "Z"},
	]
	var r2: Dictionary = CombatService.validate_word(slots2)
	_check(r2.get("ok", false), "2-letter word is valid (no dict check)")


func _test_no_skip_turn() -> void:
	_check(not CombatService.has_method("skip_turn"), "skip_turn removed")


func _test_eventbus_signals() -> void:
	if not EventBus.has_signal("shop_requested"):
		_check(false, "shop_requested signal exists")
		return
	_check(EventBus.shop_requested != null, "shop_requested signal exists")
	if not EventBus.has_signal("game_complete"):
		_check(false, "game_complete signal exists")
		return
	_check(EventBus.game_complete != null, "game_complete signal exists")
	_check(not EventBus.has_signal("pack_selected"), "pack_selected removed")


func _test_game_root_signals() -> void:
	var scene: PackedScene = load("res://scenes/GameRoot.tscn")
	if scene == null:
		_check(false, "GameRoot scene loads")
		return
	var game_root: Variant = scene.instantiate()
	add_child(game_root)
	await get_tree().process_frame
	_check(game_root.has_method("_on_shop_requested"), "game_root has _on_shop_requested")
	_check(game_root.has_method("_on_game_complete"), "game_root has _on_game_complete")
	game_root.queue_free()
	await get_tree().process_frame
