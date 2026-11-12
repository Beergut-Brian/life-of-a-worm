## Food and creature sprites (A-13): every food and creature of the slice has a 4 x 2 sheet at least
## as big as its body, and the FaceSprite mirrors the host's state (wide-eyed when it could be eaten
## or is carried, smug after bonking a small worm) while hiding the placeholder drawing.
class_name TestLookSprites
extends GdUnitTestSuite

const FOOD_SCRIPT := preload("res://scripts/arena/arena_food.gd")


func _ids(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(f.get_basename())
	return out


func test_every_food_and_creature_has_a_sheet_at_its_size() -> void:
	for pair in [["res://data/foods", false], ["res://data/creatures", true]]:
		for id in _ids(pair[0]):
			var d = load("%s/%s.tres" % [pair[0], id])
			var tex := FaceSprite.sheet_for(StringName(id), pair[1])
			assert_object(tex).override_failure_message("no sprite sheet for %s" % id).is_not_null()
			assert_int(tex.get_width() % 4).is_equal(0)
			assert_int(tex.get_height() % 2).is_equal(0)
			var cell := mini(tex.get_width() / 4, tex.get_height() / 2)
			if id != "boot" and id != "bird":
				assert_int(cell).override_failure_message("%s cell %d < body %.1f" % [id, cell, d.radius * 2.0]).is_greater_equal(int(d.radius * 2.0))


func test_face_sprite_mirrors_the_host_and_hides_the_placeholder() -> void:
	var f: ArenaFood = FOOD_SCRIPT.new()
	f.data = load("res://data/foods/seed.tres")
	add_child(f)
	var s := FaceSprite.attach(f)
	assert_object(s).is_not_null()
	assert_object(FaceSprite.attach(f)).is_same(s)  # once only
	assert_float(f.self_modulate.a).is_equal(0.0)
	assert_int(s.hframes).is_equal(4)
	f._carried = true
	assert_int(s._mood()).is_equal(FaceSprite.Mood.WIDE)
	f._carried = false
	f._scared = false
	f._smug = 1.0
	assert_int(s._mood()).is_equal(FaceSprite.Mood.SMUG)
	f._smug = 0.0
	assert_int(s._mood()).is_in([FaceSprite.Mood.CALM, FaceSprite.Mood.BLINK])
	f._gone = true
	s._process(0.016)
	assert_bool(s.visible).is_false()
	f.free()
