extends SceneTree

const TEST_DIR := "res://tests/"
const TEST_SCRIPTS := [
	"lexicon_test.gd",
	"word_test.gd",
	"monster_modifier_test.gd",
	"scenario_test.gd",
]

func _init() -> void:
	await process_frame
	var godot_path: String = OS.get_executable_path()
	var total := 0
	var passed := 0
	for fname: String in TEST_SCRIPTS:
		var path := TEST_DIR + fname
		print("[test] == ", fname, " ==")
		var args: PackedStringArray = ["--headless", "--quit-after", "60", "-s", path]
		var output: Array = []
		var exit_code: int = OS.execute(godot_path, args, output, true)
		total += 1
		if exit_code == 0:
			passed += 1
		else:
			print("[test] FAIL ", fname, " (exit ", exit_code, ")")
		for line: String in output:
			if line.strip_edges() != "":
				print("  ", line)
	print("[test] %d/%d suites passed" % [passed, total])
	quit(1 if passed < total else 0)
