extends Node

const VOWELS := "AEIOU"
const RARE_CONSONANTS := "VKXJQZ"

var _forms: Dictionary = {}


func _ready() -> void:
	_load_forms()


func _load_forms() -> void:
	var text := FileAccess.get_file_as_string("res://data/word_forms.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		for f: Dictionary in data.get("forms", []):
			_forms[str(f["id"])] = f


func get_form(form_id: String) -> Dictionary:
	return _forms.get(form_id, {})


func detect(slots: Array) -> Dictionary:
	var word := ""
	var letters: Array = []
	for s in slots:
		var l: String = str(s.get("letter", s if typeof(s) == TYPE_STRING else ""))
		word += l
		letters.append(l)

	var len_word: int = word.length()

	if len_word >= 3:
		if _is_palindrome(word):
			var f: Dictionary = _forms.get("mirror", {})
			if not f.is_empty() and len_word >= int(f.get("min_length", 3)):
				var level: int = GameState.word_form_levels.get("mirror", 0)
				return _build_result(f, level)

		if _has_adjacent_duplicate(letters):
			var f: Dictionary = _forms.get("double_tap", {})
			if not f.is_empty() and len_word >= int(f.get("min_length", 3)):
				var level: int = GameState.word_form_levels.get("double_tap", 0)
				return _build_result(f, level)

		if _has_consonant_core(letters):
			var f: Dictionary = _forms.get("consonant_core", {})
			if not f.is_empty():
				var level: int = GameState.word_form_levels.get("consonant_core", 0)
				return _build_result(f, level)

	if len_word >= 6:
		var f: Dictionary = _forms.get("hexagram", {})
		var level: int = GameState.word_form_levels.get("hexagram", 0)
		return _build_result(f, level)
	elif len_word == 5:
		var f: Dictionary = _forms.get("quintet", {})
		var level: int = GameState.word_form_levels.get("quintet", 0)
		return _build_result(f, level)
	elif len_word == 4:
		var f: Dictionary = _forms.get("quartet", {})
		var level: int = GameState.word_form_levels.get("quartet", 0)
		return _build_result(f, level)
	elif len_word == 3:
		var f: Dictionary = _forms.get("trio", {})
		var level: int = GameState.word_form_levels.get("trio", 0)
		return _build_result(f, level)

	return {}


func _build_result(form: Dictionary, level: int) -> Dictionary:
	var form_id: String = str(form["id"])
	var base_dmg: int = int(form.get("base_damage", 0)) + level * 2
	var base_mult: float = float(form.get("base_multiplier", 1.0)) + level * 0.1
	return {
		"form_id": form_id,
		"name": str(form.get("name", form_id)),
		"base_damage": base_dmg,
		"base_multiplier": base_mult
	}


func _is_palindrome(word: String) -> bool:
	var len_w: int = word.length()
	if len_w < 3:
		return false
	for i in range(len_w / 2):
		if word[i] != word[len_w - 1 - i]:
			return false
	return true


func _has_adjacent_duplicate(letters: Array) -> bool:
	for i in range(letters.size() - 1):
		if str(letters[i]) == str(letters[i + 1]):
			return true
	return false


func _has_consonant_core(letters: Array) -> bool:
	var count := 0
	for l in letters:
		if RARE_CONSONANTS.contains(str(l)):
			count += 1
	return count >= 3
