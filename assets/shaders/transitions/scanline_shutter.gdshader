shader_type canvas_item;
// Scanline / shutter curtain: interlaced pixel bands (blinds) close in a staggered sweep,
// then open in reverse on fade-in. Orientation is randomized via the `vertical` uniform.
//
// progress = 0.0 -> fully transparent, progress = 1.0 -> fully opaque.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 logical_size = vec2(540.0, 960.0);
uniform float cell_size = 16.0;
uniform bool vertical = false;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 px = floor(UV * logical_size);
	float coord = vertical ? px.x : px.y;
	float extent = vertical ? logical_size.x : logical_size.y;
	float band = floor(coord / cell_size);
	float inner = fract(coord / cell_size); // 0..1 position within the band
	float count = ceil(extent / cell_size);
	// Band k fills between progress thresholds k/count and (k+1)/count (staggered blinds).
	float start = band / count;
	float end = (band + 1.0) / count;
	float fill = clamp((progress - start) / (end - start), 0.0, 1.0);
	// Each band's fill sweeps its own width top-to-bottom, so all bands close by progress 1.
	float cover = step(1.0 - fill, inner);
	if (progress >= 1.0) cover = 1.0;
	if (progress <= 0.0) cover = 0.0;
	COLOR = vec4(transition_color.rgb, transition_color.a * cover);
}