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
	_test_bag_modal()
	_test_victory_modal()
	await _test_combat_screen()
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


func _test_victory_modal() -> void:
	var scene: PackedScene = load("res://scenes/components/VictoryModal.tscn")
	_check(scene != null, "VictoryModal scene loads")
	var modal: Control = scene.instantiate()
	add_child(modal)
	await get_tree().process_frame
	_check(modal.has_method("open"), "VictoryModal has open()")
	modal.queue_free()
	await get_tree().process_frame


func _test_bag_modal() -> void:
	var scene: PackedScene = load("res://scenes/components/BagModal.tscn")
	if scene == null:
		_check(false, "BagModal scene loads")
		return
	var modal: Control = scene.instantiate()
	add_child(modal)
	await get_tree().process_frame
	_check(modal.has_method("open"), "BagModal has open()")
	var close_btn: Button = modal.get_node("CloseButton")
	_check(close_btn != null, "BagModal has CloseButton")
	if close_btn != null:
		_check(close_btn.custom_minimum_size.y >= 120.0, "close button >= 120 tall")
	modal.queue_free()
	await get_tree().process_frame


func _test_combat_screen() -> void:
	var scene: PackedScene = load("res://scenes/CombatScreen.tscn")
	_check(scene != null, "CombatScreen loads")
	var screen: Control = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	_check(screen.get_node("%PlayButton") != null, "PlayButton exists")
	_check(screen.get_node("%BagButton") != null, "BagButton exists")
	_check(screen.get_node("%RedrawButton") != null, "RedrawButton exists")
	_check(screen.get_node("%SkipButton") == null, "SkipButton removed")
	_check(screen.get_node("%BackspaceButton") == null, "BackspaceButton removed")
	var play_btn: Button = screen.get_node("%PlayButton")
	_check(play_btn.custom_minimum_size.y >= 130.0, "PlayButton >= 130 tall")
	screen.queue_free()
	await get_tree().process_frame
