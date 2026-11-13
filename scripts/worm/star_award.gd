## Star traits in space (D-10, worm-star-trait-1). A child of the SpaceStage scene: each themed
## planet wears its Star (the twinkling star SpacePlanet already draws), so the reward shows before
## it is eaten; eating the planet earns it through SpaceDrift's own star path (`star_earned`, once
## per run). Then the reveal: the trait's sting, two rings off the head, the camera leans in on
## that worm, and the trait's part flies from a big gold star into its orbit round the head.
## Only reads hooks: it never moves a worm. It drives two Star stats the space stage doesn't know:
## space_turn (steering accel x(1 + turn), sharper turns) and space_pull (small foods within that
## many px of the mouth drift in). The stage's own add_star handles speed, reach and steady.
class_name StarAward
extends Node2D

signal revealed(player: int, id: StringName)

const REVEAL_TIME := 1.8      # s: the camera beat and the part flying into orbit
const BEAT_ZOOM := 0.35       # camera zooms in by up to this share mid-beat
const BEAT_LEAN := 0.7        # and moves this share of the way to the earning worm
const PULL_SPEED := 170.0     # px/s a pulled food drifts at, relative to the worm
const PULL_ACCEL := 500.0
const PART_SCALE := 2.6       # a 16 px Star part drawn at this scale on its orbiting star

var stage: SpaceStage
## trait id -> reveals shown (earn only).
var reveals := {}
var _beat: Dictionary = {}
var _applied := {}
var _set_zoom := Vector2.ZERO     # what the beat last wrote, and what it was before
var _set_pos := Vector2.ZERO
var _base_zoom := Vector2.ONE
var _base_pos := Vector2.ZERO


func _ready() -> void:
	stage = get_parent() as SpaceStage
	process_priority = 10          # after the stage has placed its camera this frame
	process_physics_priority = 10
	z_index = 20
	if stage == null:
		return
	if stage.is_node_ready():
		_hook()
	else:
		stage.ready.connect(_hook, CONNECT_ONE_SHOT)


func _hook() -> void:
	stage.drift.arrived.connect(_on_arrived)
	stage.drift.star_earned.connect(_on_star_earned)
	PlanetPagePop.watch(stage)     # S-18: a planet eaten whole pops its book page
	_on_arrived(stage.drift.big)
	for w in stage.worms:          # stars restored from the tin
		for t in w.stars:
			_apply(w, t)


func _on_arrived(b: SpacePlanet) -> void:
	if b == null or b.kind != &"planet" or b.data == null:
		return
	var t: TraitData = b.data.star_trait
	if t != null and not stage.drift.star_taken(t.id):
		b.star_trait = t


func _worm(player: int) -> SpaceWorm:
	for w in stage.worms:
		if w.player == player:
			return w
	return null


func _trait(id: StringName) -> TraitData:
	for d in stage.drift.order:
		if d.star_trait != null and d.star_trait.id == id:
			return d.star_trait
	return null


func _on_star_earned(player: int, id: StringName) -> void:
	var w := _worm(player)
	var t := _trait(id)
	if w == null or t == null:
		return
	_apply(w, t)
	Audio.play(t.cue)
	for spec in [[t.color, 320.0, 1.0], [Color("ffd94a"), 220.0, 0.7]]:
		var r := WormRing.new()
		r.color = spec[0]
		r.max_radius = spec[1]
		r.life = spec[2]
		r.position = w.position
		r.z_index = 21
		stage.add_child(r)
	_beat = { "worm": w, "trait": t, "t": 0.0 }
	reveals[id] = int(reveals.get(id, 0)) + 1
	StarTraits.record(player, id)
	revealed.emit(player, id)


func _apply(w: SpaceWorm, t: TraitData) -> void:
	var key := "%d/%s" % [w.player, t.id]
	if _applied.has(key):
		return
	_applied[key] = true
	w.accel *= 1.0 + float(t.add.get("space_turn", 0.0))


func beat_showing() -> bool:
	return not _beat.is_empty()


static func _sum(w: SpaceWorm, stat: String) -> float:
	var v := 0.0
	for t in w.stars:
		v += float(t.add.get(stat, 0.0))
	return v


func _physics_process(delta: float) -> void:
	if stage == null or stage.drift == null:
		return
	for w in stage.worms:
		var pull := _sum(w, "space_pull")
		if pull <= 0.0:
			continue
		var m := w.mouth.global_position
		for p in stage.drift.get_children():
			if not (p is SpacePlanet) or p.eaten or not p.kind in [&"food", &"moon", &"comet"]:
				continue
			if StageRule.relation(w.size_stage, p.size_stage) != StageRule.FOOD:
				continue
			var d: Vector2 = m - p.global_position
			if d.length() < pull + p.radius and d.length() > 1.0:
				p.linear_velocity = p.linear_velocity.move_toward(w.velocity + d.normalized() * PULL_SPEED, PULL_ACCEL * delta)


func _process(delta: float) -> void:
	if stage == null:
		return
	if not _beat.is_empty():
		_beat.t += delta
		if _beat.t >= REVEAL_TIME or not is_instance_valid(_beat.worm):
			_beat = {}
		elif stage.camera:
			# the stage rewrites its camera every frame; if it didn't (a paused stage) don't stack
			var cam := stage.camera
			if cam.zoom != _set_zoom or cam.position != _set_pos:
				_base_zoom = cam.zoom
				_base_pos = cam.position
			var k := sin(PI * _beat.t / REVEAL_TIME)
			cam.zoom = _base_zoom * (1.0 + BEAT_ZOOM * k)
			cam.position = _base_pos.lerp(_beat.worm.position, BEAT_LEAN * k)
			_set_zoom = cam.zoom
			_set_pos = cam.position
	queue_redraw()


func _head_r(w: SpaceWorm) -> float:
	return w.seg_radius * 1.25 * (1.0 + w.squash * 0.15)


func _draw() -> void:
	if stage == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	# the planet's Star rider (SpacePlanet draws a small star) gets a big star and the part on it,
	# so what eating it will give is seen before it is eaten
	var big := stage.drift.big if stage.drift else null
	if big != null and not big.eaten and big.star_trait != null:
		var tex0 := big.star_trait.part_texture(1)
		var at0 := big.position + Vector2.from_angle(big._t * 1.5) * (big.radius + 26.0)
		_star(at0, 40.0 + 5.0 * sin(now * 8.0), Color("ffd94a"))
		if tex0 != null:
			var size0 := tex0.get_size() * PART_SCALE
			draw_texture_rect(tex0, Rect2(at0 - size0 * 0.5, size0), false)
	for w in stage.worms:
		var hr := _head_r(w)
		var reach := _sum(w, "space_reach")
		var pull := _sum(w, "space_pull")
		var m := to_local(w.mouth.global_position)
		if reach > 0.0:      # the bigger mouth, shown
			draw_arc(m, SpaceStage.MOUTH_SHAPE + reach, 0, TAU, 40, Color(0.37, 0.89, 0.42, 0.55), 5.0)
		if pull > 0.0:       # how far the sweet pull reaches: a dotted ring
			for i in 28:
				var a := i * TAU / 28.0 + now * 0.4
				draw_circle(m + Vector2.from_angle(a) * pull, 5.0, Color(1, 0.56, 0.82, 0.5))
		# positions below are stage-local, the same as this node's (it sits at the stage origin)
		# each Star's own part rides on its orbiting star (SpaceWorm draws the stars)
		for i in w.stars.size():
			var t := w.stars[i]
			var tex := t.part_texture(1)
			if tex == null:
				continue
			var at := w.position + Vector2.from_angle(now * 1.4 + i * TAU / w.stars.size()) * hr * 1.7
			var s := PART_SCALE
			if not _beat.is_empty() and _beat.worm == w and _beat.trait == t:
				var k := clampf(_beat.t / (REVEAL_TIME * 0.8), 0.0, 1.0)
				var from := w.position + Vector2(0, -hr * 4.0)
				var e := ease(k, 2.4)
				at = from.lerp(at, e)
				s = lerpf(9.0, PART_SCALE, e)
				_star(at, tex.get_width() * s * 0.85 * (1.0 + 0.08 * sin(now * 14.0)), Color("ffd94a"))
			else:
				_star(at, 30.0, Color("ffd94a"))     # every Star part rides on a gold star
			var size := tex.get_size() * s
			draw_texture_rect(tex, Rect2(at - size * 0.5, size), false)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, SpaceWorm.OUTLINE, 4.0)
