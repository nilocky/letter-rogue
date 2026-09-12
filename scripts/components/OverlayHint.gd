extends Control
## Draws a translucent labeled rect. Used by UISandbox to annotate regions.

@export var color: Color = Color(1, 0.3, 0.3, 0.25)
@export var title: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(color.r, color.g, color.b, 1.0), false, 2.0)
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(6, 18), title, \
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 1))