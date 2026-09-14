class_name PixelHPBar
extends TextureProgressBar

@export var segments: int = 20
@export var gap: int = 2
@export var fill_color := Color(0.3, 0.85, 0.35)
@export var warn_color := Color(0.95, 0.8, 0.2)
@export var crit_color := Color(0.95, 0.25, 0.15)
@export var empty_color := Color(0.15, 0.12, 0.18)
@export var border_color := Color(0.04, 0.03, 0.06)


func _ready() -> void:
	texture_progress = null
	texture_under = null
	texture_over = null
	changed.connect(queue_redraw)


func filled_count() -> int:
	if max_value <= 0:
		return 0
	return clampi(roundi(float(value) / float(max_value) * float(segments)), 0, segments)


func _draw() -> void:
	var w := roundi(size.x)
	var h := roundi(size.y)
	if w <= 0 or h <= 0:
		return
	draw_rect(Rect2(0, 0, w, h), border_color, true)
	var inner := Rect2(2, 2, w - 4, h - 4)
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	draw_rect(inner, empty_color, true)
	var filled := filled_count()
	if filled <= 0:
		return
	var col := fill_color
	var ratio := float(value) / float(max_value)
	if ratio <= 0.25:
		col = crit_color
	elif ratio <= 0.55:
		col = warn_color
	var pitch := inner.size.x / float(segments)
	for i in range(filled):
		var x := roundi(inner.position.x + float(i) * pitch)
		var pw := maxi(roundi(pitch) - gap, 2)
		var prect := Rect2(x, inner.position.y, pw, inner.size.y)
		draw_rect(prect, col, true)
		draw_rect(Rect2(prect.position, Vector2(prect.size.x, 1)), col.lightened(0.35), true)