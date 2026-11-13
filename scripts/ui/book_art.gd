## Sketches for the collection book, drawn in code in Old Reel's pencil style (placeholder look until
## the Art lane's D92 pass). Each draw takes `found`: false draws the same outline as a flat grey
## silhouette with no face, colour or detail, so the shape is a clue and finding it is the reveal.
## The picture comes from the entry's own data: a food's colour and radius, a creature's colour,
## hat and behaviour, a trait's part texture and colour, a cutscene's time of day.
class_name BookArt
extends RefCounted

const PAPER := Color("f7efd9")
const PENCIL := Color("4a3a30")
const GREY := Color("a39d92")
const GREY_DARK := Color("8a847a")
const SECTION_COLORS := { &"foods": Color("f08a3c"), &"creatures": Color("e0483a"),
	&"traits": Color("5fd0e8"), &"secrets": Color("ffd23f"), &"cutscenes": Color("8a7be0"),
	&"planets": Color("4f7fd8") }
## Sky per time-of-day word in a cutscene's "time_of_day".
const SKIES := { "dawn": Color("f6b98a"), "morning": Color("9fd0f0"), "noon": Color("8cc8f4"),
	"dusk": Color("f09a6a"), "night": Color("26305a") }


static func draw_entry(ci: CanvasItem, section: StringName, e: Dictionary, c: Vector2, found: bool, t: float, i: int) -> void:
	match section:
		&"foods":
			food(ci, c, e.data, found, i)
		&"creatures":
			creature(ci, c, e.data, found, t, i)
		&"traits":
			trait_pic(ci, c, e.data, found, i)
		&"secrets":
			secret(ci, c, e.id, found, t, i)
		&"cutscenes":
			cutscene(ci, c, e.data, found, i)
		&"planets":
			planet(ci, c, e.data, found, t, i)


## Section tab icon (always drawn in colour: it names the section, it is not a thing to find).
static func tab_icon(ci: CanvasItem, section: StringName, c: Vector2, t: float) -> void:
	var col: Color = SECTION_COLORS[section]
	match section:
		&"foods":
			blob(ci, c, 30.0, col, 3, true)
			face(ci, c, 30.0)
		&"creatures":
			bug(ci, c, 32.0, col, Color.WHITE, Color.TRANSPARENT, true, t)
		&"traits":
			star(ci, c, 34.0, col, true)
		&"secrets":
			mound(ci, c + Vector2(0, 8), 36.0, Color("b07a4a"), true, t)
		&"cutscenes":
			dock(ci, c, 40.0, SKIES["dawn"], true)
		&"planets":
			ringed(ci, c, 26.0, col, Color.WHITE, true)


# --- per section ----------------------------------------------------------------------------------

static func food(ci: CanvasItem, c: Vector2, f: FoodData, found: bool, i: int) -> void:
	var r := clampf(24.0 + f.radius * 4.0, 34.0, 78.0)
	var col := f.color if found else GREY
	match f.flavour:
		&"stone":
			rock(ci, c, r, col, i, found)
		&"root":
			if String(f.id).contains("mushroom"):
				mushroom(ci, c, r, col, found)
			elif String(f.id).contains("seed"):
				oval(ci, c, Vector2(r * 0.7, r), col, found)
			else:
				root(ci, c, r, col, found)
		&"water":
			drop(ci, c, r, col, found)
		&"crystal":
			gem(ci, c, r, col, found)
		_:
			blob(ci, c, r, col, i, found)
	if found and f.flavour in [&"bug", &"root", &"water"]:
		face(ci, c + Vector2(0, r * 0.1), r * 0.8)


static func creature(ci: CanvasItem, c: Vector2, d: Resource, found: bool, t: float, i: int) -> void:
	var col: Color = d.get(&"color") if d.get(&"color") != null else Color("c0392b")
	if d is PetData:
		# A pet's sprite is its look script; the ladybird is the only one the data has.
		if found and d.id == &"ladybird":
			LadybirdLook.draw(ci, c, 46.0, -PI / 2.0 + sin(t * 2.0) * 0.2, t)
		else:
			bug(ci, c, 44.0, GREY, GREY, Color.TRANSPARENT, false, t)
		return
	if not d is CreatureData:
		blob(ci, c, 44.0, GREY if not found else col, i, found)
		return
	var cd := d as CreatureData
	var r := clampf(26.0 + cd.radius * 1.6, 34.0, 62.0)
	var body := cd.color if found else GREY
	match cd.behaviour:
		CreatureData.Behaviour.PECK:
			bird(ci, c, r, body, cd.accent if found else GREY, found)
		CreatureData.Behaviour.STOMP:
			boot(ci, c, r, body, found)
		CreatureData.Behaviour.WIGGLE:
			grub(ci, c, r, body, found, t)
		_:
			bug(ci, c, r, body, cd.accent if found else GREY, cd.hat if found else Color.TRANSPARENT, found, t)


static func trait_pic(ci: CanvasItem, c: Vector2, d: TraitData, found: bool, i: int) -> void:
	blob(ci, c, 54.0, d.color if found else GREY, i, found)
	var tex := d.part_texture(1)
	if tex:
		var s := 78.0 / maxf(tex.get_width(), tex.get_height())
		var mod := Color.WHITE if found else Color(0, 0, 0, 0.28)   # black x texture = flat silhouette
		ci.draw_texture_rect(tex, Rect2(c - tex.get_size() * s * 0.5, tex.get_size() * s), false, mod)
	else:
		star(ci, c, 30.0, Color.WHITE if found else GREY_DARK, found)


static func secret(ci: CanvasItem, c: Vector2, id: StringName, found: bool, t: float, i: int) -> void:
	if String(id).contains("ant"):
		mound(ci, c, 60.0, Color("b07a4a") if found else GREY, found, t)
	else:
		star(ci, c, 52.0, SECTION_COLORS[&"secrets"] if found else GREY, found)


static func cutscene(ci: CanvasItem, c: Vector2, d: Dictionary, found: bool, i: int) -> void:
	var tod := String(d.get("time_of_day", "noon")).to_lower()
	var sky: Color = SKIES["noon"]
	for k: String in SKIES:
		if tod.begins_with(k):
			sky = SKIES[k]
	dock(ci, c, 72.0, sky if found else GREY, found, tod.begins_with("night"))


## A space planet type: its own colour and accent band, its foods circling it, a sleepy face, and
## its Star trait twinkling beside it. Unfound: the same round outline in flat grey, nothing else.
static func planet(ci: CanvasItem, c: Vector2, d: PlanetData, found: bool, t: float, i: int) -> void:
	var r := 52.0
	if not found:
		blob(ci, c, r, GREY, i, false)
		return
	for j in mini(3, d.foods.size()):   # its foods, in orbit
		var a := t * 0.6 + TAU * j / 3.0
		var fc := c + Vector2(cos(a) * r * 1.35, sin(a) * r * 0.55)
		ci.draw_circle(fc, 9.0, d.foods[j].color)
		ci.draw_circle(fc, 9.0, PENCIL, false, 2.0)
	ringed(ci, c, r, d.color, d.accent, true, i)
	# Sleepy: two closed-lid arcs and a small smile.
	for sx: float in [-1.0, 1.0]:
		ci.draw_arc(c + Vector2(sx * r * 0.32, -r * 0.12), r * 0.12, 0.2, PI - 0.2, 8, PENCIL, 3.0)
	ci.draw_arc(c + Vector2(0, r * 0.18), r * 0.18, 0.3, PI - 0.3, 8, PENCIL, 2.5)
	if d.star_trait != null:
		star(ci, c + Vector2(r * 0.95, -r * 0.9), 13.0 + 2.0 * sin(t * 4.0 + i), d.star_trait.color, true)


## A round planet with one accent band across it (also the planets tab icon).
static func ringed(ci: CanvasItem, c: Vector2, r: float, col: Color, accent: Color, found: bool, seed_i := 2) -> void:
	_fill(ci, _wobbly(c, Vector2(r, r), seed_i), col, found)
	ci.draw_line(c + Vector2(-r * 0.92, r * 0.28), c + Vector2(r * 0.92, r * 0.02), Color(accent, 0.85), maxf(3.0, r * 0.16))
	ci.draw_circle(c + Vector2(-r * 0.38, -r * 0.42), r * 0.14, Color(1, 1, 1, 0.75))


# --- shapes ---------------------------------------------------------------------------------------

static func _wobbly(c: Vector2, r: Vector2, seed_i: int, n := 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for j in n:
		var a := TAU * j / n
		var w := 1.0 + 0.05 * sin(a * 3.0 + seed_i) + 0.03 * sin(a * 7.0 + seed_i * 2.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * w)
	return pts


static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, found: bool) -> void:
	ci.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, PENCIL if found else GREY_DARK, 3.0 if found else 2.0)


## A pencil-hatched disc: colour scribbled inside the lines, mostly.
static func blob(ci: CanvasItem, c: Vector2, r: float, col: Color, seed_i: int, found: bool) -> void:
	_fill(ci, _wobbly(c, Vector2(r, r), seed_i), col, found)
	if found:
		for j in 7:
			var y := -r * 0.7 + j * r * 0.23
			var hw := sqrt(maxf(0.0, r * r * 0.7 - y * y))
			ci.draw_line(c + Vector2(-hw, y + 5), c + Vector2(hw, y - 5), Color(col.darkened(0.2), 0.6), 3.0)
		ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1, 1, 1, 0.8))


static func face(ci: CanvasItem, c: Vector2, r: float) -> void:
	for sx: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * r * 0.32, -r * 0.08), maxf(2.5, r * 0.1), PENCIL)
	ci.draw_arc(c + Vector2(0, r * 0.12), r * 0.22, 0.2, PI - 0.2, 8, PENCIL, 2.5)


static func oval(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, found: bool) -> void:
	_fill(ci, _wobbly(c, r, 4), col, found)
	if found:
		ci.draw_line(c + Vector2(0, -r.y * 0.7), c + Vector2(0, r.y * 0.5), Color(col.darkened(0.3)), 3.0)


static func rock(ci: CanvasItem, c: Vector2, r: float, col: Color, seed_i: int, found: bool) -> void:
	var pts := PackedVector2Array()
	for j in 9:
		var a := TAU * j / 9.0 + seed_i
		pts.append(c + Vector2(cos(a), sin(a) * 0.8) * r * (0.82 + 0.18 * sin(j * 2.3 + seed_i)))
	_fill(ci, pts, col, found)
	if found:
		ci.draw_line(c + Vector2(-r * 0.3, -r * 0.1), c + Vector2(r * 0.1, r * 0.2), Color(col.darkened(0.35)), 3.0)


static func root(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool) -> void:
	var pts := PackedVector2Array()
	for j in 12:
		var k := j / 11.0
		pts.append(c + Vector2(-r + 2.0 * r * k, sin(k * TAU * 1.2) * r * 0.35))
	ci.draw_polyline(pts, PENCIL if found else GREY_DARK, 22.0)
	ci.draw_polyline(pts, col, 15.0)
	ci.draw_line(pts[6], pts[6] + Vector2(10, r * 0.6), col, 8.0)


static func mushroom(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool) -> void:
	var stem := Rect2(c + Vector2(-r * 0.22, -r * 0.1), Vector2(r * 0.44, r * 0.8))
	ci.draw_rect(stem, Color("f1e4c8") if found else GREY)
	ci.draw_rect(stem, PENCIL if found else GREY_DARK, false, 2.0)
	var cap := PackedVector2Array()
	for j in 19:
		var a := PI + PI * j / 18.0
		cap.append(c + Vector2(cos(a) * r, sin(a) * r * 0.7) + Vector2(0, -r * 0.05))
	_fill(ci, cap, col, found)
	if found:
		for p: Vector2 in [Vector2(-0.4, -0.35), Vector2(0.2, -0.5), Vector2(0.5, -0.2)]:
			ci.draw_circle(c + p * r, r * 0.1, Color(1, 1, 1, 0.85))


static func drop(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool) -> void:
	var pts := PackedVector2Array()
	for j in 24:
		var a := TAU * j / 24.0
		var p := Vector2(cos(a), sin(a)) * r * 0.75
		if p.y < 0.0:
			p.x *= 1.0 + p.y / (r * 0.75)
			p.y *= 1.6
		pts.append(c + p + Vector2(0, r * 0.2))
	_fill(ci, pts, col, found)


static func gem(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.4, r * 0.8),
		c + Vector2(-r * 0.4, r * 0.8), c + Vector2(-r * 0.6, -r * 0.2)])
	_fill(ci, pts, col, found)
	if found:
		ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.8), Color(1, 1, 1, 0.6), 2.0)


static func bug(ci: CanvasItem, c: Vector2, r: float, col: Color, accent: Color, hat: Color, found: bool, t: float) -> void:
	var line := PENCIL if found else GREY_DARK
	for j in 3:
		for sx: float in [-1.0, 1.0]:
			var a := Vector2(sx * r * 0.7, -r * 0.3 + j * r * 0.35)
			var kick := sin(t * 8.0 + j) * 3.0 if found else 0.0
			ci.draw_line(c + a, c + a + Vector2(sx * r * 0.45, r * 0.15 + kick), line, 3.0)
	_fill(ci, _wobbly(c, Vector2(r * 0.8, r * 0.85), 5), col, found)
	ci.draw_circle(c + Vector2(0, -r * 0.85), r * 0.38, line if found else GREY)
	if not found:
		return
	ci.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.8), Color(accent, 0.8), 3.0)
	for sx: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * r * 0.15, -r * 0.9), r * 0.1, Color.WHITE)
	if hat.a > 0.0:   # the ant's little cap
		ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 1.38), Vector2(r * 0.6, r * 0.22)), hat)
		ci.draw_rect(Rect2(c + Vector2(-r * 0.05, -r * 1.24), Vector2(r * 0.5, r * 0.08)), hat.darkened(0.2))


static func grub(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool, t: float) -> void:
	var line := PENCIL if found else GREY_DARK
	for j in range(4, -1, -1):
		var p := c + Vector2(-r * 0.8 + j * r * 0.4, sin(j * 1.3 + (t * 4.0 if found else 0.0)) * r * 0.1)
		ci.draw_circle(p, r * 0.34, line)
		ci.draw_circle(p, r * 0.3, col)
	if found:
		ci.draw_circle(c + Vector2(r * 0.9, -r * 0.08), r * 0.07, PENCIL)


static func bird(ci: CanvasItem, c: Vector2, r: float, col: Color, accent: Color, found: bool) -> void:
	_fill(ci, _wobbly(c, Vector2(r * 0.9, r * 0.7), 2), col, found)
	var head := c + Vector2(r * 0.7, -r * 0.6)
	ci.draw_circle(head, r * 0.42, PENCIL if found else GREY_DARK)
	ci.draw_circle(head, r * 0.38, col)
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(r * 0.3, -r * 0.1), head + Vector2(r * 0.8, r * 0.05),
		head + Vector2(r * 0.3, r * 0.15)]), Color("f2b632") if found else GREY_DARK)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.2), c + Vector2(r * 0.3, -r * 0.1),
		c + Vector2(-r * 0.5, r * 0.4)]), accent.darkened(0.1))
	if found:
		ci.draw_circle(head + Vector2(r * 0.08, -r * 0.1), r * 0.08, PENCIL)


static func boot(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r * 0.1, -r), c + Vector2(r * 0.1, r * 0.1),
		c + Vector2(r, r * 0.25), c + Vector2(r, r * 0.7), c + Vector2(-r * 0.6, r * 0.7)])
	_fill(ci, pts, col, found)
	if found:
		ci.draw_rect(Rect2(c + Vector2(-r * 0.65, r * 0.55), Vector2(r * 1.7, r * 0.2)), PENCIL)
		for j in 3:
			ci.draw_line(c + Vector2(-r * 0.5, -r * 0.8 + j * r * 0.25), c + Vector2(0, -r * 0.8 + j * r * 0.25), Color.WHITE, 3.0)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool) -> void:
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI / 2.0 + TAU * j / 10.0
		pts.append(c + Vector2.from_angle(a) * (r if j % 2 == 0 else r * 0.45))
	_fill(ci, pts, col, found)


static func mound(ci: CanvasItem, c: Vector2, r: float, col: Color, found: bool, t: float) -> void:
	var pts := PackedVector2Array()
	for j in 17:
		var a := PI + PI * j / 16.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8 + r * 0.4))
	_fill(ci, pts, col, found)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.05), Vector2(r * 0.3, r * 0.35)), PENCIL if found else GREY_DARK)
	if found:
		for a in 4:
			var ap := c + Vector2(-r * 0.6 + a * r * 0.4, r * 0.5 + sin(t * 4.0 + a) * 2.0)
			ci.draw_circle(ap, 4.0, PENCIL)
			ci.draw_circle(ap + Vector2(5, 0), 3.0, PENCIL)


## A tiny dock: sky in the scene's light, the pond, the jetty with Old Reel's hat.
static func dock(ci: CanvasItem, c: Vector2, r: float, sky: Color, found: bool, night := false) -> void:
	var box := Rect2(c - Vector2(r, r * 0.72), Vector2(r * 2.0, r * 1.44))
	ci.draw_rect(box, sky)
	if found:
		ci.draw_rect(Rect2(box.position + Vector2(0, box.size.y * 0.62), Vector2(box.size.x, box.size.y * 0.38)), Color(0.25, 0.45, 0.7))
		ci.draw_rect(Rect2(box.position + Vector2(box.size.x * 0.1, box.size.y * 0.55), Vector2(box.size.x * 0.5, box.size.y * 0.08)), Color(0.55, 0.38, 0.22))
		var hat := box.position + Vector2(box.size.x * 0.32, box.size.y * 0.42)
		ci.draw_rect(Rect2(hat - Vector2(r * 0.14, 0), Vector2(r * 0.28, r * 0.08)), PENCIL)
		ci.draw_rect(Rect2(hat - Vector2(r * 0.08, r * 0.12), Vector2(r * 0.16, r * 0.12)), PENCIL)
		var sun := box.position + Vector2(box.size.x * 0.78, box.size.y * 0.25)
		ci.draw_circle(sun, r * 0.12, Color(1, 0.97, 0.8) if night else Color(1, 0.85, 0.3))
	else:
		ci.draw_rect(Rect2(box.position + Vector2(0, box.size.y * 0.62), Vector2(box.size.x, box.size.y * 0.38)), GREY_DARK)
	ci.draw_rect(box, PENCIL if found else GREY_DARK, false, 3.0)
