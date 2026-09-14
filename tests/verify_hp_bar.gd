extends SceneTree

func _init() -> void:
	await process_frame
	var hp_script: GDScript = load("res://scripts/components/PixelHPBar.gd")
	if hp_script == null:
		print("FAIL: PixelHPBar.gd did not load")
		quit(1)
		return
	var bar: TextureProgressBar = hp_script.new()
	bar.segments = 20
	bar.max_value = 100
	bar.value = 100
	var checks: Array[Array] = [
		[100, 20],
		[50, 10],
		[37, 7],
		[25, 5],
		[0, 0],
		[999, 20],
	]
	for c: Array in checks:
		bar.value = c[0]
		if bar.filled_count() != c[1]:
			print("FAIL: value=", c[0], " expected ", c[1], " got ", bar.filled_count())
			quit(1)
			return
	bar.max_value = 0
	if bar.filled_count() != 0:
		print("FAIL: max_value=0 should return 0, got ", bar.filled_count())
		quit(1)
		return
	bar.free()
	print("verify_hp_bar: PASS")
	quit(0)