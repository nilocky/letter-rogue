shader_type canvas_item;
// Pixelate & darken: the viewport steps down through chunky block sizes (1 -> 2 -> 4 -> 8 ->
// 16 -> 32) while each block fills from its center toward black, then refines into the new
// screen on fade-in (same pattern unwound).
//
// progress = 0.0 -> fully transparent, progress = 1.0 -> fully opaque.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 logical_size = vec2(540.0, 960.0);
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 px = floor(UV * logical_size);
	const float steps = 6.0;
	float p = progress * steps;
	float level = clamp(floor(p), 0.0, steps - 1.0);
	float fill = p - level; // 0..1 progress inside the current block level
	float block = exp2(level); // 1, 2, 4, 8, 16, 32
	vec2 c = floor(px / block);
	vec2 center = (c + 0.5) * block;
	float d = length(px - center) / block; // 0 at block center, ~0.71 at corners
	// radius 0.01 at fill 0 keeps progress 0 fully clean; 0.72 at fill 1 covers every corner.
	float radius = mix(0.01, 0.72, fill);
	float cover = smoothstep(radius, radius + 0.02, d);
	if (progress >= 1.0) cover = 1.0;
	if (progress <= 0.0) cover = 0.0;
	COLOR = vec4(transition_color.rgb, transition_color.a * cover);
}