## A wild pet in the dirt (a ladybird): a small creature that potters about its pocket. To a worm it
## is food like any small thing (eat it), or hold X and carry it home alive: the burrow makes it a
## pet (Burrow.bring sees pet_id()). Also a creature the tackle box can meet (group "creature").
class_name WildPet
extends ArenaFood

var pet: PetData
var creature_id: StringName
var _dir := 0.0
var _wander := 0.0


func _ready() -> void:
	super._ready()
	data = pet.food
	creature_id = pet.id
	add_to_group(&"creature")
	_dir = randf() * TAU


func pet_id() -> StringName:
	return pet.id


func _process(delta: float) -> void:
	super._process(delta)
	if not is_available() or _carried:
		return
	_wander -= delta
	if _wander <= 0.0:
		_wander = randf_range(0.8, 2.0)
		_dir += randf_range(-1.6, 1.6)
	var step := Vector2.from_angle(_dir) * 6.0 * delta
	if (position + step).distance_to(home) < 10.0:
		position += step
	else:
		_dir = (home - position).angle()


func _draw() -> void:
	if pet == null:
		return
	LadybirdLook.draw(self, Vector2(0, sin(_t * 3.0) * 0.5), pet.food.radius, _dir, _t, 1.0 if _carried else 0.0, pet.color)
	if _carried:   # wide eyes: carried, alive, delighted
		var f := Vector2.from_angle(_dir)
		for k: float in [-1.0, 1.0]:
			draw_circle(f * 5.0 + f.orthogonal() * k * 1.3, 1.0, Color.WHITE)
