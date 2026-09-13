extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var ks: Node = root.get_node("KeyCapService")
	gs.bag = ks.load_starter_bag("standard")
	assert(gs.bag.size() == 14)
	gs.active_pack_id = "clicky"
	gs.hand.clear()
	gs.discard_pile.clear()

	# Draw initial hand
	ks.draw_hand()
	var initial_hand_size: int = gs.hand.size()
	assert(initial_hand_size > 0, "Hand should not be empty")

	# Simulate playing 3 tiles (they go to discard)
	var used: Array = [gs.hand[0], gs.hand[1], gs.hand[2]]
	gs.discard_pile.append_array(used)
	for cap in used:
		gs.hand.erase(cap)

	# Unused tiles should still be in hand
	assert(gs.hand.size() == initial_hand_size - 3,
		"Unused tiles should stay in hand, got %d" % gs.hand.size())
	assert(gs.discard_pile.size() == 3,
		"Used tiles should go to discard, got %d" % gs.discard_pile.size())

	# Refill hand
	ks.draw_hand()
	assert(gs.hand.size() <= gs.draw_size(),
		"Hand should not exceed draw size after refill")

	# Vowel safeguard check
	const VOWELS := "AEIOU"
	var vowels := 0
	for cap in gs.hand:
		var l: String = str(cap.get("letter", ""))
		if VOWELS.contains(l) or l == "~" or l == "*":
			vowels += 1
	assert(vowels >= 2, "Hand should have at least 2 vowels/wildcards, got %d" % vowels)

	print("OK: Play-and-refill + vowel safeguard working")
	quit(0)
