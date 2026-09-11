extends HBoxContainer

signal item_dropped(from_slot: WordRuneSlot, to_pure_index: int)

var insertion_spacer: PanelContainer = null
var active_gap_index: int = -1
var target_gap_width: float = 0.0
var is_drag_active: bool = false

const MAX_GAP_WIDTH: float = 54.0
const INFLUENCE_RADIUS: float = 75.0
const SPRING_SPEED: float = 18.0

func _setup_spacer() -> void:
	if insertion_spacer:
		return
	insertion_spacer = PanelContainer.new()
	insertion_spacer.name = "InsertionSpacer"
	insertion_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insertion_spacer.custom_minimum_size = Vector2(0, 52)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.8, 1.0, 0.10)
	style.border_color = Color(0.0, 1.0, 1.0, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	insertion_spacer.add_theme_stylebox_override("panel", style)
	insertion_spacer.visible = false
	add_child(insertion_spacer)

func get_pure_runes() -> Array:
	var runes: Array = []
	for c in get_children():
		if c is WordRuneSlot:
			runes.append(c)
	return runes

func _process(delta: float) -> void:
	if not insertion_spacer or not insertion_spacer.visible:
		return
	var cur: float = insertion_spacer.custom_minimum_size.x
	var diff: float = target_gap_width - cur
	if absf(diff) > 0.1:
		insertion_spacer.custom_minimum_size.x = cur + diff * minf(SPRING_SPEED * delta, 1.0)
	elif not is_drag_active and cur > 0.0:
		insertion_spacer.custom_minimum_size.x = 0.0

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("source_slot")):
		return false
	_setup_spacer()
	is_drag_active = true
	var dragged: WordRuneSlot = data["source_slot"]
	var runes: Array = get_pure_runes().filter(func(r): return r != dragged)

	if runes.is_empty():
		active_gap_index = 0
		move_child(insertion_spacer, 0)
		target_gap_width = MAX_GAP_WIDTH
		insertion_spacer.visible = true
		return true

	var best_idx: int = 0
	var min_dist: float = 99999.0

	var front_x: float = runes[0].position.x
	var d_front: float = absf(at_position.x - front_x)
	if d_front < min_dist:
		min_dist = d_front
		best_idx = 0

	for i in range(1, runes.size()):
		var prev: Control = runes[i - 1] as Control
		var curr: Control = runes[i] as Control
		var cx: float = (prev.position.x + prev.size.x + curr.position.x) * 0.5
		var d: float = absf(at_position.x - cx)
		if d < min_dist:
			min_dist = d
			best_idx = i

	var last: Control = runes[-1] as Control
	var tail_x: float = last.position.x + last.size.x
	var d_tail: float = absf(at_position.x - tail_x)
	if d_tail < min_dist:
		min_dist = d_tail
		best_idx = runes.size()

	if best_idx != active_gap_index:
		active_gap_index = best_idx
		move_child(insertion_spacer, best_idx)
		insertion_spacer.visible = true

	var nd: float = clampf(min_dist / INFLUENCE_RADIUS, 0.0, 1.0)
	var weight: float = 1.0 - (nd * nd * (3.0 - 2.0 * nd))
	target_gap_width = weight * MAX_GAP_WIDTH
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	is_drag_active = false
	target_gap_width = 0.0
	var source_slot: WordRuneSlot = data["source_slot"]
	var to_idx: int = active_gap_index
	if to_idx < 0:
		to_idx = get_pure_runes().size()
	if insertion_spacer:
		insertion_spacer.queue_free()
		insertion_spacer = null
	item_dropped.emit(source_slot, to_idx)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		is_drag_active = false
		target_gap_width = 0.0
		active_gap_index = -1
		for c in get_children():
			if c is WordRuneSlot:
				c.modulate.a = 1.0
		if insertion_spacer:
			insertion_spacer.queue_free()
			insertion_spacer = null
