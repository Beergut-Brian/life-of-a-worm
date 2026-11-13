## W-10: loose things fall toward the core. A child node of any Node2D on the planet (a pebble
## pickup, a prop chunk, a surface prop): while the tile just under it (one step toward the core)
## is air, its parent falls with the disk's own gravity (world.shape.gravity_at(pos), which is
## -pos.normalized() * g), and it rests on the first solid tile it meets. A worm eating the tile
## under a resting thing is what sets it loose again; nothing else pushes it.
## Kinematic on purpose: foods are Node2D pickups the worm carries, pulls and hops, so a RigidBody
## (the addon's FallingBody) would fight the worm. Carried or eaten things never fall.
class_name LooseFall
extends Node

signal landed(body: Node2D, speed: float)

## Fall speed cap, px/s.
const MAX_SPEED := 520.0
## Longest move per collision check, px (under a third of a tile, so nothing skips a tile).
const STEP_PX := 4.0
## Touchdowns slower than this are silent (a nudge, not a landing).
const LAND_SPEED := 90.0
const LAND_CUE := "loose_land"

var world: TileWorld
## Distance from the parent's origin to its underside, px (a food's radius; 0 for a prop whose
## origin is its bottom edge).
var radius := -1.0
var velocity := Vector2.ZERO
var resting := false
## Landings with a sound (tests and the report read it).
var landings := 0

var _land_cool := 0.0


func _ready() -> void:
	if world == null:
		world = get_tree().get_first_node_in_group(&"world") as TileWorld
	if radius < 0.0:
		var p := get_parent()
		var d = p.get("data") if p else null
		radius = float(d.radius) if d != null and "radius" in d else 4.0


func _physics_process(delta: float) -> void:
	step(delta)


## One fall step. True while it is moving.
func step(delta: float) -> bool:
	_land_cool = maxf(0.0, _land_cool - delta)
	var body := get_parent() as Node2D
	if world == null or not is_instance_valid(world) or body == null or not _free(body):
		velocity = Vector2.ZERO
		return false
	var p := world.to_local(body.global_position)
	if p.length_squared() < 1.0:
		return false
	if velocity == Vector2.ZERO and supported_at(p):
		resting = true
		return false
	resting = false
	velocity = (velocity + world.shape.gravity_at(p) * delta).limit_length(MAX_SPEED)
	var move := velocity * delta
	var n := maxi(1, ceili(move.length() / STEP_PX))
	for i in n:
		var q := p + move / float(n)
		if world.is_solid(world.shape.cell_at(q)):
			# Sideways into a wall: keep only the fall toward the core.
			var down := -p.normalized()
			velocity = down * maxf(0.0, velocity.dot(down))
			move = velocity * delta
			q = p + down * maxf(0.0, move.dot(down)) / float(n)
			if world.is_solid(world.shape.cell_at(q)):
				_land(body, p)
				return false
		p = q
		if supported_at(p):
			_land(body, p)
			return false
	body.global_position = world.to_global(p)
	return true


## True when the cell just under p (toward the core) is solid.
func supported_at(p: Vector2) -> bool:
	var down := -p.normalized()
	return world.is_solid(world.shape.cell_at(p + down * (radius + 1.0)))


## Sets it falling now with this velocity (a chunk popping out of a prop).
func launch(v: Vector2) -> void:
	velocity = v
	resting = false


func _land(body: Node2D, p: Vector2) -> void:
	var speed := velocity.length()
	velocity = Vector2.ZERO
	# Touch down on the tile, not up to a step above it (the wall check stops a step early): a
	# resting thing is always supported, so it never creeps on after its landing.
	var down := -p.normalized()
	for i in ceili(STEP_PX * 2.0):
		if supported_at(p) or world.is_solid(world.shape.cell_at(p + down * 0.5)):
			break
		p += down * 0.5
	resting = true
	body.global_position = world.to_global(p)
	if speed < LAND_SPEED or _land_cool > 0.0:
		return
	_land_cool = 0.2
	landings += 1
	Audio.play(LAND_CUE)
	# The visual: a squash on touchdown and a puff of dust at its feet.
	var tw := body.create_tween()
	tw.tween_property(body, "scale", Vector2(1.35, 0.7), 0.06)
	tw.tween_property(body, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	WormHooks.juice().debris(world.to_global(p - p.normalized() * radius))
	landed.emit(body, speed)


func _free(body: Node2D) -> bool:
	if not body.visible or body.get("_gone") == true or body.get("_carried") == true:
		return false
	return not (body.get("broken") == true)
