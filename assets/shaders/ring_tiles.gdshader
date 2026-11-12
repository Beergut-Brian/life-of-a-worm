// Ring tiles (look B, D92): every solid tile of the disk. The TileSet's atlas (tile_masks.png) is an
// autotile mask, not the picture: R = material, G = edge code | open sides << 3, B = grass shade,
// A = 0 cut away (rounded corners, gaps between grass blades). The picture comes from the
// material's seamless 128 px texture sampled in world space, so neighbouring tiles always join and
// the ground never repeats on a 16 px grid. Lit by Light2D through the material's normal map.
shader_type canvas_item;

uniform sampler2D mats : filter_nearest, repeat_disable;
uniform sampler2D mats_n : filter_nearest, repeat_disable;
uniform float mat_size = 128.0;
uniform float mat_count = 15.0;
uniform vec3 ink : source_color = vec3(0.07, 0.047, 0.063);
uniform vec3 grass_dark : source_color = vec3(0.17, 0.29, 0.17);
uniform vec3 grass_mid : source_color = vec3(0.25, 0.38, 0.21);
uniform vec3 grass_tip : source_color = vec3(0.45, 0.54, 0.27);
// Rain: soil within wet_depth px of the surface (radius surface_r) darkens; the front is ragged.
uniform float wet = 0.0;
uniform float wet_depth = 0.0;
uniform float surface_r = 4800.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a < 0.5) {
		discard;
	}
	int mat = int(m.r * 255.0 + 0.5);
	int g = int(m.g * 255.0 + 0.5);
	int code = g & 7;
	int open = g >> 3;
	int grass = int(m.b * 255.0 + 0.5);
	vec2 px = floor(local);
	vec2 wp = mod(px, mat_size);
	vec2 auv = (vec2(float(mat) * mat_size, 0.0) + wp + 0.5) / vec2(mat_size * mat_count, mat_size);
	vec3 col = texture(mats, auv).rgb;
	vec3 n = texture(mats_n, auv).rgb * 2.0 - 1.0;
	// Bevel toward open sides: the lip catches light from the tunnel.
	vec2 tilt = vec2(0.0);
	if ((open & 1) != 0) { tilt.y += 0.6; }
	if ((open & 2) != 0) { tilt.x += 0.6; }
	if ((open & 4) != 0) { tilt.y -= 0.6; }
	if ((open & 8) != 0) { tilt.x -= 0.6; }
	if (grass > 0) {
		col = grass == 3 ? grass_tip : (grass == 2 ? grass_mid : grass_dark);
		n = vec3(tilt * 0.5, 1.0);
	} else if (code == 1) {
		col = ink;
		n = vec3(0.0, 0.0, 1.0);
	} else if (code == 2) {
		col = min(col * 1.22 + 0.03, vec3(1.0));
		n = vec3(tilt, 1.0);
	} else if (code >= 3) {
		col *= 1.0 - 0.07 * float(code - 2);
	}
	if (wet > 0.0) {
		float depth = surface_r - length(local);
		float front = wet_depth - hash(px) * 10.0;
		if (depth < front) {
			col = col * vec3(0.66, 0.68, 0.74) * wet + col * (1.0 - wet);
		}
	}
	COLOR = vec4(col, 1.0);
	NORMAL = normalize(n);
}
