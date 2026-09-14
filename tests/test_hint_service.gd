extends SceneTree

func _init() -> void:
	await process_frame
	var hs: Node = root.get_node("HintService")
	var ws: Node = root.get_node("WordService")
	var failures := 0

	var letters_cat: Array[String] = ["C", "A", "T"]
	var word: String = hs.find_basic_word(letters_cat)
	if word == "":
		print("FAIL: should find a word from CAT")
		failures += 1
	elif not ws.is_word(word) or word.length() < 3:
		print("FAIL: returned '%s' not a valid 3+ word" % word)
		failures += 1

	var letters_xyz: Array[String] = ["Q", "X", "Z"]
	if hs.find_basic_word(letters_xyz) != "":
		print("FAIL: QXZ should return empty, got '%s'" % hs.find_basic_word(letters_xyz))
		failures += 1

	var letters_big: Array[String] = ["C", "A", "T", "S", "B"]
	var big: String = hs.find_basic_word(letters_big)
	if big == "" or not ws.is_word(big):
		print("FAIL: 5-letter hand should find valid word, got '%s'" % big)
		failures += 1

	if failures == 0:
		print("OK: HintService found %s / %s" % [word, big])
	quit(1 if failures > 0 else 0)