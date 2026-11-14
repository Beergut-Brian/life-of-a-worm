## K-08 (gap-close-38): the deep-rock apex pill bug was slate blue (#4a6890) on slate-navy rock,
## the same hue as the ground, so a kid could not see the thing they must outgrow. It is
## raspberry now: a warm, saturated shell that reads on the rock (the rock beetles went warm tan
## for the same reason in gap-close-23), pale pink once it is food. Its book page wears the same.
class_name TestPillbugStandsOut
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")


func _ring_hue(id: StringName) -> Color:
	for r in RINGS.rings:
		if r.id == id:
			return r.hue
	return Color.BLACK


func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_the_pillbug_lives_in_the_deep_rock() -> void:
	var pill: Dictionary = ApexBeetle.DEEP.filter(func(d: Dictionary) -> bool: return d.look == &"pillbug")[0]
	assert_int(pill.ring).is_equal(4)
	var page: CreatureData = load("res://data/apexes/apex_pillbug.tres")
	assert_str(String(page.ring)).is_equal("deep_rock")


func test_its_threat_shell_is_not_the_colour_of_the_rock() -> void:
	var rock := _ring_hue(&"deep_rock")
	assert_float(rock.a).is_greater(0.5)
	var shell := ApexBeetle.shell_color(&"pillbug", false)
	assert_float(_hue_gap(shell, rock)).override_failure_message("same hue as the rock").is_greater(0.15)
	assert_float(_dist(shell, rock)).override_failure_message("too close to the rock").is_greater(0.3)
	assert_float(shell.s).is_greater(0.5)   # saturated: "threats look smug", not grey
	# The ore seams (the rock's other colour) are gold; the shell is not that either.
	assert_float(_hue_gap(shell, Color(0.788, 0.635, 0.29))).is_greater(0.15)


func test_as_food_it_goes_pale_in_the_same_hue() -> void:
	var threat := ApexBeetle.shell_color(&"pillbug", false)
	var food := ApexBeetle.shell_color(&"pillbug", true)
	assert_float(food.v).is_greater(threat.v)
	assert_float(food.s).is_less(threat.s)
	assert_float(_hue_gap(food, threat)).is_less(0.05)


func test_its_book_page_matches_the_one_you_met() -> void:
	var page: CreatureData = load("res://data/apexes/apex_pillbug.tres")
	var shell := ApexBeetle.shell_color(&"pillbug", false)
	assert_float(_dist(page.color, shell)).is_less(0.01)
	assert_float(_dist(page.accent, ApexBeetle.shell_color(&"pillbug", true))).is_less(0.01)
	assert_bool(ApexBeetle.shell_color(&"pillbug", false) != ApexBeetle.shell_color(&"ember", false)).is_true()
