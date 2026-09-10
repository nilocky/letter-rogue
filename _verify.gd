extends Node

var _failures: int = 0


func _ready() -> void:
	get_window().size = Vector2i(1080, 1920)
	await get_tree().process_frame
	_test_starter_bags()
	_test_setup_new_run()
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


func _test_starter_bags() -> void:
	if not KeyCapService.has_method("get_starter_bags"):
		_check(false, "KeyCapService.get_starter_bags missing")
		return
	var bags: Array = KeyCapService.get_starter_bags()
	_check(bags.size() == 4, "expected 4 starter bags, got %d" % bags.size())
	for bag_id: String in ["standard", "vowel", "consonant", "minimalist"]:
		var tiles: Array = KeyCapService.load_starter_bag(bag_id)
		_check(not tiles.is_empty(), "bag %s has tiles" % bag_id)
	_check(KeyCapService.load_starter_bag("standard").size() == 8, "standard has 8 tiles")
	_check(KeyCapService.load_starter_bag("minimalist").size() == 6, "minimalist has 6 tiles")
	_check(KeyCapService.starter_bag_money("minimalist") == 15, "minimalist money is 15")
	_check(
		KeyCapService.load_starter_bag("does_not_exist").size() == 8,
		"unknown bag id falls back to standard"
	)


func _test_setup_new_run() -> void:
	if not GameState.has_method("setup_new_run"):
		_check(false, "GameState.setup_new_run missing")
		return
	GameState.setup_new_run("mx_brown", "minimalist")
	_check(GameState.active_pack_id == "mx_brown", "pack id applied")
	_check(GameState.active_starter_bag_id == "minimalist", "bag id applied")
	_check(GameState.bag.size() == 6, "minimalist bag loaded")
	_check(GameState.money == 30, "money is 10 base + 5 pack + 15 bag")
	_check(GameState.draw_size() == 5, "mx_brown draw size is 5")
	GameState.setup_new_run("mx_speed", "standard")
	_check(GameState.draw_size() == 6, "mx_speed draw size is 6")
	GameState.setup_new_run("mx_black", "standard")
	_check(GameState.draw_size() == 4, "mx_black draw size is 4")
