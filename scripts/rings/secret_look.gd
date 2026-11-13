## The small picture of each hidden place (placeholder, drawn in code, no words): the same sketch in
## the find bubble over the hall and on the tackle box's secrets page, so the page reads as "that's
## the place you found". Also the bubble's food and tackle-box pictures.
## PictoBubble ids (register() once; safe to call again): "secret:<id>", "secret_food:<food>",
## &"secret_box", &"secret_dig" (the worm's head biting through a rock wall: a find's cause).
## Unknown secret ids draw a gold star.
class_name SecretLook
extends RefCounted

const INK := Color("3a2a44")
const WATER := Color("4f9be0")
const WOOD := Color("a0683a")
const WOOD_DARK := Color("6e4526")
const TIN := Color("3f6f5a")
const BONE := Color("efe4c8")
const ROCK := Color("6f7586")
const GOLD := Color("ffd23f")

## The pictures this file can draw (secret ids).
const KNOWN: Array[StringName] = [&"ant_city", &"sunken_rowboat", &"fossil_hall", &"geode_cathedral",
		&"picnic_basket", &"cloud_nest"]
const GEMS: Array[Color] = [Color("c46cff"), Color("5fe8ff"), Color("ff7ad9"), Color("ffd23f")]


static func register() -> void:
	PictoBubble.register_prefix("secret:", func(ci: CanvasItem, id: StringName, c: Vector2, s: float, a: float) -> void:
		draw(ci, StringName(String(id).trim_prefix("secret:")), c, s, a))
	PictoBubble.register_prefix("secret_food:", _food_pic)
	PictoBubble.register(&"secret_box", _box_pic)
	PictoBubble.register(&"secret_dig", _dig_pic)


static func has(id: StringName) -> bool:
	return id in KNOWN


## The picture of secret `id` centred at c in a box of side s, alpha a, t = seconds (bubbles bob).
static func draw(ci: CanvasItem, id: StringName, c: Vector2, s: float, a := 1.0, t := 0.0) -> void:
	var u := s / 22.0
	match id:
		&"ant_city":
			_ant_city(ci, c, u, a, t)
		&"sunken_rowboat":
			_rowboat(ci, c, u, a, t)
		&"fossil_hall":
			_fossil_hall(ci, c, u, a, t)
		&"geode_cathedral":
			_geode_cathedral(ci, c, u, a, t)
		&"picnic_basket":
			_picnic_basket(ci, c, u, a, t)
		&"cloud_nest":
			_cloud_nest(ci, c, u, a, t)
		_:
			_star(ci, c, 8.0 * u, Color(GOLD, a), Color(INK, a))


static func _ant_city(ci: CanvasItem, c: Vector2, u: float, a: float, t: float) -> void:
	var mound := PackedVector2Array()
	for k in 13:
		var ang := PI + PI * k / 12.0
		mound.append(c + Vector2(cos(ang) * 10.0, 6.0 + sin(ang) * 10.0) * u)
	ci.draw_colored_polygon(mound, Color(INK, a))
	var inner := PackedVector2Array()
	for k in 13:
		var ang := PI + PI * k / 12.0
		inner.append(c + Vector2(cos(ang) * 8.8, 6.0 + sin(ang) * 8.8) * u)
	ci.draw_colored_polygon(inner, Color(Color("b07a4a"), a))
	ci.draw_rect(Rect2(c + Vector2(-2.0, 1.0) * u, Vector2(4.0, 5.0) * u), Color(INK, a))
	for i in 3:
		var p := c + Vector2(-6.0 + i * 6.0, 8.0 + sin(t * 4.0 + i) * 0.5) * u
		ci.draw_circle(p, 1.3 * u, Color(INK, a))
		ci.draw_circle(p + Vector2(1.6, 0) * u, 1.0 * u, Color(INK, a))


## Old Reel's little rowboat on its side in the water, his green tackle tin spilled by it.
static func _rowboat(ci: CanvasItem, c: Vector2, u: float, a: float, t: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-10.5, -4.0) * u, Vector2(21.0, 14.5) * u), Color(WATER, 0.55 * a))
	var wave := PackedVector2Array()
	for k in 9:
		wave.append(c + Vector2(-10.5 + k * 21.0 / 8.0, -4.0 + sin(t * 2.0 + k) * 0.6) * u)
	ci.draw_polyline(wave, Color(Color.WHITE, 0.8 * a), 1.2 * u)
	var hull := _rot(PackedVector2Array([Vector2(-9, -1), Vector2(7, -1), Vector2(4, 5), Vector2(-6, 5)]), -0.25, c + Vector2(-1, 2) * u, u)
	ci.draw_colored_polygon(_grow(hull, 1.2 * u), Color(INK, a))
	ci.draw_colored_polygon(hull, Color(WOOD, a))
	ci.draw_line(hull[0].lerp(hull[3], 0.5), hull[1].lerp(hull[2], 0.5), Color(WOOD_DARK, a), 1.0 * u)
	ci.draw_line(c + Vector2(-8, -7) * u, c + Vector2(2, 4) * u, Color(INK, a), 1.6 * u)        # an oar
	ci.draw_circle(c + Vector2(-8, -7) * u, 1.8 * u, Color(WOOD, a))
	ci.draw_rect(Rect2(c + Vector2(4.5, 5.0) * u, Vector2(6.0, 4.0) * u), Color(INK, a))         # the tin
	ci.draw_rect(Rect2(c + Vector2(5.2, 5.6) * u, Vector2(4.6, 2.8) * u), Color(TIN, a))
	ci.draw_circle(c + Vector2(8.5, 3.6) * u, 1.1 * u, Color(Color("e0483a"), a))                # a lure
	for i in 2:
		var b := c + Vector2(-3.0 + i * 6.0, -6.0 - fmod(t * 4.0 + i * 3.0, 5.0)) * u
		ci.draw_arc(b, 1.1 * u, 0.0, TAU, 10, Color(Color.WHITE, 0.8 * a), 0.8 * u)


## A rock arch with a curled shell and a long fish skeleton set in the wall, and a drop of amber.
static func _fossil_hall(ci: CanvasItem, c: Vector2, u: float, a: float, t: float) -> void:
	var arch := PackedVector2Array()
	for k in 15:
		var ang := PI + PI * k / 14.0
		arch.append(c + Vector2(cos(ang) * 11.0, 8.0 + sin(ang) * 14.0) * u)
	ci.draw_colored_polygon(arch, Color(INK, a))
	var inner := PackedVector2Array()
	for k in 15:
		var ang := PI + PI * k / 14.0
		inner.append(c + Vector2(cos(ang) * 9.8, 8.0 + sin(ang) * 12.8) * u)
	ci.draw_colored_polygon(inner, Color(ROCK, a))
	# a fish skeleton: spine, ribs, a skull and a tail fan
	var a0 := c + Vector2(-7.0, 0.0) * u
	var a1 := c + Vector2(6.0, 0.0) * u
	ci.draw_line(a0, a1, Color(BONE, a), 1.3 * u)
	for i in 5:
		var x := lerpf(-4.5, 4.0, i / 4.0)
		var h := 3.2 - absf(x) * 0.25
		ci.draw_line(c + Vector2(x, -h) * u, c + Vector2(x, h) * u, Color(BONE, a), 0.9 * u)
	ci.draw_circle(a1 + Vector2(1.6, 0) * u, 2.2 * u, Color(BONE, a))
	ci.draw_circle(a1 + Vector2(2.2, -0.6) * u, 0.6 * u, Color(INK, a))
	ci.draw_colored_polygon(PackedVector2Array([a0, a0 + Vector2(-3, -3) * u, a0 + Vector2(-3, 3) * u]), Color(BONE, a))
	# a curled shell low on the left
	_spiral(ci, c + Vector2(-5.0, 6.0) * u, 3.2 * u, Color(BONE, a), 0.9 * u)
	# a glowing drop of amber on the floor, right
	var g := 0.6 + 0.4 * sin(t * 3.0)
	ci.draw_circle(c + Vector2(5.0, 6.0) * u, 2.8 * u, Color(Color("ffa826"), 0.3 * g * a))
	ci.draw_circle(c + Vector2(5.0, 6.0) * u, 1.7 * u, Color(Color("ffa826"), a))


## A tall pointed arch in lit violet rock, crystal pillars in the middle, a split geode either side.
static func _geode_cathedral(ci: CanvasItem, c: Vector2, u: float, a: float, t: float) -> void:
	var arch := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 15:
		var ang := PI + PI * k / 14.0
		var lift := 1.0 + 0.35 * sin(PI * k / 14.0)   # a pointed crown
		arch.append(c + Vector2(cos(ang) * 11.0, 9.0 + sin(ang) * 15.0 * lift) * u)
		inner.append(c + Vector2(cos(ang) * 9.6, 9.0 + sin(ang) * 13.6 * lift) * u)
	ci.draw_colored_polygon(arch, Color(INK, a))
	ci.draw_colored_polygon(inner, Color(Color("9a6cc4"), a))
	for i in 3:
		var x := -4.0 + i * 4.0
		var h := 9.0 if i == 1 else 6.0
		var col := GEMS[i + 1]
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 1.6, 9) * u, c + Vector2(x + 1.6, 9) * u, c + Vector2(x, 9 - h - 2.5) * u]), Color(col, a))
	for sx in [-1.0, 1.0]:
		var g: Vector2 = c + Vector2(sx * 6.5, -3.0) * u
		ci.draw_circle(g, 2.8 * u, Color(Color("c9b8a6"), a))
		ci.draw_circle(g, 2.0 * u, Color(GEMS[0], a))
	var tw := 0.6 + 0.4 * sin(t * 3.0)
	ci.draw_circle(c + Vector2(0, -10.0) * u, 1.3 * u, Color(Color(1, 1, 1), tw * a))


## The cause of a find: the worm's head biting through a rock wall, chips flying off.
static func _dig_pic(ci: CanvasItem, _id: StringName, c: Vector2, s: float, a: float) -> void:
	var u := s / 22.0
	var wall := PackedVector2Array([c + Vector2(2, -10) * u, c + Vector2(10, -10) * u, c + Vector2(10, 10) * u, c + Vector2(2, 10) * u, c + Vector2(4, 4) * u, c + Vector2(1, 0) * u, c + Vector2(4, -5) * u])
	ci.draw_colored_polygon(wall, Color(Color("d8643a"), a))
	ci.draw_polyline(PackedVector2Array([c + Vector2(2, -10) * u, c + Vector2(4, -5) * u, c + Vector2(1, 0) * u, c + Vector2(4, 4) * u, c + Vector2(2, 10) * u]), Color(INK, a), 1.2 * u)
	# the worm: a pink body coming from the left, head at the crack, mouth open
	for i in 3:
		ci.draw_circle(c + Vector2(-9.0 + i * 3.5, 2.0 - i * 0.6) * u, (2.6 + i * 0.3) * u, Color(INK, a))
		ci.draw_circle(c + Vector2(-9.0 + i * 3.5, 2.0 - i * 0.6) * u, (2.0 + i * 0.3) * u, Color(Color("f29ab0"), a))
	ci.draw_circle(c + Vector2(-0.5, 0.5) * u, 3.6 * u, Color(INK, a))
	ci.draw_circle(c + Vector2(-0.5, 0.5) * u, 3.0 * u, Color(Color("f29ab0"), a))
	ci.draw_circle(c + Vector2(-1.0, -0.8) * u, 0.7 * u, Color(INK, a))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(1.5, 0.0) * u, c + Vector2(3.0, -1.2) * u, c + Vector2(3.0, 1.8) * u]), Color(INK, a))
	# chips flying off the wall
	for spec in [[Vector2(5, -8), 1.2], [Vector2(7, 6), 1.0], [Vector2(-3, -7), 0.9]]:
		ci.draw_rect(Rect2(c + (spec[0] as Vector2) * u - Vector2.ONE * spec[1] * u, Vector2.ONE * spec[1] * 2.0 * u), Color(Color("f08a5a"), a))


static func _food_pic(ci: CanvasItem, id: StringName, c: Vector2, s: float, a: float) -> void:
	var path := "res://data/foods/%s.tres" % String(id).trim_prefix("secret_food:")
	var f: FoodData = load(path) if ResourceLoader.exists(path) else null
	var col := f.color if f else Color.WHITE
	var r := s * 0.3
	ci.draw_circle(c, r + s * 0.05, Color(INK, a))
	ci.draw_circle(c, r, Color(col, a))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.3, Color(1, 1, 1, 0.6 * a))


## Old Reel's tackle box, lid up, a lure on the peg: "it's in the tackle box now".
static func _box_pic(ci: CanvasItem, _id: StringName, c: Vector2, s: float, a: float) -> void:
	var u := s / 22.0
	ci.draw_rect(Rect2(c + Vector2(-9, -1) * u, Vector2(18, 10) * u), Color(INK, a))
	ci.draw_rect(Rect2(c + Vector2(-8, 0) * u, Vector2(16, 8) * u), Color(TIN, a))
	var lid := PackedVector2Array([c + Vector2(-9, -1) * u, c + Vector2(9, -1) * u, c + Vector2(7, -9) * u, c + Vector2(-7, -9) * u])
	ci.draw_colored_polygon(lid, Color(INK, a))
	ci.draw_colored_polygon(_grow(lid, -1.0 * u), Color(Color("5d9a7c"), a))
	ci.draw_line(c + Vector2(-3, 4) * u, c + Vector2(3, 4) * u, Color(INK, a), 1.4 * u)          # handle
	_star(ci, c + Vector2(0, -5) * u, 2.6 * u, Color(GOLD, a), Color(INK, a))


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color, ol: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rr)
	ci.draw_colored_polygon(_grow(pts, r * 0.18), ol)
	ci.draw_colored_polygon(pts, col)


static func _spiral(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var f := k / 27.0
		pts.append(c + Vector2.from_angle(f * TAU * 2.2) * r * (1.0 - f * 0.85))
	ci.draw_polyline(pts, col, w)


static func _rot(pts: PackedVector2Array, ang: float, at: Vector2, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + (p * u).rotated(ang))
	return out


## Pushes each point of a convex polygon away from its middle by d (an outline behind it).
static func _grow(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= maxf(1.0, pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - mid).normalized() * d)
	return out


## The topsoil's hidden place: a picnic basket buried under the grass, its red-and-white cloth
## spilling out and a tipped jam jar dripping jam drops.
static func _picnic_basket(ci: CanvasItem, c: Vector2, u: float, a: float, t: float) -> void:
	var o := c + Vector2(0, 2.0) * u
	# the cloth, a checked square under the basket
	var cloth := PackedVector2Array([o + Vector2(-11, 3) * u, o + Vector2(10, 1) * u, o + Vector2(12, 9) * u, o + Vector2(-10, 10) * u])
	ci.draw_colored_polygon(cloth, Color(INK, a))
	for i in 4:
		for j in 2:
			var p := o + Vector2(-9 + i * 5.2, 3.4 + j * 3.2) * u
			ci.draw_rect(Rect2(p, Vector2(2.4, 2.4) * u), Color(Color("e0483a") if (i + j) % 2 == 0 else Color.WHITE, a))
	# the basket and its handle
	ci.draw_arc(o + Vector2(-2, -3) * u, 6.0 * u, PI, TAU, 10, Color(INK, a), 2.6 * u)
	ci.draw_arc(o + Vector2(-2, -3) * u, 6.0 * u, PI, TAU, 10, Color(WOOD, a), 1.4 * u)
	var basket := PackedVector2Array([o + Vector2(-9, -3) * u, o + Vector2(5, -3) * u, o + Vector2(3, 4) * u, o + Vector2(-7, 4) * u])
	ci.draw_colored_polygon(basket, Color(INK, a))
	var inner := PackedVector2Array([o + Vector2(-8, -2) * u, o + Vector2(4, -2) * u, o + Vector2(2.4, 3) * u, o + Vector2(-6.4, 3) * u])
	ci.draw_colored_polygon(inner, Color(WOOD, a))
	for k in 3:
		ci.draw_line(o + Vector2(-7.5 + k * 0.4, -0.5 + k * 1.3) * u, o + Vector2(3.5 - k * 0.4, -0.5 + k * 1.3) * u, Color(WOOD_DARK, a), 0.8 * u)
	# the tipped jam jar and two drops
	ci.draw_circle(o + Vector2(8, -2) * u, 3.4 * u, Color(INK, a))
	ci.draw_circle(o + Vector2(8, -2) * u, 2.6 * u, Color(Color("dc3657"), a))
	ci.draw_circle(o + Vector2(7, -3) * u, 0.8 * u, Color(1, 1, 1, 0.8 * a))
	for k in 2:
		var bob := sin(t * 3.0 + k) * 0.6
		ci.draw_circle(o + Vector2(11.5 + k * 2.5, 1.5 + bob) * u, 1.4 * u, Color(Color("dc3657"), a))


## The sky's hidden place: a cloud island with a bird's nest on top, a little rainbow over it and
## rainbow drops hanging in the air.
static func _cloud_nest(ci: CanvasItem, c: Vector2, u: float, a: float, t: float) -> void:
	var o := c + Vector2(0, 3.0 + sin(t * 1.5) * 0.6) * u
	var bands: Array[Color] = [Color("e0483a"), Color("ffb03a"), Color("ffd23f"), Color("6fcf5a"), Color("4f9be0")]
	for i in bands.size():
		ci.draw_arc(o + Vector2(0, -1) * u, (12.0 - i * 1.3) * u, PI, TAU, 18, Color(bands[i], a), 1.3 * u)
	for p in [Vector2(-7, 3), Vector2(0, 1), Vector2(7, 3), Vector2(-3, 5), Vector2(4, 5)]:
		ci.draw_circle(o + p * u, 5.2 * u, Color(INK, a))
	for p in [Vector2(-7, 3), Vector2(0, 1), Vector2(7, 3), Vector2(-3, 5), Vector2(4, 5)]:
		ci.draw_circle(o + p * u, 4.4 * u, Color(Color("f4f7ff"), a))
	# the nest: a brown bowl of twigs with three speckled eggs peeking out
	var nest := o + Vector2(0, -3) * u
	for k in 3:
		ci.draw_circle(nest + Vector2(-2.2 + k * 2.2, -1.4) * u, 1.6 * u, Color(Color("bfe8ff"), a))
	ci.draw_arc(nest, 4.6 * u, 0.0, PI, 10, Color(INK, a), 3.2 * u)
	ci.draw_arc(nest, 4.6 * u, 0.0, PI, 10, Color(WOOD, a), 1.8 * u)
	# rainbow drops
	for k in 2:
		var d := o + Vector2(-11 + k * 22, -6 + sin(t * 2.0 + k) * 0.8) * u
		ci.draw_circle(d, 2.0 * u, Color(INK, a))
		ci.draw_circle(d, 1.4 * u, Color(Color("b496ff"), a))
