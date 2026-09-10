extends Control

const KeyCapElementScene := preload("res://scenes/components/KeyCapElement.tscn")
const BAG_MODAL := preload("res://scenes/components/BagModal.tscn")
const VICTORY_MODAL := preload("res://scenes/components/VictoryModal.tscn")
const KB_FONT := preload("res://assets/fonts/Kenney Blocks.ttf")

@onready var monster_label: Label = %MonsterLabel
@onready var hp_label: Label = %HpLabel
@onready var turns_label: Label = %TurnsLabel
@onready var money_label: Label = %MoneyLabel
@onready var bag_button: Button = %BagButton
@onready var word_strip = %WordStrip
@onready var hint_label: Label = %HintLabel
@onready var hand_container = %HandContainer
@onready var redraw_button: Button = %RedrawButton
@onready var play_button: Button = %PlayButton
@onready var wildcard_popup: PopupPanel = %WildcardPopup
@onready var picker_grid: GridContainer = %PickerGrid
@onready var picker_cancel_button: Button = %PickerCancelButton
@onready var hand_empty_warning: Label = %HandEmptyWarning

var _slots: Array = []
var _pending_redraw: Array = []
var _redraw_mode: bool = false
var _wildcard_pending: Dictionary = {}
var _hand_elements: Array = []
var _animating: bool = false


func _ready() -> void:
	EventBus.hand_drawn.connect(_on_hand_drawn)
	EventBus.turns_changed.connect(_on_turns_changed)
	EventBus.redraws_changed.connect(_on_redraws_changed)
	EventBus.monster_damaged.connect(_on_monster_damaged)
	EventBus.round_won.connect(_on_round_won)
	bag_button.pressed.connect(_on_bag_pressed)
	redraw_button.pressed.connect(_on_redraw_toggle)
	play_button.pressed.connect(_on_play_pressed)
	picker_cancel_button.pressed.connect(_on_picker_cancel)


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
	money_label.text = "$%d" % GameState.money
	var bag_total: int = GameState.bag.size() + GameState.hand.size()
	bag_button.text = "BAG (%d/%d)" % [GameState.bag.size(), bag_total]


func _on_hand_drawn(hand: Array) -> void:
	_refresh_header()
	_refresh_hand()
	_clear_word()


func _on_turns_changed(turns: int) -> void:
	_refresh_header()


func _on_redraws_changed(redraws: int) -> void:
	_refresh_header()
	_redraw_button_ui()


func _on_monster_damaged(remaining: int, max_hp: int) -> void:
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), max_hp]


func _on_round_won(_summary: Dictionary) -> void:
	_clear_word()
	_refresh_header()
	var modal: Control = VICTORY_MODAL.instantiate()
	add_child(modal)
	modal.open(_summary)


func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_hand_elements.clear()
	for i in range(GameState.hand.size()):
		var el: Control = KeyCapElementScene.instantiate()
		el.custom_minimum_size = Vector2(120, 120)
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
		el.set_redraw_marked(_redraw_mode and i in _pending_redraw)


func _slot_pos_of_hand(idx: int) -> int:
	for i in range(_slots.size()):
		if int(_slots[i].get("hand_idx", -1)) == idx:
			return i + 1
	return 0


func _on_hand_clicked(idx: int) -> void:
	if _animating or GameState.turns_left <= 0:
		return
	if _redraw_mode:
		if idx in _pending_redraw:
			_pending_redraw.erase(idx)
		else:
			_pending_redraw.append(idx)
		_refresh_hand_states()
		return
	var cap: Dictionary = GameState.hand[idx]
	if bool(cap.get("is_symbol", false)):
		_wildcard_pending = {"cap": cap, "hand_idx": idx, "slot": -1}
		_open_picker(cap)
		return
	if _slot_uses_hand_index(idx):
		_remove_slot_by_hand_index(idx)
		return
	_add_slot(cap, str(cap["letter"]), idx)


func _remove_slot_by_hand_index(idx: int) -> void:
	for i in range(_slots.size()):
		if int(_slots[i].get("hand_idx", -1)) == idx:
			_slots.remove_at(i)
			_refresh_word()
			return


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


func _on_redraw_toggle() -> void:
	_redraw_mode = not _redraw_mode
	if not _redraw_mode:
		_pending_redraw.clear()
	_redraw_button_ui()


func _redraw_button_ui() -> void:
	if _redraw_mode:
		redraw_button.text = "Cancel"
		play_button.text = "Confirm swap"
	else:
		redraw_button.text = "REDRAW (%d)" % GameState.redraws_left
	redraw_button.disabled = _redraw_mode and (_pending_redraw.is_empty() or GameState.redraws_left < 1)


func _refresh_word() -> void:
	for child in word_strip.get_children():
		child.queue_free()
	var word := ""
	for i in range(_slots.size()):
		var s: Dictionary = _slots[i]
		word += str(s["letter"])
		var el: Control = KeyCapElementScene.instantiate()
		el.custom_minimum_size = Vector2(120, 120)
		word_strip.add_child(el)
		el.setup(s["cap"])
		el.override_letter(str(s["letter"]))
		el.drag_index = i
		el.clicked.connect(_on_slot_clicked.bind(i))
		el.drag_drop.connect(_on_word_drop)
	_refresh_hand_states()
	if _redraw_mode:
		hint_label.text = "Mark tiles to swap"
		play_button.text = "Confirm swap"
		play_button.disabled = _pending_redraw.is_empty() or GameState.redraws_left < 1
		return
	if _slots.is_empty():
		hint_label.text = "Tap tiles to spell a word"
		play_button.text = "PLAY"
		play_button.disabled = true
		return
	var valid: Dictionary = CombatService.validate_word(_slots)
	if valid.get("ok", false):
		var res: Dictionary = CombatService.calculate_word(_slots)
		var dmg: int = int(res["damage"])
		if _slots.size() < 3:
			hint_label.text = "PLAY (%d DMG)" % dmg
			play_button.text = "PLAY (%d DMG)" % dmg
		else:
			hint_label.text = "WORD: %s · %d DMG" % [word, dmg]
			play_button.text = "PLAY (%d DMG)" % dmg
		play_button.disabled = false
	else:
		hint_label.text = "Not a word"
		play_button.text = "PLAY"
		play_button.disabled = true


func _on_slot_clicked(i: int) -> void:
	if _animating or i >= _slots.size():
		return
	var s: Dictionary = _slots[i]
	if bool(s.get("cap", {}).get("is_symbol", false)):
		_wildcard_pending = {"cap": s["cap"], "hand_idx": int(s.get("hand_idx", -1)), "slot": i}
		_open_picker(s["cap"])
		return
	_slots.remove_at(i)
	_refresh_word()


func _on_word_drop(from: int, to: int) -> void:
	if _animating or from < 0 or from >= _slots.size() or to < 0 or to >= _slots.size():
		return
	var moving: Dictionary = _slots[from]
	_slots.remove_at(from)
	_slots.insert(to, moving)
	_refresh_word()


func _on_play_pressed() -> void:
	if _animating or GameState.turns_left <= 0:
		return
	if _redraw_mode:
		if _pending_redraw.is_empty() or GameState.redraws_left < 1:
			return
		_do_redraw()
		return
	if _slots.is_empty():
		return
	_play_score_animation()


func _on_bag_pressed() -> void:
	var modal: Control = BAG_MODAL.instantiate()
	add_child(modal)
	modal.open()


func _do_redraw() -> void:
	var indices := _pending_redraw.duplicate()
	_animating = true
	_set_controls_enabled(false)
	var marked: Array = []
	for i in indices:
		if i < _hand_elements.size():
			marked.append(_hand_elements[i])
	var tw := create_tween()
	tw.set_parallel(true)
	for el: Control in marked:
		tw.tween_property(el, "position", el.position + Vector2(0, 60), 0.2)
		tw.tween_property(el, "modulate:a", 0.0, 0.2)
	await tw.finished
	if not KeyCapService.redraw_tiles(indices):
		for el: Control in marked:
			el.position -= Vector2(0, 60)
			el.modulate.a = 1.0
		_animating = false
		_set_controls_enabled(true)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var incoming: Array = []
	for i in indices:
		if i < _hand_elements.size():
			incoming.append(_hand_elements[i])
	var tw2 := create_tween()
	tw2.set_parallel(true)
	for el: Control in incoming:
		var target := el.position
		tw2.tween_property(el, "position", target, 0.25) \
			.from(target + Vector2(0, 60)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(el, "modulate:a", 1.0, 0.25).from(0.0)
	await tw2.finished
	_animating = false
	_set_controls_enabled(true)


func _play_score_animation() -> void:
	_animating = true
	_set_controls_enabled(false)
	var res: Dictionary = CombatService.calculate_word(_slots, false)
	var scores: Array = res.get("letter_scores", [])
	var tiles: Array = word_strip.get_children()
	var tween := create_tween()
	for i in range(tiles.size()):
		tween.tween_interval(0.22)
		var pts: float = float(scores[i]) if i < scores.size() else 0.0
		var tile: Control = tiles[i] as Control
		tween.tween_callback(func() -> void: _hop_tile(tile, pts))
	await tween.finished
	_set_controls_enabled(true)
	_animating = false
	CombatService.commit_word(_slots)


func _hop_tile(tile: Control, pts: float) -> void:
	var origin: Vector2 = tile.global_position
	var hop := create_tween()
	hop.tween_property(tile, "global_position", origin + Vector2(0, -16), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(tile, "global_position", origin, 0.14) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_spawn_score_label(tile, pts)


func _spawn_score_label(tile: Control, pts: float) -> void:
	if pts <= 0.0:
		return
	var lbl := Label.new()
	lbl.text = _fmt_pts(pts)
	lbl.add_theme_font_override("font", KB_FONT)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.z_index = 100
	lbl.position = tile.global_position + Vector2(0, -32)
	add_child(lbl)
	var ft := lbl.create_tween()
	ft.set_parallel(true)
	ft.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -32), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.tween_property(lbl, "modulate:a", 0.0, 0.5)
	ft.chain().tween_callback(lbl.queue_free)


func _fmt_pts(pts: float) -> String:
	if absf(pts - roundi(pts)) < 0.001:
		return "+%d" % roundi(pts)
	return "+%.1f" % pts


func _set_controls_enabled(v: bool) -> void:
	redraw_button.disabled = not v
	if v:
		_refresh_word()
	else:
		play_button.disabled = true


func _clear_word() -> void:
	_slots.clear()
	_pending_redraw.clear()
	_redraw_mode = false
	redraw_button.text = "REDRAW (%d)" % GameState.redraws_left
	_refresh_word()


func _open_picker(cap: Dictionary) -> void:
	_build_picker_grid(cap)
	wildcard_popup.popup_centered(Vector2i(900, 1100))


func _build_picker_grid(cap: Dictionary) -> void:
	for child in picker_grid.get_children():
		child.queue_free()
	for c in _letters_for_wild(cap):
		var b := Button.new()
		b.text = str(c)
		b.add_theme_font_override("font", KB_FONT)
		b.add_theme_font_size_override("font_size", 48)
		b.custom_minimum_size = Vector2(120, 120)
		b.pressed.connect(_on_wild_letter.bind(str(c)))
		picker_grid.add_child(b)


func _on_wild_letter(letter: String) -> void:
	if _wildcard_pending.is_empty():
		return
	var slot: int = int(_wildcard_pending.get("slot", -1))
	if slot >= 0:
		_slots[slot]["letter"] = letter
		_refresh_word()
	else:
		_add_slot(_wildcard_pending["cap"], letter, int(_wildcard_pending.get("hand_idx", -1)))
	_wildcard_pending = {}
	wildcard_popup.hide()


func _on_picker_cancel() -> void:
	_wildcard_pending = {}
	wildcard_popup.hide()


func _letters_for_wild(cap: Dictionary) -> Array:
	match str(cap.get("ability_id", "")):
		"vowel_wild":
			return ["A", "E", "I", "O", "U"]
		"consonant_wild":
			var cons: Array = []
			for c in "BCDFGHJKLMNPQRSTVWXYZ":
				cons.append(c)
			return cons
		_:
			var allc: Array = []
			for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
				allc.append(c)
			return allc
