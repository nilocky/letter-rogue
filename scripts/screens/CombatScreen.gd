extends Control

const KeyCapElementScene := preload("res://scenes/components/KeyCapElement.tscn")
const WORD_RUNE_SLOT_SCENE := preload("res://scenes/components/WordRuneSlot.tscn")
const BAG_MODAL := preload("res://scenes/components/BagModal.tscn")
const DEPTH_INFO_POPUP := preload("res://scenes/components/DepthInfoPopup.tscn")
const VICTORY_MODAL := preload("res://scenes/components/VictoryModal.tscn")
const KB_FONT := preload("res://assets/fonts/Kenney Blocks.ttf")
const KB_PX_FONT := preload("res://assets/fonts/Kenney Pixel.ttf")
const ParticleBurstFx := preload("res://scripts/components/ParticleBurst.gd")

const TILE_HOP_TIME := 0.15
const TILE_LAND_TIME := 0.18
const BETWEEN_TILE_PAUSE := 0.2
const MULT_RAMP_TIME := 0.35
const HP_DROP_TIME := 0.4
const PROJECTILE_TIME := 0.35

@onready var monster_label: Label = %MonsterNameLabel
@onready var monster_sprite: TextureRect = %MonsterSprite
@onready var hp_bar: TextureProgressBar = %MonsterHPBar
@onready var hp_label: Label = %HpLabel
@onready var turns_label: Label = %TurnRoundLabel
@onready var money_label: Label = %MoneyLabel
@onready var bag_button: Button = %DeckButton
@onready var hint_button: Button = %HintButton
@onready var word_strip = %WordRackContainer
@onready var hint_label: Label = %HintLabel
@onready var hand_container = %HandTileContainer
@onready var redraw_button: Button = %RedrawButton
@onready var play_button: Button = %PlayButton
@onready var wildcard_popup: PopupPanel = %WildcardPopup
@onready var picker_grid: GridContainer = %PickerGrid
@onready var picker_cancel_button: Button = %PickerCancelButton
@onready var hand_empty_warning: Label = %HandEmptyWarning
@onready var base_panel: PanelContainer = %PersistBasePanel
@onready var base_score_label: Label = %PersistBaseLabel
@onready var mult_panel: PanelContainer = %PersistMultPanel
@onready var mult_score_label: Label = %PersistMultLabel
@onready var mult_sub_label: Label = %PersistMultSubLabel
@onready var total_shelf: PanelContainer = %TotalDamageShelf
@onready var total_damage_label: Label = %TotalDamageLabel
@onready var word_meta_label: Label = %WordMetaLabel
@onready var artisan_rail: ArtisanRailDisplay = %ArtisanRail
@onready var grimoire_row = %GrimoireRow
@onready var depth_info_btn: Button = %DepthInfoButton
@onready var settings_btn: Button = %SettingsButton
@onready var depth_panel: Label = %DepthPanel

var _slots: Array = []
var _pending_redraw: Array = []
var _redraw_mode: bool = false
var _wildcard_pending: Dictionary = {}
var _hand_elements: Array = []
var _animating: bool = false
var _skip_requested: bool = false
var _idle_tween: Tween = null


func _ready() -> void:
	EventBus.hand_drawn.connect(_on_hand_drawn)
	EventBus.turns_changed.connect(_on_turns_changed)
	EventBus.redraws_changed.connect(_on_redraws_changed)
	EventBus.monster_damaged.connect(_on_monster_damaged)
	EventBus.round_won.connect(_on_round_won)
	bag_button.pressed.connect(_on_bag_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	depth_info_btn.pressed.connect(_on_depth_info_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	redraw_button.pressed.connect(_on_redraw_toggle)
	play_button.pressed.connect(_on_play_pressed)
	picker_cancel_button.pressed.connect(_on_picker_cancel)
	word_strip.item_dropped.connect(_on_rune_dropped)
	_setup_hand_container_geometry()
	_start_idle_anim()


func _flash_hp_bar() -> void:
	hp_bar.modulate = Color(1.6, 1.6, 1.6, 1.0)
	var tw := create_tween()
	tw.tween_property(hp_bar, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_LINEAR)


func _start_idle_anim() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	_idle_tween.tween_property(monster_sprite, "scale", Vector2(1.04, 1.04), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(monster_sprite, "scale", Vector2(1.0, 1.0), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _squash_hit() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	monster_sprite.scale = Vector2(1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(monster_sprite, "scale", Vector2(1.25, 0.75), 0.06) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(monster_sprite, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(_start_idle_anim)


func _setup_hand_container_geometry() -> void:
	hand_container.custom_minimum_size = Vector2(324, 130)
	hand_container.size = Vector2(324, 130)
	hand_container.position = Vector2(106, 680)
	hand_container.mouse_filter = Control.MOUSE_FILTER_PASS


func show_round() -> void:
	_refresh_header()
	_refresh_hand()
	artisan_rail.refresh()
	grimoire_row.refresh()


func _refresh_header() -> void:
	depth_panel.text = "DEPTH %d-%d" % [GameState.depth_stage + 1, GameState.round_number]
	var monster: Dictionary = GameState.current_monster
	if monster.is_empty():
		return
	monster_label.text = str(monster.get("name", "?"))
	var sprite_path: String = str(monster.get("sprite", ""))
	var sprite_tex: Texture2D = null
	if sprite_path != "":
		sprite_tex = load(sprite_path) as Texture2D
	monster_sprite.texture = sprite_tex
	var total: int = GameState.monster_hp_scaled()
	var remaining: int = int(monster.get("hp_remaining", total))
	hp_bar.max_value = total
	hp_bar.value = maxi(remaining, 0)
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), total]
	turns_label.text = "R%d \u2022 TURNS: %d" % [GameState.round_number, GameState.turns_left]
	money_label.text = "$%d" % GameState.money
	var bag_total: int = GameState.bag.size() + GameState.hand.size()
	bag_button.text = "DECK (%d/%d)" % [GameState.bag.size(), bag_total]
	_update_hint_button_ui()


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
	hp_bar.max_value = max_hp
	hp_bar.value = maxi(remaining, 0)
	hp_label.text = "HP %d/%d" % [maxi(remaining, 0), max_hp]
	_flash_hp_bar()


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
	var total := GameState.hand.size()
	if total == 0:
		hand_empty_warning.visible = true
		return
	hand_empty_warning.visible = false
	var tile_size := Vector2(62, 58)
	var font_size := 30
	var v_sep := 4

	var row_sep := func(count: int) -> int:
		return 3 if count >= 5 else 6

	var max_per_row := 5
	var top_count := mini(total, max_per_row)
	var bottom_count := maxi(0, total - max_per_row)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", v_sep)
	hand_container.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row1.add_theme_constant_override("separation", row_sep.call(mini(top_count, 5)))
	vbox.add_child(row1)

	for i in range(top_count):
		var el := _instantiate_tile(GameState.hand[i], i, tile_size, font_size, row1)
		_hand_elements.append(el)

	if bottom_count > 0:
		var row2 := HBoxContainer.new()
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row2.add_theme_constant_override("separation", row_sep.call(5))
		vbox.add_child(row2)
		for i in range(bottom_count):
			var hand_idx := top_count + i
			var el := _instantiate_tile(GameState.hand[hand_idx], hand_idx, tile_size, font_size, row2)
			_hand_elements.append(el)
	_refresh_hand_states()

func _instantiate_tile(data: Dictionary, idx: int, tile_size: Vector2, font_size: int, parent: Node) -> Control:
	var el: Control = KeyCapElementScene.instantiate()
	el.set("embedded_mode", true)
	el.custom_minimum_size = tile_size
	el.size = tile_size
	parent.add_child(el)
	el.setup(data)
	var lbl: Label = el.get_node_or_null("%LetterLabel")
	if lbl:
		lbl.add_theme_font_size_override("font_size", font_size)
	el.clicked.connect(_on_hand_clicked.bind(idx))
	return el


func _refresh_hand_states() -> void:
	for i in range(mini(_hand_elements.size(), GameState.hand.size())):
		var pos: int = _slot_pos_of_hand(i)
		var el: Control = _hand_elements[i]
		if pos > 0 and not el.is_latched:
			el.set_latched(true)
		elif pos == 0 and el.is_latched:
			el.set_latched(false)
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
		_redraw_button_ui()
		_refresh_hand_states()
		return
	var cap: Dictionary = GameState.hand[idx]
	if bool(cap.get("is_symbol", false)):
		_wildcard_pending = {"cap": cap, "hand_idx": idx, "slot": -1}
		_open_picker(cap)
		return
	var el: Control = _hand_elements[idx]
	if el.is_latched:
		_remove_slot_by_hand_index(idx)
		return
	_add_slot(cap, str(cap["letter"]), idx)


func _remove_slot_by_hand_index(idx: int) -> void:
	for i in range(_slots.size()):
		if int(_slots[i].get("hand_idx", -1)) == idx:
			_slots.remove_at(i)
			_refresh_word()
			return


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
		_refresh_word()
	_redraw_button_ui()


func _redraw_button_ui() -> void:
	if _redraw_mode:
		redraw_button.text = "Cancel"
		redraw_button.disabled = false
		play_button.text = "Confirm swap"
		play_button.disabled = _pending_redraw.is_empty() or GameState.redraws_left < 1
	else:
		redraw_button.text = "REDRAW (%d)" % GameState.redraws_left
		redraw_button.disabled = GameState.redraws_left < 1
		play_button.disabled = false


func _refresh_word() -> void:
	for child in word_strip.get_children():
		if child is WordRuneSlot:
			child.queue_free()
	var word := ""
	for i in range(_slots.size()):
		var s: Dictionary = _slots[i]
		word += str(s["letter"])
		var el: WordRuneSlot = WORD_RUNE_SLOT_SCENE.instantiate()
		word_strip.add_child(el)
		el.setup(str(s["letter"]), int(s.get("cap", {}).get("ability_strength", 0)), i, s)
		el.rune_dismissed.connect(_on_slot_dismissed)
	_refresh_hand_states()
	_update_word_ui()

func _update_word_ui() -> void:
	_refresh_hand_states()
	_update_persistent_scoring()
	var word := ""
	for s in _slots:
		word += str(s["letter"])
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


func _on_slot_dismissed(slot: WordRuneSlot) -> void:
	var i: int = _slots.find(slot.tile_data)
	if i < 0 or _animating:
		return
	var s: Dictionary = _slots[i]
	if bool(s.get("cap", {}).get("is_symbol", false)):
		_wildcard_pending = {"cap": s["cap"], "hand_idx": int(s.get("hand_idx", -1)), "slot": i}
		_open_picker(s["cap"])
		return
	_slots.remove_at(i)
	_refresh_word()

func _on_rune_dropped(from_slot: WordRuneSlot, to_pure_index: int) -> void:
	var runes: Array = word_strip.get_pure_runes()
	var tree_idx: int = word_strip.get_child_count()
	if to_pure_index >= 0 and to_pure_index < runes.size():
		tree_idx = runes[to_pure_index].get_index()
	word_strip.move_child(from_slot, tree_idx)
	from_slot.modulate.a = 1.0
	_slots.clear()
	for c in word_strip.get_children():
		if c is WordRuneSlot:
			_slots.append(c.tile_data)
	var tw := create_tween()
	tw.tween_property(from_slot, "scale", Vector2(1.2, 1.2), 0.08)
	tw.tween_property(from_slot, "scale", Vector2.ONE, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_word_ui()


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


func _on_hint_pressed() -> void:
	if _animating or GameState.hints_remaining <= 0:
		return
	var letters: Array[String] = []
	for cap: Dictionary in GameState.hand:
		if not bool(cap.get("is_symbol", false)):
			letters.append(str(cap.get("letter", "?")))
	var word := HintService.find_basic_word(letters)
	if word == "":
		hint_label.text = "No hints available"
		return
	GameState.hints_remaining -= 1
	_update_hint_button_ui()
	hint_label.text = "HINT: Try %s" % word


func _update_hint_button_ui() -> void:
	hint_button.text = "HINT (%d)" % GameState.hints_remaining
	hint_button.disabled = (GameState.hints_remaining <= 0 or _animating)


func _on_depth_info_pressed() -> void:
	var popup := DEPTH_INFO_POPUP.instantiate()
	add_child(popup)


func _on_settings_pressed() -> void:
	push_error("Settings menu not yet implemented")


func _update_persistent_scoring() -> void:
	var base_sum := 0.0
	for s in _slots:
		base_sum += float(CombatService.letter_base_score(str(s["letter"])))
	base_score_label.text = "%d" % roundi(base_sum)
	var mult := WordService.length_multiplier(_slots.size())
	mult_score_label.text = "×%.1f" % mult


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
	for k in range(marked.size()):
		var el: Control = marked[k]
		tw.tween_property(el, "position", el.position + Vector2(0, 60), 0.2) \
			.set_delay(k * 0.05) \
			.set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(el, "modulate:a", 0.0, 0.2).set_delay(k * 0.05)
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
	for k in range(incoming.size()):
		var el: Control = incoming[k]
		var target := el.position
		var delay: float = k * 0.05
		tw2.tween_property(el, "position", target, 0.25) \
			.from(target + Vector2(0, 60)) \
			.set_delay(delay) \
			.set_trans(Tween.TRANS_LINEAR)
		tw2.tween_property(el, "modulate:a", 1.0, 0.25).from(0.0).set_delay(delay)
		tw2.tween_property(el, "scale", Vector2.ONE, 0.25) \
			.from(Vector2(1.15, 1.15)) \
			.set_delay(delay)
	await tw2.finished
	_animating = false
	_set_controls_enabled(true)


func _play_score_animation() -> void:
	_animating = true
	_skip_requested = false
	_set_controls_enabled(false)

	var res: Dictionary = CombatService.calculate_word(_slots, false)
	var trace: Array = res.get("trace", [])
	var tiles: Array = []
	for c in word_strip.get_children():
		if c is WordRuneSlot:
			tiles.append(c)

	_score_start()
	if not _skip_requested:
		await get_tree().create_timer(0.2).timeout

	# Drive animation from trace events
	for evt in trace:
		var step: String = evt["step_type"]

		if step == "tile_hop":
			await _animate_tile_hop(evt, tiles, res)
		elif step == "tile_retrigger":
			await _animate_tile_retrigger(evt, tiles)
		elif step == "form_ignite":
			await _animate_form_ignite(evt, res)
		elif step == "artisan_trigger":
			await _animate_artisan_trigger(evt)
		elif step == "clash_resolve":
			await _animate_clash(evt, res)

	# Word metadata subtitle
	var word := ""
	for s in _slots:
		word += str(s["letter"])
	if word.length() >= 3:
		var meta: Dictionary = WordService.get_word_meta(word)
		if meta.get("is_valid", false):
			word_meta_label.text = "%s \u00b7 %s \u00b7 \"%s\" \u00b7 V%d/C%d" % [
				word, meta["part_of_speech"], meta["short_def"],
				meta["vowel_count"], meta["consonant_count"]
			]
			word_meta_label.show()

	# Hitstop & HP drop
	var final_damage: int = int(res["damage"])
	await _monster_hitstop(final_damage)

	# Commit & cleanup
	CombatService.commit_word(_slots)
	_score_reset()


func _animate_tile_hop(evt: Dictionary, tiles: Array, res: Dictionary) -> void:
	var i: int = evt["source_index"]
	var pts: float = evt["delta_chips"]
	var tile: Control = tiles[i] as Control

	if _skip_requested:
		base_score_label.text = "%d" % roundi(evt["running_chips"])
		return

	await _hop_tile(tile, pts)

	base_score_label.text = "%d" % roundi(evt["running_chips"])
	var punch := create_tween()
	base_score_label.scale = Vector2(1.3, 1.3)
	punch.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

	if Engine.has_singleton("AudioManager"):
		AudioManager.play("score_chip")

	var cap: Dictionary = _slots[i].get("cap", {})
	if pts > 0.0 and _has_ability_modifier(cap):
		_spawn_floating_text(tile, _ability_float_text(cap, pts))
		await get_tree().create_timer(0.25).timeout

	await get_tree().create_timer(BETWEEN_TILE_PAUSE).timeout


func _animate_tile_retrigger(evt: Dictionary, tiles: Array) -> void:
	if _skip_requested:
		base_score_label.text = "%d" % roundi(evt["running_chips"])
		return

	var tile: Control = tiles[evt["source_index"]] as Control
	var hop := create_tween()
	hop.tween_property(tile, "scale", Vector2(1.3, 1.3), 0.08)
	hop.tween_property(tile, "scale", Vector2.ONE, 0.1)
	_spawn_floating_text(tile, evt["annotation"])

	base_score_label.text = "%d" % roundi(evt["running_chips"])
	var punch := create_tween()
	base_score_label.scale = Vector2(1.3, 1.3)
	punch.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

	if Engine.has_singleton("AudioManager"):
		AudioManager.play("score_chip", 0.85)

	await get_tree().create_timer(0.15).timeout


func _animate_form_ignite(evt: Dictionary, res: Dictionary) -> void:
	var form_base: float = evt["delta_chips"]
	var running_mult: float = evt["running_mult"]
	var form_data: Dictionary = res.get("form_data", {})

	if _skip_requested:
		if form_base > 0:
			base_score_label.text = "%d" % roundi(evt["running_chips"])
		mult_score_label.text = "×%.1f" % running_mult
		return

	if form_base > 0:
		base_score_label.text = "%d" % roundi(evt["running_chips"])
		var form_punch := create_tween()
		form_punch.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)
		base_score_label.scale = Vector2(1.3, 1.3)

		var lbl: String = evt["label"]
		if lbl != "":
			var flabel := Label.new()
			flabel.text = "%s +%d" % [lbl, form_base]
			flabel.add_theme_font_override("font", KB_PX_FONT)
			flabel.add_theme_font_size_override("font_size", 14)
			flabel.add_theme_color_override("font_color", Color(1, 0.6, 0.3, 1))
			flabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			flabel.add_theme_constant_override("outline_size", 2)
			flabel.z_index = 100
			flabel.position = base_panel.global_position + Vector2(0, -32)
			add_child(flabel)
			var ft := flabel.create_tween()
			ft.set_parallel(true)
			ft.tween_property(flabel, "global_position", flabel.global_position + Vector2(0, -24), 0.5)
			ft.tween_property(flabel, "modulate:a", 0.0, 0.5)
			ft.chain().tween_callback(flabel.queue_free)

		await get_tree().create_timer(0.2).timeout

	# Mult ramp
	await get_tree().create_timer(0.15).timeout
	if Engine.has_singleton("AudioManager"):
		AudioManager.play("mult_ignite")
	var scale_pulse := create_tween()
	mult_panel.scale = Vector2(1.25, 1.25)
	scale_pulse.tween_property(mult_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_LINEAR)
	mult_score_label.add_theme_color_override("font_color", Color(1, 0.34, 0.13, 1))
	mult_sub_label.add_theme_color_override("font_color", Color(1, 0.6, 0.3, 1))

	var ramp := create_tween()
	ramp.tween_method(_ramp_mult_display, 1.0, running_mult, MULT_RAMP_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	await ramp.finished
	await get_tree().create_timer(0.3).timeout


func _animate_artisan_trigger(evt: Dictionary) -> void:
	if _skip_requested:
		return

	var idx: int = evt["source_index"]
	var artisan_label_text: String = evt["label"]
	var dmult: float = evt["delta_mult"]
	var xmult: float = evt["x_mult"]

	# Show artisan rail trigger
	if idx >= 0 and idx < 5:
		artisan_rail.trigger_slot(idx)
	else:
		# Aggregate artisan — pulse all filled slots
		for ai in 5:
			artisan_rail.trigger_slot(ai)

	# Update mult display
	var running_mult: float = evt["running_mult"]
	mult_score_label.text = "×%.1f" % running_mult
	var mult_pulse := create_tween()
	mult_pulse.set_parallel(true)
	mult_score_label.scale = Vector2(1.3, 1.3)
	mult_pulse.tween_property(mult_score_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_LINEAR)
	base_score_label.scale = Vector2(1.1, 1.1)
	mult_pulse.tween_property(base_score_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_LINEAR)

	# Floating text for artisan bonus
	var parts: Array = []
	if dmult > 0:
		parts.append("+%d Mult" % dmult)
	if xmult != 1.0:
		parts.append("×%g" % xmult)
	if parts.size() > 0:
		var flabel := Label.new()
		flabel.text = "Artisan: %s" % ", ".join(parts)
		flabel.add_theme_font_override("font", KB_PX_FONT)
		flabel.add_theme_font_size_override("font_size", 13)
		flabel.add_theme_color_override("font_color", Color(0.4, 1, 0.6, 1))
		flabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		flabel.add_theme_constant_override("outline_size", 2)
		flabel.z_index = 100
		flabel.position = mult_panel.global_position + Vector2(0, -32)
		add_child(flabel)
		var ft := flabel.create_tween()
		ft.set_parallel(true)
		ft.tween_property(flabel, "global_position", flabel.global_position + Vector2(0, -24), 0.5)
		ft.tween_property(flabel, "modulate:a", 0.0, 0.5)
		ft.chain().tween_callback(flabel.queue_free)

	if Engine.has_singleton("AudioManager"):
		AudioManager.play("mult_ignite", 1.15)

	await get_tree().create_timer(0.3).timeout


func _animate_clash(evt: Dictionary, res: Dictionary) -> void:
	var final_damage: int = int(res["damage"])

	if _skip_requested:
		total_shelf.show()
		total_damage_label.text = "= %d DMG" % final_damage
		return

	total_shelf.show()
	total_damage_label.text = "= %d DMG" % final_damage
	var flash := create_tween()
	total_damage_label.scale = Vector2(1.4, 1.4)
	flash.tween_property(total_damage_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_LINEAR)

	# Base + Mult pulse in sync
	var sync_pulse := create_tween()
	sync_pulse.set_parallel(true)
	base_score_label.scale = Vector2(1.15, 1.15)
	mult_score_label.scale = Vector2(1.15, 1.15)
	sync_pulse.tween_property(base_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)
	sync_pulse.tween_property(mult_score_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(0.35).timeout

	# Projectile from banner to monster
	await _projectile_to_monster(final_damage)


func _monster_hitstop(dmg: int) -> void:
	if _skip_requested:
		var hp_total: int = GameState.monster_hp_scaled()
		var hp_remaining: int = int(GameState.current_monster.get("hp_remaining", hp_total))
		var hp_new: int = maxi(hp_remaining - dmg, 0)
		hp_bar.value = float(hp_new)
		return

	var hp_total: int = GameState.monster_hp_scaled()
	var hp_remaining: int = int(GameState.current_monster.get("hp_remaining", hp_total))
	var hp_new: int = maxi(hp_remaining - dmg, 0)
	var hp_from: float = hp_bar.value
	var hp_tween := create_tween()
	hp_tween.tween_method(func(v: float) -> void: hp_bar.value = v, hp_from, float(hp_new), HP_DROP_TIME) \
		.set_trans(Tween.TRANS_LINEAR)

	_spawn_damage_float(dmg)
	await hp_tween.finished


func _has_ability_modifier(cap: Dictionary) -> bool:
	return cap.get("finish", "") != "" or cap.get("sticker", "") != "" or cap.get("condition", "") != "" or cap.get("ability_id", "") != ""


func _ability_float_text(cap: Dictionary, _pts: float) -> String:
	var parts: Array = []
	if cap.get("finish") == "foil":
		parts.append("+3 Foil!")
	elif cap.get("finish") == "holographic":
		parts.append("+1 Holographic!")
	elif cap.get("finish") == "polychrome":
		parts.append("×1.5 Polychrome!")
	if cap.get("sticker") == "red":
		parts.append("×2 Red!")
	if cap.get("condition") == "glass":
		parts.append("×2 Glass!")
	var ability: String = str(cap.get("ability_id", ""))
	if ability == "bonus_points":
		parts.append("+%s Power!" % str(cap.get("ability_strength", "0")))
	elif ability == "double_score":
		parts.append("DOUBLE!")
	return " ".join(parts)


func _spawn_floating_text(anchor: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", KB_PX_FONT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.z_index = 100
	lbl.position = anchor.global_position + Vector2(0, -48)
	add_child(lbl)
	var ft := lbl.create_tween()
	ft.set_parallel(true)
	ft.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -24), 0.5) \
		.set_trans(Tween.TRANS_LINEAR)
	ft.tween_property(lbl, "modulate:a", 0.0, 0.5)
	ft.chain().tween_callback(lbl.queue_free)


func _spawn_damage_float(dmg: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	lbl.add_theme_font_override("font", KB_FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.2, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 100
	lbl.position = hp_label.global_position + Vector2(0, -16)
	add_child(lbl)
	var ft := lbl.create_tween()
	ft.set_parallel(true)
	ft.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -48), 0.6) \
		.set_trans(Tween.TRANS_LINEAR)
	ft.tween_property(lbl, "modulate:a", 0.0, 0.6)
	ft.chain().tween_callback(lbl.queue_free)


func _ramp_mult_display(v: float) -> void:
	mult_score_label.text = "×%.1f" % v


func _hop_tile(tile: Control, pts: float) -> void:
	var origin: Vector2 = tile.global_position
	var hop := create_tween()
	hop.tween_property(tile, "global_position", origin + Vector2(0, -20), TILE_HOP_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	hop.tween_property(tile, "global_position", origin, TILE_LAND_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	_spawn_tile_score(tile, pts)


func _spawn_tile_score(tile: Control, pts: float) -> void:
	if pts <= 0.0:
		return
	ParticleBurstFx.burst(self, tile.global_position + Vector2(0, -20), Color(1, 0.9, 0.3), 10, {"vel_min": 80, "vel_max": 160, "lifetime": 0.45})
	var lbl := Label.new()
	lbl.text = _fmt_pts(pts)
	lbl.add_theme_font_override("font", KB_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 100
	lbl.position = tile.global_position + Vector2(0, -32)
	add_child(lbl)
	var ft := lbl.create_tween()
	ft.set_parallel(true)
	ft.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -32), 0.5) \
		.set_trans(Tween.TRANS_LINEAR)
	ft.tween_property(lbl, "modulate:a", 0.0, 0.5)
	ft.chain().tween_callback(lbl.queue_free)


func _fmt_pts(pts: float) -> String:
	if absf(pts - roundi(pts)) < 0.001:
		return "+%d" % roundi(pts)
	return "+%.1f" % pts


func _score_start() -> void:
	var row: Control = %PersistentScoringRow
	row.scale = Vector2(0.95, 0.95)
	var tw := create_tween()
	tw.tween_property(row, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	total_shelf.hide()
	base_score_label.text = "0"
	base_score_label.scale = Vector2(1, 1)
	mult_score_label.text = "×1.0"
	mult_score_label.scale = Vector2(1, 1)
	mult_score_label.add_theme_color_override("font_color", Color(0.96, 0.68, 0.33, 1))
	mult_sub_label.add_theme_color_override("font_color", Color(0.96, 0.68, 0.33, 1))
	mult_panel.scale = Vector2(1, 1)


func _score_reset() -> void:
	base_score_label.text = "0"
	base_score_label.scale = Vector2(1, 1)
	mult_score_label.text = "×1.0"
	mult_score_label.scale = Vector2(1, 1)
	mult_score_label.add_theme_color_override("font_color", Color(0.96, 0.68, 0.33, 1))
	mult_sub_label.add_theme_color_override("font_color", Color(0.96, 0.68, 0.33, 1))
	mult_panel.scale = Vector2(1, 1)
	total_shelf.hide()
	total_damage_label.text = ""
	total_damage_label.scale = Vector2(1, 1)
	word_meta_label.hide()
	word_meta_label.text = ""
	_set_controls_enabled(true)
	_animating = false


func _projectile_to_monster(dmg: int) -> void:
	var ghost := Label.new()
	ghost.text = "%d" % dmg
	ghost.add_theme_font_override("font", KB_FONT)
	ghost.add_theme_font_size_override("font_size", 14)
	ghost.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	ghost.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	ghost.add_theme_constant_override("outline_size", 3)
	ghost.z_index = 150
	ghost.position = total_damage_label.global_position
	add_child(ghost)

	var target: Vector2 = hp_bar.global_position + Vector2(hp_bar.size.x / 2, 0)
	var tw := create_tween()
	tw.tween_property(ghost, "global_position", target, PROJECTILE_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(ghost.queue_free)

	ParticleBurstFx.burst(self, target, Color(1, 0.25, 0.15), 18, {"vel_min": 90, "vel_max": 200, "lifetime": 0.5})

	ScreenShake.shake(%MonsterDisplayArea, 6.0, 0.2)
	_squash_hit()

	if Engine.has_singleton("AudioManager"):
		AudioManager.play("slam_impact")

	await tw.finished


func _set_controls_enabled(v: bool) -> void:
	redraw_button.disabled = not v
	if v:
		_refresh_word()
	else:
		play_button.disabled = true


func _gui_input(event: InputEvent) -> void:
	if _animating and event is InputEventMouseButton and not event.pressed:
		_skip_requested = true


func _clear_word() -> void:
	_slots.clear()
	_pending_redraw.clear()
	_redraw_mode = false
	redraw_button.text = "REDRAW (%d)" % GameState.redraws_left
	_refresh_word()


func _open_picker(cap: Dictionary) -> void:
	_build_picker_grid(cap)
	wildcard_popup.popup_centered(Vector2i(460, 520))


func _build_picker_grid(cap: Dictionary) -> void:
	for child in picker_grid.get_children():
		child.queue_free()
	for c in _letters_for_wild(cap):
		var b := Button.new()
		b.text = str(c)
		b.add_theme_font_override("font", KB_FONT)
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(60, 60)
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
