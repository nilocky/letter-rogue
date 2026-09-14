class_name ScreenShake
## Static screen shake utility. Shakes a node's position for `duration` seconds.

static func shake(node: Node, magnitude: float, duration: float) -> void:
	var orig: Vector2 = node.position
	var tw := node.create_tween()
	var steps := maxi(ceili(duration / 0.05), 4)
	for _i in range(steps):
		var offset := Vector2(
			randf_range(-magnitude, magnitude),
			randf_range(-magnitude * 0.6, magnitude * 0.6)
		)
		tw.tween_callback(node.set_position.bind(orig + offset))
		tw.tween_interval(duration / float(steps))
	tw.tween_callback(node.set_position.bind(orig))
