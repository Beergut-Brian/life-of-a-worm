## A ring's hidden place, drawn (placeholder, in code). Each is carved by RingsDirector and kept (a
## keep zone: it never regrows shut).
##  - ant_city: a little town of ant domes with lit windows and doors, flags with tiny hats and a
##    string of lights across the hall;
##  - sunken_rowboat: an aquifer pool at the foot of the dirt with Old Reel's lost rowboat sunk in it,
##    oars, his spilled green tackle tin, lures and rising bubbles;
##  - fossil_hall: a hall in the rock with layered walls, a long fish skeleton, curled shells and
##    little many-legged imprints set in the stone;
##  - geode_cathedral: a tall hall in the core rock lined with split geodes, crystal pillars in
##    violet, teal, pink and gold, shafts of coloured light and drifting sparkles (lit, never dark).
## The find beat (play_found_beat): a picture bubble over the hall, [the place] [its food] [the tackle
## box], popping in, held, then fading; the tackle box shows the same picture afterwards.
class_name SecretSpot
extends Node2D

const INK := Color("2a1a14")
const BEAT_IN := 0.3
const BEAT_HOLD := 4.5
const BEAT_OUT := 0.6
const BEAT_SCALE := 3.0

var data: SecretData
var director: RingsDirector
## Seconds since the find beat started; < 0 when not playing.
var beat_t := -1.0
var _t := 0.0
var _bubble: Node2D
## The camera the beat steers (default: the level's shared camera); seconds left on its hold.
var camera: PolarCamera
var camera_t := 0.0
var _cam_at = null
var _leaning := false


func _ready() -> void:
	z_index = -1
	SecretLook.register()


func _process(delta: float) -> void:
	_t += delta
	if beat_t >= 0.0:
		beat_t += delta
		if beat_t > BEAT_IN + BEAT_HOLD + BEAT_OUT:
			beat_t = -1.0
			if is_instance_valid(_bubble):
				_bubble.queue_free()
		elif is_instance_valid(_bubble):
			_bubble.queue_redraw()
	if camera_t > 0.0:
		camera_t -= delta
		if camera_t <= 0.0:
			_release_camera()
	if get_viewport().get_camera_2d() and get_viewport().get_camera_2d().get_screen_center_position().distance_to(position) < 1400.0:
		queue_redraw()


## The picture beat when the worm first gets in: a bubble pops up over the hall.
func play_found_beat() -> void:
	beat_t = 0.0
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = Node2D.new()
	_bubble.name = "FoundBubble"
	_bubble.z_as_relative = false
	_bubble.z_index = 80
	var up := position.normalized() if position != Vector2.ZERO else Vector2.UP
	_bubble.position = up * (data.radius_tiles * 16.0 * 0.55)
	_bubble.rotation = up.angle() + PI / 2.0   # local -y points away from the core
	_bubble.draw.connect(_draw_bubble)
	add_child(_bubble)
	if data.camera_beat > 0.0:
		_hold_camera()


func _hold_camera() -> void:
	if camera == null and director and director.level:
		camera = director.level.camera
	if camera == null:
		return
	_cam_at = global_position
	camera.centre_override = _cam_at
	camera_t = data.camera_beat
	# one step closer while it holds, if every worm still fits (the fit zoom checks that)
	if not _leaning:
		_leaning = true
		camera.lean_in += 1


func _release_camera() -> void:
	camera_t = 0.0
	if is_instance_valid(camera) and _cam_at != null and camera.centre_override == _cam_at:
		camera.centre_override = null
	if is_instance_valid(camera) and _leaning:
		camera.lean_in = maxi(0, camera.lean_in - 1)
	_leaning = false
	_cam_at = null


func _exit_tree() -> void:
	_release_camera()


## The bubble's pictures: the place, its food, the tackle box.
func beat_pictures() -> Array[StringName]:
	var out: Array[StringName] = []
	if data.lead_picture != &"":
		out.append(data.lead_picture)
	out.append_array([StringName("secret:%s" % data.id), StringName("secret_food:%s" % data.food), &"secret_box"])
	return out


func beat_alpha() -> float:
	if beat_t < 0.0:
		return 0.0
	if beat_t > BEAT_IN + BEAT_HOLD:
		return clampf(1.0 - (beat_t - BEAT_IN - BEAT_HOLD) / BEAT_OUT, 0.0, 1.0)
	return 1.0


func _draw_bubble() -> void:
	var k := BEAT_SCALE
	if beat_t < BEAT_IN:
		var f := beat_t / BEAT_IN
		k *= 0.6 + 0.4 * f + sin(f * PI) * 0.15
	var tip := Vector2(0, -6.0 * sin(_t * 2.5))
	PictoBubble.draw(_bubble, tip, beat_pictures(), beat_alpha(), k)


func _draw() -> void:
	if data == null:
		return
	match data.id:
		&"sunken_rowboat":
			_draw_rowboat()
		&"fossil_hall":
			_draw_fossil_hall()
		&"geode_cathedral":
			_draw_geode_cathedral()
		_:
			_draw_ant_city()


## A point in the hall's own frame: x along the ground, y up (away from the core).
func _p(x: float, y: float) -> Vector2:
	var up := position.normalized() if position != Vector2.ZERO else Vector2.UP
	return up.orthogonal() * x + up * y


func _poly(pts: Array, col: Color, outline := 0.0) -> void:
	var pp := PackedVector2Array()
	for q in pts:
		pp.append(_p(q.x, q.y))
	if outline > 0.0:
		var mid := Vector2.ZERO
		for q in pp:
			mid += q
		mid /= pp.size()
		var ol := PackedVector2Array()
		for q in pp:
			ol.append(q + (q - mid).normalized() * outline)
		draw_colored_polygon(ol, INK)
	draw_colored_polygon(pp, col)


func _draw_rowboat() -> void:
	var r := data.radius_tiles * 16.0
	var wl := -r * 0.05 + sin(_t * 1.2) * 1.5     # the waterline
	draw_circle(Vector2.ZERO, r * 0.95, Color(0.35, 0.65, 1.0, 0.07))   # cool glow
	# a fishing rod leaning on the left wall, line trailing into the water
	draw_line(_p(-r * 0.78, -r * 0.4), _p(-r * 0.35, r * 0.62), INK, 3.0)
	draw_line(_p(-r * 0.78, -r * 0.4), _p(-r * 0.35, r * 0.62), Color("c9a16a"), 1.5)
	draw_line(_p(-r * 0.35, r * 0.62), _p(-r * 0.2, wl), Color(1, 1, 1, 0.5), 1.0)
	draw_circle(_p(-r * 0.68, -r * 0.2), 3.5, Color("5a5a66"))               # the reel
	# the hull, sunk and tilted on the floor
	var fy := -r * 0.62
	var hull := []
	for q in [Vector2(-38, 14), Vector2(36, 18), Vector2(24, -6), Vector2(-26, -8)]:
		hull.append(q.rotated(0.18) + Vector2(-6, fy + 10))
	_poly(hull, Color("a0683a"), 2.5)
	for k in 2:
		var a: Vector2 = hull[0].lerp(hull[3], 0.35 + k * 0.3)
		var b: Vector2 = hull[1].lerp(hull[2], 0.35 + k * 0.3)
		draw_line(_p(a.x, a.y), _p(b.x, b.y), Color("6e4526"), 1.5)   # planks
	var bow: Vector2 = hull[1]
	draw_circle(_p(bow.x - 4, bow.y - 2), 2.0, Color("ffd36a"))      # the brass ring at the bow
	# oars: one in the boat, one on the floor
	draw_line(_p(-20, fy + 20), _p(20, fy + 32), INK, 3.5)
	draw_line(_p(-20, fy + 20), _p(20, fy + 32), Color("c98c52"), 2.0)
	_poly([Vector2(20, fy + 28), Vector2(34, fy + 32), Vector2(33, fy + 38), Vector2(19, fy + 35)], Color("c98c52"), 1.5)
	draw_line(_p(-r * 0.75, fy - 4), _p(-r * 0.3, fy - 10), INK, 3.0)
	# the tackle tin, lid open, lures spilled out
	var tx := r * 0.52
	_poly([Vector2(tx - 14, fy - 12), Vector2(tx + 14, fy - 12), Vector2(tx + 14, fy + 2), Vector2(tx - 14, fy + 2)], Color("3f6f5a"), 2.0)
	_poly([Vector2(tx - 14, fy + 2), Vector2(tx + 14, fy + 2), Vector2(tx + 20, fy + 14), Vector2(tx - 8, fy + 14)], Color("5d9a7c"), 2.0)
	var lures := [Color("e0483a"), Color("ffd23f"), Color("f08a3c"), Color("8a7be0")]
	for i in lures.size():
		var lp := _p(tx - 24 + i * 15.0, fy - 14.0 + (i % 2) * 3.0)
		draw_circle(lp, 3.6, INK)
		draw_circle(lp, 2.6, lures[i])
		draw_circle(lp + _p(3.5, 0), 1.4, Color.WHITE)
	# the water over it all (an aquifer pool, see-through)
	var a := asin(clampf(wl / (r * 0.97), -1.0, 1.0))
	var pool := PackedVector2Array()
	for k in 17:
		var th := (PI - a) + (PI + 2.0 * a) * k / 16.0
		pool.append(_p(cos(th) * r * 0.97, sin(th) * r * 0.97))
	var w := sqrt(maxf(0.0, r * r * 0.94 - wl * wl))
	var wave := PackedVector2Array()
	for k in 13:
		var x := lerpf(w, -w, k / 12.0)
		var pt := _p(x, wl + sin(_t * 2.0 + k * 0.9) * 1.6 * sin(PI * k / 12.0))   # ends meet the wall
		pool.append(pt)
		wave.append(pt)
	draw_colored_polygon(pool, Color(0.31, 0.61, 0.88, 0.42))
	draw_polyline(wave, Color(0.85, 0.95, 1.0, 0.8), 2.0)
	# bubbles rising from the boat
	for i in 4:
		var f := fmod(_t * 0.5 + i * 0.27, 1.0)
		var bp := _p(-10 + i * 9.0 + sin(_t * 3.0 + i) * 2.0, lerpf(fy + 14.0, wl - 2.0, f))
		draw_arc(bp, 2.0 + i % 2, 0.0, TAU, 12, Color(1, 1, 1, 0.7 * (1.0 - f * 0.5)), 1.0)
	# a cork floating on top, bobbing
	var cp := _p(r * 0.15, wl + 2.0 + sin(_t * 2.2) * 1.5)
	draw_circle(cp, 4.5, INK)
	draw_circle(cp, 3.5, Color("d9a066"))


func _draw_fossil_hall() -> void:
	var r := data.radius_tiles * 16.0
	# layered rock back wall, so it reads as a hall in the stone
	draw_circle(Vector2.ZERO, r * 0.96, Color("4a4e5c"))
	for k in 5:
		var y := lerpf(-r * 0.8, r * 0.7, k / 4.0)
		var w := sqrt(maxf(0.0, r * r * 0.9 - y * y))
		var band := PackedVector2Array()
		for i in 9:
			var x := lerpf(-w, w, i / 8.0)
			band.append(_p(x, y + sin(i * 1.3 + k) * 3.0))
		draw_polyline(band, Color(0.55, 0.58, 0.66, 0.6), 2.0)
	var g := 0.75 + 0.25 * sin(_t * 1.3)
	draw_circle(_p(0, -r * 0.3), r * 0.7, Color(1.0, 0.66, 0.15, 0.08 * g))   # warm glow from the amber
	# a long fish skeleton set in the back wall
	var bone := Color("efe4c8")
	var sx := -r * 0.55
	var ex := r * 0.45
	var y0 := r * 0.18
	draw_line(_p(sx, y0), _p(ex, y0), INK, 6.0)
	draw_line(_p(sx, y0), _p(ex, y0), bone, 3.5)
	for i in 9:
		var x := lerpf(sx + 12.0, ex - 10.0, i / 8.0)
		var h := 22.0 - absf(x) / r * 14.0
		for sgn in [-1.0, 1.0]:
			var tip := _p(x - 6.0, y0 + sgn * h)
			draw_line(_p(x, y0), tip, INK, 4.0)
			draw_line(_p(x, y0), tip, bone, 2.0)
	var skull := _p(ex + 12.0, y0 + 2.0)
	draw_circle(skull, 15.0, INK)
	draw_circle(skull, 13.0, bone)
	draw_circle(_p(ex + 16.0, y0 + 6.0), 3.5, INK)                         # eye hole
	draw_line(_p(ex + 14.0, y0 - 6.0), _p(ex + 25.0, y0 - 4.0), INK, 2.0)   # jaw
	for sgn in [-1.0, 1.0]:   # the tail fan, two fins
		_poly([Vector2(sx, y0), Vector2(sx - 26, y0 + sgn * 20), Vector2(sx - 16, y0 + sgn * 2)], bone, 2.0)
	# curled shells low on the walls
	for spec in [[-r * 0.62, -r * 0.35, 16.0], [r * 0.58, -r * 0.25, 13.0], [-r * 0.1, r * 0.66, 10.0]]:
		var c := _p(spec[0], spec[1])
		draw_circle(c, spec[2] + 2.0, INK)
		draw_circle(c, spec[2], Color("d8c9a6"))
		var pts := PackedVector2Array()
		for k in 30:
			var f := k / 29.0
			pts.append(c + Vector2.from_angle(f * TAU * 2.3 + _t * 0.0) * spec[2] * (1.0 - f * 0.85))
		draw_polyline(pts, INK, 2.0)
	# little many-legged imprints on the floor
	for spec in [[-r * 0.3, -r * 0.58], [r * 0.25, -r * 0.62]]:
		var c := _p(spec[0], spec[1])
		for k in 4:
			var ry := -6.0 + k * 4.0
			draw_line(c + _p(-9, ry), c + _p(9, ry), INK, 2.0)
		var shell := PackedVector2Array()
		for k in 13:
			var th := TAU * k / 12.0
			shell.append(c + _p(cos(th) * 7.0, sin(th) * 9.0))
		draw_colored_polygon(shell, Color("b9ad92"))
		draw_line(c + _p(0, -9), c + _p(0, 9), INK, 1.5)


const GEMS: Array[Color] = [Color("c46cff"), Color("5fe8ff"), Color("ff7ad9"), Color("ffd23f"), Color("7dff9a")]


func _draw_geode_cathedral() -> void:
	var r := data.radius_tiles * 16.0
	# the side chapels and the necks to them: lit violet too, a geode in each
	for room in RingsDirector.rooms_of(data, position):
		var o := Vector2(room.x, room.y)
		draw_circle(o * 0.5, 1.7 * 16.0, Color("8a5cb2"))
		draw_circle(o, room.z + 2.0, Color("7a4fa0"))
		draw_circle(o, room.z * 0.75, Color("b68ad8"))
		draw_circle(o, 9.0, INK)
		draw_circle(o, 7.5, Color("c9b8a6"))
		draw_circle(o, 5.5, GEMS[1])
		draw_circle(o, 2.0, Color(1, 1, 1, 0.6 + 0.3 * sin(_t * 2.0 + o.x)))
	# a warm lit back wall, lighter towards the top: a cathedral, never a dark cave
	draw_circle(Vector2.ZERO, r * 0.97, Color("7a4fa0"))
	draw_circle(_p(0, r * 0.12), r * 0.78, Color("9a6cc4"))
	draw_circle(_p(0, r * 0.3), r * 0.5, Color("c39be6"))
	# shafts of coloured light falling from the crown
	for i in 5:
		var x := lerpf(-r * 0.55, r * 0.55, i / 4.0)
		var sway := sin(_t * 0.7 + i) * 6.0
		var col := GEMS[i % GEMS.size()]
		var shaft := [Vector2(x - 6, r * 0.85), Vector2(x + 6, r * 0.85), Vector2(x + 22 + sway, -r * 0.6), Vector2(x - 22 + sway, -r * 0.6)]
		var pp := PackedVector2Array()
		for q in shaft:
			pp.append(_p(q.x, q.y))
		draw_colored_polygon(pp, Color(col, 0.16 + 0.06 * sin(_t * 1.5 + i)))
	# split geodes set round the walls: a rough rim, a ring of crystal teeth, a bright heart
	for i in 9:
		var a := TAU * i / 9.0 + 0.35   # all round the walls
		var gr := 11.0 + (i % 3) * 4.0
		var c := _p(cos(a) * r * 0.8, sin(a) * r * 0.8)
		var col := GEMS[i % GEMS.size()]
		draw_circle(c, gr + 2.0, INK)
		draw_circle(c, gr, Color("c9b8a6"))
		draw_circle(c, gr * 0.75, col)
		for k in 7:
			var ta := TAU * k / 7.0 + i
			var b := c + Vector2.from_angle(ta) * gr * 0.75
			draw_colored_polygon(PackedVector2Array([b + Vector2.from_angle(ta + 1.6) * gr * 0.2, c + Vector2.from_angle(ta) * gr * 0.3, b + Vector2.from_angle(ta - 1.6) * gr * 0.2]), col.lightened(0.5))
		draw_circle(c, gr * 0.22, Color(1, 1, 1, 0.6 + 0.3 * sin(_t * 2.0 + i)))
	# crystal pillars rising from the floor, tallest in the middle (the cathedral's nave)
	for i in 7:
		var x := lerpf(-r * 0.6, r * 0.6, i / 6.0)
		var h := r * (0.55 - absf(x) / r * 0.45)
		var w := 7.0 + (3 - absi(i - 3)) * 1.5
		var col := GEMS[(i + 1) % GEMS.size()]
		var base := -r * 0.7
		_poly([Vector2(x - w, base), Vector2(x + w, base), Vector2(x + w * 0.7, base + h), Vector2(x, base + h + w * 1.6), Vector2(x - w * 0.7, base + h)], col, 2.0)
		draw_line(_p(x, base + 2.0), _p(x, base + h + w), col.lightened(0.6), 1.5)
	# sparkles drifting up through the light
	for i in 10:
		var f := fmod(_t * 0.25 + i * 0.137, 1.0)
		var sp := _p(sin(i * 2.3) * r * 0.6 + sin(_t + i) * 4.0, lerpf(-r * 0.5, r * 0.8, f))
		var s := 2.5 * sin(f * PI) + 0.5
		var col := Color(GEMS[i % GEMS.size()].lightened(0.4), sin(f * PI))
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -s * 2), sp + Vector2(s * 0.6, 0), sp + Vector2(0, s * 2), sp + Vector2(-s * 0.6, 0)]), col)
		draw_colored_polygon(PackedVector2Array([sp + Vector2(-s * 2, 0), sp + Vector2(0, s * 0.6), sp + Vector2(s * 2, 0), sp + Vector2(0, -s * 0.6)]), col)


func _draw_ant_city() -> void:
	var up := position.normalized()
	var s := up.orthogonal()
	var r := data.radius_tiles * 16.0
	var floor_p := -up * (r * 0.62)
	# warm glow in the hall
	draw_circle(Vector2.ZERO, r * 0.9, Color(1.0, 0.8, 0.45, 0.08))
	# string of lights
	for i in 9:
		var t := float(i) / 8.0
		var p := s * lerpf(-r * 0.8, r * 0.8, t) + up * (r * 0.45 - sin(t * PI) * 14.0)
		var on := fmod(_t * 2.0 + i * 0.37, 1.0) > 0.25
		draw_circle(p, 2.5, Color("ffd36a") if on else Color("a8873a"))
	# domes along the floor
	var cols := [Color("c97b4a"), Color("b8693e"), Color("d68e57"), Color("a65e36")]
	for i in 4:
		var x := lerpf(-r * 0.65, r * 0.65, float(i) / 3.0)
		var base := floor_p + s * x
		var h := 16.0 + (i % 2) * 6.0
		var dome := PackedVector2Array()
		for k in 13:
			var t := PI * k / 12.0
			dome.append(base + s * cos(t) * 13.0 + up * sin(t) * h)
		draw_colored_polygon(dome, INK)
		var inner := PackedVector2Array()
		for k in 13:
			var t := PI * k / 12.0
			inner.append(base + s * cos(t) * 11.5 + up * (sin(t) * (h - 1.5)))
		draw_colored_polygon(inner, cols[i])
		draw_circle(base + up * 4.0, 3.5, INK)                                     # door
		var lit := 0.6 + 0.4 * sin(_t * 1.5 + i)
		draw_circle(base + up * (h * 0.6) + s * 5.0, 2.0, Color(1, 0.85, 0.4, lit))  # window
		# flag with a tiny hat on top
		var top := base + up * h
		draw_line(top, top + up * 10.0, INK, 1.0)
		draw_colored_polygon(PackedVector2Array([top + up * 10.0, top + up * 7.0 + s * 6.0, top + up * 4.0]), Color.from_hsv(0.1 * i, 0.7, 0.95))
