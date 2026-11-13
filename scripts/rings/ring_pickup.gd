## A dirt or topsoil food on the planet (RingFood): the ArenaFood pickup protocol worms already eat
## and carry, drawn in its own shape (seed, root, mushroom, crumb, honeydew, egg, pebble). The face
## goes wide-eyed and trembles when a worm that can eat it comes near; smug when a small one bonks it.
## species != &"": a live body of a population counter (freed when eaten; the counter regrows it).
class_name RingPickup
extends ArenaFood

var species: StringName
## Statically placed: regrows where it was after RingFood.regrow_time planet seconds.
var gone_at := -1.0


func _draw() -> void:
	if data == null:
		return
	var rf := data as RingFood
	var look := rf.look if rf else RingFood.Look.BLOB
	if rf and look == RingFood.Look.BLOB and rf.ring == &"sky":
		look = RingFood.Look.CLOUD
	var accent := rf.accent if rf else data.color.lightened(0.4)
	var r := data.radius
	var o := Vector2(0, sin(_t * 3.0) * 0.6)
	if _scared and not _carried:
		o.x = sin(_t * 40.0) * 0.7
	var face := o
	match look:
		RingFood.Look.SEED:
			_poly_ellipse(o, Vector2(r * 0.8, r) , data.color)
			draw_line(o + Vector2(0, -r), o + Vector2(r * 0.4, -r - 3), Color("6fbf4a"), 1.5)
		RingFood.Look.ROOT:
			draw_line(o + Vector2(-r * 0.2, -r * 1.2), o + Vector2(0, r * 0.2), INK, 4.0)
			draw_line(o + Vector2(-r * 0.2, -r * 1.2), o + Vector2(0, r * 0.2), data.color, 2.0)
			draw_line(o + Vector2(0, r * 0.2), o + Vector2(r * 0.6, r * 1.1), data.color, 1.0)
			draw_line(o + Vector2(0, r * 0.2), o + Vector2(-r * 0.5, r * 1.0), data.color, 1.0)
			draw_circle(o, r * 0.75 + 1.0, INK)
			draw_circle(o, r * 0.75, data.color)
		RingFood.Look.MUSHROOM:
			draw_rect(Rect2(o + Vector2(-r * 0.35, -r * 0.1), Vector2(r * 0.7, r * 1.0)), INK)
			draw_rect(Rect2(o + Vector2(-r * 0.25, -r * 0.1), Vector2(r * 0.5, r * 0.95)), Color("f3e7d0"))
			var cap := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.9))
			draw_colored_polygon(cap, INK)
			cap = PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r, sin(a) * r * 0.78 + 0.5))
			draw_colored_polygon(cap, data.color)
			draw_circle(o + Vector2(-r * 0.4, -r * 0.45), r * 0.16, accent)
			draw_circle(o + Vector2(r * 0.35, -r * 0.3), r * 0.12, accent)
			face = o + Vector2(0, r * 0.45)
		RingFood.Look.CRUMB:
			var pts := PackedVector2Array([o + Vector2(-r, -r * 0.6), o + Vector2(r * 0.9, -r * 0.8), o + Vector2(r, r * 0.7), o + Vector2(-r * 0.8, r * 0.8)])
			draw_colored_polygon(pts, INK)
			draw_colored_polygon(PackedVector2Array([pts[0] * 0.85, pts[1] * 0.85, pts[2] * 0.85, pts[3] * 0.85]), data.color)
			draw_line(pts[0] * 0.85, pts[1] * 0.85, accent, 1.5)
		RingFood.Look.HONEYDEW:
			var glow := 0.5 + 0.5 * sin(_t * 4.0)
			draw_circle(o, r + 3.0 + glow, Color(accent, 0.25))
			_drop(o, r, data.color)
			draw_circle(o + Vector2(-r * 0.3, -r * 0.1), r * 0.2, Color(1, 1, 1, 0.8))
		RingFood.Look.EGG:
			_poly_ellipse(o, Vector2(r * 0.75, r), data.color)
			draw_circle(o + Vector2(r * 0.2, r * 0.3), r * 0.15, accent)
			draw_circle(o + Vector2(-r * 0.3, -r * 0.3), r * 0.12, accent)
		RingFood.Look.CRYSTAL:
			# a cluster of three glowing points
			var glow := 0.5 + 0.5 * sin(_t * 2.5)
			draw_circle(o, r * 1.15 + glow * 2.0, Color(data.color, 0.22))
			for spec in [[-0.55, 0.75, -0.35], [0.0, 1.15, 0.0], [0.55, 0.8, 0.35]]:
				var b := o + Vector2(spec[0] * r, r * 0.55)
				var tip := b + Vector2(0, -spec[1] * r * 1.4).rotated(spec[2])
				var side := Vector2(r * 0.28, 0).rotated(spec[2])
				var pts := PackedVector2Array([b - side, tip, b + side])
				draw_colored_polygon(PackedVector2Array([b - side * 1.4 + Vector2(0, 1), tip + (tip - b).normalized() * 1.5, b + side * 1.4 + Vector2(0, 1)]), INK)
				draw_colored_polygon(pts, data.color)
				draw_line(b, tip, accent, 1.0)
			face = o + Vector2(0, r * 0.2)
		RingFood.Look.GEODE:
			# a split geode: a rough shell, a ring of crystal teeth, a glowing heart
			var glow := 0.5 + 0.5 * sin(_t * 3.0)
			draw_circle(o, r + 3.0 + glow * 2.0, Color(accent, 0.25))
			draw_circle(o, r + 1.0, INK)
			draw_circle(o, r, Color("9a8a7a"))
			draw_circle(o, r * 0.78, data.color)
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				var b := o + Vector2.from_angle(a) * r * 0.78
				draw_colored_polygon(PackedVector2Array([b + Vector2.from_angle(a + 1.6) * r * 0.18, o + Vector2.from_angle(a) * r * 0.42, b + Vector2.from_angle(a - 1.6) * r * 0.18]), accent)
			draw_circle(o, r * 0.3, Color(1, 1, 1, 0.55 + 0.35 * glow))
		RingFood.Look.NUGGET:
			# a lumpy, faceted lump of ore with a glint (placeholder)
			var pts := look_shape(RingFood.Look.NUGGET, r)
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for p in pts:
				outer.append(o + p * (1.0 + 1.2 / r))
				inner.append(o + p)
			draw_colored_polygon(outer, INK)
			draw_colored_polygon(inner, data.color)
			draw_colored_polygon(PackedVector2Array([o + pts[0] * 0.55, o + pts[1] * 0.6, o, o + pts[7] * 0.5]), accent)
			draw_line(o + pts[3] * 0.3, o + pts[4] * 0.75, data.color.darkened(0.3), 1.0)
			var tw := 0.5 + 0.5 * sin(_t * 2.0)
			var g := o + pts[1] * 0.7
			draw_line(g + Vector2(-2.5 * tw, 0), g + Vector2(2.5 * tw, 0), Color.WHITE, 1.0)
			draw_line(g + Vector2(0, -2.5 * tw), g + Vector2(0, 2.5 * tw), Color.WHITE, 1.0)
		RingFood.Look.FOSSIL:
			# a curled shell in the stone: round, ribbed, a spiral in its accent (placeholder)
			draw_circle(o, r + 1.0, INK)
			draw_circle(o, r, data.color)
			var spiral := look_shape(RingFood.Look.FOSSIL, r)
			for i in spiral.size():
				spiral[i] += o
			draw_polyline(spiral, accent, 1.5)
			for i in 10:
				var a := TAU * i / 10.0
				draw_line(o + Vector2.from_angle(a) * r * 0.72, o + Vector2.from_angle(a) * r * 0.95, accent, 1.0)
			face = o + Vector2(0, r * 0.15)
		RingFood.Look.CLOUD:
			# a puffy cloud: five overlapping puffs, a shaded underside, the face in the middle
			var puffs := [Vector3(-0.55, 0.15, 0.5), Vector3(-0.15, -0.2, 0.62), Vector3(0.3, -0.12, 0.55),
					Vector3(0.65, 0.18, 0.42), Vector3(0.05, 0.25, 0.55)]
			for q in puffs:
				draw_circle(o + Vector2(q.x, q.y) * r, q.z * r + 1.5, INK)
			for q in puffs:
				draw_circle(o + Vector2(q.x, q.y + 0.08) * r, q.z * r, accent)
			for q in puffs:
				draw_circle(o + Vector2(q.x, q.y - 0.04) * r, q.z * r * 0.86, data.color)
		RingFood.Look.PLANE:
			# a toy plane: a long body, a wing across it, a tail fin, a spinning propeller
			var body := PackedVector2Array([o + Vector2(-r, -r * 0.18), o + Vector2(r * 0.75, -r * 0.28),
					o + Vector2(r, 0), o + Vector2(r * 0.75, r * 0.28), o + Vector2(-r, r * 0.18)])
			var wing := PackedVector2Array([o + Vector2(-r * 0.1, -r * 0.85), o + Vector2(r * 0.25, -r * 0.85),
					o + Vector2(r * 0.3, r * 0.85), o + Vector2(-r * 0.05, r * 0.85)])
			var fin := PackedVector2Array([o + Vector2(-r, -r * 0.15), o + Vector2(-r * 0.75, -r * 0.15), o + Vector2(-r * 1.05, -r * 0.6)])
			for poly in [wing, fin, body]:
				var ol := PackedVector2Array()
				for q in poly:
					ol.append(o + (q - o) * 1.12)
				draw_colored_polygon(ol, INK)
			draw_colored_polygon(wing, accent)
			draw_colored_polygon(fin, accent)
			draw_colored_polygon(body, data.color)
			var spin := absf(sin(_t * 30.0))
			draw_line(o + Vector2(r * 1.05, -r * 0.5 * spin), o + Vector2(r * 1.05, r * 0.5 * spin), INK, 2.0)
			draw_circle(o + Vector2(r * 1.05, 0), maxf(1.0, r * 0.1), INK)
			face = o + Vector2(r * 0.4, 0)
			r *= 0.6
		_:
			draw_circle(o, r + 1.0, INK)
			draw_circle(o, r, data.color)
			draw_circle(o + Vector2(-r * 0.35, -r * 0.4), maxf(1.0, r * 0.25), accent)
	_face(face, r)


## The outline of a code-drawn look, around (0, 0) at radius r: NUGGET's lumpy 8-point rock,
## FOSSIL's spiral (a polyline from the rim curling in). Empty for the other looks.
static func look_shape(look: RingFood.Look, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	match look:
		RingFood.Look.NUGGET:
			var lumps := [1.0, 0.82, 0.95, 0.75, 0.9, 0.8, 1.0, 0.78]
			for i in 8:
				var a := TAU * i / 8.0 - PI / 2.0 + 0.2
				out.append(Vector2.from_angle(a) * r * lumps[i] * Vector2(1.1, 0.9))
		RingFood.Look.FOSSIL:
			for i in 40:
				var k := float(i) / 39.0
				out.append(Vector2.from_angle(k * TAU * 2.2) * r * lerpf(0.72, 0.08, k))
	return out


func _face(at: Vector2, r: float) -> void:
	var e := maxf(1.0, r * 0.22)
	for sx in [-1.0, 1.0]:
		var c := at + Vector2(sx * r * 0.36, -r * 0.05)
		if _scared or _carried:
			draw_circle(c, e + 1.0, Color.WHITE)
			draw_circle(c, e * 0.5, INK)
		elif _smug > 0.0:
			draw_line(c + Vector2(-e, 0), c + Vector2(e, 0), INK, 1.0)
		else:
			draw_circle(c, e * 0.6, INK)
	if _scared:
		draw_circle(at + Vector2(0, r * 0.35), maxf(1.0, r * 0.15), INK)   # little "o" mouth


func _poly_ellipse(at: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(at + Vector2(cos(a) * (radii.x + 1.0), sin(a) * (radii.y + 1.0)))
		inner.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, INK)
	draw_colored_polygon(inner, col)


func _drop(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var k := 1.0 + 0.5 * maxf(0.0, -sin(a)) * absf(cos(a * 0.5))
		pts.append(at + Vector2(cos(a) * r, sin(a) * r * k - (r * 0.6 if sin(a) < -0.95 else 0.0)))
	draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(at + (p - at) * 0.85)
	draw_colored_polygon(inner, col)
