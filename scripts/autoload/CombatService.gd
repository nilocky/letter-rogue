extends Node
## Round and turn loop. Round = N turns (budget); each turn spells one word.

const COMMON_LETTERS := "ETAOINRS"
const UNCOMMON_LETTERS := "HLDCUMFPGWYB"
const VOWELS := "AEIOU"

const REWARD_BASE := 5


func start_round() -> void:
	GameState.turns_left = GameState.round_turn_budget()
	GameState.redraws_left = GameState.round_redraw_budget()
	GameState.next_draw_bonus = 0
	GameState.current_monster["hp_remaining"] = GameState.monster_hp_scaled()
	EventBus.turn_started.emit(GameState.turns_left, GameState.redraws_left)
	KeyCapService.draw_hand()


## Validate a word built from `slots` (each {"cap": Dictionary, "letter": String}).
func validate_word(slots: Array) -> Dictionary:
	if slots.size() < 3:
		return {"ok": false, "reason": "too_short"}
	var word := ""
	var letters: Array = []
	for s in slots:
		word += str(s["letter"])
		letters.append(str(s["letter"]))
	if not WordService.is_word(word):
		return {"ok": false, "reason": "not_word"}
	var modifier: String = str(GameState.current_monster.get("boss_modifier", ""))
	if modifier == "no_repeats":
		var seen: Dictionary = {}
		for letter in letters:
			if seen.has(letter):
				return {"ok": false, "reason": "repeat_letter"}
			seen[letter] = true
	return {"ok": true, "word": word}


## Deterministic damage/money for a word. Does NOT mutate GameState.
func calculate_word(slots: Array) -> Dictionary:
	var disabled: bool = str(GameState.current_monster.get("boss_modifier", "")) == "silence"
	var pack := PackService.pack_by_id(GameState.active_pack_id)
	var per_tile: int = int(pack.get("score_modifier", 0)) if not pack.is_empty() else 0

	var total := 0.0
	var flat := 0
	var money := 0
	for s in slots:
		var cap: Dictionary = s["cap"]
		var letter: String = str(s["letter"])
		var is_vowel: bool = VOWELS.contains(letter)
		var contribution := 0.0
		if not bool(cap.get("is_symbol", false)):
			contribution = float(_letter_base_score(str(cap["letter"])))
		if not disabled:
			contribution += float(per_tile)
			var ability := KeyCapService.resolve_ability(cap)
			contribution += float(ability.get("score", 0))
			contribution *= float(ability.get("score_multiplier", 1.0))
			money += int(ability.get("money", 0))
			flat += int(ability.get("bonus", 0))
			match str(cap.get("finish", "")):
				"foil":
					contribution += 3.0
				"holographic":
					contribution += 1.0
				"polychrome":
					contribution *= 1.5
			if str(cap.get("sticker", "")) == "red":
				contribution *= 2.0
			elif str(cap.get("sticker", "")) == "gold":
				money += 2
			if str(cap.get("condition", "")) == "glass":
				contribution *= 2.0
		var modifier: String = str(GameState.current_monster.get("boss_modifier", ""))
		if modifier == "vowel_lock" and not is_vowel:
			contribution = 0.0
		elif modifier == "consonant_lock" and is_vowel:
			contribution = 0.0
		total += contribution
	var damage: int = int(round(total * WordService.length_multiplier(slots.size()))) + flat
	return {"damage": damage, "money": money}


## Commit a word: deal damage, collect money, roll lucky/glass/blue side
## effects, then advance the turn. Emits win/lose/game_over as needed.
func commit_word(slots: Array) -> void:
	var res := calculate_word(slots)
	var word := ""
	for s in slots:
		word += str(s["letter"])
	EventBus.word_committed.emit(word, res["damage"], slots.size())

	var lucky_extra_damage := 0
	var money_gain: int = res["money"]
	for s in slots:
		var cap: Dictionary = s["cap"]
		var disabled: bool = str(GameState.current_monster.get("boss_modifier", "")) == "silence"
		if disabled:
			continue
		if str(cap.get("sticker", "")) == "blue":
			GameState.next_draw_bonus += 1
		if str(cap.get("condition", "")) == "glass":
			if randf() < 0.25:
				GameState.bag.erase(cap)
		elif str(cap.get("condition", "")) == "lucky":
			if randf() < 0.2:
				lucky_extra_damage += 10
			if randf() < 0.0667:
				money_gain += 10

	_apply_monster_damage(int(res["damage"]) + lucky_extra_damage, money_gain)


func skip_turn() -> void:
	EventBus.word_committed.emit("", 0, 0)
	_end_turn()


func _letter_base_score(letter: String) -> int:
	if COMMON_LETTERS.contains(letter):
		return 1
	if UNCOMMON_LETTERS.contains(letter):
		return 2
	return 4  # V K X J Q Z


func _apply_monster_damage(damage: int, money_gain: int) -> void:
	var remaining: int = int(GameState.current_monster.get("hp_remaining", GameState.monster_hp_scaled()))
	remaining -= damage
	GameState.current_monster["hp_remaining"] = remaining
	if money_gain > 0:
		GameState.money += money_gain
	if remaining <= 0:
		var reward: int = GameState.round_reward()
		GameState.money += reward
		GameState.turns_left = 0
		EventBus.monster_damaged.emit(0, GameState.monster_hp_scaled())
		EventBus.round_won.emit(reward)
	else:
		EventBus.monster_damaged.emit(remaining, GameState.monster_hp_scaled())
		_end_turn()


func _monster_hp_remaining() -> int:
	return int(GameState.current_monster.get("hp_remaining", GameState.monster_hp_scaled()))


func _end_turn() -> void:
	GameState.turns_left -= 1
	EventBus.turns_changed.emit(GameState.turns_left)
	if GameState.turns_left <= 0:
		# Emit only game_over; round_lost is not emitted (GameRoot handles
		# game_over, emitting both caused a double game-over transition).
		EventBus.game_over.emit(GameState.round_number)
	else:
		EventBus.turn_started.emit(GameState.turns_left, GameState.redraws_left)
		KeyCapService.draw_hand()