## The cap on every Glow shimmer (D-06 seams, secret halls): a shimmer colour is always light
## (luminance at least MIN_LUMA, so blending it over the rock can only brighten it, never darken a
## ring) and never fully opaque (alpha at most MAX_ALPHA, so the dirt under it still shows).
## Every shimmer draw goes through tint().
class_name GlowCap
extends RefCounted

const MIN_LUMA := 0.55
const MAX_ALPHA := 0.8


static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## `base` lightened until it is at least MIN_LUMA, with alpha clamped to 0..MAX_ALPHA.
static func tint(base: Color, alpha: float) -> Color:
	var c := Color(base.r, base.g, base.b, 1.0)
	var k := 0.0
	while luma(c) < MIN_LUMA and k < 1.0:
		k += 0.05
		c = Color(base.r, base.g, base.b).lerp(Color.WHITE, k)
	c.a = clampf(alpha, 0.0, MAX_ALPHA)
	return c
