## Placeholder Mole drawing from his look sheet (openjar-characters/characters/mole/look.md): a
## slate pear with no neck, a pointy pink snout with a darker tip, huge pink three-lobed claws, a
## squint (dots only when startled). A soft warm outline round him means friend (never food).
## Art lane swaps in his pixel form traced from the 3D master (A-20).
class_name MoleLook
extends RefCounted

enum Face { SQUINT, HAPPY, SORRY, HOPEFUL, STARTLED }

const FUR := Color("56607a")
const BELLY := Color("8792ac")
const PINK := Color("f2a0a8")
const NOSE := Color("e0607a")
const INK := Color("2a1e2c")
const FRIEND := Color(1.0, 0.93, 0.6, 0.55)


## Draws the Mole standing at `c` (his feet), scale k (1 = about one stage-1 worm tall), facing up.
## bow: 0..1 (the apology), rise: 0..1 (popping out of the wall; below 1 he is partly in it).
static func draw(ci: CanvasItem, c: Vector2, k: float, face: int, t: float, bow := 0.0, rise := 1.0, a := 1.0) -> void:
	var h := 22.0 * k * rise
	if h <= 0.5:
		return
	var tip := c + Vector2(bow * 8.0 * k, -h)
	var body := PackedVector2Array()
	for j in 24:
		var ang := TAU * j / 24.0
		var w := 9.0 * k * (0.7 + 0.3 * (0.5 + 0.5 * sin(ang)))   # wider low down: a pear
		body.append(c.lerp(tip, 0.5 - 0.5 * sin(ang) * 0.95) + Vector2(cos(ang) * w, 0))
	# Friend outline: soft and warm, pulsing gently.
	var glow := 2.0 + 0.8 * sin(t * 2.0)
	var outline := PackedVector2Array()
	for p in body:
		outline.append(p + (p - c.lerp(tip, 0.5)).normalized() * glow)
	ci.draw_colored_polygon(outline, Color(FRIEND, FRIEND.a * a))
	ci.draw_colored_polygon(body, Color(FUR, a))
	var bp := PackedVector2Array()
	for p in body:
		bp.append(p)
	bp.append(body[0])
	ci.draw_polyline(bp, Color(INK, a), maxf(1.0, k * 0.6))
	# Belly oval.
	ci.draw_circle(c.lerp(tip, 0.3), 5.0 * k, Color(BELLY, a))
	# Snout: a pink point on top, darker tip.
	var head := c.lerp(tip, 0.82)
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-3.0 * k, 0), tip + Vector2(0, -3.0 * k), head + Vector2(3.0 * k, 0)]), Color(PINK, a))
	ci.draw_circle(tip + Vector2(0, -3.0 * k), 1.3 * k, Color(NOSE, a))
	# Eyes.
	var ey := c.lerp(tip, 0.7)
	for sx: float in [-1.0, 1.0]:
		var e := ey + Vector2(sx * 3.2 * k, 0)
		match face:
			Face.STARTLED:
				ci.draw_circle(e, 0.9 * k, Color(INK, a))
			Face.HAPPY:
				ci.draw_arc(e + Vector2(0, 0.6 * k), 1.4 * k, PI, TAU, 6, Color(INK, a), maxf(1.0, k * 0.5))
			Face.SORRY:
				ci.draw_line(e + Vector2(-1.5 * k, -0.6 * k * sx), e + Vector2(1.5 * k, 0.6 * k * sx), Color(INK, a), maxf(1.0, k * 0.5))
			_:
				ci.draw_line(e + Vector2(-1.5 * k, 0), e + Vector2(1.5 * k, 0), Color(INK, a), maxf(1.0, k * 0.5))
	if face == Face.HOPEFUL or face == Face.HAPPY:
		ci.draw_arc(ey + Vector2(0, 3.0 * k), 2.0 * k, 0.2, PI - 0.2, 6, Color(INK, a), maxf(1.0, k * 0.4))
	# Claws: huge, pink, three lobes, out at his sides (wave a little).
	for sx: float in [-1.0, 1.0]:
		var cl := c.lerp(tip, 0.45) + Vector2(sx * (10.5 * k), sin(t * 3.0 + sx) * k)
		for l in 3:
			ci.draw_circle(cl + Vector2(sx * 1.2 * k, (l - 1) * 2.4 * k), 1.9 * k, Color(PINK, a))
		ci.draw_circle(cl, 2.6 * k, Color(PINK, a))
	# Feet peeking out.
	for sx: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * 4.0 * k, -0.5 * k), 1.8 * k, Color(PINK, a))
