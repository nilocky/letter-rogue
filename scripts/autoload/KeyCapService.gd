extends Node

const BASE_DRAW = 5

func draw_hand():
	var draw_count = BASE_DRAW + GameState.extra_draw
	if GameState.active_pack_id != "":
		var pack = _get_active_pack()
		if pack and pack.has("base_draw"):
			draw_count = pack.base_draw + GameState.extra_draw
		elif pack:
			draw_count = (BASE_DRAW + pack.get("draw_modifier", 0)) + GameState.extra_draw

	GameState.extra_draw = 0
	GameState.hand.clear()

	for i in range(draw_count):
		if GameState.bag.size() == 0:
			_shuffle_discard_into_bag()
		if GameState.bag.size() > 0:
			GameState.hand.append(GameState.bag.pop_front())

	EventBus.hand_drawn.emit(GameState.hand)

func play_caps(slot_map: Dictionary) -> Dictionary:
	var played = []
	var returned = []
	for letter in slot_map.keys():
		var cap = slot_map[letter]
		GameState.hand.erase(cap)
		if cap.get("sticker") == "glow":
			returned.append(cap)
		else:
			GameState.discard.append(cap)
		played.append(cap)
	# Glow caps go back to hand
	for cap in returned:
		GameState.hand.append(cap)
	return played

func _shuffle_discard_into_bag():
	GameState.bag.append_array(GameState.discard)
	GameState.discard.clear()
	GameState.bag.shuffle()

func resolve_ability(cap: Dictionary, context: Dictionary) -> Dictionary:
	match cap.ability_id:
		"bonus_points":
			return {"score": cap.ability_strength}
		"double_score":
			return {"score_multiplier": 2}
		"wild":
			return {"wild": true}
		"money_bonus":
			return {"money": cap.ability_strength}
		"bonus_damage":
			return {"bonus_damage": cap.ability_strength}
		"heal":
			var heal_amount = cap.ability_strength
			GameState.hp = mini(GameState.hp + heal_amount, GameState.max_hp)
			return {"heal": heal_amount}
		"extra_draw":
			GameState.extra_draw += cap.ability_strength
			return {"extra_draw": cap.ability_strength}
		"shield":
			GameState.shield += cap.ability_strength
			return {"shield": cap.ability_strength}
		_:
			return {}

func _get_active_pack() -> Dictionary:
	var packs_json = FileAccess.get_file_as_string("res://data/packs.json")
	if packs_json == "":
		return {}
	var data = JSON.parse_string(packs_json)
	for p in data["packs"]:
		if p["id"] == GameState.active_pack_id:
			return p
	return {}
