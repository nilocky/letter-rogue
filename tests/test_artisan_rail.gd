extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var arm: Node = root.get_node("ArtisanRailManager")
	var ps: Node = root.get_node("PackService")

	gs.active_pack_id = "mx_red"
	gs.word_form_levels = {}
	gs.redraws_left = 3
	gs.turns_left = 3

	var packs_text := FileAccess.get_file_as_string("res://data/packs.json")
	var packs_data: Variant = JSON.parse_string(packs_text)
	ps.available_packs = packs_data.get("packs", [])

	var art_text := FileAccess.get_file_as_string("res://data/artisans.json")
	var art_data: Variant = JSON.parse_string(art_text)
	var artisans: Array = art_data.get("artisans", [])

	var caps_lock: Dictionary = {}
	for a in artisans:
		if str(a["id"]) == "caps_lock":
			caps_lock = a
			break
	assert(not caps_lock.is_empty(), "Caps Lock artisan should exist")

	var equipped: bool = arm.equip(0, caps_lock)
	assert(equipped, "Should equip to slot 0")

	var slots3: Array = []
	for l in "CAT":
		slots3.append({"cap": {"letter": l}, "letter": l})
	var res3: Dictionary = arm.cascade("CAT", slots3, [1.0, 1.0, 1.0], {}, {})
	assert(res3["flat"] == 0, "Caps Lock should not trigger on 3-letter word")

	var slots4: Array = []
	for l in "BEAR":
		slots4.append({"cap": {"letter": l}, "letter": l})
	var res4: Dictionary = arm.cascade("BEAR", slots4, [1.0, 1.0, 1.0, 1.0], {}, {})
	assert(res4["flat"] == 8, "Caps Lock should add +8 flat on 4-letter word, got %d" % res4["flat"])

	var rotary: Dictionary = {}
	for a in artisans:
		if str(a["id"]) == "rotary_knob":
			rotary = a
			break
	arm.equip(0, rotary)
	gs.redraws_left = 2
	var res_rot: Dictionary = arm.cascade("BEAR", slots4, [1.0, 1.0, 1.0, 1.0], {}, {})
	assert(absf(res_rot["xmult"] - 1.69) < 0.01, "Rotary Knob should be 1.3^2=1.69, got %.2f" % res_rot["xmult"])

	print("OK: Artisan rail cascade working — flat=%d xmult=%.2f" % [res4["flat"], res_rot["xmult"]])
	quit(0)
