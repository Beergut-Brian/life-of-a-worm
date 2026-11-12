## The lawnmower (stage 5, L-12; GAME.md "Bugs and threats"): a creature that drives back and forth
## along the surface, very loud, mowing the grass, and bumps a worm it runs into. It is not a threat
## that hunts: it never turns toward a worm, never eats one, and is never food itself (like the
## boot's shadow, it leaves the "food" group). The bump is a push, never a steer: the worm keeps its
## stick the whole time and can dig straight back down.
##
## - Drives: along the ground line (cached per tile column), `drive` px either side of its home,
##   turning round at each end with a putt of exhaust. Rides over its own mowed strip.
## - Very loud: the engine (`cue`, a loop) is loud near a worm and fades with distance; a warning
##   bark (`bark`) and a honk when a worm it could bump is ahead on the grass.
## - Eats grass only: the top grass tile under its blade is mowed (dug; it regrows at the ring's
##   rate). It never takes a food, a creature or a worm.
## - Bumps: a worm (its size or smaller) touching it, warned at least `telegraph` seconds earlier,
##   is knocked up off the grass and away (`bump` px over ~0.4 s), with the cause beat: the mower's
##   shadow flashes, a boing star, `bump_cue`, and a quick camera beat (shake, one step closer).
##   A bigger worm just makes it honk and turn round.
## Placeholder shape drawn in code (no new art).
class_name Lawnmower
extends Creature

signal bumped(player: int, push: Vector2)
signal beat_requested(player: int, at: Vector2)
signal mowed(cell: Vector2i)

const KNOCK_DECAY := 8.0
const KNOCK_TIME := 0.45
const BEAT_TIME := 0.6
const BEAT_SHAKE := 0.35
const TURN_PAUSE := 0.5
const HONK_TIME := 0.5
const BARK_GAP := 4.0
const LANE := 46.0        # px above / below the line a worm counts as "on the grass" in its way

var angle := 0.0          # where it is round the planet (radians)
var home_angle := 0.0
var drive_dir := 1.0
## Fallback line radius (px from the core) when there is no world (tests, scratch frames).
var line_r := 0.0
var mowed_count := 0
var bumps := 0
var beats := 0
## player -> seconds since it was warned about (the telegraph).
var warned := {}
var _knocks: Array[Dictionary] = []   # {worm, v, t}
var _cool := {}                       # player -> seconds left before it can be bumped again
var _ground := {}                     # column key -> ground radius px
var _mowed := {}                      # cells this mower mowed
var _pause := 0.0
var _honk := 0.0
var _flash := 0.0
var _beat_t := 0.0
var _leaning := false
var _camera: PolarCamera
var _engine: AudioStreamPlayer
var _star_at := Vector2.ZERO


func _ready() -> void:
	super._ready()
	remove_from_group(&"food")   # never food, at any size
	if line_r <= 0.0:
		line_r = position.length()
	angle = position.angle() if position != Vector2.ZERO else -PI / 2.0
	home_angle = angle
	drive_dir = 1.0 if randf() < 0.5 else -1.0
	_place()
	if mower() and mower().cue != "":
		_engine = Audio.loop_player(mower().cue)
		_engine.volume_db = -40.0
		add_child(_engine)
		_engine.play()


func _exit_tree() -> void:
	if _engine:
		_engine.stop()
		_engine.stream = null
	_release_camera()


func mower() -> LawnmowerData:
	return data as LawnmowerData


# --- never food, never eats -------------------------------------------------------------------

func is_available() -> bool:
	return false


func take() -> void:
	pass


func can_be_eaten_by(_w: Node) -> bool:
	return false


func threatens(_w: Node) -> bool:
	return false


# --- the line it drives -----------------------------------------------------------------------

func cell_px() -> float:
	return float(world.shape.cell_size) if world else 16.0


## Ground radius (px from the core) under this angle: the top of the solid ground, cached per tile
## column so the strip it mows does not lower its line; re-read if something else ate the top.
func ground_r(a: float) -> float:
	if world == null:
		return line_r
	var r0 := float(world.shape.radius) * cell_px()
	var key := roundi(a * r0 / cell_px())
	if _ground.has(key):
		var r: float = _ground[key]
		var top := world.shape.cell_at(Vector2.from_angle(a) * (r - cell_px() * 0.5))
		if world.is_solid(top) or _mowed.has(top):
			return r
	var r := WorldDestruct.surface_distance(world, a)
	_ground[key] = r
	return r


func up() -> Vector2:
	return Vector2.from_angle(angle)


## The way it drives, world space (along the surface).
func way() -> Vector2:
	return Vector2.from_angle(angle + PI / 2.0) * drive_dir


func _place() -> void:
	position = up() * (ground_r(angle) + _body_h())
	rotation = angle + PI / 2.0
	facing = drive_dir


func _body_h() -> float:
	return (data.radius if data else 24.0) * 0.55


# --- one tick ---------------------------------------------------------------------------------

func step(delta: float) -> void:
	if _gone or data == null:
		return
	_t += delta
	_pause = maxf(0.0, _pause - delta)
	_honk = maxf(0.0, _honk - delta)
	_flash = maxf(0.0, _flash - delta)
	_barked = maxf(0.0, _barked - delta)
	for p in _cool.keys():
		_cool[p] = maxf(0.0, _cool[p] - delta)
	_knock_step(delta)
	_beat_step(delta)
	var worms := _worms()
	_warn(worms, delta)
	var blocked := _touch(worms)
	if _pause <= 0.0 and not blocked:
		_drive(delta)
	_place()
	_mow()
	_engine_volume(worms)
	queue_redraw()


func _drive(delta: float) -> void:
	var r := maxf(ground_r(angle), 1.0)
	angle += drive_dir * data.speed * delta / r
	var off := wrapf(angle - home_angle, -PI, PI) * r
	var reach := mower().drive if mower() else 240.0
	if absf(off) >= reach and signf(off) == drive_dir:
		turn_round()


func turn_round() -> void:
	drive_dir = -drive_dir
	_pause = TURN_PAUSE
	facing = drive_dir


## A worm it could bump, ahead of it on the grass: the warning (bark, honk). The time since is the
## telegraph a bump waits for.
func _warn(worms: Array, delta: float) -> void:
	var seen := {}
	for w in worms:
		if not _bumpable(w):
			continue
		var rel: Vector2 = w.head_position() - global_position
		var along := rel.dot(way())
		var height := rel.dot(up())
		var near := rel.length() < data.radius * 2.0
		if (along > -data.radius and along < data.notice and absf(height) < LANE) or near:
			seen[w.player] = true
			if not warned.has(w.player):
				warned[w.player] = 0.0
				_honk = HONK_TIME
				if _barked <= 0.0:
					_barked = BARK_GAP
					Audio.play(data.bark)
			else:
				warned[w.player] += delta
	for p in warned.keys():
		if not seen.has(p):
			warned.erase(p)


## Worms touching it: bump the ones warned long enough; brake (honking) for the rest. A bigger
## worm turns it round. True when it should not move on this frame.
func _touch(worms: Array) -> bool:
	var stop := false
	for w in worms:
		var d: float = w.head_position().distance_to(global_position)
		if d > touch_range(w):
			continue
		if not _bumpable(w):
			if _pause <= 0.0 and way().dot(w.head_position() - global_position) > 0.0:
				_honk = HONK_TIME
				turn_round()
			continue
		if _cool.get(w.player, 0.0) > 0.0:
			continue
		if float(warned.get(w.player, -1.0)) >= data.telegraph_time():
			bump(w)
		else:
			stop = true
			_honk = HONK_TIME
	return stop


func touch_range(w: Node) -> float:
	var head_r := 8.0 * (1.0 + Worm.SIZE_STEP * (int(w.model.stage) - 1)) if w.get("model") else 8.0
	return data.radius + head_r


## Its size or smaller (bigger worms are never pushed about by it).
func _bumpable(w: Node) -> bool:
	return w != null and w.get("model") != null and CreatureSense.worm_size(w, data) <= data.size_stage


## The bump: a push up off the grass and away along its way, the cue, and the cause beat. Never
## a bite: the worm keeps every segment and its stick.
func bump(w: Node) -> Vector2:
	var side := signf((w.head_position() - global_position).dot(way().normalized()))
	var along := way() * (side if side != 0.0 else 1.0)
	var push := (up() * 0.8 + along * 0.6).normalized() * (mower().bump if mower() else 90.0)
	_knocks.append({"worm": w, "v": push * KNOCK_DECAY, "t": 0.0})
	_cool[w.player] = mower().bump_cooldown if mower() else 1.6
	warned.erase(w.player)
	bumps += 1
	_flash = BEAT_TIME
	_honk = HONK_TIME
	_pause = TURN_PAUSE
	_star_at = to_local(w.head_position())
	if mower() and mower().bump_cue != "":
		Audio.play(mower().bump_cue)
	bumped.emit(w.player, push)
	request_beat(w)
	return push


## The knock: a decaying push added to the head each tick (the worm still steers on top of it).
func _knock_step(delta: float) -> void:
	for i in range(_knocks.size() - 1, -1, -1):
		var k: Dictionary = _knocks[i]
		var w = k.worm
		k.t += delta
		if not is_instance_valid(w) or k.t > KNOCK_TIME:
			_knocks.remove_at(i)
			continue
		w.head.global_position += k.v * delta
		k.v *= exp(-KNOCK_DECAY * delta)


## The cause beat: the shadow flash (drawn), a quick shake and one zoom step closer for BEAT_TIME.
func request_beat(w: Node) -> void:
	beats += 1
	_beat_t = BEAT_TIME
	beat_requested.emit(w.player, global_position)
	_camera = _find_camera()
	if _camera == null:
		return
	if SettingsPanel.screen_shake():
		_camera.shake = maxf(_camera.shake, BEAT_SHAKE)
	if not _leaning:
		_leaning = true
		_camera.lean_in += 1


func _beat_step(delta: float) -> void:
	if _beat_t <= 0.0:
		return
	_beat_t -= delta
	if _beat_t <= 0.0:
		_release_camera()


func _release_camera() -> void:
	if _leaning and is_instance_valid(_camera):
		_camera.lean_in = maxi(0, _camera.lean_in - 1)
	_leaning = false


func _find_camera() -> PolarCamera:
	if not is_inside_tree():
		return null
	var rings := get_tree().get_first_node_in_group(&"rings")
	if rings and rings.get("level") and rings.level.get("camera") is PolarCamera:
		return rings.level.camera
	var c := get_viewport().get_camera_2d()
	return c as PolarCamera


## Mows the top grass tile under its blade (grass only: flowers, props, foods are left alone).
func _mow() -> void:
	if world == null:
		return
	var r := ground_r(angle)
	var cell := world.shape.cell_at(up() * (r - cell_px() * 0.5))
	if _mowed.has(cell) or world.get_tile(cell) != world.id_of(&"grass"):
		return
	if not world.dig(cell).is_empty():
		_mowed[cell] = true
		mowed_count += 1
		mowed.emit(cell)


func _engine_volume(worms: Array) -> void:
	if _engine == null or mower() == null:
		return
	var d := INF
	for w in worms:
		d = minf(d, w.head_position().distance_to(global_position))
	var k := clampf(1.0 - d / mower().hear, 0.0, 1.0)
	_engine.volume_db = lerpf(-30.0, mower().loud_db, k) if d < INF else -30.0
	_engine.pitch_scale = 0.85 if _pause > 0.0 else 1.0


# --- the look ---------------------------------------------------------------------------------

func draw_scale() -> float:
	return 1.0


func _draw() -> void:
	if data == null:
		return
	var r := data.radius
	var f := facing
	var shake := Vector2(sin(_t * 50.0) * 0.8, absf(sin(_t * 31.0)) * -0.8)   # engine rattle
	var ground := Vector2(0, _body_h())
	# The shadow: on the grass ahead of it, darker the longer a worm has been warned; flashes on a bump.
	var warn_k := 0.0
	for p in warned.keys():
		warn_k = maxf(warn_k, minf(1.0, float(warned[p]) / data.telegraph_time()))
	var sh := 0.22 + 0.25 * warn_k + 0.4 * (_flash / BEAT_TIME)
	var sl := r * (1.4 + 0.8 * warn_k)
	var poly := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		poly.append(ground + Vector2(f * r * 0.4 + cos(a) * sl, sin(a) * r * 0.22))
	draw_colored_polygon(poly, Color(0, 0, 0, sh))
	var o := shake
	# body: a boxy ride-on mower, no driver (the gardener is never seen)
	var col := data.color
	var body := Rect2(o + Vector2(-r, -r * 0.55), Vector2(r * 2.0, r * 0.8))
	draw_rect(body.grow(1.5), INK)
	draw_rect(body, col)
	draw_rect(Rect2(o + Vector2(-r * 0.9, -r * 0.5), Vector2(r * 1.8, r * 0.14)), col.lightened(0.3))
	# seat and steering wheel
	var seat := o + Vector2(-f * r * 0.35, -r * 0.55)
	draw_rect(Rect2(seat + Vector2(-r * 0.3, -r * 0.4), Vector2(r * 0.6, r * 0.4)), INK)
	draw_line(o + Vector2(f * r * 0.25, -r * 0.55), o + Vector2(f * r * 0.15, -r * 1.0), INK, 2.0)
	draw_line(o + Vector2(f * r * 0.0, -r * 1.0), o + Vector2(f * r * 0.32, -r * 1.0), INK, 2.5)
	# deck with the blade guard, just over the grass
	draw_rect(Rect2(o + Vector2(-r * 0.7, r * 0.2), Vector2(r * 1.4, r * 0.22)), INK)
	# wheels: big back, small front, turning
	var spin := _t * data.speed * 0.2 * drive_dir
	for wh in [[-f * r * 0.65, r * 0.42], [f * r * 0.7, r * 0.28]]:
		var c: Vector2 = o + Vector2(wh[0], ground.y - wh[1])
		draw_circle(c, wh[1] + 1.5, INK)
		draw_circle(c, wh[1], Color(0.25, 0.22, 0.2))
		draw_line(c, c + Vector2.from_angle(spin) * wh[1] * 0.8, Color(0.6, 0.6, 0.6), 1.5)
	# face on the front: headlight eyes (wide while honking), a grin grille
	var front := o + Vector2(f * r * 0.98, -r * 0.2)
	var e := r * 0.16
	for dy in [-r * 0.18, r * 0.1]:
		var c: Vector2 = front + Vector2(0, dy)
		draw_circle(c, e + 1.0 + (e * 0.4 if _honk > 0.0 else 0.0), INK)
		draw_circle(c, e + (e * 0.4 if _honk > 0.0 else 0.0), data.accent)
		draw_circle(c + Vector2(f * 1.0, 0), e * 0.45, INK)
	# exhaust pipe and puffs
	var pipe := o + Vector2(-f * r * 0.85, -r * 0.55)
	draw_line(pipe, pipe + Vector2(0, -r * 0.45), INK, 3.0)
	for i in 3:
		var k := fmod(_t * 1.6 + i / 3.0, 1.0)
		var p := pipe + Vector2(-f * k * r * 0.6, -r * 0.5 - k * r * 0.9)
		draw_circle(p, 2.0 + k * r * 0.25, Color(0.85, 0.85, 0.85, 0.7 * (1.0 - k)))
	# grass clippings flying out the side
	if _pause <= 0.0:
		for i in 4:
			var k := fmod(_t * 3.0 + i * 0.25, 1.0)
			var p := o + Vector2(-f * (r * 0.7 + k * r * 0.8), r * 0.25 - sin(k * PI) * r * 0.5)
			draw_rect(Rect2(p, Vector2(2.5, 2.5)), Color(0.45, 0.8, 0.3, 1.0 - k))
	# the honk: sound lines out of the front
	if _honk > 0.0:
		var k := 1.0 - _honk / HONK_TIME
		for i in 3:
			var a := (i - 1) * 0.45 + (0.0 if f > 0.0 else PI)
			var p := front + Vector2.from_angle(a) * (r * 0.4 + k * r * 0.6)
			draw_line(p, p + Vector2.from_angle(a) * r * 0.35, Color.WHITE, 2.0)
	# the boing star where it bumped the worm
	if _flash > 0.0:
		var k := _flash / BEAT_TIME
		var pts := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0 + _t * 3.0
			pts.append(_star_at + Vector2.from_angle(a) * (r * (0.9 if i % 2 == 0 else 0.4)) * (1.6 - k * 0.6))
		draw_colored_polygon(pts, Color(1.0, 0.95, 0.4, k))
