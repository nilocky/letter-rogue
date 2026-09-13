extends SceneTree

func _init() -> void:
	await process_frame
	var ps: Node = root.get_node("PackService")

	var clicky: Dictionary = ps.pack_by_id("clicky")
	assert(not clicky.is_empty(), "Clicky pack should exist")
	assert(clicky.get("name") == "Clicky Pack")

	var conds: Array = clicky.get("conditionals", [])
	assert(conds.size() == 2, "Clicky should have 2 conditionals")

	var silent: Dictionary = ps.pack_by_id("silent")
	assert(not silent.is_empty(), "Silent pack should exist")

	var slots: Array = []
	for l in "QUIZ":
		slots.append({"letter": l, "cap": {"letter": l}})
	var result: Dictionary = ps.evaluate_conditionals("clicky", "QUIZ", slots, [])
	assert(result["score_mult"] == 1.5, "Clicky should give 1.5x for rare consonants, got %s" % result["score_mult"])

	var plain: Array = []
	for l in "BEAR":
		plain.append({"letter": l, "cap": {"letter": l}})
	var no_rare: Dictionary = ps.evaluate_conditionals("clicky", "BEAR", plain, [])
	assert(no_rare["score_mult"] == 1.0, "No rare consonants should give 1.0x, got %s" % no_rare["score_mult"])

	var five: Array = []
	for l in "CRANE":
		five.append({"letter": l, "cap": {"letter": l}})
	var long_res: Dictionary = ps.evaluate_conditionals("tactile", "CRANE", five, [])
	assert(long_res["xmult"] == 1.5, "Tactile should give 1.5x for 5-letter words, got %s" % long_res["xmult"])

	print("OK: Switch packs rewritten with conditional passives")
	quit(0)