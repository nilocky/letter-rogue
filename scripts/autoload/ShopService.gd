extends Node
## Shop: tile inventory buy/sell/reroll plus persistent run upgrades.

const SHOP_SIZE := 5
const REROLL_COST := 3
const SELL_RATIO := 0.5

const UPGRADES := [
	{"id": "bigger_bag", "name": "Bigger Bag", "desc": "+1 tile drawn per turn", "field": "upgrade_draw", "base": 6},
	{"id": "extra_turn", "name": "Extra Turn", "desc": "+1 turn per round", "field": "upgrade_turns", "base": 8},
	{"id": "extra_redraw", "name": "Extra Redraw", "desc": "+1 redraw token per round", "field": "upgrade_redraws", "base": 5}
]

var _pool: Array = []


func _ready() -> void:
	_load_pool()


func _load_pool() -> void:
	var text := FileAccess.get_file_as_string("res://data/key_caps.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_pool = data.get("shop_pool", [])


func new_shop() -> void:
	GameState.shop_inventory.clear()
	for i in range(SHOP_SIZE):
		GameState.shop_inventory.append(_weighted_pick())
	EventBus.shop_inventory_generated.emit(GameState.shop_inventory)


func _weighted_pick() -> Dictionary:
	var rarity_roll := randf()
	var rarity := "Normal"
	if rarity_roll < 0.05:
		rarity = "Legendary"
	elif rarity_roll < 0.20:
		rarity = "Epic"
	elif rarity_roll < 0.55:
		rarity = "Rare"
	var candidates: Array = _pool.filter(func(c: Dictionary) -> bool:
		return str(c.get("rarity", "")) == rarity)
	if candidates.is_empty():
		candidates = _pool
	var cap: Dictionary = candidates[randi() % candidates.size()].duplicate(true)
	cap["price"] = _price_for(cap)
	return cap


func _price_for(cap: Dictionary) -> int:
	var base := 3
	match str(cap.get("rarity", "Normal")):
		"Rare":
			base = 6
		"Epic":
			base = 10
		"Legendary":
			base = 15
	var total: int = base
	total += int(cap.get("ability_strength", 0))
	match str(cap.get("finish", "")):
		"foil":
			total += 2
		"holographic":
			total += 3
		"polychrome":
			total += 5
	if cap.has("sticker"):
		total += 2
	if cap.has("condition"):
		total += 2
	return total


func buy_cap(cap: Dictionary) -> bool:
	var price: int = int(cap.get("price", 0))
	if GameState.money < price:
		return false
	GameState.money -= price
	GameState.bag.append(cap)
	GameState.shop_inventory.erase(cap)
	EventBus.cap_purchased.emit(cap)
	return true


func sell_cap(cap: Dictionary) -> bool:
	if str(cap.get("condition", "")) == "eternal":
		return false
	var value: int = sell_value(cap)
	GameState.bag.erase(cap)
	GameState.money += value
	EventBus.cap_sold.emit(cap)
	return true


func sell_value(cap: Dictionary) -> int:
	return maxi(int(round(int(cap.get("price", 0)) * SELL_RATIO)), 1)


func reroll() -> bool:
	if GameState.money < REROLL_COST:
		return false
	GameState.money -= REROLL_COST
	new_shop()
	EventBus.shop_rerolled.emit()
	return true


func generate_grab_bag(pack_type: String, choices: int, pick: int) -> Array:
	var pool: Array = []
	match pack_type:
		"artisan":
			var text := FileAccess.get_file_as_string("res://data/artisans.json")
			var data: Variant = JSON.parse_string(text)
			pool = data.get("artisans", [])
		"grimoire":
			pool = ConsumableService.get_grimoires()
		"toolkit":
			pool = ConsumableService.get_tarot()
		"black_box":
			pool = ConsumableService.get_spectral()
	if pool.is_empty():
		return []
	pool.shuffle()
	var options: Array = pool.slice(0, choices)
	for opt in options:
		opt["price"] = int(opt.get("price", 6))
	return options


func blueprint_defs() -> Array:
	var text := FileAccess.get_file_as_string("res://data/blueprints.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		return data.get("blueprints", [])
	return []


func purchase_blueprint(bp: Dictionary) -> bool:
	var price: int = int(bp.get("base_price", 0))
	if GameState.money < price:
		return false
	GameState.money -= price
	GameState.active_blueprints[str(bp.get("id", ""))] = true
	EventBus.blueprint_purchased.emit(bp)
	return true


func owned_blueprint(id: String) -> bool:
	return GameState.active_blueprints.has(id)


func upgrade_defs() -> Array:
	return UPGRADES


func owned_level(id: String) -> int:
	match id:
		"bigger_bag":
			return GameState.upgrade_draw
		"extra_turn":
			return GameState.upgrade_turns
		"extra_redraw":
			return GameState.upgrade_redraws
	return 0


func upgrade_cost(id: String) -> int:
	for u in UPGRADES:
		if u["id"] == id:
			return int(u["base"]) * int(pow(2, owned_level(id)))
	return 999999


func purchase_upgrade(id: String) -> bool:
	var cost: int = upgrade_cost(id)
	if GameState.money < cost:
		return false
	var level: int = owned_level(id)
	GameState.money -= cost
	match id:
		"bigger_bag":
			GameState.upgrade_draw += 1
		"extra_turn":
			GameState.upgrade_turns += 1
		"extra_redraw":
			GameState.upgrade_redraws += 1
	EventBus.upgrade_purchased.emit(id, level + 1)
	return true