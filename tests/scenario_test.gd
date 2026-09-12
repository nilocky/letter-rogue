extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var cs: Node = root.get_node("CombatService")
	var failures := 0
	gs.reset()
	gs.setup_new_run("mx_red", "standard")
	gs.current_monster = {"name": "Test", "hp": 10, "modifier": "", "hp_remaining": 10}
	cs.start_round()
	var slots: Array = [{"cap": {"letter": "C", "is_symbol": false, "finish": "", "sticker": "", "condition": ""}, "letter": "C"},
		{"cap": {"letter": "A", "is_symbol": false, "finish": "", "sticker": "", "condition": ""}, "letter": "A"},
		{"cap": {"letter": "T", "is_symbol": false, "finish": "", "sticker": "", "condition": ""}, "letter": "T"}]
	var res: Dictionary = cs.calculate_word(slots)
	failures += 0 if res.get("damage", 0) > 0 else 1
	print("[scenario] failures=", failures)
	quit(failures)
