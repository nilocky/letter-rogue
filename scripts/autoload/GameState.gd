extends Node

var hp: int = 20
var max_hp: int = 20
var money: int = 10
var round: int = 1
var bag: Array = []
var hand: Array = []
var discard: Array = []
var current_monster: Dictionary = {}
var shop_inventory: Array = []
var active_pack_id: String = ""
var shield: int = 0
var extra_draw: int = 0

func reset():
	hp = 20
	max_hp = 20
	money = 10
	round = 1
	bag = []
	hand = []
	discard = []
	current_monster = {}
	shop_inventory = []
	active_pack_id = ""
	shield = 0
	extra_draw = 0

func process_rental_costs() -> int:
	var cost = 0
	for cap in bag:
		if cap.get("condition") == "rental":
			cost += 1
	money -= cost
	money = maxi(money, 0)
	return cost

func load_starter_bag(caps: Array):
	bag = caps.duplicate()
	bag.shuffle()
