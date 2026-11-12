// Lantern Deep tiles (Docket D92): solid ground darkens away from open air (Terraria-like), read on
// the GPU from the world's overview texture (1 px per 2 tiles, alpha 0 where eaten or outside the
// disk), so a bite lightens the ground round it as soon as the overview uploads. Normal maps come
// from the tile set's CanvasTexture; lights and CanvasModulate do the rest
// (scripts/lighting/lantern.gd). Never black: the deepest ground keeps 1 - max_dark of its colour.
shader_type canvas_item;

uniform sampler2D overview : filter_linear, repeat_disable;
uniform bool has_overview = false;
uniform float radius_tiles = 300.0;
uniform float overview_span = 600.0;   // tiles covered by the overview's width
uniform float cell_size = 16.0;
uniform vec2 world_origin = vec2(0.0);
uniform float near_reach = 3.0;        // tiles
uniform float far_reach = 7.0;         // tiles
uniform float max_dark = 0.5;
uniform vec3 deep_tint : source_color = vec3(0.50, 0.47, 0.62);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin;
}

float solid_at(vec2 cell) {
	vec2 uv = (cell + vec2(radius_tiles)) / overview_span;
	return texture(overview, uv).a;
}

void fragment() {
	vec4 c = COLOR;   // vertex colour x texture
	if (has_overview) {
		vec2 cell = world_pos / cell_size;
		float s = 0.0;
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.7853982 + 0.39;
			vec2 d = vec2(cos(a), sin(a));
			s += solid_at(cell + d * near_reach);
			s += solid_at(cell + d * far_reach);
		}
		s /= 16.0;
		float dark = smoothstep(0.55, 1.0, s) * max_dark;
		c.rgb = mix(c.rgb, c.rgb * deep_tint, dark / max(max_dark, 0.001) * max_dark * 2.0);
	}
	COLOR = c;
}
