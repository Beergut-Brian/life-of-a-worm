## Stage 7, space: gravity off, camera follows the worm without rotating, sleepy planets drift as
## RigidBody2Ds, and the worm eats anything with a smaller size stage on contact (StageRule).
## --demo-chomp: an autopilot steers to the nearest edible planet so the demo shows the first bite.
## (Autopilot is demo-only; in play the worm is never moved for the player.)
class_name SpaceLevel
extends Node2D

signal ate(player: int, what: StringName, growth: float)

var demo := false
var eaten := 0
var shake := 0.0
var _debris: CPUParticles2D

@onready var worm: SpaceWorm = $Worm
@onready var camera: Camera2D = $Camera
@onready var _sfx: ProtoSfx = $Sfx


func _ready() -> void:
	demo = "--demo-chomp" in OS.get_cmdline_user_args()
	worm.touched.connect(func(b): resolve_contact(worm, b))
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
	camera.position = worm.position


func planets() -> Array[SpacePlanet]:
	var out: Array[SpacePlanet] = []
	for c in $Planets.get_children():
		if c is SpacePlanet and not c.eaten:
			out.append(c)
	return out


## Bigger eats smaller; a bigger planet bumps the worm back and wakes up. Returns the StageRule result.
func resolve_contact(eater: SpaceWorm, body: Node) -> int:
	var other := StageRule.stage_of(body)
	if other < 0 or (body is SpacePlanet and body.eaten):
		return StageRule.IGNORE
	var rel := StageRule.relation(eater.size_stage, other)
	match rel:
		StageRule.FOOD:
			var p := body as SpacePlanet
			p.be_eaten(eater.mouth)
			eaten += 1
			eater.mouth_open = 1.0
			eater.add_segment()
			shake = 16.0
			_sfx.play("space_bite")
			_debris.global_position = eater.mouth.global_position
			_debris.color = p.color()
			_debris.restart()
			var growth := float(eater.size_stage - other)
			ate.emit(eater.player, StringName("planet_" + String(p.theme)), growth)
			eater.ate.emit(eater.player, StringName("planet_" + String(p.theme)), growth)
		StageRule.THREAT:
			var away: Vector2 = (eater.global_position - (body as Node2D).global_position).normalized()
			eater.velocity = away * 520.0
			if body is SpacePlanet:
				body.wake()
				body.apply_central_impulse(-away * 60.0)
			shake = 8.0
			_sfx.play("space_bump")
	return rel


func _process(delta: float) -> void:
	worm.steer = (_demo_steer() if eaten == 0 else Vector2.ZERO) if demo else Players.move_vector(worm.player)
	camera.position = camera.position.lerp(worm.position, minf(1.0, delta * 3.0))
	shake = maxf(0.0, shake - delta * 40.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake


func _demo_steer() -> Vector2:
	var best: SpacePlanet = null
	for p in planets():
		if StageRule.relation(worm.size_stage, p.size_stage) == StageRule.FOOD:
			if best == null or p.position.distance_to(worm.position) < best.position.distance_to(worm.position):
				best = p
	if best == null:
		return Vector2(0.4, -0.2)
	return (best.position - worm.position).normalized() * 0.8
