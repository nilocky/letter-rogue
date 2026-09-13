extends Node

signal on_draw(hand)
signal on_letter_slotted(cap, index)
signal on_word_validated(word, valid)
signal on_score_calculated(result)
signal on_word_form_evaluated(form_id: String, base: int, mult: float)
signal on_artisan_triggered(artisan_id: String, slot: int, effect: Dictionary)
signal on_shop_opened
signal on_bag_mutated(mutation_type: String, affected_tiles: Array)
signal on_monster_damaged(monster, damage, remaining)
signal on_monster_defeated(monster, summary)
signal on_turn_end(turns_left)

var _cap_effects: Dictionary = {}


func register_cap(cap: Dictionary) -> void:
	var effects: Array = cap.get("effects", [])
	if effects.is_empty():
		return
	var cap_id: String = str(cap.get("id", cap.get("letter", "")))
	for effect: Variant in effects:
		var e: Dictionary = effect
		var hook: String = str(e.get("hook", ""))
		if hook == "":
			continue
		if not _cap_effects.has(cap_id):
			_cap_effects[cap_id] = []
		_cap_effects[cap_id].append(e)


func unregister_cap(cap: Dictionary) -> void:
	_cap_effects.erase(str(cap.get("id", cap.get("letter", ""))))


func trigger(hook: String, args: Array) -> void:
	_emit_hook_signal(hook, args)
	for cap_id: String in _cap_effects:
		for effect: Variant in _cap_effects[cap_id]:
			var e: Dictionary = effect
			if str(e.get("hook", "")) != hook:
				continue
			var apply: Callable = e.get("apply", Callable())
			if apply.is_valid():
				match args.size():
					0: apply.call()
					1: apply.call(args[0])
					2: apply.call(args[0], args[1])
					3: apply.call(args[0], args[1], args[2])
					_: push_error("EffectPipeline: too many args (%d)" % args.size())


func _emit_hook_signal(hook: String, args: Array) -> void:
	match hook:
		"on_draw":
			on_draw.emit(args[0])
		"on_letter_slotted":
			on_letter_slotted.emit(args[0], args[1])
		"on_word_validated":
			on_word_validated.emit(args[0], args[1])
		"on_score_calculated":
			on_score_calculated.emit(args[0])
		"on_word_form_evaluated":
			on_word_form_evaluated.emit(args[0], args[1], args[2])
		"on_artisan_triggered":
			on_artisan_triggered.emit(args[0], args[1], args[2])
		"on_shop_opened":
			on_shop_opened.emit()
		"on_bag_mutated":
			on_bag_mutated.emit(args[0], args[1])
		"on_monster_damaged":
			on_monster_damaged.emit(args[0], args[1], args[2])
		"on_monster_defeated":
			on_monster_defeated.emit(args[0], args[1])
		"on_turn_end":
			on_turn_end.emit(args[0])
