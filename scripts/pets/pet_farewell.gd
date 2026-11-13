## Kid-check N5: a pet carried home when one of its kind already lives there is not taken quietly.
## The newcomer is shown going back to the wild: it rises out of the room the way it came (away
## from the core), wings or legs going, a heart over it, and fades out in FLY_SECS with the
## `pet_away` cue (the ladybird's own leaving sound). The resident pet still says hello
## (Burrow.bring). Not a pet: not counted, not saved, not in group `pets`; it frees itself.
class_name PetFarewell
extends Node2D

signal gone(id: StringName)

const FLY_SECS := 1.6
const SPEED := 45.0

var data: PetData
## Away from the core, in the parent's space.
var up := Vector2.UP
var t := 0.0


static func make(p_data: PetData, at: Vector2, p_up: Vector2) -> PetFarewell:
	var f := PetFarewell.new()
	f.data = p_data
	f.position = at
	f.up = p_up.normalized() if p_up.length() > 0.01 else Vector2.UP
	f.z_index = 2
	return f


func _ready() -> void:
	add_to_group(&"pet_farewell")
	PetLook.register_pictures()
	Audio.play("pet_away")


func _physics_process(delta: float) -> void:
	step(delta)


## Advances the farewell (tests call it directly).
func step(delta: float) -> void:
	if t >= FLY_SECS:
		return
	t += delta
	position += up * SPEED * delta
	modulate.a = clampf(1.0 - maxf(0.0, t - FLY_SECS * 0.5) / (FLY_SECS * 0.5), 0.0, 1.0)
	queue_redraw()
	if t >= FLY_SECS:
		gone.emit(data.id if data else &"")
		queue_free()


func _draw() -> void:
	if data == null:
		return
	var r := data.food.radius if data.food else 4.0
	var flap := 0.6 + 0.4 * sin(t * 30.0)
	PetLook.draw(self, data.look, Vector2.ZERO, r, up.angle(), t * 4.0, flap, data.color)
	var h := up * (r + 6.0 + t * 6.0)   # a heart over it: it liked visiting
	draw_circle(h + up.orthogonal() * 1.4, 1.8, Color(1, 0.5, 0.6))
	draw_circle(h - up.orthogonal() * 1.4, 1.8, Color(1, 0.5, 0.6))
	draw_circle(h - up * 1.6, 1.3, Color(1, 0.5, 0.6))
