shader_type canvas_item;
// Stepped radial wipe: an iris / circle transition with chunky, pixelated stepped edges.
//
// progress = 0.0 -> fully transparent, progress = 1.0 -> fully opaque.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 logical_size = vec2(540.0, 960.0);
uniform float cell_size = 8.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 px = floor(UV * logical_size);
	vec2 center = logical_size * 0.5;
	float d = length(px - center);
	// Quantize the radius so the iris edge reads as chunky retro pixels, not smooth AA.
	float stepped = floor(d / cell_size) * cell_size;
	float max_r = length(logical_size * 0.5) + cell_size;
	float cover = step(stepped, progress * max_r);
	if (progress >= 1.0) cover = 1.0;
	if (progress <= 0.0) cover = 0.0;
	COLOR = vec4(transition_color.rgb, transition_color.a * cover);
}