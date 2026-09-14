extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var cs: Node = root.get_node("CombatService")
	var ps: Node = root.get_node("PackService")

	gs.active_pack_id = "clicky"
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
	assert(res.has("trace"), "Result should have trace key")
	assert(typeof(res["trace"]) == TYPE_ARRAY, "trace should be an Array")
	assert(res["trace"].size() >= 3, "trace should have at least 3 events (tile_hop, form_ignite, clash_resolve)")

	var step_types: Array = []
	for ev in res["trace"]:
		step_types.append(ev.get("step_type", ""))

	assert(step_types.has("tile_hop"), "trace should contain tile_hop events")
	assert(step_types.has("form_ignite"), "trace should contain form_ignite event")
	assert(step_types.has("clash_resolve"), "trace should contain clash_resolve event")

	var last_event: Dictionary = res["trace"][res["trace"].size() - 1]
	assert(last_event["step_type"] == "clash_resolve", "Last event should be clash_resolve")
	assert(last_event["annotation"] == "= %d DMG" % res["damage"], "clash_resolve annotation should match damage")

	for ev in res["trace"]:
		assert(ev.has("step_type"), "each event should have step_type")
		assert(ev.has("source_index"), "each event should have source_index")
		assert(ev.has("label"), "each event should have label")
		assert(ev.has("delta_chips"), "each event should have delta_chips")
		assert(ev.has("delta_mult"), "each event should have delta_mult")
		assert(ev.has("x_mult"), "each event should have x_mult")
		assert(ev.has("running_chips"), "each event should have running_chips")
		assert(ev.has("running_mult"), "each event should have running_mult")
		assert(ev.has("annotation"), "each event should have annotation")

	print("OK: Scoring trace pipeline — %d events, final damage=%d" % [res["trace"].size(), res["damage"]])
	quit(0)
