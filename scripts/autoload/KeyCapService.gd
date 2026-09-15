extends Node
## Draws a random hand from the bag each turn; targeted redraw swaps.
## Also resolves a tile's ability into scoring effects.

func draw_hand() -> void:
	var target: int = mini(GameState.draw_size(), GameState.bag.size() + GameState.hand.size())
	var already: int = GameState.hand.size()
	var need: int = maxi(0, target - already)
	GameState.next_draw_bonus = 0
	if need == 0:
		EventBus.hand_drawn.emit(GameState.hand)
		return
	if GameState.bag.is_empty() and not GameState.discard_pile.is_empty():
		_reshuffle_from_discard()
	if GameState.bag.is_empty():
		EventBus.hand_drawn.emit(GameState.hand)
		return
	var pool := range(GameState.bag.size())
	pool.shuffle()
	for i in range(mini(need, pool.size())):
		GameState.hand.append(GameState.bag[pool[i]])
	_vowel_safeguard()
	EventBus.hand_drawn.emit(GameState.hand)


func _reshuffle_from_discard() -> void:
	GameState.bag = GameState.discard_pile.duplicate()
	GameState.discard_pile.clear()
	EventBus.bag_reshuffled.emit()


func _vowel_safeguard() -> void:
	const VOWELS := "AEIOU"
	var vowel_count := 0
	var wild_vowel_count := 0
	for cap in GameState.hand:
		var letter: String = str(cap.get("letter", ""))
		if VOWELS.contains(letter):
			vowel_count += 1
		elif letter == "~" or letter == "*":
			wild_vowel_count += 1
	if vowel_count + wild_vowel_count >= 2:
		return
	var to_swap: Array = []
	for i in range(GameState.hand.size()):
		var cap: Dictionary = GameState.hand[i]
		var letter: String = str(cap.get("letter", ""))
		if not VOWELS.contains(letter) and letter != "~" and letter != "*":
			to_swap.append(i)
	var vowel_pool: Array = []
	for i in range(GameState.bag.size()):
		var cap: Dictionary = GameState.bag[i]
		var letter: String = str(cap.get("letter", ""))
		if VOWELS.contains(letter) or letter == "~" or letter == "*":
			vowel_pool.append(i)
	vowel_pool.shuffle()
	for idx in to_swap:
		if vowel_pool.is_empty():
			break
		if vowel_count + wild_vowel_count >= 2:
			break
		var vi: int = vowel_pool.pop_back()
		GameState.bag.append(GameState.hand[idx])
		GameState.hand[idx] = GameState.bag[vi]
		GameState.bag.remove_at(vi)
		vowel_count += 1


func hand_size() -> int:
	return GameState.hand.size()


## Replace the tiles at `indices` with new random tiles from the bag.
## Costs 1 redraw token per redraw action (any number of tiles). Returns
## false (no change) on invalid indices or no tokens left.
## Cursed tiles cannot be redrawn.
func redraw_tiles(indices: Array) -> bool:
	if indices.is_empty():
		return false
	var idx := indices.duplicate()
	for i in idx:
		if typeof(i) != TYPE_INT or i < 0 or i >= GameState.hand.size():
			return false
		# Cursed tiles cannot be redrawn
		if str(GameState.hand[i].get("condition", "")) == "cursed":
			return false
	if GameState.redraws_left < 1:
		return false
	idx.sort()
	idx.reverse()
	var returned: Array = []
	for i in idx:
		returned.append(GameState.hand[i])
		GameState.hand.remove_at(i)
	# Remove the returned tiles from the bag so they cannot be drawn straight
	# back, then redraw replacements, then return them to the bag.
	for cap in returned:
		GameState.bag.erase(cap)
	var need: int = returned.size()
	var avail: int = GameState.bag.size()
	var pool := range(avail)
	pool.shuffle()
	var drawn: int = 0
	for k in range(mini(need, avail)):
		GameState.hand.append(GameState.bag[pool[k]])
		drawn += 1
	GameState.bag.append_array(returned)
	if drawn < need:
		for cap in returned:
			if drawn >= need:
				break
			GameState.hand.append(cap)
			drawn += 1
	GameState.redraws_left -= 1
	EventBus.redraws_changed.emit(GameState.redraws_left)
	EventBus.hand_drawn.emit(GameState.hand)
	return true


## Returns scoring effects contributed by a tile, keyed by effect name.
## Only additive/multiplicative score effects live here; money/glass/lucky
## side effects are applied during combat commit (see CombatService).
func resolve_ability(cap: Dictionary) -> Dictionary:
	var ability: String = str(cap.get("ability_id", ""))
	match ability:
		"bonus_points":
			return {"score": int(cap.get("ability_strength", 0))}
		"double_score":
			return {"score_multiplier": 2.0}
		"money_bonus":
			return {"money": int(cap.get("ability_strength", 1))}
		"bonus_damage":
			return {"bonus": int(cap.get("ability_strength", 1))}
		_:
			return {}


var _starter_bags_cache: Array = []


func get_starter_bags() -> Array:
	if _starter_bags_cache.is_empty():
		var text := FileAccess.get_file_as_string("res://data/starter_bags.json")
		var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			_starter_bags_cache = data.get("starter_bags", []) as Array
	return _starter_bags_cache


func _bag_by_id(bag_id: String) -> Dictionary:
	for bag: Dictionary in get_starter_bags():
		if str(bag.get("id", "")) == bag_id:
			return bag
	return {}


func load_starter_bag(bag_id: String) -> Array:
	var bag: Dictionary = _bag_by_id(bag_id)
	if bag.is_empty():
		bag = _bag_by_id("standard")
	if bag.is_empty():
		return []
	return (bag.get("tiles", []) as Array).duplicate(true)


func starter_bag_money(bag_id: String) -> int:
	var bag: Dictionary = _bag_by_id(bag_id)
	return int(bag.get("start_money", 0))
