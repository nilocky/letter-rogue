extends Node
## Two-phase retro pixel-art screen transition. A persistent overlay on CanvasLayer 128
## carries a ShaderMaterial; each phase animates that material's `progress` uniform.
## The fade-in unwinds the exact same shader pattern that faded the old screen out.
##
## No-flash guarantee: at progress 1.0 the overlay is fully opaque, and the old screen is
## freed / the new screen added while progress stays at 1.0. Both phases explicitly reset
## progress before tweening, so no leftover frame state leaks into a new transition.
## Stutter protection: play_in awaits a frame so the new screen's heavy _ready finishes
## before the reveal tween starts (kills the first-delta jump).
##
## All style shaders are preloaded at script load (this script is preloaded by game_root at
## boot), so they are parsed at startup, not on the first transition.

const OUT_DURATION: float = 0.45
const IN_DURATION: float = 0.45
const OVERLAY_LAYER: int = 128

const BAYER_SHADER := preload("res://assets/shaders/transitions/bayer_dither.gdshader")
const PIXELATE_SHADER := preload("res://assets/shaders/transitions/pixelate_darken.gdshader")
const DIAMOND_SHADER := preload("res://assets/shaders/transitions/diamond_grid.gdshader")
const SCANLINE_SHADER := preload("res://assets/shaders/transitions/scanline_shutter.gdshader")
const RADIAL_SHADER := preload("res://assets/shaders/transitions/radial_wipe.gdshader")

static var _pool: Array[Shader] = [
	BAYER_SHADER,
	PIXELATE_SHADER,
	DIAMOND_SHADER,
	SCANLINE_SHADER,
	RADIAL_SHADER,
]

static var _overlay: CanvasLayer = null
static var _overlay_rect: ColorRect = null
static var _material: ShaderMaterial = null
static var _active_tween: Tween = null


static func play_out(screen: Control) -> void:
	if _get_overlay():
		# Overlay was just created and is entering the tree this frame.
		await _wait_frames(1)
	# Pick a style for this transition; both phases share it so the reveal unwinds the cover.
	var shader: Shader = random_style()
	_material.shader = shader
	_material.set_shader_parameter("progress", 0.0)
	if shader == SCANLINE_SHADER:
		_material.set_shader_parameter("vertical", randi() % 2 == 0)
	# Explicit reset: never inherit the overlay rect state from a previous transition.
	_overlay_rect.position = Vector2.ZERO
	_overlay_rect.size = _viewport_size(screen)
	var tween := _new_tween(screen)
	tween.tween_property(_material, "shader_parameter/progress", 1.0, OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


static func play_in(screen: Control) -> void:
	if _get_overlay():
		await _wait_frames(1)
	# First screen (no preceding play_out) still needs a style for its reveal wipe.
	if _material.shader == null:
		_material.shader = random_style()
	# The overlay is opaque (progress left at 1.0); the scene swap happened unseen.
	_material.set_shader_parameter("progress", 1.0)
	_overlay_rect.position = Vector2.ZERO
	_overlay_rect.size = _viewport_size(screen)
	# Wait a frame so the new screen finishes its first layout pass before the reveal
	# tween starts; otherwise heavy _ready work inflates the tween's first delta.
	await _wait_frames(1)
	var tween := _new_tween(screen)
	tween.tween_property(_material, "shader_parameter/progress", 0.0, IN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


static func random_style() -> Shader:
	return _pool[randi() % _pool.size()]


static func _get_overlay() -> bool:
	# Returns true if the overlay was just created and needs a frame to enter the tree.
	if _overlay != null and is_instance_valid(_overlay):
		return false
	var canvas := CanvasLayer.new()
	canvas.layer = OVERLAY_LAYER
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	rect.material = material
	canvas.add_child(rect)
	_overlay = canvas
	_overlay_rect = rect
	_material = material
	var tree := Engine.get_main_loop() as SceneTree
	# Deferred add: transitions can be requested from a node's _ready(), when the root
	# window is still busy setting up children and rejects a direct add_child().
	tree.root.add_child.call_deferred(canvas)
	return true


static func _new_tween(screen: Control) -> Tween:
	# Kill any leftover transition tween before starting a new one so a stray tween can
	# never fight the current animation.
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = screen.create_tween()
	return _active_tween


static func _viewport_size(screen: Control) -> Vector2:
	return screen.get_viewport_rect().size


static func _wait_frames(count: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in count:
		await tree.process_frame