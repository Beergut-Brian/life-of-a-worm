// Tall Tale grade (look C) for the dock and its cutscenes only, never underground (Docket D92):
// a sun-faded palette (desaturate, lift the blacks to sepia ink, roll the whites to paper), paper
// grain and a soft vignette, as one full-screen pass over what is already drawn.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 ink : source_color = vec3(0.227, 0.141, 0.094);    // #3a2418, C's ink
uniform vec3 paper : source_color = vec3(0.973, 0.925, 0.816);  // #f8ecd0
uniform float fade : hint_range(0.0, 1.0) = 0.35;
uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float grain_px = 3.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.38;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 faded = mix(c, vec3(l), fade * 0.55);
	faded = mix(ink, paper, faded);
	vec2 g = floor(FRAGCOORD.xy / grain_px);
	float n = hash(g) * 0.7 + hash(g * 0.37 + 11.0) * 0.3;
	faded *= 1.0 - grain + grain * 2.0 * n * 0.5 + grain * 0.5;
	vec2 d = SCREEN_UV - 0.5;
	faded = mix(faded, faded * ink * 2.2, clamp(dot(d, d) * 2.4 * vignette, 0.0, 1.0));
	COLOR = vec4(mix(c, faded, strength), 1.0);
}
