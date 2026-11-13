## Kid-check N5 (B-04): a pet carried home when its kind already lives there goes back to the wild
## where the kid can see and hear it: the resident says hello, and the newcomer (a PetFarewell)
## flies up out of the room away from the core with a heart and the `pet_away` cue, fades and is
## gone. It is never a second pet (not counted, not saved). The first of a kind still moves in.
## The ant crew keeps one of its kind (max_kept 1); a ladybird is waved off once the house is full.
## Staged: a bare Burrow and a stand-in bug in the mouth, no planet, no physics pile.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


class Bug extends Node2D:
	var data: FoodData
	var pet := &"ant_crew"
	var taken := 0

	func pet_id() -> StringName:
		return pet

	func take() -> void:
		taken += 1


var _burrow: Burrow
var _worm: Worm
var _waved: Array[StringName] = []
var _gone: Array[StringName] = []


func before_test() -> void:
	_waved.clear()
	_gone.clear()
	_burrow = auto_free(Burrow.new())
	_burrow.home = Vector2(0, -300)   # home is up the disk: away from the core is -y here
	add_child(_burrow)
	_burrow.pet_waved_off.connect(func(id: StringName) -> void: _waved.append(id))
	_worm = auto_free(WORM.instantiate())


func _bug() -> Bug:
	var b: Bug = auto_free(Bug.new())
	b.data = (load("res://data/pets/ant_crew.tres") as PetData).food
	b.position = Vector2(10, -300)
	_burrow.add_child(b)
	return b


func _farewells() -> Array[Node]:
	return _burrow.get_children().filter(func(n: Node) -> bool: return n is PetFarewell)


func test_the_first_of_a_kind_moves_in_and_nothing_flies_off() -> void:
	var b := _bug()
	assert_str(String(_burrow.bring(_worm, b))).is_equal("pet")
	assert_int(_burrow.pet_count(&"ant_crew")).is_equal(1)
	assert_array(_waved).is_empty()
	assert_array(_farewells()).is_empty()


func test_a_second_of_a_kind_flies_back_to_the_wild_and_is_seen_going() -> void:
	_burrow.add_pet(&"ant_crew")
	var b := _bug()
	assert_bool(_burrow.can_keep(&"ant_crew")).is_false()
	assert_str(String(_burrow.bring(_worm, b))).is_equal("pet")
	assert_int(b.taken).is_equal(1)
	assert_int(_burrow.pet_count(&"ant_crew")).is_equal(1)   # never a second pet
	assert_array(_waved).is_equal([&"ant_crew"])
	var fs := _farewells()
	assert_int(fs.size()).is_equal(1)
	var f: PetFarewell = fs[0]
	assert_bool(f.is_in_group(&"pets")).is_false()
	assert_vector(f.position).is_equal(Vector2(10, -300))   # leaves from the mouth
	f.set_physics_process(false)
	f.gone.connect(func(id: StringName) -> void: _gone.append(id))
	var start := f.position
	f.step(0.5)
	assert_float(f.position.y).is_less(start.y)   # rising away from the core
	assert_float(f.modulate.a).is_equal(1.0)       # seen whole for the first half
	f.step(0.6)
	assert_float(f.modulate.a).is_less(1.0)        # then fading
	assert_array(_gone).is_empty()
	f.step(0.6)
	assert_array(_gone).is_equal([&"ant_crew"])
	assert_bool(f.is_queued_for_deletion()).is_true()


func test_the_farewell_is_not_saved_with_the_pets() -> void:
	_burrow.add_pet(&"ant_crew")
	_burrow.bring(_worm, _bug())
	assert_array(_burrow.pet_ids()).is_equal([&"ant_crew"])


func test_a_full_house_waves_off_a_fourth_ladybird() -> void:
	for i in Burrow.MAX_PETS:
		_burrow.add_pet(&"ladybird")
	var b := _bug()
	b.pet = &"ladybird"
	b.data = (load("res://data/pets/ladybird.tres") as PetData).food
	_burrow.bring(_worm, b)
	assert_int(_burrow.pets.size()).is_equal(Burrow.MAX_PETS)
	assert_array(_waved).is_equal([&"ladybird"])
	assert_int(_farewells().size()).is_equal(1)
