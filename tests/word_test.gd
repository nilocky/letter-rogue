extends SceneTree

func _init() -> void:
	await process_frame
	var ws: Node = root.get_node("WordService")
	var failures := 0
	failures += 0 if ws.is_word("CAT") else 1
	failures += 0 if not ws.is_word("XYZQZZ") else 1
	failures += 0 if ws.length_multiplier(4) == 1.3 else 1
	failures += 0 if ws.word_count() > 0 else 1
	print("[word] failures=", failures)
	quit(failures)
