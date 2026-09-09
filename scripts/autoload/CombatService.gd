extends Node

var current_word: String = ""
var word_letters: Array = []
var _boss_matched_letters: Array = []

func start_combat(monster: Dictionary):
	current_word = monster["word_pool"][randi() % monster["word_pool"].size()]
	word_letters = []
	_boss_matched_letters = []
	for c in current_word:
		word_letters.append(c)
	EventBus.combat_word_generated.emit(current_word, monster["name"])
	KeyCapService.draw_hand()

func calculate_score(played_caps: Array, slot_indices: Array) -> Dictionary:
	var total_score = 0
	var money_bonus = 0
	var breakdown = {}

	for i in range(played_caps.size()):
		var cap = played_caps[i]
		var letter = word_letters[slot_indices[i]]
		var letter_score = _letter_base_score(letter)

		var ctx = {"letter": letter, "base_score": letter_score}
		var ability_result = KeyCapService.resolve_ability(cap, ctx)

		var final_score = letter_score
		if ability_result.has("score"):
			final_score += ability_result["score"]
		if ability_result.has("score_multiplier"):
			final_score *= ability_result["score_multiplier"]
		if ability_result.has("bonus_damage"):
			final_score += ability_result["bonus_damage"]
		if ability_result.has("money"):
			money_bonus += ability_result["money"]

		var finish_result = resolve_finish(cap, final_score, i, played_caps.size())
		final_score += finish_result.get("score", 0)
		if finish_result.has("score_mult"):
			final_score = ceili(final_score * finish_result["score_mult"])
		if finish_result.get("extra_slots", 0) > 0:
			pass
		if finish_result.get("adjacent_bonus", 0) > 0:
			pass

		# Sticker: Gold
		if cap.get("sticker") == "gold":
			money_bonus += 2
		# Sticker: Red (retrigger)
		if cap.get("sticker") == "red":
			final_score *= 2
		# Sticker: Blue
		if cap.get("sticker") == "blue":
			GameState.extra_draw += 1
		# Sticker: Rainbow — mark for UI, already counted as match
		if cap.get("sticker") == "rainbow":
			pass

		# Condition: Glass — 2x score, 1-in-4 break
		if cap.get("condition") == "glass":
			final_score *= 2
			if randf() < 0.25:
				cap["_break"] = true
		# Condition: Lucky
		if cap.get("condition") == "lucky":
			if randf() < 0.2:
				final_score += 10
			if randf() < 0.067:
				money_bonus += 10

		final_score = _apply_boss_modifier(letter, final_score)
		total_score += final_score
		breakdown[letter] = final_score

	# Apply neon adjacent bonuses
	for i in range(played_caps.size()):
		var cap = played_caps[i]
		if cap.get("finish") == "neon":
			if i > 0:
				breakdown[word_letters[slot_indices[i-1]]] = breakdown.get(word_letters[slot_indices[i-1]], 0) + 1
				total_score += 1
			if i < played_caps.size() - 1:
				breakdown[word_letters[slot_indices[i+1]]] = breakdown.get(word_letters[slot_indices[i+1]], 0) + 1
				total_score += 1

	# Pack score modifier
	if GameState.active_pack_id != "":
		var pack = _get_active_pack()
		if pack and pack.get("score_modifier", 0) != 0:
			total_score += pack["score_modifier"] * played_caps.size()

	# Check full-word clear
	if slot_indices.size() == word_letters.size():
		var pack = _get_active_pack()
		if pack and pack.get("heal_on_full_clear", false):
			var heal = ceili(GameState.max_hp * 0.05)
			GameState.hp = mini(GameState.hp + heal, GameState.max_hp)

	EventBus.score_calculated.emit(total_score, breakdown)
	return {"score": total_score, "money_bonus": money_bonus}

func apply_monster_damage(score: int):
	GameState.current_monster["hp"] -= score
	if GameState.current_monster["hp"] <= 0:
		GameState.current_monster["hp"] = 0
		var money_earned = _calculate_money_reward()
		GameState.money += money_earned
		EventBus.round_won.emit(money_earned)
	else:
		EventBus.monster_damaged.emit(GameState.current_monster["hp"], GameState.current_monster["max_hp"])

func resolve_held_conditions():
	var hand_score = 0
	var gold_held = false
	for cap in GameState.hand:
		if cap.get("condition") == "steel":
			hand_score += 2
		if cap.get("condition") == "gold_held":
			gold_held = true
	if hand_score > 0:
		GameState.current_monster["hp"] -= hand_score
	if gold_held:
		GameState.money += 3

func monster_attack():
	resolve_held_conditions()
	var base_damage = GameState.current_monster.get("attack_pattern", 2)
	var damage = base_damage

	if GameState.shield > 0:
		var blocked = mini(GameState.shield, damage)
		damage -= blocked
		GameState.shield -= blocked

	GameState.hp -= damage
	if GameState.hp <= 0:
		GameState.hp = 0
		EventBus.round_lost.emit()
		EventBus.game_over.emit()
	else:
		EventBus.player_hit.emit(damage, GameState.hp)

func _calculate_money_reward() -> int:
	var base = 5 + GameState.round * 2
	return base

func resolve_finish(cap: Dictionary, base_score: int, slot_index: int, total_slots: int) -> Dictionary:
	var finish = cap.get("finish", "")
	var result = {"score": 0, "extra_slots": 0, "adjacent_bonus": 0}
	match finish:
		"foil":
			result["score"] = 3
		"holographic":
			result["score"] = base_score
		"polychrome":
			result["score_mult"] = 1.5
		"double_shot":
			result["extra_slots"] = 1
		"neon":
			result["adjacent_bonus"] = 1
	return result

func _letter_base_score(letter: String) -> int:
	var common = ["E", "T", "A", "O", "I", "N", "S", "R"]
	var uncommon = ["H", "L", "D", "C", "U", "M", "F", "P", "G", "W", "Y", "B"]
	var rare = ["V", "K", "X", "J", "Q", "Z"]
	if letter in common:
		return 1
	elif letter in uncommon:
		return 2
	elif letter in rare:
		return 4
	return 1

func _apply_boss_modifier(letter: String, score: int) -> int:
	var mod = GameState.current_monster.get("boss_modifier", "")
	match mod:
		"vowel_lock":
			if letter in ["A", "E", "I", "O", "U"]:
				return score
			return 0
		"consonant_lock":
			if letter in ["A", "E", "I", "O", "U"]:
				return 0
			return score
		"mirror_words":
			return score
		"no_repeats":
			if not _boss_matched_letters.has(letter):
				_boss_matched_letters.append(letter)
				return score
			return 0
		"silence":
			return score
		"tight_grip":
			return score
		_:
			return score

func _get_active_pack() -> Dictionary:
	var packs_json = FileAccess.get_file_as_string("res://data/packs.json")
	if packs_json == "":
		return {}
	var data = JSON.parse_string(packs_json)
	for p in data["packs"]:
		if p["id"] == GameState.active_pack_id:
			return p
	return {}
