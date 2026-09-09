extends Node

enum State { MENU, PACK_SELECT, COMBAT, SHOP, GAME_OVER }

var current_state = State.MENU
var current_screen = null

var menu_scene = preload("res://scenes/MainMenuScreen.tscn")
var combat_scene = preload("res://scenes/CombatScreen.tscn")
var shop_scene = preload("res://scenes/ShopScreen.tscn")
var game_over_scene = preload("res://scenes/GameOverScreen.tscn")

func _ready():
	EventBus.run_started.connect(_on_run_started)
	EventBus.round_won.connect(_on_round_won)
	EventBus.fight_pressed.connect(_on_fight_pressed)
	EventBus.game_over.connect(_on_game_over)
	_switch_to_menu()

func _switch_to_menu():
	GameState.reset()
	_clear_screen()
	current_state = State.MENU
	current_screen = menu_scene.instantiate()
	add_child(current_screen)

func _on_run_started():
	GameState.reset()
	var caps_json = FileAccess.get_file_as_string("res://data/key_caps.json")
	var data = JSON.parse_string(caps_json)
	GameState.load_starter_bag(data["starter_bag"])

	var monsters_json = FileAccess.get_file_as_string("res://data/monsters.json")
	var monsters_data = JSON.parse_string(monsters_json)
	var monster = monsters_data["normal"][0].duplicate()
	var scale = 1.0 + (GameState.round - 1) * 0.15
	monster["max_hp"] = ceili(monster["max_hp"] * scale)
	monster["hp"] = monster["max_hp"]
	GameState.current_monster = monster

	_switch_to_combat()

func _switch_to_combat():
	_clear_screen()
	current_state = State.COMBAT
	current_screen = combat_scene.instantiate()
	add_child(current_screen)
	CombatService.start_combat(GameState.current_monster)

func _on_round_won(money_earned: int):
	for cap in GameState.hand:
		if cap.get("condition") == "gold_held":
			GameState.money += 3
			break
	GameState.round += 1
	if GameState.round % 3 == 0:
		var monsters_json = FileAccess.get_file_as_string("res://data/monsters.json")
		var data = JSON.parse_string(monsters_json)
		var boss = data["bosses"][0].duplicate()
		var scale = 1.0 + (GameState.round - 1) * 0.15
		boss["max_hp"] = ceili(boss["max_hp"] * scale)
		boss["hp"] = boss["max_hp"]
		GameState.current_monster = boss
		_switch_to_combat()
	else:
		_switch_to_shop()

func _switch_to_shop():
	_clear_screen()
	current_state = State.SHOP
	current_screen = shop_scene.instantiate()
	GameState.process_rental_costs()
	add_child(current_screen)
	ShopService.generate_inventory()

func _on_fight_pressed():
	_load_next_normal_monster()
	_switch_to_combat()

func _load_next_normal_monster():
	var monsters_json = FileAccess.get_file_as_string("res://data/monsters.json")
	var data = JSON.parse_string(monsters_json)
	var pool = data["normal"]
	var monster = pool[randi() % pool.size()].duplicate()
	var scale = 1.0 + (GameState.round - 1) * 0.15
	monster["max_hp"] = ceili(monster["max_hp"] * scale)
	monster["hp"] = monster["max_hp"]
	GameState.current_monster = monster

func _on_game_over():
	_clear_screen()
	current_state = State.GAME_OVER
	current_screen = game_over_scene.instantiate()
	add_child(current_screen)

func _clear_screen():
	if current_screen:
		current_screen.queue_free()
		current_screen = null
