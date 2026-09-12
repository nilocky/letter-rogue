extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var cs: Node = root.get_node("CombatService")
	var failures := 0

	gs.current_monster = {"hp": 10, "hp_remaining": 10, "modifier": "silence"}
	var word: Array = [
		{"cap": {"letter": "A", "is_symbol": false, "finish": "foil", "sticker": "", "condition": ""}, "letter": "A"},
		{"cap": {"letter": "B", "is_symbol": false, "finish": "", "sticker": "gold", "condition": ""}, "letter": "B"}
	]
	var res: Dictionary = cs.calculate_word(word)
	if res.get("damage", 0) != 3:
		print("  silence: expected 3 got ", res.get("damage", 0))
		failures += 1

	gs.current_monster = {"hp": 10, "hp_remaining": 10, "modifier": "vowel_lock"}
	word = [
		{"cap": {"letter": "A", "is_symbol": false}, "letter": "A"},
		{"cap": {"letter": "B", "is_symbol": false}, "letter": "B"}
	]
	res = cs.calculate_word(word)
	if res.get("damage", 0) != 1:
		print("  vowel_lock: expected 1 got ", res.get("damage", 0))
		failures += 1

	gs.current_monster = {"hp": 10, "hp_remaining": 10, "modifier": "consonant_lock"}
	word = [
		{"cap": {"letter": "A", "is_symbol": false}, "letter": "A"},
		{"cap": {"letter": "B", "is_symbol": false}, "letter": "B"}
	]
	res = cs.calculate_word(word)
	if res.get("damage", 0) != 2:
		print("  consonant_lock: expected 2 got ", res.get("damage", 0))
		failures += 1

	gs.current_monster = {"hp": 10, "hp_remaining": 10, "modifier": "no_repeats"}
	var val: Dictionary = cs.validate_word([
		{"cap": {"letter": "A"}, "letter": "A"},
		{"cap": {"letter": "A"}, "letter": "A"},
		{"cap": {"letter": "B"}, "letter": "B"}
	])
	if val.get("ok", false) != false:
		print("  no_repeats: expected false got true")
		failures += 1

	print("[modifier] failures=", failures)
	quit(failures)
