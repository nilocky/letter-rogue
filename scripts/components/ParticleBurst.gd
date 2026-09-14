class_name ParticleBurst
## One-shot CPU particle burst, spawned in code and self-freed.
## Usage: ParticleBurst.burst(parent, global_pos, color, amount, opts)

static var _pixel_tex: ImageTexture = null


static func burst(parent: Node, global_pos: Vector2, color: Color, amount: int = 16, opts: Dictionary = {}) -> void:
	var p := CPUParticles2D.new()
	p.texture = _pixel_texture()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = maxi(amount, 1)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = float(opts.get("lifetime", 0.6))
	p.direction = Vector2.UP
	p.spread = float(opts.get("spread", 180.0))
	p.initial_velocity_min = float(opts.get("vel_min", 120.0))
	p.initial_velocity_max = float(opts.get("vel_max", 240.0))
	p.gravity = opts.get("gravity", Vector2(0, 420))
	p.scale_amount_min = float(opts.get("scale_min", 2.0))
	p.scale_amount_max = float(opts.get("scale_max", 4.0))
	p.color = color
	p.z_index = 200
	p.global_position = global_pos
	parent.add_child(p)
	p.emitting = true
	var tween := p.create_tween()
	tween.tween_interval(p.lifetime + 0.3)
	tween.tween_callback(p.queue_free)


static func _pixel_texture() -> ImageTexture:
	if _pixel_tex:
		return _pixel_tex
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for y in range(6):
		for x in range(6):
			var edge := x == 0 or y == 0 or x == 5 or y == 5
			img.set_pixel(x, y, Color(1, 1, 1, 1) if not edge else Color(0.7, 0.7, 0.7, 1))
	_pixel_tex = ImageTexture.create_from_image(img)
	return _pixel_tex