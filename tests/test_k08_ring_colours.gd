## K-08 kid check: nothing in the dirt is dark; every deep ring stays colourful, not black.
## For each ring of data/rings/rings.tres this samples the Lantern ambient across the whole ring
## (inner edge to outer edge) and keeps the darkest, then lights every tile colour that ring shows
## (its ground hue and its alt hue) with that darkest ambient. The threshold is the lighting test's
## own (Lantern.AMBIENT_FLOOR, test_lighting_lantern::test_ambient_is_dim_never_dark_in_every_ring):
##   * the ambient's darkest channel never drops under it, anywhere in the ring;
##   * a lit tile colour's brightest channel (HSV value) never drops under it: dim, not dark;
##   * a ring's ground and alt hues keep some colour (saturation), so no ring reads as grey/black.
## Garden tiles and the Strangestone can grow in any ring, so they are lit by the darkest ambient
## of all. A failing ring is fixed in data (the hue in rings.tres), never in the art.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const RADIUS := 160
## Samples per ring, inner edge to outer edge.
const STEPS := 12
## A ring's ground must keep at least this much colour (HSV saturation): not grey, not black.
const MIN_SATURATION := 0.15


func _lantern() -> Lantern:
	var level := Node2D.new()
	var lantern := Lantern.new()
	lantern.max_lights = 4
	level.add_child(lantern)
	add_child(level)
	auto_free(level)
	var w := PolarWorld.new()
	w.setup_planet(RINGS, RADIUS, 7)
	level.add_child(w)
	w.set_physics_process(false)
	return lantern


static func _darkness(c: Color) -> float:
	return minf(c.r, minf(c.g, c.b))


## ring id -> the darkest ambient sampled inside it.
func _darkest_ambient(lantern: Lantern) -> Dictionary:
	var px := RADIUS * 16.0
	var out := {}
	var inner := 0.0
	for r: RingDef in RINGS.rings:
		var worst := Color.WHITE
		for i in STEPS:
			var f := lerpf(inner, r.outer, (i + 0.5) / STEPS)
			for ang in [0.0, 1.3, 2.9, 4.4]:   # a few directions: the ambient is by depth only
				var c := lantern.ambient_at(Vector2.from_angle(ang) * px * f)
				if _darkness(c) < _darkness(worst):
					worst = c
		out[r.id] = worst
		inner = r.outer
	return out


static func _lit(hue: Color, ambient: Color) -> Color:
	return Color(hue.r * ambient.r, hue.g * ambient.g, hue.b * ambient.b)


func test_the_darkest_ambient_in_every_ring_stays_over_the_floor() -> void:
	var amb := _darkest_ambient(_lantern())
	assert_int(amb.size()).is_equal(RINGS.rings.size())
	for id in amb:
		assert_float(_darkness(amb[id])).override_failure_message(
				"%s ambient dips to %s" % [id, amb[id]]).is_greater_equal(Lantern.AMBIENT_FLOOR)


func test_every_ring_tile_colour_stays_bright_under_its_darkest_light() -> void:
	var amb := _darkest_ambient(_lantern())
	for r: RingDef in RINGS.rings:
		for pair in [["hue", r.hue], ["alt_hue", r.alt_hue]]:
			var lit := _lit(pair[1], amb[r.id])
			assert_float(lit.v).override_failure_message("%s %s %s lights to %s (v %.3f): dark" % [
					r.id, pair[0], (pair[1] as Color).to_html(false), lit.to_html(false), lit.v]) \
					.is_greater_equal(Lantern.AMBIENT_FLOOR)


func test_every_ring_ground_keeps_its_colour() -> void:
	for r: RingDef in RINGS.rings:
		for c: Color in [r.hue, r.alt_hue]:
			assert_float(c.s).override_failure_message("%s %s is grey" % [r.id, c.to_html(false)]) \
					.is_greater_equal(MIN_SATURATION)


func test_gardens_and_strangestone_stay_bright_in_the_darkest_ring() -> void:
	var amb := _darkest_ambient(_lantern())
	var darkest := Color.WHITE
	for id in amb:
		if _darkness(amb[id]) < _darkness(darkest):
			darkest = amb[id]
	var hues: Array[Color] = [RINGS.strangestone_hue]
	for k in RINGS.garden_hues:
		hues.append(RINGS.garden_hues[k])
	for c in hues:
		assert_float(_lit(c, darkest).v).override_failure_message("%s goes dark" % c.to_html(false)) \
				.is_greater_equal(Lantern.AMBIENT_FLOOR)


func test_deeper_rings_are_still_dimmer_than_the_surface() -> void:
	# the fix brightens colours, not the depth story: the surface stays the brightest light
	var amb := _darkest_ambient(_lantern())
	for id in [&"deep_rock", &"core", &"dirt"]:
		assert_float((amb[id] as Color).v).is_less((amb[&"surface"] as Color).v)
