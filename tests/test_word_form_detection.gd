extends SceneTree

func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var ws: Node = root.get_node("WordFormService")

	gs.word_form_levels = {}

	var trio: Dictionary = ws.detect([{"letter":"C"},{"letter":"A"},{"letter":"T"}])
	assert(trio.get("form_id") == "trio", "CAT should be trio, got %s" % trio.get("form_id"))

	var quartet: Dictionary = ws.detect([{"letter":"B"},{"letter":"E"},{"letter":"A"},{"letter":"R"}])
	assert(quartet.get("form_id") == "quartet", "BEAR should be quartet, got %s" % quartet.get("form_id"))

	var quintet: Dictionary = ws.detect([{"letter":"C"},{"letter":"R"},{"letter":"A"},{"letter":"N"},{"letter":"E"}])
	assert(quintet.get("form_id") == "quintet", "CRANE should be quintet, got %s" % quintet.get("form_id"))

	var mirror: Dictionary = ws.detect([{"letter":"L"},{"letter":"E"},{"letter":"V"},{"letter":"E"},{"letter":"L"}])
	assert(mirror.get("form_id") == "mirror", "LEVEL should be mirror, got %s" % mirror.get("form_id"))

	var dt: Dictionary = ws.detect([{"letter":"B"},{"letter":"O"},{"letter":"O"},{"letter":"K"}])
	assert(dt.get("form_id") == "double_tap", "BOOK should be double_tap, got %s" % dt.get("form_id"))

	var cc: Dictionary = ws.detect([{"letter":"Q"},{"letter":"U"},{"letter":"I"},{"letter":"Z"},{"letter":"X"}])
	assert(cc.get("form_id") == "consonant_core", "QUIZX should be consonant_core, got %s" % cc.get("form_id"))

	var level_mirror: Dictionary = ws.detect([{"letter":"L"},{"letter":"E"},{"letter":"V"},{"letter":"E"},{"letter":"L"}])
	assert(level_mirror.get("form_id") == "mirror", "LEVEL should be mirror (not quintet), got %s" % level_mirror.get("form_id"))

	print("OK: All word form detections pass")
	quit(0)
