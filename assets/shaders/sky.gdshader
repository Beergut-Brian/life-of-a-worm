// The sky above the topsoil (look B): a banded gradient from horizon to high sky that follows the
// day/night colours, far hills and near hills that slide at their own parallax around the disk,
// drifting clouds, stars at night and a grey veil in the rain. Drawn on a screen-sized quad in a
// CanvasLayer below the world that follows the camera (so the world's ambient never darkens it).
shader_type canvas_item;

uniform sampler2D clouds : filter_nearest, repeat_enable;
uniform vec2 origin;
uniform float surface_r;
uniform float cam_angle;
uniform vec3 top : source_color = vec3(0.18, 0.37, 0.59);
uniform vec3 horizon : source_color = vec3(0.78, 0.89, 0.95);
uniform vec3 hill_far : source_color = vec3(0.36, 0.52, 0.56);
uniform vec3 hill_near : source_color = vec3(0.22, 0.36, 0.3);
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float time = 0.0;

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origin;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hills(float a, float seed) {
	return sin(a * 23.0 + seed) * 0.5 + sin(a * 57.0 + seed * 2.1) * 0.3 + sin(a * 131.0 + seed * 0.7) * 0.2;
}

void fragment() {
	vec2 p = floor(wp / 2.0) * 2.0 + 1.0;   // 2 px sky pixels
	float r = length(p);
	float alt = r - surface_r;
	float ang = atan(p.y, p.x);
	// banded gradient (8 bands with an ordered-dither seam between them)
	float h = clamp(alt / 900.0, 0.0, 1.0);
	float bayer = mod(floor(p.x / 2.0) + floor(p.y / 2.0) * 2.0, 4.0) / 4.0;
	float hb = floor(h * 8.0 + bayer * 0.9) / 8.0;
	vec3 col = mix(horizon, top, smoothstep(0.0, 1.0, hb));
	// stars
	if (night > 0.01) {
		vec2 sp = floor(vec2(ang * surface_r, alt) / 3.0);
		float s = hash(sp);
		if (s > 0.996 && alt > 60.0) {
			col = mix(col, vec3(1.0, 0.97, 0.85), night * (0.6 + 0.4 * sin(time * 2.0 + s * 90.0)));
		}
	}
	// clouds: a strip at 120..300 px up, drifting, at 0.3 parallax
	float ca = ang - cam_angle * 0.7;
	vec2 cuv = vec2(ca / 6.28318 * 18.0 + time * 0.004, 1.0 - (alt - 140.0) / 192.0);
	if (cuv.y > 0.0 && cuv.y < 1.0) {
		vec4 c = texture(clouds, cuv);
		vec3 cc = mix(c.rgb, horizon, 0.25) * mix(1.0, 0.45, night);
		col = mix(col, cc, c.a * (1.0 - 0.4 * rain));
	}
	// far and near hills on the horizon, each at its own parallax
	float far_h = 26.0 + 18.0 * hills(ang - cam_angle * 0.6, 1.3);
	float near_h = 12.0 + 10.0 * hills(ang - cam_angle * 0.3, 4.1);
	if (alt < far_h) {
		col = mix(hill_far, horizon, 0.25);
	}
	if (alt < near_h) {
		col = hill_near;
	}
	col = mix(col, vec3(0.45, 0.48, 0.52) * (1.0 - night * 0.6), rain * 0.45);
	COLOR = vec4(col, 1.0);
}
