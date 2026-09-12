extends Control
## Debug overlay panel. Parented to the scene tree root by DebugManager.

@onready var state_label: Label = %StateLabel


func _ready() -> void:
	%MenuButton.pressed.connect(func(): DebugManager.route_to("menu"))
	%CombatButton.pressed.connect(func(): DebugManager.route_to("combat"))
	%ShopButton.pressed.connect(func(): DebugManager.route_to("shop"))
	%BossButton.pressed.connect(func(): DebugManager.route_to("boss"))
	%SpeedHalf.pressed.connect(func(): DebugManager.set_time_scale(0.5))
	%SpeedNormal.pressed.connect(func(): DebugManager.set_time_scale(1.0))
	%SpeedDouble.pressed.connect(func(): DebugManager.set_time_scale(2.0))
	%ShotButton.pressed.connect(func(): DebugManager.screenshot())
	%GrantMoney.pressed.connect(func(): DebugManager.inject_state({"money": GameState.money + 50}))
	%TriggerSilence.pressed.connect(func(): DebugManager.trigger_mechanic("silence"))
	%CloseButton.pressed.connect(func(): DebugManager.close_overlay())
	DebugManager.overlay_state_changed.connect(_on_overlay_changed)
	_refresh()


func _on_overlay_changed(open: bool) -> void:
	visible = open
	if open:
		_refresh()


func _refresh() -> void:
	var m: Dictionary = GameState.current_monster
	state_label.text = "R%d  $%d\nTURNS %d  REDRAW %d\n%s" % [
		GameState.round_number, GameState.money,
		GameState.turns_left, GameState.redraws_left,
		str(m.get("name", "?"))
	]