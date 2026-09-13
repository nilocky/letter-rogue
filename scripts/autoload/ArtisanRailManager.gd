extends Node

var rail: Array = []


func _ready() -> void:
	rail.resize(5)


func equip(slot: int, artisan: Dictionary) -> bool:
	if slot < 0 or slot >= 5:
		return false
	rail[slot] = artisan
	return true


func unequip(slot: int) -> bool:
	if slot < 0 or slot >= 5 or rail[slot] == null:
		return false
	rail[slot] = null
	return true


func get_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= 5 or rail[slot] == null:
		return {}
	return rail[slot]


func cascade(word: String, slots: Array, letter_scores: Array, form_data: Dictionary, _pack_data: Dictionary) -> Dictionary:
	var flat: int = 0
	var xmult: float = 1.0
	var artisan_ids: Array = []

	for slot in range(5):
		var artisan_v: Variant = rail[slot]
		if artisan_v == null:
			continue
		var artisan: Dictionary = artisan_v as Dictionary
		if artisan.is_empty():
			continue
		artisan_ids.append(str(artisan.get("id", "")))
		var trigger: Dictionary = artisan.get("trigger", {})
		var trigger_type: String = str(trigger.get("type", ""))
		var triggered: bool = _evaluate_trigger(trigger_type, trigger, word, slots, letter_scores, form_data)

		if not triggered:
			continue

		var effect: Dictionary = artisan.get("effect", {})
		var effect_type: String = str(effect.get("type", ""))
		match effect_type:
			"add_flat":
				flat += int(effect.get("value", 0))
			"multiply":
				xmult *= float(effect.get("value", 1.0))
			"multiply_per_redraw":
				var unused: int = GameState.redraws_left
				xmult *= pow(float(effect.get("value", 1.0)), maxi(unused, 0))

	return {"flat": flat, "xmult": xmult}


func _evaluate_trigger(trigger_type: String, trigger: Dictionary, word: String, slots: Array, letter_scores: Array, form_data: Dictionary) -> bool:
	match trigger_type:
		"word_length":
			var min_l: int = int(trigger.get("min", 0))
			var max_l: int = int(trigger.get("max", 99))
			return slots.size() >= min_l and slots.size() <= max_l
		"no_redraws_used":
			return GameState.redraws_left == GameState.round_redraw_budget()
		"rare_consonant":
			var count := 0
			for s in slots:
				var l: String = str(s.get("letter", ""))
				if "VKXJQZ".contains(l):
					count += 1
			return count >= 1
		"unused_redraws":
			return GameState.redraws_left > 0
		"more_vowels_than_consonants":
			var vowels := 0
			var cons := 0
			for s in slots:
				var l: String = str(s.get("letter", ""))
				if "AEIOU".contains(l):
					vowels += 1
				elif l != "~" and l != "*" and l != "#":
					cons += 1
			return vowels > cons
		"word_form":
			var target_form: String = str(trigger.get("form", ""))
			return form_data.get("form_id", "") == target_form
		"leftover_turns":
			return GameState.turns_left >= int(trigger.get("min", 0))
		"consecutive_start_letter":
			if slots.is_empty():
				return false
			var first: String = str(slots[0].get("letter", ""))
			return first.length() > 0 and word.length() > 1 and word[0] == word[1]
	return false
