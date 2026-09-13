extends Node
## Runtime state for the whole run. Data only; behaviour lives in services.

signal state_changed

const BASE_TURNS := 3
const BASE_REDRAWS := 3
const BASE_DRAW := 5

var money: int = 10
var round_number: int = 1
var bag: Array = []
var hand: Array = []
var current_monster: Dictionary = {}
var shop_inventory: Array = []
var active_pack_id: String = ""
var active_starter_bag_id: String = ""

var turns_left: int = 0
var redraws_left: int = 0

var upgrade_draw: int = 0
var upgrade_turns: int = 0
var upgrade_redraws: int = 0
var next_draw_bonus: int = 0

var discard_pile: Array = []
var altar_rune: Dictionary = {}
var word_form_levels: Dictionary = {}
var artisan_rail: Array = []
var active_blueprints: Dictionary = {}
var skip_tags: Array = []
var depth_stage: int = 0


func reset() -> void:
	money = 10
	round_number = 1
	bag = []
	hand = []
	current_monster = {}
	shop_inventory = []
	active_pack_id = ""
	active_starter_bag_id = ""
	turns_left = 0
	redraws_left = 0
	upgrade_draw = 0
	upgrade_turns = 0
	upgrade_redraws = 0
	next_draw_bonus = 0
	discard_pile = []
	altar_rune = {}
	word_form_levels = {}
	artisan_rail = []
	active_blueprints = {}
	skip_tags = []
	depth_stage = 0


func round_turn_budget() -> int:
	return BASE_TURNS + upgrade_turns


func round_redraw_budget() -> int:
	return BASE_REDRAWS + upgrade_redraws


func draw_size() -> int:
	var base := BASE_DRAW
	if active_pack_id != "":
		var pack := PackService.pack_by_id(active_pack_id)
		if not pack.is_empty():
			if int(pack.get("base_draw", 0)) > 0:
				base = int(pack["base_draw"])
			else:
				base = BASE_DRAW + int(pack.get("draw_modifier", 0))
	return maxi(base + upgrade_draw + next_draw_bonus, 3)


func monster_hp_scaled() -> int:
	var base := int(current_monster.get("hp", 10))
	return int(round(float(base) * (1.0 + float(round_number - 1) * 0.15)))


func round_reward() -> int:
	return 5 + round_number * 2


func setup_new_run(pack_id: String, starter_bag_id: String) -> void:
	reset()
	active_pack_id = pack_id
	active_starter_bag_id = starter_bag_id
	bag = KeyCapService.load_starter_bag(starter_bag_id)
	var pack: Dictionary = PackService.pack_by_id(pack_id)
	if not pack.is_empty():
		money += int(pack.get("start_money", 0))
	money += KeyCapService.starter_bag_money(starter_bag_id)
