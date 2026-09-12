extends Control

@onready var title: Label = %Title
@onready var receipt: VBoxContainer = %Receipt
@onready var total_label: Label = %TotalLabel
@onready var continue_button: Button = %ContinueButton

var _summary: Dictionary = {}
var _total: int = 0
var _animated_total: int = 0
var _pending_loot: Array = []


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)


func open(summary: Dictionary) -> void:
	_summary = summary
	_total = int(summary.get("total", 0))
	var is_boss: bool = bool(summary.get("is_boss", false))
	title.text = "GAME COMPLETE" if is_boss else "ROUND WON"
	continue_button.text = "BACK TO MENU" if is_boss else "CONTINUE TO SHOP"

	var base: int = int(summary.get("base_reward", 0))
	var leftover: int = int(summary.get("leftover_turns", 0))
	var ability: int = int(summary.get("ability_money", 0))

	_add_receipt_line("Base Reward", base)
	if leftover > 0:
		_add_receipt_line("Leftover Turns (+$1/turn)", leftover)
	if ability > 0:
		_add_receipt_line("Abilities", ability)
	if summary.has("loot"):
		_pending_loot = summary["loot"]
		for drop: Variant in _pending_loot:
			var d: Dictionary = drop
			_add_receipt_line(str(d.get("label", "Drop")), int(d.get("value", 0)))
	if is_boss:
		var cleared := Label.new()
		cleared.theme_type_variation = &"BodyLabel"
		cleared.text = "You cleared all rounds!"
		receipt.add_child(cleared)

	total_label.text = "TOTAL CASH: +$0"
	_animate_total()


func _add_receipt_line(label: String, amount: int) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.theme_type_variation = &"BodyLabel"
	lbl.text = label
	lbl.size_flags_horizontal = 3
	var val := Label.new()
	val.theme_type_variation = &"BodyLabel"
	val.text = "+$%d" % amount
	row.add_child(lbl)
	row.add_child(val)
	receipt.add_child(row)


func _animate_total() -> void:
	var tw := create_tween()
	_animated_total = 0
	tw.tween_method(_on_total_tick, 0.0, float(_total), 1.5).set_ease(Tween.EASE_OUT)
	await tw.finished
	_animated_total = _total
	total_label.text = "TOTAL CASH: +$%d" % _total


func _on_total_tick(value: float) -> void:
	var tick: int = roundi(value)
	if tick != _animated_total:
		_animated_total = tick
		total_label.text = "TOTAL CASH: +$%d" % tick


func _on_continue() -> void:
	GameState.money += _total
	for drop: Variant in _pending_loot:
		var d: Dictionary = drop
		if d.get("type", "") == "money":
			GameState.money += int(d.get("value", 0))
	if bool(_summary.get("is_boss", false)):
		EventBus.game_complete.emit()
	else:
		EventBus.shop_requested.emit()
