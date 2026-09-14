extends SceneTree

const VIEWPORTS: Array = [
	Vector2i(540, 960),
	Vector2i(800, 960),
	Vector2i(540, 1300),
	Vector2i(700, 1100),
]


func _init() -> void:
	await process_frame
	for vp: Vector2i in VIEWPORTS:
		var ok: bool = await _check_viewport(vp)
		if not ok:
			quit(1)
			return
	print("[verify_banner_layout] ALL VIEWPORTS OK")
	quit(0)


func _check_viewport(vp: Vector2i) -> bool:
	root.size = vp
	var screen: Control = load("res://scenes/CombatScreen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	var visible: Rect2 = root.get_visible_rect()
	var hand: Control = screen.get_node("%HandTileContainer")
	var redraw_btn: Control = screen.get_node("%RedrawButton")
	var play_btn: Control = screen.get_node("%PlayButton")
	var banner: Control = screen.get_node("%PersistentScoringRow")
	var shelf: Control = screen.get_node("%TotalDamageShelf")

	var ok := true
	ok = ok and _assert_within(hand.get_global_rect(), visible, "hand", vp)
	ok = ok and _assert_within(redraw_btn.get_global_rect(), visible, "redraw_btn", vp)
	ok = ok and _assert_within(play_btn.get_global_rect(), visible, "play_btn", vp)
	ok = ok and _assert_within(banner.get_global_rect(), visible, "banner(hidden)", vp)

	banner.show()
	shelf.show()
	await process_frame
	await process_frame
	ok = ok and _assert_within(banner.get_global_rect(), visible, "banner(shown)", vp)
	ok = ok and _assert_within(hand.get_global_rect(), visible, "hand(scoring)", vp)
	ok = ok and _assert_within(redraw_btn.get_global_rect(), visible, "redraw_btn(scoring)", vp)

	screen.queue_free()
	await process_frame
	return ok


func _assert_within(rect: Rect2, bounds: Rect2, label: String, vp: Vector2i) -> bool:
	var eps := 2.0
	var inside: bool = rect.position.x >= bounds.position.x - eps and rect.position.y >= bounds.position.y - eps \
		and rect.end.x <= bounds.end.x + eps and rect.end.y <= bounds.end.y + eps
	print("[verify_banner_layout] vp=%s %s rect=%s within=%s" % [vp, label, rect, inside])
	if not inside:
		print("[verify_banner_layout]   bounds=%s" % bounds)
	return inside