## Stage 7 (S-17, C-04, S-11): a separate scene with no tiles and no gravity. The camera opens on
## the fixed planet shot (centred where the planet was, zoom 1, no rotation), holds it, then eases out
## to follow the worms and never rotates again. A why bubble over the first worm shows the cause:
## the planet was eaten, so nothing pulls down any more.
## SpaceDrift (`drift`) brings the themed planets by, one at a time, with their foods, moons and
## comets; the worm's mouth eats anything smaller (StageRule FOOD), a bigger planet bumps it back
## (THREAT, a visible ring where it hit), and the sun comes last. The tin's "space" key keeps it.
## The stick only moves the worm: nothing here steers or moves a player.
class_name SpaceStage
extends Node2D

const HOLD := 0.9            # s on the fixed planet shot before the camera moves
const EASE := 2.6            # s to ease from the planet shot into space
const SPACE_ZOOM := 0.7
const WHY_TIME := 4.5
const BODY_SHAPE := 46.0
const MOUTH_SHAPE := 62.0
const SUN_WHY_TIME := 5.0

signal ate(player: int, what: StringName, growth: float)

## Who is in space, set before _ready (default: the active players, else P1).
var players: Array[int] = []
var worms: Array[SpaceWorm] = []
## The big thing drifting by now: this run's current themed planet, else the sun (null after it).
var planet: SpacePlanet
var drift: SpaceDrift
var camera: Camera2D
var why: WhyBubble
var sun_why: SunBubble
var shake := 0.0
var _debris: CPUParticles2D
var _flash: ColorRect
## 0 on the planet shot .. 1 following the worms.
var ease_k := 0.0
var _t := 0.0


func _ready() -> void:
	var back := CanvasLayer.new()
	back.layer = -9
	var fill := ColorRect.new()
	fill.color = Color("05060f")
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	add_child(back)
	for spec in [[420, 3, 0.3], [160, 11, 0.7]]:
		var s := Starfield.new()
		s.extent = Vector2(2600, 1600)
		s.count = spec[0]
		s.star_seed = spec[1]
		s.parallax = spec[2]
		add_child(s)
	if players.is_empty():
		for p in Players.active_players():
			players.append(p)
	if players.is_empty():
		players.append(Players.P1)
	for i in players.size():
		worms.append(_add_worm(players[i], Vector2(-60.0 + 120.0 * i, 40.0 * i)))
	drift = SpaceDrift.new()
	drift.name = "Drift"
	drift.centre_fn = worms_centre
	add_child(drift)
	var saved = Save.get_value(SpaceDrift.SAVE_KEY, {})
	drift.setup(load(SpaceDrift.LIFE_PATH), int(Save.get_value("seed", randi() % 100000)),
			saved if saved is Dictionary else {})
	drift.sun_eaten.connect(_on_sun_eaten)
	drift.arrived.connect(func(b): planet = b)
	drift.begin()
	for s in drift.stars:
		for w in worms:
			if w.player == int(s[0]):
				for d in drift.order:
					if d.star_trait != null and String(d.star_trait.id) == String(s[1]):
						w.add_star(d.star_trait)
	if drift.sun_gone:
		for w in worms:
			w.sun_glow = 1.0
	planet = drift.big if drift.big != null else drift.sun
	_add_effects()
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.ignore_rotation = true
	add_child(camera)
	camera.make_current()
	why = WhyBubble.new()
	why.z_index = 10
	add_child(why)
	why.show_for(WHY_TIME)
	Audio.play("warp")


func _add_worm(p: int, at: Vector2) -> SpaceWorm:
	var w := SpaceWorm.new()
	w.name = "Worm%d" % p
	w.player = p
	w.z_index = 2
	w.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	w.position = at
	var body := CollisionShape2D.new()
	var bc := CircleShape2D.new()
	bc.radius = BODY_SHAPE
	body.shape = bc
	w.add_child(body)
	var mouth := Area2D.new()
	mouth.name = "Mouth"
	var ms := CollisionShape2D.new()
	var mc := CircleShape2D.new()
	mc.radius = MOUTH_SHAPE
	ms.shape = mc
	mouth.add_child(ms)
	mouth.collision_mask = 1 | SpaceDrift.SMALL_LAYER
	w.add_child(mouth)
	add_child(w)
	w.touched.connect(func(b): resolve_contact(w, b))
	return w


func _add_effects() -> void:
	_debris = CPUParticles2D.new()
	_debris.one_shot = true
	_debris.emitting = false
	_debris.explosiveness = 0.9
	_debris.amount = 48
	_debris.lifetime = 1.0
	_debris.spread = 180.0
	_debris.gravity = Vector2.ZERO
	_debris.initial_velocity_min = 120.0
	_debris.initial_velocity_max = 420.0
	_debris.damping_min = 150.0
	_debris.damping_max = 300.0
	_debris.scale_amount_min = 6.0
	_debris.scale_amount_max = 14.0
	_debris.z_index = 3
	add_child(_debris)
	sun_why = SunBubble.new()
	sun_why.z_index = 10
	sun_why.visible = false
	add_child(sun_why)
	var top := CanvasLayer.new()
	top.layer = 5
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.85, 0.4, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_flash)
	add_child(top)


## The eaten path, as in SpaceLevel: bigger eats smaller (the thing flies into the mouth, a bite,
## debris, a new segment), a bigger planet bumps the worm back and shows where it hit. Nothing
## steers: the knock-back is a bounce, the stick still drives. Returns the StageRule result.
func resolve_contact(eater: SpaceWorm, body: Node) -> int:
	var other := StageRule.stage_of(body)
	if other < 0 or (body is SpacePlanet and body.eaten):
		return StageRule.IGNORE
	var rel := StageRule.relation(eater.size_stage, other)
	match rel:
		StageRule.FOOD:
			var p := body as SpacePlanet
			if p == null:
				return StageRule.IGNORE
			var what := StringName(String(p.kind) + "_" + String(p.theme))
			p.be_eaten(eater.mouth)
			eater.mouth_open = 1.0
			eater.add_segment()
			shake = 30.0 if p.kind in [&"planet", &"sun"] else 12.0
			Audio.play("space_bite")
			if _debris:
				_debris.global_position = eater.mouth.global_position
				_debris.color = p.color()
				_debris.restart()
			var growth := float(eater.size_stage - other)
			ate.emit(eater.player, what, growth)
			eater.ate.emit(eater.player, what, growth)
			if drift:
				drift.on_eaten(eater, p)
				planet = drift.big if drift.big != null else drift.sun
		StageRule.THREAT:
			var b := body as Node2D
			var away: Vector2 = (eater.global_position - b.global_position).normalized()
			eater.velocity = away * (drift.life.bump_speed if drift else 520.0) * eater.knock_scale
			if body is SpacePlanet:
				var p := body as SpacePlanet
				p.bump(p.global_position + away * p.radius)
				p.apply_central_impulse(-away * 60.0)
			shake = 8.0
			Audio.play("space_bump")
	return rel


func _on_sun_eaten(player: int) -> void:
	var w: SpaceWorm = null
	for x in worms:
		if x.player == player:
			w = x
	if w == null and not worms.is_empty():
		w = worms[0]
	for x in worms:
		create_tween().tween_property(x, "sun_glow", 1.0, 1.2)
	sun_why.colors.clear()
	for d in drift.order:
		sun_why.colors.append(d.color)
	if w:
		sun_why.worm_color = w.body_color()
	sun_why.show_for(SUN_WHY_TIME)
	_flash.color.a = 0.85
	create_tween().tween_property(_flash, "color:a", 0.0, 1.2).set_ease(Tween.EASE_OUT)
	shake = 40.0
	Audio.play("stage_up")
	Save.set_value("sun_eaten", true)


## Gravity is off for everything in here.
func gravity_on() -> bool:
	for c in get_children():
		if c is RigidBody2D and (c as RigidBody2D).gravity_scale != 0.0:
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	for w in worms:
		w.steer = Players.move_vector(w.player)
	step_world(delta)


## Everything a frame does apart from reading the stick (tests and staged shots call it directly).
func step_world(delta: float) -> void:
	step_camera(delta)
	# a planet that ripened (or the sun) while a mouth was already on it: eat it now
	for w in worms:
		for b in w.mouth.get_overlapping_bodies():
			if b is SpacePlanet and not b.eaten and b.ripe:
				resolve_contact(w, b)
	shake = maxf(0.0, shake - delta * 40.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if why and not worms.is_empty():
		why.position = worms[0].position + Vector2(0, -190)
	if sun_why and not worms.is_empty():
		sun_why.position = worms[0].position + Vector2(0, -230)


func step_camera(delta: float) -> void:
	if _t > HOLD:
		ease_k = minf(1.0, ease_k + delta / EASE)
	var k := smoothstep(0.0, 1.0, ease_k)
	camera.rotation = 0.0
	camera.position = Vector2.ZERO.lerp(worms_centre(), k)
	camera.zoom = Vector2.ONE * lerpf(1.0, SPACE_ZOOM, k)


func worms_centre() -> Vector2:
	if worms.is_empty():
		return Vector2.ZERO
	var c := Vector2.ZERO
	for w in worms:
		c += w.position
	return c / worms.size()
