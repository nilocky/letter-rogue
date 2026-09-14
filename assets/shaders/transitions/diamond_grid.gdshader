shader_type canvas_item;
// Diamond grid / tile wipe: a grid of pixelated diamond shapes expand from their centers to
// cover the viewport, and shrink to reveal on fade-in.
//
// progress = 0.0 -> fully transparent, progress = 1.0 -> fully opaque.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 logical_size = vec2(540.0, 960.0);
uniform float cell_size = 24.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 px = floor(UV * logical_size);
	vec2 cell = floor(px / cell_size);
	vec2 center = (cell + 0.5) * cell_size;
	// Manhattan distance: diamond (rotated square) metric. Max within a cell = cell_size.
	float d = abs(px.x - center.x) + abs(px.y - center.y);
	// +2.0 smoothing so the exact-center pixel at progress 0 stays uncovered.
	float cover = smoothstep(progress * cell_size, progress * cell_size + 2.0, d);
	if (progress >= 1.0) cover = 1.0;
	if (progress <= 0.0) cover = 0.0;
	COLOR = vec4(transition_color.rgb, transition_color.a * cover);
}