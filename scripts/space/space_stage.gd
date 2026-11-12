## Stage 7 arrival, prototype (S-17, C-04): a separate scene with no tiles and no gravity. The camera
## opens on the fixed planet shot (centred where the planet was, zoom 1, no rotation), holds it, then
## eases out to follow the worms and never rotates again. One placeholder planet (a SpacePlanet, a
## RigidBody2D) drifts past; there is no hunting here yet. A why bubble over the first worm shows the
## cause: the planet was eaten, so nothing pulls down any more.
## The stick only moves the worm: nothing here steers or moves a player.
class_name SpaceStage
extends Node2D

const HOLD := 0.9            # s on the fixed planet shot before the camera moves
const EASE := 2.6            # s to ease from the planet shot into space
const SPACE_ZOOM := 0.7
const WHY_TIME := 4.5
const BODY_SHAPE := 46.0
const MOUTH_SHAPE := 62.0

## Who is in space, set before _ready (default: the active players, else P1).
var players: Array[int] = []
var worms: Array[SpaceWorm] = []
var planet: SpacePlanet
var camera: Camera2D
var why: WhyBubble
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
	planet = SpacePlanet.new()
	planet.name = "Planet"
	planet.size_stage = 9          # far too big to eat: there is no hunting in this prototype
	planet.theme = &"ice"
	planet.drift = Vector2(-26, 9)
	planet.position = Vector2(1250, -420)
	add_child(planet)
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
	w.add_child(mouth)
	add_child(w)
	return w


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
	step_camera(delta)
	if why and not worms.is_empty():
		why.position = worms[0].position + Vector2(0, -190)


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
