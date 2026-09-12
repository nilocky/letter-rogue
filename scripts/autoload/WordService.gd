extends Node
## Word dictionary + word-length scoring helper. Pure lookups; no state.

const WORDS_PATH := "res://data/words.json"

var _words: Dictionary = {}  # word:String -> {pos:int, def:String}
var _count: int = 0


func _ready() -> void:
	_load_dictionary()


func _load_dictionary() -> void:
	var text := FileAccess.get_file_as_string(WORDS_PATH)
	if text.is_empty():
		push_error("WordService: missing %s" % WORDS_PATH)
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("words"):
		push_error("WordService: %s has no 'words' array" % WORDS_PATH)
		return
	var raw: Variant = data["words"]
	if raw.size() > 0 and typeof(raw[0]) == TYPE_STRING:
		for w: String in raw:
			_words[w] = {"pos": 16, "def": ""}
	else:
		for entry: Dictionary in raw:
			_words[entry["w"]] = {"pos": entry.get("pos", 16), "def": entry.get("def", "")}
	_count = _words.size()


func is_word(word: String) -> bool:
	return _words.has(word)


func length_multiplier(length: int) -> float:
	match length:
		1, 2:
			return 1.0
		3:
			return 1.0
		4:
			return 1.3
		5:
			return 1.6
		6:
			return 2.0
		_:
			return 2.5


func word_count() -> int:
	return _count


func get_word_meta(word: String) -> Dictionary:
	var meta: Variant = _words.get(word)
	var valid: bool = typeof(meta) == TYPE_DICTIONARY
	var pos_name_str: String = pos_name(meta.get("pos", 16)) if valid else "Other"
	var def_str: String = meta.get("def", "") if valid else ""
	var vowel_count: int = 0
	var consonant_count: int = 0
	for c: String in word:
		if "AEIOU".contains(c):
			vowel_count += 1
		else:
			consonant_count += 1
	return {
		"is_valid": valid,
		"part_of_speech": pos_name_str,
		"short_def": def_str,
		"vowel_count": vowel_count,
		"consonant_count": consonant_count,
		"length": word.length(),
	}


func pos_name(pos: int) -> String:
	match pos:
		1:
			return "Noun"
		2:
			return "Verb"
		4:
			return "Adj"
		8:
			return "Adv"
		_:
			return "Other"