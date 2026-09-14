shader_type canvas_item;
// Ordered dither dissolve (4x4 Bayer matrix). Pixel clusters progressively turn black
// as `progress` rises; the reverse (fade-in) unwinds the exact same ordered pattern.
//
// progress = 0.0 -> fully transparent (gameplay visible)
// progress = 1.0 -> fully opaque (safe window for the scene swap)

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 logical_size = vec2(540.0, 960.0);
uniform float cell_size = 8.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float bayer_4[16] = float[](
	0.0,  8.0,  2.0, 10.0,
	12.0, 4.0, 14.0,  6.0,
	3.0, 11.0,  1.0,  9.0,
	15.0, 7.0, 13.0,  5.0
);

void fragment() {
	// Pixel coords snapped to the logical resolution so cells stay crisp regardless of stretch.
	vec2 px = floor(UV * logical_size);
	vec2 cell = floor(px / cell_size);
	int idx = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	// +1/16 so the lowest threshold is above 0: progress 0 leaves the screen untouched.
	float threshold = (bayer_4[idx] + 1.0) / 16.0;
	float cover = step(threshold, progress);
	// Hard guarantees at the two endpoints (spec: 0 fully visible, 1 fully opaque).
	if (progress >= 1.0) cover = 1.0;
	if (progress <= 0.0) cover = 0.0;
	COLOR = vec4(transition_color.rgb, transition_color.a * cover);
}