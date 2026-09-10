extends Node
## Top-level state machine: menu -> combat <-> shop -> game over.

enum State { MENU, PACK_SELECT, COMBAT, SHOP, GAME_OVER }

var current_state: State = State.MENU
var current_screen: Node = null

const MENU_SCENE := preload("res://scenes/MainMenuScreen.tscn")
const COMBAT_SCENE := preload("res://scenes/CombatScreen.tscn")
const SHOP_SCENE := preload("res://scenes/ShopScreen.tscn")
const GAME_OVER_SCENE := preload("res://scenes/GameOverScreen.tscn")

var _monsters_cache: Dictionary = {}


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.fight_pressed.connect(_on_fight_pressed)
	EventBus.round_won.connect(_on_round_won)
	EventBus.game_over.connect(_on_game_over)
	_switch_to_menu()


func _switch_to_menu() -> void:
	GameState.reset()
	current_state = State.MENU
	_show(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		GameState.reset()
		GameState.active_pack_id = "mx_red"
		GameState.money = 50
		GameState.bag = _load_starter_bag()
		ShopService.new_shop()
		current_state = State.SHOP
		_show(SHOP_SCENE)


func _on_run_started() -> void:
	var pack_id: String = GameState.active_pack_id
	GameState.reset()
	GameState.active_pack_id = pack_id
	var pack: Dictionary = PackService.pack_by_id(pack_id)
	if not pack.is_empty() and not GameState.pack_start_money_granted:
		GameState.money += int(pack.get("start_money", 0))
		GameState.pack_start_money_granted = true
	GameState.bag = _load_starter_bag()
	_fight_or_boss()


func _on_fight_pressed() -> void:
	_fight_or_boss()


func _fight_or_boss() -> void:
	var boss_round: bool = GameState.round_number % 3 == 0
	var list: Array = _monster_list_for("bosses" if boss_round else "normal")
	if list.is_empty():
		return
	var entry: Dictionary = list[randi() % list.size()].duplicate(true)
	entry["hp_remaining"] = _scaled_hp(entry, GameState.round_number)
	GameState.current_monster = entry
	current_state = State.COMBAT
	_show(COMBAT_SCENE)
	CombatService.start_round()


func _on_round_won(_money_earned: int) -> void:
	GameState.round_number += 1
	ShopService.new_shop()
	current_state = State.SHOP
	_show(SHOP_SCENE)


func _on_game_over(reached_round: int) -> void:
	current_state = State.GAME_OVER
	_show(GAME_OVER_SCENE)
	if current_screen.has_method("show_game_over"):
		current_screen.show_game_over(reached_round)


func _show(scene: PackedScene) -> void:
	if current_screen:
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)


func _load_starter_bag() -> Array:
	var text := FileAccess.get_file_as_string("res://data/key_caps.json")
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	return (data.get("starter_bag", []) as Array).duplicate(true)


func _monster_list_for(pool: String) -> Array:
	if _monsters_cache.is_empty():
		var text := FileAccess.get_file_as_string("res://data/monsters.json")
		var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			_monsters_cache = data
	return _monsters_cache.get(pool, [])


func _scaled_hp(entry: Dictionary, round_number: int) -> int:
	return int(round(float(entry.get("hp", 10)) * (1.0 + float(round_number - 1) * 0.15)))