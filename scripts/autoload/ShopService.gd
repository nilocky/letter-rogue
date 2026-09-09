extends Node

const SHOP_SIZE = 5
const REROLL_COST = 3
const SELL_RATIO = 0.5

func generate_inventory():
	var caps_json = FileAccess.get_file_as_string("res://data/key_caps.json")
	var data = JSON.parse_string(caps_json)
	var pool = data["shop_pool"]
	var inventory = []

	for i in range(SHOP_SIZE):
		var rarity_roll = randf()
		var candidate = null
		if rarity_roll < 0.5:
			candidate = _pick_from_pool(pool, "Normal")
		elif rarity_roll < 0.8:
			candidate = _pick_from_pool(pool, "Rare")
		elif rarity_roll < 0.95:
			candidate = _pick_from_pool(pool, "Epic")
		else:
			candidate = _pick_from_pool(pool, "Legendary")
		if candidate:
			var entry = candidate.duplicate()
			entry["price"] = _calculate_price(entry)
			inventory.append(entry)

	GameState.shop_inventory = inventory
	EventBus.shop_inventory_generated.emit(inventory)

func buy_cap(index: int) -> bool:
	if index < 0 or index >= GameState.shop_inventory.size():
		return false
	var cap = GameState.shop_inventory[index]
	if GameState.money < cap["price"]:
		return false
	GameState.money -= cap["price"]
	GameState.bag.append(cap)
	GameState.shop_inventory.remove_at(index)
	EventBus.cap_purchased.emit(cap)
	return true

func sell_cap(index: int) -> bool:
	if index < 0 or index >= GameState.bag.size():
		return false
	var cap = GameState.bag[index]
	if cap.get("condition") == "eternal":
		return false
	var price = ceili((cap.get("price", 5)) * SELL_RATIO)
	if price < 1:
		price = 1
	GameState.money += price
	GameState.bag.remove_at(index)
	EventBus.cap_sold.emit(cap)
	return true

func reroll() -> bool:
	if GameState.money < REROLL_COST:
		return false
	GameState.money -= REROLL_COST
	generate_inventory()
	EventBus.shop_rerolled.emit()
	return true

func _calculate_price(cap: Dictionary) -> int:
	var base = 3
	match cap["rarity"]:
		"Normal": base = 3
		"Rare": base = 6
		"Epic": base = 12
		"Legendary": base = 20
	if cap.has("finish") and cap["finish"] != "":
		var finish_data = _get_finish_data(cap["finish"])
		if finish_data:
			base += finish_data.get("price_mod", 0)
	if cap.has("sticker") and cap["sticker"] != "":
		base += 2
	return base

func _get_finish_data(finish_id: String) -> Dictionary:
	var json_str = FileAccess.get_file_as_string("res://data/key_caps.json")
	if json_str == "": return {}
	var data = JSON.parse_string(json_str)
	for f in data.get("finishes", []):
		if f["id"] == finish_id:
			return f
	return {}

func _pick_from_pool(pool: Array, rarity: String) -> Dictionary:
	var candidates = []
	for c in pool:
		if c["rarity"] == rarity:
			candidates.append(c)
	if candidates.size() == 0:
		return pool[randi() % pool.size()].duplicate()
	return candidates[randi() % candidates.size()].duplicate()
