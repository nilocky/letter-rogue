# scripts/screens/CombatScreen.gd
extends Control

@onready var word_container = $WordContainer
@onready var hand_container = $HandContainer
@onready var monster_hp_bar = $MonsterHPBar
@onready var player_hp_bar = $PlayerHPBar
@onready var money_label = $MoneyLabel
@onready var score_label = $ScoreLabel
@onready var confirm_button = $ConfirmButton
@onready var word_label = $WordLabel
@onready var monster_name_label = $MonsterNameLabel
@onready var boss_mod_label = $BossModLabel

var word_slots: Array = []
var hand_elements: Array = []
var selected_caps: Dictionary = {}  # slot_index -> cap

var WordSlotScene = preload("res://scenes/components/WordSlot.tscn")
var KeyCapScene = preload("res://scenes/components/KeyCapElement.tscn")

func _ready():
	EventBus.combat_word_generated.connect(_on_word_generated)
	EventBus.hand_drawn.connect(_on_hand_drawn)
	EventBus.score_calculated.connect(_on_score_calculated)
	EventBus.monster_damaged.connect(_on_monster_damaged)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.round_won.connect(_on_round_won)

func _on_word_generated(word: String, monster_name: String):
	word_label.text = word
	monster_name_label.text = monster_name
	var mod = GameState.current_monster.get("boss_modifier", "")
	boss_mod_label.text = ("Modifier: " + mod) if mod else ""
	boss_mod_label.visible = mod != ""

	for c in word_label.text:
		var slot = WordSlotScene.instantiate()
		slot.setup(c)
		# slot click handling via _on_cap_clicked on hand elements
		word_container.add_child(slot)
		word_slots.append(slot)

	monster_hp_bar.max_value = GameState.current_monster["max_hp"]
	monster_hp_bar.value = GameState.current_monster["hp"]
	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value = GameState.hp
	money_label.text = "$" + str(GameState.money)

func _on_hand_drawn(hand: Array):
	for c in hand_container.get_children():
		c.queue_free()
	hand_elements.clear()

	for cap in hand:
		var elem = KeyCapScene.instantiate()
		elem.setup(cap)
		elem.connect("gui_input", Callable(self, "_on_cap_clicked").bind(hand_elements.size()))
		hand_container.add_child(elem)
		hand_elements.append(elem)

func _on_cap_clicked(index: int, event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		var cap = GameState.hand[index]
		for i in range(word_slots.size()):
			if not word_slots[i].is_occupied():
				word_slots[i].place_cap(cap)
				hand_elements[index].visible = false
				selected_caps[i] = cap
				break

func _on_confirm_pressed():
	if selected_caps.size() == 0:
		return
	var slot_indices = []
	var played = []
	var slot_map = {}
	for i in range(word_slots.size()):
		if word_slots[i].is_occupied():
			var cap = selected_caps[i]
			slot_indices.append(i)
			played.append(cap)
			slot_map[word_label.text[i]] = cap
	KeyCapService.play_caps(slot_map)
	var result = CombatService.calculate_score(played, slot_indices)
	CombatService.apply_monster_damage(result["score"])
	if result["money_bonus"] > 0:
		GameState.money += result["money_bonus"]
	selected_caps.clear()

func _on_score_calculated(score: int, breakdown: Dictionary):
	score_label.text = "Score: " + str(score)

func _on_monster_damaged(hp: int, max_hp: int):
	monster_hp_bar.value = hp
	await get_tree().create_timer(0.5).timeout
	CombatService.monster_attack()

func _on_player_hit(damage: int, hp: int):
	player_hp_bar.value = hp
	money_label.text = "$" + str(GameState.money)
	KeyCapService.draw_hand()

func _on_round_won(money_earned: int):
	score_label.text = "ROUND WON! +$" + str(money_earned)
