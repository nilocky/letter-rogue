extends Control
## Standalone debug gallery for safe-area, touch-target, and mouse-filter layout.

@onready var hit_log: Label = %HitLog
@onready var touch_layer: Control = %TouchLayer


func _ready() -> void:
	_populate_touch_grid()
	%ToggleTouch.pressed.connect(func(): touch_layer.visible = not touch_layer.visible)
	%StopBox.gui_input.connect(_on_box_gui.bind("STOP"))
	%PassBox.gui_input.connect(_on_box_gui.bind("PASS"))
	%IgnoreBox.gui_input.connect(_on_box_gui.bind("IGNORE"))


func _populate_touch_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 10
	grid.name = "TouchGrid"
	for i in range(40):
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(48, 48)
		rect.size = Vector2(48, 48)
		rect.color = Color(0.3, 0.8, 0.3, 0.3)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(rect)
	touch_layer.add_child(grid)


func _on_box_gui(event: InputEvent, tag: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		hit_log.text = "clicked: " + tag
