extends Node
## Top-level state machine: menu -> combat <-> shop -> game over.

enum State { MENU, RUN_SETUP, COMBAT, SHOP, GAME_OVER }

var current_state: State = State.MENU
var current_screen: Node = null

const MENU_SCENE := preload("res://scenes/MainMenuScreen.tscn")
const RUN_SETUP_SCENE := preload("res://scenes/RunSetupScreen.tscn")
const COMBAT_SCENE := preload("res://scenes/CombatScreen.tscn")
const SHOP_SCENE := preload("res://scenes/ShopScreen.tscn")
const GAME_OVER_SCENE := preload("res://scenes/GameOverScreen.tscn")

var _monsters_cache: Dictionary = {}


func _ready() -> void:
	EventBus.run_setup_requested.connect(_on_run_setup_requested)
	EventBus.run_setup_cancelled.connect(_on_run_setup_cancelled)
	EventBus.run_started.connect(_on_run_started)
	EventBus.fight_pressed.connect(_on_fight_pressed)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.game_complete.connect(_on_game_complete)
	EventBus.game_over.connect(_on_game_over)
	_switch_to_menu()


func _switch_to_menu() -> void:
	GameState.reset()
	current_state = State.MENU
	_show(MENU_SCENE)


func _on_run_setup_requested() -> void:
	current_state = State.RUN_SETUP
	_show(RUN_SETUP_SCENE)


func _on_run_setup_cancelled() -> void:
	current_state = State.MENU
	_show(MENU_SCENE)


func _on_run_started(pack_id: String, starter_bag_id: String) -> void:
	GameState.setup_new_run(pack_id, starter_bag_id)
	_fight_or_boss()


func _on_fight_pressed() -> void:
	_fight_or_boss()


func _fight_or_boss() -> void:
	if not GameState.skip_tags.is_empty():
		var tag: String = GameState.skip_tags.pop_front()
		if tag == "skip":
			GameState.round_number += 1
			_on_shop_requested()
			return
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


func _fight_or_boss_depths() -> void:
	var stage: int = GameState.depth_stage
	var entry: Dictionary = DepthService.generate_encounter(stage)
	if entry.is_empty():
		_fight_or_boss()
		return
	entry["hp_remaining"] = _scaled_hp(entry, GameState.round_number)
	GameState.current_monster = entry
	current_state = State.COMBAT
	_show(COMBAT_SCENE)
	CombatService.start_round()


func _on_shop_requested() -> void:
	if GameState.round_number % 3 == 0:
		GameState.depth_stage += 1
		EventBus.depth_advanced.emit(GameState.depth_stage)
	GameState.round_number += 1
	ShopService.new_shop()
	current_state = State.SHOP
	_show(SHOP_SCENE)


func _on_game_complete() -> void:
	_switch_to_menu()


func _on_game_over(reached_round: int) -> void:
	current_state = State.GAME_OVER
	_show(GAME_OVER_SCENE)
	if current_screen.has_method("show_game_over"):
		current_screen.show_game_over(reached_round)


func route_to(state: String) -> void:
	match state:
		"menu":
			_switch_to_menu()
		"run_setup":
			_on_run_setup_requested()
		"combat":
			_fight_or_boss()
		"shop":
			if GameState.active_pack_id == "":
				GameState.active_pack_id = "clicky"
				GameState.bag = KeyCapService.load_starter_bag("standard")
			_on_shop_requested()
		"boss":
			jump_boss_round()


func inject_state(cfg: Dictionary) -> void:
	for key: String in cfg:
		if GameState.has_method("set_" + key):
			GameState.call("set_" + key, cfg[key])
		elif GameState.get(key) != null:
			GameState.set(key, cfg[key])
	if current_screen and current_screen.has_method("show_round"):
		current_screen.show_round()


func trigger_mechanic(id: String) -> void:
	if current_state != State.COMBAT or current_screen == null:
		return
	match id:
		"silence":
			GameState.current_monster["modifier"] = "silence"
	if current_screen.has_method("_refresh_header"):
		current_screen._refresh_header()


func jump_boss_round() -> void:
	var next: int = int(ceil(GameState.round_number / 3.0)) * 3
	if next == 0:
		next = 3
	GameState.round_number = next
	_fight_or_boss()


func _show(scene: PackedScene) -> void:
	if current_screen:
		current_screen.queue_free()
	current_screen = scene.instantiate()
	add_child(current_screen)


func _monster_list_for(pool: String) -> Array:
	if _monsters_cache.is_empty():
		var text := FileAccess.get_file_as_string("res://data/monsters.json")
		var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			_monsters_cache = data
	return _monsters_cache.get(pool, [])


func _scaled_hp(entry: Dictionary, round_number: int) -> int:
	return int(round(float(entry.get("hp", 10)) * (1.0 + float(round_number - 1) * 0.15)))
