extends Control
## Word-builder combat screen: spell one dictionary word per turn.

@onready var monster_label: Label = %MonsterLabel
@onready var hp_label: Label = %HpLabel
@onready var turns_label: Label = %TurnsLabel
@onready var redraws_label: Label = %RedrawsLabel
@onready var money_label: Label = %MoneyLabel
@onready var word_strip: HBoxContainer = %WordStrip
@onready var hint_label: Label = %HintLabel
@onready var hand_container: HBoxContainer = %HandContainer
@onready var confirm_button: Button = %ConfirmButton
@onready var backspace_button: Button = %BackspaceButton
@onready var redraw_button: Button = %RedrawButton
@onready var skip_button: Button = %SkipButton
@onready var letter_picker: HBoxContainer = %LetterPicker
@onready var hand_empty_warning: Label = %HandEmptyWarning

var _slots: Array = []  # {"cap": Dictionary, "letter": String} in word order
var _pending_redraw: Array = []  # hand indices to swap
var _redraw_mode: bool = false
var _wildcard_pending: Dictionary = {}  # {"cap":..., "index": int} awaiting letter
var _hand_elements: Array = []  # parallel to GameState.hand, tile controls

const KeyCapElementScene := preload("res://scenes/components/KeyCapElement.tscn")


func _ready() -> void:
	EventBus.hand_drawn.connect(_on_hand_drawn)
	EventBus.turns_changed.connect(_on_turns_changed)
	EventBus.redraws_changed.connect(_on_redraws_changed)
	EventBus.monster_damaged.connect(_on_monster_damaged)
	EventBus.round_won.connect(_on_round_won)
	# No round_lost subscription: CombatService emits only game_over (Task 6).
	confirm_button.pressed.connect(_on_confirm_pressed)
	backspace_button.pressed.connect(_on_backspace_pressed)
	redraw_button.pressed.connect(_on_redraw_toggle)
	skip_button.pressed.connect(_on_skip_pressed)
	letter_picker.visible = false
	_build_letter_picker()


func show_round() -> void:
	_refresh_header()
	_refresh_hand()


func _refresh_header() -> void:
	var monster: Dictionary = GameState.current_monster
	if monster.is_empty():
		return
	monster_label.text = str(monster.get("name", "?"))
	var total: int = GameState.monster_hp_scaled()
	var remaining: int = int(monster.get("hp_remaining", total))
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), total]
	turns_label.text = "Turns: %d" % GameState.turns_left
	redraws_label.text = "Redraws: %d" % GameState.redraws_left
	money_label.text = "$%d" % GameState.money


func _on_hand_drawn(hand: Array) -> void:
	_refresh_header()
	_refresh_hand()
	_clear_word()


func _on_turns_changed(turns: int) -> void:
	_refresh_header()


func _on_redraws_changed(redraws: int) -> void:
	_refresh_header()


func _on_monster_damaged(remaining: int, max_hp: int) -> void:
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), max_hp]


func _on_round_won(_money_earned: int) -> void:
	set_process_input(false)
	_clear_word()
	_refresh_header()


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_hand_elements.clear()
	for i in range(GameState.hand.size()):
		var el: Control = KeyCapElementScene.instantiate()
		el.custom_minimum_size = Vector2(56, 56)
		hand_container.add_child(el)
		el.setup(GameState.hand[i])
		el.clicked.connect(_on_hand_clicked.bind(i))
		_hand_elements.append(el)
	hand_empty_warning.visible = GameState.hand.is_empty()
	_refresh_hand_states()


func _refresh_hand_states() -> void:
	for i in range(mini(_hand_elements.size(), GameState.hand.size())):
		var pos: int = _slot_pos_of_hand(i)
		var el: Control = _hand_elements[i]
		el.set_used(pos > 0)
		el.set_word_index(pos)


func _slot_pos_of_hand(idx: int) -> int:
	for i in range(_slots.size()):
		if int(_slots[i].get("hand_idx", -1)) == idx:
			return i + 1
	return 0


func _on_hand_clicked(idx: int) -> void:
	if GameState.turns_left <= 0:
		return
	if _redraw_mode:
		if idx in _pending_redraw:
			_pending_redraw.erase(idx)
		else:
			_pending_redraw.append(idx)
		_redraw_button_ui()
		return
	var cap: Dictionary = GameState.hand[idx]
	if bool(cap.get("is_symbol", false)):
		_wildcard_pending = {"cap": cap, "index": idx, "hand_idx": idx}
		_show_letter_picker(cap)
		return
	if _slot_uses_hand_index(idx):
		return
	# Pass the hand index so the same physical tile can't be reused.
	_add_slot(cap, str(cap["letter"]), idx)


func _slot_uses_hand_index(idx: int) -> bool:
	for s in _slots:
		if int(s.get("hand_idx", -1)) == idx:
			return true
	return false


func _add_slot(cap: Dictionary, letter: String, hand_idx: int = -1) -> void:
	var boss_modifier: String = str(GameState.current_monster.get("boss_modifier", ""))
	if boss_modifier == "no_repeats":
		for s in _slots:
			if str(s["letter"]) == letter:
				hint_label.text = "Can't repeat letters"
				return
	_slots.append({"cap": cap, "letter": letter, "hand_idx": hand_idx})
	_refresh_word()


func _on_backspace_pressed() -> void:
	if _slots.is_empty():
		return
	_slots.pop_back()
	_refresh_word()


func _on_skip_pressed() -> void:
	if GameState.turns_left > 0:
		CombatService.skip_turn()


func _on_redraw_toggle() -> void:
	_redraw_mode = not _redraw_mode
	if not _redraw_mode:
		_pending_redraw.clear()
	_redraw_button_ui()


func _redraw_button_ui() -> void:
	redraw_button.text = "Redraw (%d marked)" % _pending_redraw.size() if _redraw_mode else "Redraw mode"
	confirm_button.disabled = _redraw_mode


func _refresh_word() -> void:
	for child in word_strip.get_children():
		child.queue_free()
	var word := ""
	for i in range(_slots.size()):
		var s: Dictionary = _slots[i]
		word += str(s["letter"])
		var el: Control = KeyCapElementScene.instantiate()
		el.custom_minimum_size = Vector2(44, 44)
		word_strip.add_child(el)
		el.setup(s["cap"])
		el.override_letter(str(s["letter"]))
		el.clicked.connect(_on_slot_clicked.bind(i))
	_refresh_hand_states()
	var valid: Dictionary = CombatService.validate_word(_slots) if _slots.size() >= 3 else {"ok": false}
	if valid.get("ok", false):
		var res: Dictionary = CombatService.calculate_word(_slots)
		hint_label.text = "%s · %d dmg" % [str(valid["word"]), int(res["damage"])]
		confirm_button.disabled = false
	else:
		hint_label.text = _reason_text(valid.get("reason", "keep building"))
		confirm_button.disabled = true


func _on_slot_clicked(i: int) -> void:
	if i >= _slots.size() - 1:
		return
	var tmp: Dictionary = _slots[i]
	_slots[i] = _slots[i + 1]
	_slots[i + 1] = tmp
	_refresh_word()


func _reason_text(reason: String) -> String:
	match reason:
		"not_word":
			return "Not a word"
		"repeat_letter":
			return "Can't repeat letters here"
		_:
			return "Keep building (min 3 letters)"


func _on_confirm_pressed() -> void:
	if confirm_button.disabled:
		return
	if GameState.turns_left <= 0:
		return
	var valid: Dictionary = CombatService.validate_word(_slots)
	if not valid.get("ok", false):
		return
	CombatService.commit_word(_slots)


func _clear_word() -> void:
	_slots.clear()
	_pending_redraw.clear()
	_redraw_mode = false
	redraw_button.text = "Redraw mode"
	_refresh_word()


func _build_letter_picker() -> void:
	var letters: Array = _letters_for_wild("")
	for c in letters:
		var b := Button.new()
		b.text = str(c)
		b.custom_minimum_size = Vector2(36, 36)
		b.pressed.connect(_on_wild_letter.bind(str(c)))
		letter_picker.add_child(b)


func _on_wild_letter(letter: String) -> void:
	if _wildcard_pending.is_empty():
		return
	var hidx: int = int(_wildcard_pending.get("hand_idx", -1))
	_add_slot(_wildcard_pending["cap"], letter, hidx)
	_wildcard_pending = {}
	letter_picker.visible = false


func _letters_for_wild(_cap: Variant) -> Array:
	# populated on demand per wildcard type
	var ab: String = str(_wildcard_pending.get("cap", {}).get("ability_id", ""))
	if ab == "vowel_wild":
		return ["A", "E", "I", "O", "U"].duplicate()
	if ab == "consonant_wild":
		var cons: Array = []
		for c in "BCDFGHJKLMNPQRSTVWXYZ":
			cons.append(c)
		return cons
	var allc: Array = []
	for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		allc.append(c)
	return allc


func _show_letter_picker(cap: Dictionary) -> void:
	for child in letter_picker.get_children():
		child.queue_free()
	var letters: Array = _letters_for_wild(cap)
	for c in letters:
		var b := Button.new()
		b.text = str(c)
		b.custom_minimum_size = Vector2(36, 36)
		var hidx: int = int(_wildcard_pending.get("hand_idx", -1))
		b.pressed.connect(func() -> void:
			_add_slot(_wildcard_pending["cap"], str(c), hidx)
			letter_picker.visible = false)
		letter_picker.add_child(b)
	letter_picker.visible = true