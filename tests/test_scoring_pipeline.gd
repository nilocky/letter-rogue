extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var cs: Node = root.get_node("CombatService")
	var ps: Node = root.get_node("PackService")

	gs.active_pack_id = "mx_red"
	gs.word_form_levels = {}
	gs.current_monster = {"name": "Test", "hp": 10, "modifier": "", "hp_remaining": 10}

	var packs_text := FileAccess.get_file_as_string("res://data/packs.json")
	var packs_data: Variant = JSON.parse_string(packs_text)
	ps.available_packs = packs_data.get("packs", [])

	var slots: Array = [
		{"cap": {"letter": "C", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": "C"},
		{"cap": {"letter": "A", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": "A"},
		{"cap": {"letter": "T", "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": "T"}
	]
	var res: Dictionary = cs.calculate_word(slots)
	assert(res.has("damage"), "Result should have damage")
	assert(res.has("form_data"), "Result should have form_data")
	assert(res["form_data"].get("form_id") == "trio", "CAT should detect as trio")
	assert(res["damage"] > 0, "Damage should be positive")

	var slots2: Array = []
	for l in "LEVEL":
		slots2.append({"cap": {"letter": l, "ability_id": "bonus_points", "rarity": "Normal", "ability_strength": 1, "is_symbol": false}, "letter": l})
	var res2: Dictionary = cs.calculate_word(slots2)
	assert(res2["form_data"].get("form_id") == "mirror", "LEVEL should detect as mirror")

	print("OK: 4-phase scoring pipeline working — CAT=%.1f dmg, LEVEL=%.1f dmg" % [res["damage"], res2["damage"]])
	quit(0)
