## Placeholder pet drawings, one per PetData.look, shared by the wild one, the pet and the meet
## bubble's picture (&"pet:<look>"). PLACEHOLDER: drawn in code until the round-two art is picked.
##  - &"ladybird": LadybirdLook (red dome, black spots).
##  - &"glowworm": a soft five-bump grub with a big lit tail bulb and a sleepy smile.
##  - &"ant_crew": three small ants in a row, the lead one carrying a crumb.
class_name PetLook
extends RefCounted

const INK := Color("2a1a14")


## Draws pet `look` centred at c (radius r) facing dir. `flap` opens ladybird wings; `glow` 0..1
## lights a glow-worm's bulb; `wiggle` 0..1 bends a glow-worm or bobs the ants (a job beat).
static func draw(ci: CanvasItem, look: StringName, c: Vector2, r: float, dir: float, t: float,
		flap := 0.0, body := Color.WHITE, a := 1.0, glow := 0.0, wiggle := 0.0) -> void:
	match look:
		&"glowworm":
			glowworm(ci, c, r, dir, t, body, a, glow, wiggle)
		&"ant_crew":
			ant_crew(ci, c, r, dir, t, body, a, wiggle)
		_:
			LadybirdLook.draw(ci, c, r, dir, t, flap, body, a)


static func glowworm(ci: CanvasItem, c: Vector2, r: float, dir: float, t: float, body: Color,
		a := 1.0, glow := 0.0, wiggle := 0.0) -> void:
	var f := Vector2.from_angle(dir)
	var s := f.orthogonal()
	var ink := Color(INK, a)
	var bulb := c - f * r * 1.5
	if glow > 0.0:   # the lamp: a soft halo round the tail bulb
		for k in 4:
			ci.draw_circle(bulb, r * (3.2 - k * 0.6), Color(1.0, 0.95, 0.5, 0.07 * glow * a))
	var pts: Array[Vector2] = []
	for i in 5:
		var u := float(i) / 4.0
		var bend := sin(t * 2.0 + u * 4.0) * 0.12 + sin(t * 14.0 + u * 6.0) * 0.35 * wiggle
		pts.append(c + f * r * (1.0 - u * 2.2) + s * r * bend)
	for i in range(pts.size() - 1, -1, -1):
		var rr := r * (0.62 - 0.05 * i)
		ci.draw_circle(pts[i], rr + 1.0, ink)
		ci.draw_circle(pts[i], rr, Color(body, a))
	var lit := Color(1.0, 0.98, 0.6, a).lerp(Color(0.75, 0.78, 0.45, a), 1.0 - glow)
	ci.draw_circle(bulb, r * 0.55 + 1.0, ink)
	ci.draw_circle(bulb, r * 0.55, lit)
	ci.draw_circle(bulb - s * r * 0.15 + f * r * 0.15, r * 0.18, Color(1, 1, 1, (0.4 + 0.5 * glow) * a))
	var head := pts[0]
	for k: float in [-1.0, 1.0]:   # closed happy eyes
		var e := head + f * r * 0.2 + s * k * r * 0.25
		ci.draw_arc(e, r * 0.14, PI + dir, TAU + dir, 6, ink, 1.0)


static func ant_crew(ci: CanvasItem, c: Vector2, r: float, dir: float, t: float, body: Color,
		a := 1.0, wiggle := 0.0) -> void:
	var f := Vector2.from_angle(dir)
	var s := f.orthogonal()
	var ink := Color(INK, a)
	for i in 3:
		var p := c + f * r * (1.2 - i * 1.3) + s * sin(t * 6.0 + i * 2.0) * r * 0.1
		p += s * absf(sin(t * 12.0 + i)) * r * 0.25 * wiggle
		var u := r * 0.32
		for k: float in [-1.0, 1.0]:   # legs, scuttling
			for j: float in [-1.0, 0.0, 1.0]:
				var base := p + f * u * j * 0.9
				ci.draw_line(base, base + s * k * u * 1.6 + f * u * sin(t * 18.0 + j + i) * 0.6, ink, 1.0)
		ci.draw_circle(p - f * u * 1.4, u * 1.05, Color(body, a))   # abdomen
		ci.draw_circle(p, u * 0.7, Color(body, a))                   # thorax
		ci.draw_circle(p + f * u * 1.25, u * 0.85, Color(body, a))  # head
		for k: float in [-1.0, 1.0]:
			var fb := p + f * u * 1.8 + s * k * u * 0.4
			ci.draw_line(fb, fb + f * u * 1.0 + s * k * u * 0.8, ink, 1.0)
		ci.draw_circle(p + f * u * 1.45 + s * u * 0.35, maxf(0.6, u * 0.22), Color(1, 1, 1, 0.8 * a))
		if i == 0:   # the lead ant's crumb
			ci.draw_circle(p + f * u * 2.6, u * 0.8, Color(0.95, 0.85, 0.55, a))


## The meet bubble's pictures: &"pet:<look>" draws the pet, &"job:<job>" its job.
static func register_pictures() -> void:
	PictoBubble.register_prefix("pet:", _pet_pic)
	PictoBubble.register_prefix("job:", _job_pic)


static func _pet_pic(ci: CanvasItem, id: StringName, c: Vector2, sz: float, a: float) -> void:
	var look := StringName(String(id).trim_prefix("pet:"))
	var col := Color(0.9, 0.15, 0.12)
	if look == &"glowworm":
		col = Color(0.78, 0.86, 0.55)
	elif look == &"ant_crew":
		col = Color(0.55, 0.22, 0.12)
	draw(ci, look, c, sz * 0.22, 0.0, 0.0, 0.0, col, a, 1.0 if look == &"glowworm" else 0.0)


static func _job_pic(ci: CanvasItem, id: StringName, c: Vector2, sz: float, a: float) -> void:
	var u := sz / 22.0
	var job := StringName(String(id).trim_prefix("job:"))
	if job == &"lamp":   # a sun-ray burst round a bright dot
		for i in 8:
			var d := Vector2.from_angle(i * TAU / 8.0)
			ci.draw_line(c + d * 5.0 * u, c + d * 9.0 * u, Color(1.0, 0.8, 0.2, a), 2.0 * u)
		ci.draw_circle(c, 4.5 * u, Color(1.0, 0.95, 0.5, a))
	elif job == &"tend":   # a sprout in its bed
		ci.draw_line(c + Vector2(0, 8) * u, c + Vector2(0, -2) * u, Color(0.3, 0.6, 0.2, a), 2.0 * u)
		ci.draw_circle(c + Vector2(-3.5, -3) * u, 3.5 * u, Color(0.45, 0.8, 0.3, a))
		ci.draw_circle(c + Vector2(3.5, -5) * u, 3.5 * u, Color(0.45, 0.8, 0.3, a))
		ci.draw_rect(Rect2(c + Vector2(-8, 7) * u, Vector2(16, 3) * u), Color(0.4, 0.26, 0.14, a))
	else:   # fetch: a seed
		ci.draw_circle(c, 5.0 * u, Color(INK, a))
		ci.draw_circle(c, 4.0 * u, Color(0.6275, 0.4392, 0.2353, a))
