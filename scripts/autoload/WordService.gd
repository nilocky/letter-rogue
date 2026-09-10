extends Node
## Word dictionary + word-length scoring helper. Pure lookups; no state.

const WORDS_PATH := "res://data/words.json"

var _words: Dictionary = {}  # word:String -> true
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
	for w: String in data["words"]:
		_words[w] = true
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