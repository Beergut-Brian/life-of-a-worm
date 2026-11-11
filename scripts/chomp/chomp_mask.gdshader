// Eats the planet texture: everything behind a front that sweeps round the disk is gone, and the
// front itself is a column of round bites (scallops) with a dark chewed rim. progress 0..1.
shader_type canvas_item;

uniform float progress = 0.0;
uniform float start_angle = -1.5708;   // top of the disk
uniform float tex_px = 288.0;          // texture size, for pixel-crisp edges
uniform float scallops = 3.0;          // bites stacked along the radius
uniform float bite_depth = 0.45;       // radians a bite reaches past the front
uniform vec4 rim_color : source_color = vec4(0.16, 0.06, 0.05, 1.0);

void fragment() {
	vec2 uv = (floor(UV * tex_px) + 0.5) / tex_px;
	vec2 d = uv - vec2(0.5);
	float r = length(d) * 2.0;
	float a = mod(atan(d.y, d.x) - start_angle, TAU);
	float front = progress * (TAU + bite_depth * 2.0) - bite_depth;
	float s = fract(r * scallops + 0.5 * progress) * 2.0 - 1.0;
	float edge = front + sqrt(max(0.0, 1.0 - s * s)) * bite_depth;
	// the start edge is bitten too, and the last bites wrap round to swallow it
	float s2 = fract(r * scallops * 1.3 + 0.37) * 2.0 - 1.0;
	float start_edge = sqrt(max(0.0, 1.0 - s2 * s2)) * bite_depth * 0.5;
	bool gone = (a > start_edge && a < edge) || (a + TAU < edge);
	bool rim = (a < edge + 0.09) || (a > start_edge - 0.09 && a <= start_edge);
	vec4 c = texture(TEXTURE, uv);
	if (progress > 0.0 && gone) {
		c.a = 0.0;
	} else if (progress > 0.0 && rim && c.a > 0.0) {
		c.rgb = mix(c.rgb, rim_color.rgb, 0.75);
	}
	COLOR = c;
}
