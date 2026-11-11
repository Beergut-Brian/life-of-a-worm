## Placeholder ladybird drawing (red dome, black spots, tiny head, twitchy feelers), shared by the
## wild one, the pet and the tackle-box doodle. Art lane replaces with sprites (assets/proto/burrow/).
class_name LadybirdLook
extends RefCounted

const INK := Color("2a1a14")


## Draws a ladybird centred at c, radius r, facing `dir` (radians), wings open by `flap` (0..1).
static func draw(ci: CanvasItem, c: Vector2, r: float, dir: float, t: float, flap := 0.0, body := Color(0.9, 0.15, 0.12), a := 1.0) -> void:
	var f := Vector2.from_angle(dir)
	var s := f.orthogonal()
	var ink := Color(INK, a)
	if flap > 0.0:
		for k: float in [-1.0, 1.0]:
			var wing := c - f * r * 0.2 + s * k * r * (0.9 + 0.5 * flap)
			ci.draw_circle(wing, r * 0.7, Color(0.85, 0.95, 1.0, 0.45 * a))
	ci.draw_circle(c + f * r * 0.85, r * 0.5, ink)                       # head
	for k: float in [-1.0, 1.0]:                                                 # feelers
		var base := c + f * r * 1.1 + s * k * r * 0.2
		ci.draw_line(base, base + f * r * 0.6 + s * k * r * (0.4 + 0.15 * sin(t * 9.0 + k)), ink, 1.0)
	ci.draw_circle(c, r + 1.0, ink)
	ci.draw_circle(c, r, Color(body, a))
	ci.draw_line(c - f * r, c + f * r * 0.6, ink, 1.0)                   # wing split
	for sp: Vector2 in [Vector2(0.2, 0.45), Vector2(-0.35, 0.4), Vector2(0.2, -0.45), Vector2(-0.35, -0.4)]:
		ci.draw_circle(c + f * r * sp.x + s * r * sp.y, maxf(0.8, r * 0.18), ink)
	ci.draw_circle(c + f * r * 0.3 - s * r * 0.3, maxf(0.6, r * 0.16), Color(1, 1, 1, 0.6 * a))   # shine
