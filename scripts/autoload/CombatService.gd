extends Node
## Round and turn loop. Round = N turns (budget); each turn spells one word.

const COMMON_LETTERS := "ETAOINRS"
const UNCOMMON_LETTERS := "HLDCUMFPGWYB"
const VOWELS := "AEIOU"

const REWARD_BASE := 5


func start_round() -> void:
	GameState.turns_left = GameState.round_turn_budget()
	GameState.redraws_left = GameState.round_redraw_budget()
	# Apply pack redraw penalties
	var pack: Dictionary = PackService.pack_by_id(GameState.active_pack_id)
	if not pack.is_empty():
		var conds: Array = pack.get("conditionals", [])
		for c in conds:
			if str(c.get("type", "")) == "redraw_penalty":
				GameState.redraws_left = maxi(0, GameState.redraws_left + int(c.get("value", 0)))
	GameState.next_draw_bonus = 0
	GameState.current_monster["hp_remaining"] = GameState.monster_hp_scaled()
	GameState.hand.clear()
	GameState.discard_pile.clear()
	EventBus.turn_started.emit(GameState.turns_left, GameState.redraws_left)
	KeyCapService.draw_hand()
	EffectPipeline.trigger("on_draw", [GameState.hand])


## Validate a word built from `slots` (each {"cap": Dictionary, "letter": String}).
func _current_modifier() -> String:
	return str(GameState.current_monster.get("modifier", GameState.current_monster.get("boss_modifier", "")))


func validate_word(slots: Array) -> Dictionary:
	if slots.size() < 3:
		return {"ok": true}
	var word := ""
	var letters: Array = []
	for s in slots:
		word += str(s["letter"])
		letters.append(str(s["letter"]))
	if not WordService.is_word(word):
		return {"ok": false, "reason": "not_word"}
	var modifier: String = _current_modifier()
	if modifier == "no_repeats":
		var seen: Dictionary = {}
		for letter in letters:
			if seen.has(letter):
				return {"ok": false, "reason": "repeat_letter"}
			seen[letter] = true
	EffectPipeline.trigger("on_word_validated", [word, true])
	return {"ok": true, "word": word}


func slot_letter(cap: Dictionary, index: int) -> void:
	EffectPipeline.trigger("on_letter_slotted", [cap, index])


## Deterministic damage/money for a word. Does NOT mutate GameState.
func calculate_word(slots: Array, log: bool = false) -> Dictionary:
	var modifier: String = _current_modifier()
	var disabled: bool = modifier == "silence"
	var pack := PackService.pack_by_id(GameState.active_pack_id)
	var per_tile: int = int(pack.get("score_modifier", 0)) if not pack.is_empty() else 0

	# Phase 1: Tile Hops
	var letter_scores: Array = []
	var total_base: float = 0.0
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
			match str(cap.get("finish", "")):
				"foil": contribution += 3.0
				"holographic": contribution += 1.0
				"polychrome": contribution *= 1.5
			if str(cap.get("sticker", "")) == "red":
				contribution *= 2.0
			if str(cap.get("condition", "")) == "glass":
				contribution *= 2.0
		if modifier == "vowel_lock" and not is_vowel:
			contribution = 0.0
		elif modifier == "consonant_lock" and is_vowel:
			contribution = 0.0
		total_base += contribution
		letter_scores.append(contribution)
	EffectPipeline.trigger("on_score_calculated", [{"letter_scores": letter_scores}])

	# Phase 2: Word Form Ignition
	var word := ""
	for s in slots:
		word += str(s["letter"])
	var form_data: Dictionary = {}
	if word.length() >= 3:
		form_data = WordFormService.detect(slots)
	EffectPipeline.trigger("on_word_form_evaluated", [
		form_data.get("form_id", ""),
		form_data.get("base_damage", 0),
		form_data.get("base_multiplier", 1.0)
	])

	var length_mult: float = WordService.length_multiplier(slots.size())
	var form_base: int = form_data.get("base_damage", 0)
	var form_mult: float = form_data.get("base_multiplier", 1.0)
	var total_after_form: float = (total_base + float(form_base)) * length_mult * form_mult

	# Phase 3: Artisan Cascade
	var artisan_result: Dictionary = ArtisanRailManager.cascade(
		word, slots, letter_scores, form_data, pack
	)
	var artisan_flat: int = artisan_result.get("flat", 0)
	var artisan_xmult: float = artisan_result.get("xmult", 1.0)

	# Phase 4: Runic Blast — apply flat bonuses from abilities
	var total_after_artisans: float = (total_after_form + float(artisan_flat)) * artisan_xmult
	var flat_bonus: int = 0
	var money: int = 0
	for s in slots:
		var cap: Dictionary = s["cap"]
		if not disabled:
			var ability := KeyCapService.resolve_ability(cap)
			flat_bonus += int(ability.get("bonus", 0))
			money += int(ability.get("money", 0))
			if str(cap.get("sticker", "")) == "gold":
				money += 2

	var damage: int = roundi(total_after_artisans) + flat_bonus

	if log:
		print("[score] word=\"%s\" form=%s len=%d" % [word, form_data.get("form_id", "none"), slots.size()])
		print("[score]   base=%.1f form_base=%d length_mult=%.1f form_mult=%.1f artisan_flat=%d artisan_xmult=%.1f" % [total_base, form_base, length_mult, form_mult, artisan_flat, artisan_xmult])
		print("[score]   total=%.1f -> %d dmg (+%d flat) +$%d" % [total_after_artisans, damage, flat_bonus, money])

	var result: Dictionary = {
		"damage": damage,
		"money": money,
		"letter_scores": letter_scores,
		"form_data": form_data,
		"flat_bonus": flat_bonus
	}
	return result


## Commit a word: deal damage, collect money, roll lucky/glass/blue side
## effects, then advance the turn. Emits win/lose/game_over as needed.
func commit_word(slots: Array) -> void:
	if not validate_word(slots).get("ok", false):
		return
	var res := calculate_word(slots, true)
	var word := ""
	for s in slots:
		word += str(s["letter"])
	EventBus.word_committed.emit(word, res["damage"], slots.size())

	var lucky_extra_damage := 0
	var money_gain: int = res["money"]
	var used_caps: Array = []
	for s in slots:
		var cap: Dictionary = s["cap"]
		used_caps.append(cap)
		var disabled: bool = _current_modifier() == "silence"
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

	# Move played tiles to discard pile instead of returning to bag
	GameState.discard_pile.append_array(used_caps)
	for cap in used_caps:
		GameState.hand.erase(cap)
	EventBus.tiles_consumed.emit(used_caps, GameState.discard_pile)

	_apply_monster_damage(int(res["damage"]) + lucky_extra_damage, money_gain)



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
	if remaining <= 0:
		var reward: int = GameState.round_reward()
		var leftover_turns: int = GameState.turns_left
		GameState.turns_left = 0
		EventBus.monster_damaged.emit(0, GameState.monster_hp_scaled())
		var summary: Dictionary = {
			"is_boss": GameState.round_number % 3 == 0,
			"base_reward": reward,
			"leftover_turns": leftover_turns,
			"ability_money": money_gain,
			"total": reward + leftover_turns + money_gain,
			"loot": LootService.roll_drops(GameState.current_monster),
		}
		EventBus.round_won.emit(summary)
		EffectPipeline.trigger("on_monster_defeated", [GameState.current_monster, summary])
	else:
		if money_gain > 0:
			GameState.money += money_gain
		EventBus.monster_damaged.emit(remaining, GameState.monster_hp_scaled())
		EffectPipeline.trigger("on_monster_damaged", [GameState.current_monster, damage, remaining])
		_end_turn()


func _monster_hp_remaining() -> int:
	return int(GameState.current_monster.get("hp_remaining", GameState.monster_hp_scaled()))


func _end_turn() -> void:
	GameState.turns_left -= 1
	EventBus.turns_changed.emit(GameState.turns_left)
	EffectPipeline.trigger("on_turn_end", [GameState.turns_left])
	if GameState.turns_left <= 0:
		# Emit only game_over; round_lost is not emitted (GameRoot handles
		# game_over, emitting both caused a double game-over transition).
		EventBus.game_over.emit(GameState.round_number)
	else:
		EventBus.turn_started.emit(GameState.turns_left, GameState.redraws_left)
		KeyCapService.draw_hand()
