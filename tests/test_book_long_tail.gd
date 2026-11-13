## T-04 (feature/worm-gap-close-10): the tackle box's foods page is the long tail for a solo
## player, so every food on it must grow somewhere on the planet, not just in the trait arena.
## The droplet and the bottle cap lie in the topsoil, the big boulder and the crystal in the core (data only:
## data/rings/topsoil_life.tres, core_life.tres). The trophy families (stones, shinies) can be
## filled from the planet too. Saves: the suite runs in its own sandbox profile (SuiteSandbox).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const RADIUS := 300
## Foods PlanetLevel._new_planet lays round the start (the grub trail, pebbles, a seed) and the
## beetle's grub; everything else comes from the data read in _planet_sources().
const PLANET_START: Array[StringName] = [&"grub", &"pebble", &"seed"]

var _world: PolarWorld
var _dir: RingsDirector


func before() -> void:
	SuiteSandbox.enter("book_long_tail")


func after() -> void:
	SuiteSandbox.leave()


func after_test() -> void:
	for n in [_dir, _world]:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_dir = null
	_world = null


## Every food id something on the planet puts there: ring scatters and counters, the sky, the
## surface's apples and props, the hidden places, the picnic crumbs and the start.
static func _planet_sources() -> Dictionary:
	var out := {}
	for id in PLANET_START:
		out[id] = "start"
	out[RingsDirector.SANDWICH_CRUMB.id] = "picnic"
	var lives: Array = RingsDirector.LIVES.duplicate()
	lives.append(RingsDirector.SKY)
	lives.append(RingsDirector.SURFACE)
	for life in lives:
		for f in life.scatter:
			out[f.id] = "%s scatter" % life.ring
		for rule in life.species:
			if String(rule.live).begins_with("res://data/foods/"):
				out[(load(rule.live) as FoodData).id] = "%s counter" % life.ring
	out[RingsDirector.SKY.balloon_tie] = "sky balloon"
	for p in WorldDestruct.load_props():
		if p.chunk != null:
			out[p.chunk.id] = "prop %s" % p.id
	for s in RingsDirector.SECRETS:
		out[s.food] = "secret %s" % s.id
		if s.extra_food != &"":
			out[s.extra_food] = "secret %s" % s.id
	return out


func test_every_food_on_the_book_page_grows_somewhere_on_the_planet() -> void:
	var src := _planet_sources()
	var book := TackleLog.new()
	var page: Array = book.entries[&"foods"].duplicate()
	book.free()
	assert_int(page.size()).is_greater(20)
	var missing: Array[String] = []
	for id in page:
		if not src.has(id):
			missing.append(String(id))
	assert_array(missing).override_failure_message("never on the planet: %s" % [missing]).is_empty()


func test_every_trophy_family_can_be_filled_from_the_planet() -> void:
	var src := _planet_sources()
	for f in ResourceLoader.list_directory("res://data/trophies/"):
		if not f.ends_with(".tres"):
			continue
		var fam = load("res://data/trophies/" + f)
		for m in fam.members:
			assert_bool(src.has(m)).override_failure_message("%s: %s never on the planet" % [f, m]).is_true()


func test_the_new_foods_are_ring_foods_of_their_ring() -> void:
	for pair in [[&"droplet", &"topsoil"], [&"bottle_cap", &"topsoil"], [&"big_boulder", &"core"], [&"crystal", &"core"]]:
		var f: FoodData = load("res://data/foods/%s.tres" % pair[0])
		assert_bool(f is RingFood).is_true()
		assert_str(String((f as RingFood).ring)).is_equal(String(pair[1]))


## In play: the director lays them in their ring's band, and a worm eating one unlocks it.
func test_droplets_caps_and_big_boulders_lie_in_their_rings_in_play() -> void:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 4, {})
	var counts := {&"droplet": 0, &"bottle_cap": 0, &"big_boulder": 0, &"crystal": 0}
	var rings := {&"droplet": &"topsoil", &"bottle_cap": &"topsoil", &"big_boulder": &"core", &"crystal": &"core"}
	for s in _dir._statics:
		var id: StringName = s.food.id
		if counts.has(id):
			counts[id] += 1
			var band := _dir.ring_band(rings[id])
			assert_float(_dir.depth_of(s.node.position)).is_between(band.x, band.y)
	for id in counts:
		assert_int(counts[id]).override_failure_message("%s not laid" % id).is_greater(0)
	# the core keeps at least its four crystals
	var crystals := 0
	for s in _dir._statics:
		if s.food.id == &"core_crystal":
			crystals += 1
	assert_int(crystals).is_greater_equal(4)
