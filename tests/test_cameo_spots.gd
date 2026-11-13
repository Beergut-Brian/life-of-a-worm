## X-08: "Secrets and the surface keep a few empty spots for later Jarling cameos." Each hidden
## place lists named CameoSpots (SecretData.cameos) on open floor; the surface lists stretches of
## bare grass (SurfaceLife.cameos). These check every spot loads with its own name and no Jarling,
## that an empty spot does nothing in play (a bare marker: no drawing, no body, no carve, nothing
## placed on it), and that a later update can fill one from data alone.
## Spot coordinates first proposed on local feature/worm-gap-close-6 (not on dev); this suite
## supersedes its test of the same name.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const SURFACE: SurfaceLife = preload("res://data/rings/surface_life.tres")
const RADIUS := 300
const TILE := 16.0
## A cameo needs this much clear room round its spot (tiles).
const CLEAR := 1.5

var _world: PolarWorld
var _dir: RingsDirector


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, Vector2.from_angle(-PI / 2.0) * RADIUS * TILE * 0.76, 4, {})


func after_test() -> void:
	for n in [_dir, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


func _all_spots() -> Array[CameoSpot]:
	var out: Array[CameoSpot] = []
	for s in RingsDirector.SECRETS:
		out.append_array(s.cameos)
	out.append_array(SURFACE.cameos)
	return out


## [spot, px] for every hidden place's spots.
func _secret_spots(s: SecretData) -> Array:
	var c: Vector2 = _dir.cities[s.id]
	var out: Array = []
	for k in s.cameos:
		out.append([k, c + SecretData.cameo_offset(k, c)])
	return out


## Every node the director put down (foods, pickups, creatures, the hidden places' own props).
func _things() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var stack: Array[Node] = [_dir]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for k in n.get_children():
			stack.append(k)
			if k is RingPickup or k is Creature:
				out.append(k)
	return out


## Every spot loads from data: each hidden place keeps one or more, the surface two; each has its
## own unique name (never a character's), and none has a Jarling yet (none at launch, GAME.md).
func test_every_spot_loads_named_and_empty() -> void:
	for s in RingsDirector.SECRETS:
		assert_int(s.cameos.size()).override_failure_message("%s keeps no cameo spot" % s.id).is_greater(0)
	assert_int(SURFACE.cameos.size()).is_greater_equal(2)
	var seen := {}
	var characters := DirAccess.get_directories_at("res://assets/characters/")
	for k in _all_spots():
		assert_object(k).is_not_null()
		assert_bool(k is CameoSpot).is_true()
		assert_str(String(k.id)).override_failure_message("a cameo spot has no name").is_not_empty()
		assert_bool(seen.has(k.id)).override_failure_message("two spots are named %s" % k.id).is_false()
		seen[k.id] = true
		assert_bool(String(k.id) in characters).override_failure_message("spot %s is named for a character" % k.id).is_false()
		assert_bool(k.is_empty()).override_failure_message("spot %s already has %s" % [k.id, k.jarling]).is_true()


## In play every spot has its marker, and an empty one does nothing: no child, nothing drawn, not
## a pickup or a body, no sound, and the grass under a surface spot is whole (no visible gap).
func test_an_empty_spot_does_nothing_in_play() -> void:
	var stands := _dir.cameo_stands
	assert_object(stands).is_not_null()
	assert_int(stands.spots.size()).is_equal(_all_spots().size())
	for k in _all_spots():
		var n: Node2D = stands.spots.get(k.id)
		assert_object(n).override_failure_message("spot %s has no marker" % k.id).is_not_null()
		assert_int(n.get_child_count()).override_failure_message("empty spot %s shows something" % k.id).is_equal(0)
		assert_bool(n.get_script() == null).is_true()   # a bare Node2D draws nothing
		assert_bool(n is RingPickup or n is Creature or n is CollisionObject2D).is_false()
	for k in SURFACE.cameos:
		var p: Vector2 = stands.spots[k.id].position
		var below := p - p.normalized() * 0.5 * TILE
		assert_bool(_world.is_solid(_world.shape.cell_at(below))).override_failure_message(
			"the grass under %s is gone" % k.id).is_true()
	assert_array(Audio.played.keys().filter(func(c): return "cameo" in str(c))).is_empty()


## A later cameo update only edits the data: naming a Jarling in a spot stands its pixel form there
## (a picture, never food); a name with no character folder stays a bare marker, no error.
func test_a_filled_spot_stands_its_jarling_from_data_alone() -> void:
	var k: CameoSpot = SURFACE.cameos[0].duplicate()
	k.id = &"test_filled"
	k.jarling = &"bloom"
	var n := _dir.cameo_stands.stand(k, _dir.polar(k.angle, 1.0))
	var sprite := n.get_node_or_null("Jarling") as Sprite2D
	assert_object(sprite).is_not_null()
	assert_object(sprite.texture).is_not_null()
	assert_bool(sprite.offset.y < 0.0).is_true()   # stands on the spot, not in the ground
	var missing: CameoSpot = SURFACE.cameos[1].duplicate()
	missing.id = &"test_missing"
	missing.jarling = &"nobody_here"
	assert_int(_dir.cameo_stands.stand(missing, Vector2(0, -100)).get_child_count()).is_equal(0)


## Each hidden-place spot is open ground inside a carved room or open-air hall, kept from
## regrowing, with standing room round it.
func test_the_spots_are_carved_open_and_kept() -> void:
	for s in RingsDirector.SECRETS:
		var c: Vector2 = _dir.cities[s.id]
		for kp in _secret_spots(s):
			var p: Vector2 = kp[1]
			var inside := p.distance_to(c) <= (s.radius_tiles - 1.0) * TILE
			for r in RingsDirector.rooms_of(s, c):
				if p.distance_to(c + Vector2(r.x, r.y)) <= r.z - 1.0 * TILE:
					inside = true
			assert_bool(inside).override_failure_message("%s spot %s is not inside its rooms" % [s.id, p]).is_true()
			for i in 8:
				var q := p + Vector2.from_angle(TAU * i / 8.0) * 0.5 * TILE
				var cell := _world.shape.cell_at(q)
				assert_bool(_world.is_solid(cell)).override_failure_message("%s spot %s is not open" % [s.id, p]).is_false()
				assert_bool(_world.in_keep_zone(cell)).override_failure_message("%s spot %s regrows" % [s.id, p]).is_true()


## Nothing the planet puts down sits on a spot: not the hidden place's unique food, the extra food
## in its first room, a scattered food or a creature.
func test_nothing_is_placed_on_a_hidden_spot() -> void:
	var things := _things()
	assert_int(things.size()).is_greater(10)
	for s in RingsDirector.SECRETS:
		for kp in _secret_spots(s):
			for t in things:
				assert_float(t.position.distance_to(kp[1])).override_failure_message(
					"%s has %s on it" % [kp[0].id, t.name]).is_greater(CLEAR * TILE)


## No two spots share standing room, and no spot sits inside another hidden place's hall or rooms.
func test_the_spots_are_unique_and_never_inside_another_hidden_place() -> void:
	var all: Array = []
	for s in RingsDirector.SECRETS:
		for kp in _secret_spots(s):
			all.append([s, kp[1], kp[0]])
	for i in all.size():
		for j in range(i + 1, all.size()):
			assert_float((all[i][1] as Vector2).distance_to(all[j][1])).override_failure_message(
				"%s and %s share standing room" % [all[i][2].id, all[j][2].id]).is_greater(2.0 * CLEAR * TILE)
		for o in RingsDirector.SECRETS:
			if o == all[i][0]:
				continue
			var c: Vector2 = _dir.cities[o.id]
			var p: Vector2 = all[i][1]
			assert_float(p.distance_to(c)).override_failure_message(
				"%s is inside %s" % [all[i][2].id, o.id]).is_greater(o.radius_tiles * TILE)
			for r in RingsDirector.rooms_of(o, c):
				assert_float(p.distance_to(c + Vector2(r.x, r.y))).override_failure_message(
					"%s is in a room of %s" % [all[i][2].id, o.id]).is_greater(r.z)


## The surface spots are bare grass: clear of every prop, the picnic sandwich, the scattered apples
## and the hidden places on or over the surface; one each side of the start.
func test_the_surface_keeps_bare_grass_for_cameos() -> void:
	var r := float(RADIUS)
	var margin := 2.0 / r   # two tiles of grass either side
	var angles: Array[float] = []
	for k in SURFACE.cameos:
		var a := k.angle
		for d in WorldDestruct.load_props():
			var half := float(d.size.x) * 0.5 / r
			for pa in d.angles:
				assert_float(absf(a - pa)).override_failure_message("%s under %s" % [k.id, d.id]) \
					.is_greater(half + margin)
		assert_float(absf(a - (-0.06))).is_greater(0.012 + margin)   # RingsDirector's picnic
		assert_float(absf(a)).is_greater(SURFACE.scatter_spread + margin)
		for s in RingsDirector.SECRETS:
			if s.depth < 1.0:
				continue
			var gap := absf(wrapf(a - s.angle_from_start, -PI, PI))
			assert_float(gap).override_failure_message("%s over %s" % [k.id, s.id]) \
				.is_greater(s.radius_tiles / (r * s.depth) + 0.05)
		for b in angles:
			assert_float(absf(a - b)).is_greater(0.05)
		angles.append(a)
	assert_float(angles.min() * angles.max()).is_less(0.0)
