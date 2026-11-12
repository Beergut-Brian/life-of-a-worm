// Three parallax layers behind the ground (look B): far dark, roots and stones, deep soil
// silhouettes, coloured per ring. Drawn on a screen-sized quad behind the tiles in the world canvas
// (lit by the same lights and ambient). Parallax in polar terms: each layer slides around the disk
// and in depth at its own share of the camera's movement, so it always curves with the rings.
shader_type canvas_item;

uniform sampler2D layers : filter_nearest, repeat_enable;   // R near, G mid, B far
uniform vec2 origin;          // planet centre, global
uniform float surface_r;      // px
uniform float cam_angle;
uniform float cam_depth;      // px below the surface
uniform float around = 96.0;  // pattern repeats this many times around the disk
uniform vec4 bounds;          // outer edge (px) of core, rock, dirt, topsoil
uniform vec3 cols[25];        // per ring (core, rock, dirt, topsoil, surface): far_dark, far_light, mid, near, near_edge

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origin;
}

int ring_at(float r) {
	if (r < bounds.x) return 0;
	if (r < bounds.y) return 1;
	if (r < bounds.z) return 2;
	if (r < bounds.w) return 3;
	return 4;
}

vec2 uv_for(float ang, float depth, float f, float scale) {
	float u = (ang - cam_angle * (1.0 - f)) / 6.28318 * around;
	float v = (depth - cam_depth * (1.0 - f)) / 256.0;
	return vec2(u, v) * scale;
}

void fragment() {
	vec2 p = floor(wp) + 0.5;
	float r = length(p);
	if (r > surface_r) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float depth = surface_r - r;
	// dithered ring boundary
	float jit = fract(sin(dot(floor(p / 2.0), vec2(12.9898, 78.233))) * 43758.5453) * 12.0 - 6.0;
	int ri = ring_at(r + jit) * 5;
	float far = texture(layers, uv_for(ang, depth, 0.35, 0.5)).b;
	vec3 col = mix(cols[ri], cols[ri + 1], step(0.5, far) * 0.5 + step(0.72, far) * 0.5);
	float mid = texture(layers, uv_for(ang, depth, 0.55, 1.0)).g;
	if (mid > 0.5) {
		col = mid > 0.9 ? cols[ri + 2] : cols[ri + 2] * 0.8;
	}
	float near = texture(layers, uv_for(ang, depth, 0.75, 1.3) + vec2(0.37, 0.11)).r;
	if (near > 0.5) {
		col = near > 0.9 ? cols[ri + 3] : cols[ri + 4];
	}
	COLOR = vec4(col, 1.0);
}
