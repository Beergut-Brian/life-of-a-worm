## A pet living in the burrow (Burrow.add_pet). Job &"fetch" (the ladybird): every PetData.every
## planet seconds, if fewer than max_waiting things wait by the bed, it flies up out of the room,
## is away for PetData.trip seconds, and comes back carrying PetData.fetch, which it drops by the
## bed (Burrow.add_pantry) with a chirp. Between trips it potters round the bed. Saved by id + t.
class_name Pet
extends Node2D

signal fetched(id: StringName, what: StringName)

enum State { HOME, AWAY, BACK }

var data: PetData
var burrow: Burrow
## Seconds into the current wait (or trip).
var t := 0.0
var state := State.HOME
var trips := 0
var _anim := 0.0


func _ready() -> void:
	add_to_group(&"pets")
	add_to_group(&"creature")


var creature_id: StringName:
	get:
		return data.id if data else &""


func _physics_process(delta: float) -> void:
	step(delta)


## Its place by the bed (follows home when home moves).
func spot() -> Vector2:
	return burrow.pet_spot(maxi(0, burrow.pets.find(self))) if burrow else position


## Advances the job by delta seconds (tests call it directly).
func step(delta: float) -> void:
	var _spot := spot()
	_anim += delta
	t += delta
	var up := burrow.home.normalized() if burrow else Vector2.UP
	match state:
		State.HOME:
			position = _spot + Vector2(sin(_anim * 1.3) * 6.0, cos(_anim * 1.9) * 2.0).rotated(up.angle() + PI / 2.0)
			if data.job == &"fetch" and t >= data.every and burrow and burrow.pantry.size() < data.max_waiting:
				t = 0.0
				state = State.AWAY
				Audio.play("pet_away")
		State.AWAY:
			position += up * 40.0 * delta
			modulate.a = maxf(0.0, 1.0 - t / 0.6)
			if t >= data.trip:
				t = 0.0
				state = State.BACK
				position = _spot + up * 60.0
				modulate.a = 1.0
		State.BACK:
			position = position.move_toward(_spot, 50.0 * delta)
			if position.distance_to(_spot) < 1.0:
				state = State.HOME
				t = 0.0
				trips += 1
				burrow.add_pantry(data.fetch)
				Audio.play("pet_fetch")
				fetched.emit(data.id, data.fetch)
		_:
			pass
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var up := burrow.home.normalized() if burrow else Vector2.UP
	var flying := state != State.HOME
	var dir := up.angle() if flying else up.angle() + PI / 2.0 + sin(_anim) * 0.6
	LadybirdLook.draw(self, Vector2.ZERO, data.food.radius, dir, _anim, (0.6 + 0.4 * sin(_anim * 30.0)) if flying else 0.0, data.color)
	if state == State.BACK:   # carrying the seed home
		draw_circle(-up * 6.0, 3.0, Color("2a1a14"))
		draw_circle(-up * 6.0, 2.2, Color(0.6275, 0.4392, 0.2353))
	# A tiny heart now and then: it's home.
	if state == State.HOME and fmod(_anim, 5.0) < 0.6:
		var h := up * (10.0 + fmod(_anim, 5.0) * 8.0)
		draw_circle(h + Vector2(-1.2, 0), 1.4, Color(1, 0.5, 0.6, 0.8))
		draw_circle(h + Vector2(1.2, 0), 1.4, Color(1, 0.5, 0.6, 0.8))
