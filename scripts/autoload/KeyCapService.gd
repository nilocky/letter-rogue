extends Node
## Draws a random hand from the bag each turn; targeted redraw swaps.
## Also resolves a tile's ability into scoring effects.

func draw_hand() -> void:
	GameState.hand.clear()
	# Consume the blue-sticker bonus AFTER computing the draw size.
	var target: int = mini(GameState.draw_size(), GameState.bag.size())
	GameState.next_draw_bonus = 0
	if target == 0:
		EventBus.hand_drawn.emit(GameState.hand)
		return
	var pool := range(GameState.bag.size())
	pool.shuffle()
	for i in range(target):
		GameState.hand.append(GameState.bag[pool[i]])
	EventBus.hand_drawn.emit(GameState.hand)


func hand_size() -> int:
	return GameState.hand.size()


## Replace the tiles at `indices` with new random tiles from the bag.
## Costs 1 redraw token per redraw action (any number of tiles). Returns
## false (no change) on invalid indices or no tokens left.
func redraw_tiles(indices: Array) -> bool:
	if indices.is_empty():
		return false
	var idx := indices.duplicate()
	for i in idx:
		if typeof(i) != TYPE_INT or i < 0 or i >= GameState.hand.size():
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
