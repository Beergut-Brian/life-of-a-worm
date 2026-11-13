## The hidden places added after the first four (X-01), drawn the SecretSpot way (placeholder, in
## code, no words). RingsDirector makes one of these instead of a plain SecretSpot for the ids in
## DRAWS; everything else (the find beat, the camera hold, the bubble) is SecretSpot's.
##  - picnic_basket (topsoil): Old Reel's lost picnic basket buried under the grass, a checked cloth
##    spilling out, a tipped jam jar and jam drops on the floor, a warm glow;
##  - cloud_nest (sky): a cloud island high in the air, a bird's nest of twigs with three blue eggs on
##    top, a small rainbow over it and sparkles drifting. The sky's birds (SkyFlock) circle near it.
##  - hollow_stump (surface): an old tree stump standing alone on the far meadow, opposite the town.
##    The crust is too thin for a carved hall, so the place stands on the grass: the stump is drawn
##    cut away, a warm hollow inside with a pile of golden acorns on a leaf bed, roots, moss, a
##    toadstool and a new sprout on top. A worm reaches it once it can bite out through the crust
##    (stage 5), and the find beat plays when its head gets into the hollow.
class_name SecretHalls
extends SecretSpot

const DRAWS: Array[StringName] = [&"picnic_basket", &"cloud_nest", &"hollow_stump"]

const CHECK_RED := Color("e0483a")
const CLOTH := Color("fff6ea")
const WICKER := Color("c98c52")
const WICKER_DARK := Color("8a5a30")
const JAM := Color("dc3657")
const CLOUD := Color("f4f7ff")
const CLOUD_SHADE := Color("cfdcf5")
const BARK := Color("9a6a3e")
const BARK_DARK := Color("6e4526")
const HOLLOW := Color("e2a866")
const HOLLOW_GLOW := Color(1.0, 0.86, 0.5, 0.35)
const MOSS := Color("6fcf5a")
const LEAF := Color("f08a3c")
const RAINBOW: Array[Color] = [Color("e0483a"), Color("ffb03a"), Color("ffd23f"), Color("6fcf5a"), Color("4f9be0"), Color("8a7be0")]


static func draws(id: StringName) -> bool:
	return id in DRAWS


func _draw() -> void:
	if data == null:
		return
	match data.id:
		&"picnic_basket":
			_draw_picnic_basket()
		&"cloud_nest":
			_draw_cloud_nest()
		&"hollow_stump":
			_draw_hollow_stump()
		_:
			super._draw()


func _draw_picnic_basket() -> void:
	var r := data.radius_tiles * 16.0
	var fy := -r * 0.6   # the floor of the pocket
	draw_circle(Vector2.ZERO, r * 0.95, Color(1.0, 0.85, 0.5, 0.09))   # warm glow
	# the cloth, checked red and cream, spread over the floor
	var w := r * 1.3
	var cols := 8
	for i in cols:
		var x0 := -w * 0.5 + w * i / cols
		var x1 := x0 + w / cols
		var col := CHECK_RED if i % 2 == 0 else CLOTH
		_poly([Vector2(x0, fy - 2), Vector2(x1, fy - 2), Vector2(x1, fy + 6), Vector2(x0, fy + 6)], col)
		col = CLOTH if i % 2 == 0 else CHECK_RED
		_poly([Vector2(x0, fy + 6), Vector2(x1, fy + 6), Vector2(x1, fy + 13), Vector2(x0, fy + 13)], col)
	# the basket: wicker body, lid propped open, the handle arching over
	var bx := -r * 0.12
	_poly([Vector2(bx - 26, fy + 34), Vector2(bx + 26, fy + 34), Vector2(bx + 20, fy + 10), Vector2(bx - 20, fy + 10)], WICKER, 2.5)
	for k in 3:
		var y := fy + 15.0 + k * 7.0
		draw_line(_p(bx - 21 + k, y), _p(bx + 21 - k, y), WICKER_DARK, 1.5)
	for k in 5:
		var x := bx - 16 + k * 8.0
		draw_line(_p(x, fy + 12), _p(x + 1.5, fy + 32), WICKER_DARK, 1.0)
	_poly([Vector2(bx - 26, fy + 34), Vector2(bx + 26, fy + 34), Vector2(bx + 30, fy + 44), Vector2(bx - 22, fy + 46)], WICKER, 2.0)   # the lid
	var handle := PackedVector2Array()
	for k in 11:
		var t := PI * k / 10.0
		handle.append(_p(bx + cos(t) * 20.0, fy + 34 + sin(t) * 18.0))
	draw_polyline(handle, INK, 4.0)
	draw_polyline(handle, WICKER, 2.0)
	# the jam jar, tipped over, and jam drops trickling out
	var jx := r * 0.48
	_poly([Vector2(jx - 10, fy + 2), Vector2(jx + 8, fy + 2), Vector2(jx + 10, fy + 16), Vector2(jx - 8, fy + 16)], Color(JAM, 0.95), 2.0)
	_poly([Vector2(jx + 8, fy + 3), Vector2(jx + 13, fy + 3), Vector2(jx + 14, fy + 15), Vector2(jx + 10, fy + 15)], Color("e8e2d0"), 1.5)   # lid
	draw_circle(_p(jx - 4, fy + 11), 2.0, Color(1, 1, 1, 0.7))
	for k in 3:
		var drip := sin(_t * 2.0 + k * 1.7) * 1.2
		draw_circle(_p(jx - 16 - k * 7.0, fy + 1 + drip * 0.3), 3.0, INK)
		draw_circle(_p(jx - 16 - k * 7.0, fy + 1 + drip * 0.3), 2.2, JAM)
	# a little paper flag on a toothpick in the basket
	draw_line(_p(bx + 8, fy + 34), _p(bx + 10, fy + 52), INK, 1.5)
	_poly([Vector2(bx + 10, fy + 52), Vector2(bx + 22, fy + 49), Vector2(bx + 10, fy + 45)], Color("ffd23f"), 1.0)


func _draw_cloud_nest() -> void:
	var r := data.radius_tiles * 16.0
	var bob := sin(_t * 0.9) * 3.0
	# a soft rainbow behind the island
	for i in RAINBOW.size():
		var arc := PackedVector2Array()
		var rr := r * 1.05 - i * 5.0
		for k in 21:
			var t := PI * k / 20.0
			arc.append(_p(cos(t) * rr, -r * 0.1 + sin(t) * rr * 0.8 + bob))
		draw_polyline(arc, Color(RAINBOW[i], 0.75), 5.0)
	# the cloud island: overlapping puffs, a shaded underside
	var puffs := [Vector3(-0.55, -0.35, 0.36), Vector3(-0.2, -0.22, 0.44), Vector3(0.22, -0.25, 0.42),
			Vector3(0.58, -0.38, 0.32), Vector3(0.0, -0.5, 0.38), Vector3(-0.35, -0.52, 0.3), Vector3(0.38, -0.55, 0.28)]
	for q in puffs:
		draw_circle(_p(q.x * r, q.y * r + bob), q.z * r + 2.5, INK)
	for q in puffs:
		draw_circle(_p(q.x * r, q.y * r + bob - 2.0), q.z * r, CLOUD_SHADE)
	for q in puffs:
		draw_circle(_p(q.x * r, q.y * r + bob + 1.5), q.z * r * 0.88, CLOUD)
	# the nest on top: a bowl of twigs, three blue eggs, a feather
	var ny := r * 0.08 + bob
	var bowl := PackedVector2Array()
	for k in 13:
		var t := PI + PI * k / 12.0
		bowl.append(_p(cos(t) * 30.0, ny + 8.0 + sin(t) * 16.0))
	for k in 3:
		var e := _p(-14.0 + k * 14.0, ny + 12.0 + (k % 2) * 2.0)
		draw_circle(e, 8.0, INK)
		draw_circle(e, 6.8, Color("bfe8ff"))
		draw_circle(e + _p(-2, 2), 1.5, Color("7fb0d8"))
	draw_colored_polygon(bowl, INK)
	for k in 5:
		var y := ny + 6.0 - k * 2.5
		var half := 28.0 - k * 4.0
		draw_line(_p(-half, y), _p(half, y - 1.0), Color("8a5a30") if k % 2 == 0 else Color("a87a48"), 2.0)
	draw_line(_p(26, ny + 10), _p(38, ny + 24), INK, 3.0)
	draw_line(_p(26, ny + 10), _p(38, ny + 24), Color("ffb03a"), 1.5)   # a feather sticking out
	# drifting sparkles
	for i in 6:
		var a := TAU * i / 6.0 + _t * 0.4
		var sp := _p(cos(a) * r * 0.9, sin(a) * r * 0.45 + bob)
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + i)
		draw_line(sp + Vector2(-3 * tw, 0), sp + Vector2(3 * tw, 0), Color(1, 1, 1, 0.9), 1.0)
		draw_line(sp + Vector2(0, -3 * tw), sp + Vector2(0, 3 * tw), Color(1, 1, 1, 0.9), 1.0)


## Height (px) of the hall's centre above the planet's surface: the stump's foot stands on the grass.
func ground_y() -> float:
	if director == null or director.planet_radius_px <= 0.0:
		return -data.radius_tiles * 16.0 * 1.2
	return director.planet_radius_px - position.length()


func _draw_hollow_stump() -> void:
	var r := data.radius_tiles * 16.0
	var g := ground_y()          # the grass line, below the centre (negative y)
	var top := r * 0.95          # the cut top
	var w := r * 1.05            # half width of the trunk
	# roots spreading into the grass
	for side in [-1.0, 1.0]:
		_poly([Vector2(side * w * 0.7, g + 22), Vector2(side * (w + 26), g - 2), Vector2(side * (w + 30), g - 6),
				Vector2(side * w * 0.95, g + 4)], BARK, 2.5)
	# the trunk: a slightly wider foot, the cut top
	_poly([Vector2(-w * 1.08, g - 2), Vector2(w * 1.08, g - 2), Vector2(w, top), Vector2(-w, top)], BARK, 3.0)
	for k in 5:    # bark grooves
		var x := lerpf(-w * 0.85, w * 0.85, k / 4.0)
		draw_line(_p(x, g + 6), _p(x * 0.96, top - 8), BARK_DARK, 2.0)
	# the cut top: rings in a flat ellipse
	var ell := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		ell.append(_p(cos(t) * w, top + sin(t) * 10.0))
	draw_colored_polygon(ell, INK)
	var ell2 := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		ell2.append(_p(cos(t) * (w - 3), top + sin(t) * 8.0))
	draw_colored_polygon(ell2, Color("e8c48a"))
	for ring in [0.7, 0.45, 0.2]:
		var rr := PackedVector2Array()
		for k in 25:
			var t := TAU * k / 24.0
			rr.append(_p(cos(t) * w * ring, top + sin(t) * 7.0 * ring))
		draw_polyline(rr, Color("c49a5e"), 1.5)
	# a new sprout on the top, two leaves nodding
	var sway := sin(_t * 1.6) * 2.0
	draw_line(_p(w * 0.3, top), _p(w * 0.3 + sway, top + 22), INK, 3.0)
	draw_line(_p(w * 0.3, top), _p(w * 0.3 + sway, top + 22), MOSS, 1.5)
	for side in [-1.0, 1.0]:
		_poly([Vector2(w * 0.3 + sway, top + 20), Vector2(w * 0.3 + sway + side * 12, top + 26),
				Vector2(w * 0.3 + sway + side * 4, top + 18)], MOSS, 1.5)
	# the cut-away hollow: warm wood inside, lit from within
	var hy := (g + top) * 0.5 - 4.0
	var hw := w * 0.72
	var hh := (top - g) * 0.36
	draw_circle(_p(0, hy), hh * 1.3, HOLLOW_GLOW)
	var hol := PackedVector2Array()
	var hol2 := PackedVector2Array()
	for k in 28:
		var t := TAU * k / 28.0
		hol.append(_p(cos(t) * (hw + 3), hy + sin(t) * (hh + 3)))
		hol2.append(_p(cos(t) * hw, hy + sin(t) * hh))
	draw_colored_polygon(hol, INK)
	draw_colored_polygon(hol2, HOLLOW)
	for k in 3:    # the inside wall's grain
		var y := hy + hh * (0.5 - k * 0.3)
		var half := hw * sqrt(maxf(0.0, 1.0 - pow((y - hy) / hh, 2.0))) * 0.8
		draw_line(_p(-half, y), _p(half, y + 2), Color("c98c52"), 1.5)
	# a leaf bed on the hollow's floor and a pile of golden acorns on it
	var fy := hy - hh * 0.78
	for k in 6:
		var x := lerpf(-hw * 0.7, hw * 0.7, k / 5.0)
		_poly([Vector2(x - 9, fy), Vector2(x + 9, fy + 2), Vector2(x, fy + 7)], LEAF if k % 2 == 0 else Color("ffb03a"), 1.0)
	for spec in [Vector2(-16, 6), Vector2(-3, 7), Vector2(10, 6), Vector2(-9, 15), Vector2(4, 16)]:
		var c := _p(spec.x, fy + spec.y)
		draw_circle(c, 6.5, INK)
		draw_circle(c, 5.2, Color("ffc83a"))
		var cap := _p(spec.x, fy + spec.y + 4.0)
		draw_circle(cap, 4.2, INK)
		draw_circle(cap, 3.2, Color("a0683a"))
		draw_circle(c + _p(-1.5, 1.0), 1.4, Color(1, 1, 1, 0.7))
	# twinkles over the pile
	for i in 4:
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + i * 1.7)
		var sp := _p(-20.0 + i * 13.0, fy + 26.0 + (i % 2) * 6.0)
		draw_line(sp + Vector2(-3 * tw, 0), sp + Vector2(3 * tw, 0), Color(1, 1, 0.8, 0.9), 1.2)
		draw_line(sp + Vector2(0, -3 * tw), sp + Vector2(0, 3 * tw), Color(1, 1, 0.8, 0.9), 1.2)
	# moss on the foot and a red toadstool by the roots
	for k in 5:
		draw_circle(_p(-w * 0.95 + k * 7.0, g + 4 + (k % 2) * 3.0), 5.0, MOSS)
	var tx := w * 0.75
	draw_line(_p(tx, g), _p(tx, g + 12), INK, 4.0)
	draw_line(_p(tx, g), _p(tx, g + 12), Color("fff6ea"), 2.0)
	_poly([Vector2(tx - 10, g + 11), Vector2(tx + 10, g + 11), Vector2(tx, g + 20)], Color("e0483a"), 1.5)
	draw_circle(_p(tx - 2, g + 14), 1.5, Color.WHITE)
	draw_circle(_p(tx + 3, g + 13), 1.2, Color.WHITE)
