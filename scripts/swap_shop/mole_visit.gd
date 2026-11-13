## L-09 "pops out of walls": now and then, while a worm digs through the dirt ring far from his
## nook, the Mole pops out of the tunnel wall right beside it: startled (exclaim + pop), he
## apologises (sheepish bubble + his bark, a bow), shows his swap offer with an arrow pointing back
## to his shop, then sinks back into the wall. He never moves the worm, never blocks it, is never
## food and leaves the ground as it was. Made by SwapShop as its child (top_level: world space).
class_name MoleVisit
extends Node2D

signal visited(player: int)

enum State { NONE, POP, SORRY, POINT, SINK }

## Digging time (s) in the dirt, away from the nook, between two visits.
const VISIT_EVERY := 70.0
## No visits this close to his nook (px): there he pops out of his own wall.
const AWAY_PX := 320.0
## How far beside the head (px) he looks for a wall to pop out of.
const REACH_PX := 48.0
## He pops out no closer than this to the head (px), so the worm never covers him.
const CLEAR_PX := 16.0
## His feet sit this far inside the wall (px): head, claws and belly poke out of it.
const IN_WALL_PX := 9.0
const POP_T := 0.5
const SORRY_T := 1.4
const POINT_T := 2.4
const SINK_T := 0.4
const SCALE := 0.9

var shop: SwapShop
var state := State.NONE
var player := -1
## Digging time banked toward the next visit.
var dig_t := 0.0
var visits := 0
var _state_t := 0.0
var _t := 0.0
var _wall_cell := Vector2i.ZERO
var _last := {}   # player -> head position last frame


func _ready() -> void:
	top_level = true
	z_index = 4   # over the worm's head
	visible = false
	add_to_group(&"jarling")
	add_to_group(&"creature")
	set_meta(&"creature_id", &"mole")


func _physics_process(delta: float) -> void:
	step(delta)


## One tick (tests call it directly with physics processing off).
func step(delta: float) -> void:
	_t += delta
	if state == State.NONE:
		_bank(delta)
		return
	_state_t += delta
	match state:
		State.POP:
			if _state_t >= POP_T:
				_set_state(State.SORRY)
				Audio.play("mole_sorry")
		State.SORRY:
			if _state_t >= SORRY_T:
				_set_state(State.POINT)
		State.POINT:
			if _state_t >= POINT_T:
				_sink()
		State.SINK:
			if _state_t >= SINK_T:
				_set_state(State.NONE)
				visible = false
	# A worm bit his wall away: he ducks back in.
	if state in [State.POP, State.SORRY, State.POINT] and _world() != null and not _world().is_solid(_wall_cell):
		_sink()
	queue_redraw()


func _bank(delta: float) -> void:
	var digger: Worm = null
	for w in Worm.all():
		var h := w.head.global_position
		var moved := h.distance_to(_last.get(w.player, h)) > 0.3
		_last[w.player] = h
		if moved and in_dirt_away(w):
			digger = w
	if digger == null:
		return
	dig_t += delta
	if dig_t >= VISIT_EVERY and shop != null and not shop.is_out():
		if visit(digger):
			dig_t = 0.0


func _world() -> PolarWorld:
	return shop.world if shop != null else null


## True when this worm's head is in the dirt ring and far from the nook.
func in_dirt_away(w: Worm) -> bool:
	var world := _world()
	if world == null:
		return false
	var h := w.head.global_position
	if h.distance_to(shop.global_position) < AWAY_PX:
		return false
	var r := world.ring_of(world.shape.cell_at(world.to_local(h)))
	return r != null and r.id == &"dirt"


## Pops him out of the wall beside this worm now. False when no dirt wall is in reach.
func visit(w: Worm) -> bool:
	if state != State.NONE:
		return false
	var spot := wall_spot(w)
	if spot.is_empty():
		return false
	global_position = spot.at
	# Local -y points out of the wall, into the tunnel.
	global_rotation = (spot.out as Vector2).angle() + PI / 2.0
	_wall_cell = spot.cell
	player = w.player
	visible = true
	visits += 1
	_set_state(State.POP)
	Audio.play("mole_pop")
	visited.emit(w.player)
	queue_redraw()
	return true


## Where he pops out: the first solid dirt cell ahead of the head on either side (then beside,
## then behind), as {at: his feet (world px, a little inside the wall so he pokes out of it),
## out: unit vector into the tunnel, cell: the wall cell he is in}.
func wall_spot(w: Worm) -> Dictionary:
	var world := _world()
	if world == null:
		return {}
	var h := w.head.global_position
	var fwd := Vector2.from_angle(w.heading)
	for ang: float in [0.9, -0.9, PI / 2.0, -PI / 2.0, 2.2, -2.2]:
		var dir := fwd.rotated(ang)
		var d := CLEAR_PX
		while d <= REACH_PX:
			var p := h + dir * d
			var cell := world.shape.cell_at(world.to_local(p))
			if world.is_solid(cell):
				var r := world.ring_of(cell)
				if r == null or r.id != &"dirt":
					break
				# Back off to the face of the wall, then sink his feet into it.
				var face := p
				while face.distance_to(h) > CLEAR_PX and world.is_solid(world.shape.cell_at(world.to_local(face - dir * 2.0))):
					face -= dir * 2.0
				var feet := face + dir * IN_WALL_PX
				var feet_cell := world.shape.cell_at(world.to_local(feet))
				if not world.is_solid(feet_cell):
					feet_cell = cell
				return { "at": feet, "out": -dir, "cell": feet_cell }
			d += 4.0
	return {}


func _sink() -> void:
	if state == State.SINK or state == State.NONE:
		return
	_set_state(State.SINK)
	Audio.play("mole_hide")


func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0


func is_out() -> bool:
	return state != State.NONE


# --- look -----------------------------------------------------------------------------------------

func _draw() -> void:
	if state == State.NONE:
		return
	var rise := 1.0
	var face := MoleLook.Face.SQUINT
	var bow := 0.0
	match state:
		State.POP:
			rise = clampf(_state_t / 0.25, 0.0, 1.0)
			face = MoleLook.Face.STARTLED
		State.SORRY:
			face = MoleLook.Face.SORRY
			bow = sin(clampf(_state_t / 1.0, 0.0, 1.0) * PI) * 0.6
		State.POINT:
			face = MoleLook.Face.HOPEFUL
		State.SINK:
			rise = 1.0 - clampf(_state_t / SINK_T, 0.0, 1.0)
	# Dirt crumbs where he broke through the wall.
	for i in 5:
		var x := (i - 2) * 5.0
		var y := -1.0 - absf(sin(_t * 2.0 + i)) * 1.5 * (1.0 if state == State.POP else 0.3)
		draw_circle(Vector2(x, y), 2.2, Color("6b4a32"))
	MoleLook.draw(self, Vector2.ZERO, SCALE, face, _t, bow, rise)
	# Bubbles stay upright on screen: "up" is away from the planet's centre.
	var world := _world()
	var up := Vector2.UP
	if world != null:
		var out := global_position - world.global_position
		if out.length() > 0.1:
			up = out.normalized()
	var up_local := up.rotated(-global_rotation)
	var tip := up_local * 26.0
	draw_set_transform(tip, up_local.angle() + PI / 2.0)
	match state:
		State.POP:
			PictoBubble.draw(self, Vector2.ZERO, [&"exclaim"], 1.0, 0.6)
		State.SORRY:
			PictoBubble.draw(self, Vector2.ZERO, [&"face_sheepish"], 1.0, 0.6)
		State.POINT:
			PictoBubble.draw(self, Vector2.ZERO, [&"star", &"swap_arrow", &"food:seed", &"food:seed"], 1.0, 0.6)
	draw_set_transform(Vector2.ZERO)
	# POINT: a bobbing arrow toward his shop (where the swap happens).
	if state == State.POINT and shop != null:
		var to_shop := (shop.global_position - global_position).rotated(-global_rotation)
		if to_shop.length() > 1.0:
			var dir := to_shop.normalized()
			var base := dir * (22.0 + 3.0 * sin(_t * 6.0))
			var ink := Color(MoleLook.INK, 0.9)
			var gold := Color(PictoBubble.GOLD, 0.95)
			var n := dir.orthogonal()
			var pts := PackedVector2Array([base + dir * 12.0, base + n * 6.0, base + n * 2.5, base - dir * 6.0 + n * 2.5, base - dir * 6.0 - n * 2.5, base - n * 2.5, base - n * 6.0])
			draw_colored_polygon(pts, gold)
			pts.append(pts[0])
			draw_polyline(pts, ink, 1.4)
