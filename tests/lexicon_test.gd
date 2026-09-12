extends SceneTree

func _init() -> void:
	await process_frame
	var ws: Node = root.get_node("WordService")
	var failures := 0
	var meta: Dictionary = ws.get_word_meta("CAT")
	failures += 0 if meta.get("is_valid", false) else 1
	failures += 0 if meta.get("length", 0) == 3 else 1
	failures += 0 if meta.get("vowel_count", 0) == 1 else 1
	failures += 0 if meta.get("consonant_count", 0) == 2 else 1
	var bad: Dictionary = ws.get_word_meta("ZZZZZZ")
	failures += 0 if bad.get("is_valid", true) == false else 1
	print("[lexicon] failures=", failures)
	quit(failures)
