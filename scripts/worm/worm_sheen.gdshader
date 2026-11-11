// Sheen: a bright glint that travels down the worm. Strength = the `sheen` stat.
shader_type canvas_item;

uniform float sheen = 0.0;
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float w = fract((world_pos.x + world_pos.y * 0.6) / 90.0 - TIME * 0.9);
	float band = smoothstep(0.12, 0.0, abs(w - 0.5));
	float spark = step(0.97, fract(sin(dot(floor(world_pos / 2.0), vec2(12.9898, 78.233))) * 43758.5453 + TIME * 0.5));
	c.rgb = mix(c.rgb, vec3(1.0), clamp(sheen * (band * 0.55 + spark * 0.5 + 0.08), 0.0, 1.0) * c.a);
	COLOR = c;
}
