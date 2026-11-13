## The sky's birds (W-07): flocks circling the band of air above the grass. Data in sky_life.tres;
## they fly round on their own, a worm coming near startles a flock once (tweet + the birds burst
## apart, then settle back into the V), and they never touch, push or steer a worm, never get eaten.
## Also the sky's placeholder looks: clouds draw as CLOUD, toy planes as PLANE.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm
var _flock: SkyFlock


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_worm = WORM.instantiate()
	_worm.player = Players.P1
	_worm.model = WormGrowth.new()
	_worm.set_meta("start_pos", start)
	_worm.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(_worm)
	_worm.set_physics_process(false)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 4, {})
	_flock = _dir.flock
	_flock.set_process(false)


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


## Parks the worm far below every flock (deep in the dirt).
func _park() -> void:
	_worm.head.global_position = Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.5


func test_the_flocks_are_sky_data_in_the_band_of_air() -> void:
	var sky := RingsDirector.SKY
	assert_int(sky.flocks).is_greater(0)
	assert_int(sky.flock_birds).is_greater_equal(3)
	assert_str(sky.flock_cue).is_not_empty()
	assert_bool(FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % sky.flock_cue)).is_true()
	assert_int(_flock.flock_count()).is_equal(sky.flocks)
	assert_str(String(_flock.name)).is_equal("SkyFlock")
	for i in _flock.flock_count():
		assert_int(_flock.bird_points(i).size()).is_equal(sky.flock_birds)
		for p in _flock.bird_points(i):
			var d := _dir.depth_of(p)
			assert_float(d).override_failure_message("flock %d bird at depth %.3f" % [i, d]).is_between(sky.inner - 0.02, sky.outer + 0.02)
	# never food, never a creature the director counts
	assert_bool(_flock.is_in_group(&"food")).is_false()
	assert_bool((_flock as Node) is Creature).is_false()


func test_they_fly_round_the_planet_on_their_own() -> void:
	_park()
	var before := _flock.centre(0)
	for i in 120:
		_flock.step(1.0 / 60.0)
	var after := _flock.centre(0)
	assert_float(before.distance_to(after)).is_greater(10.0)
	assert_float(absf(after.length() - before.length())).is_less(0.5)   # same height in the band
	assert_int(_flock.startles).is_equal(0)
	assert_int(Audio.played.get(RingsDirector.SKY.flock_cue, 0)).is_equal(0)


func test_a_worm_near_startles_a_flock_once_then_it_settles() -> void:
	_park()
	var events: Array[int] = []
	_flock.startled.connect(func(i: int) -> void: events.append(i))
	_flock.place(0, 0.0, 1.2)
	_flock.step(1.0 / 60.0)
	var calm := _flock.bird_points(0)
	_worm.head.global_position = _world.to_global(_flock.centre(0) + _flock.centre(0).normalized() * -60.0)
	_flock.step(1.0 / 60.0)
	assert_array(events).is_equal([0])
	assert_bool(_flock.is_scattered(0)).is_true()
	assert_int(Audio.played.get(RingsDirector.SKY.flock_cue, 0)).is_equal(1)
	# the birds burst apart: they spread wider than the V
	for i in int(SkyFlock.SCATTER_TIME * 60.0):
		_flock.step(1.0 / 60.0)
	assert_float(_spread(_flock.bird_points(0))).is_greater(_spread(calm) * 1.3)
	# the worm stays right there: still one startle while it settles
	for i in int(SkyFlock.SETTLE_TIME * 60.0) + 2:
		_flock.step(1.0 / 60.0)
		if not _flock.is_scattered(0):
			break
	assert_array(events).is_equal([0])
	assert_bool(_flock.is_scattered(0)).is_false()
	assert_float(_spread(_flock.bird_points(0))).is_less(_spread(calm) * 1.15)


func test_a_startled_flock_flies_off_away_from_the_worm() -> void:
	_park()
	_flock.place(1, 0.3, 1.2)
	var c := _flock.centre(1)
	var side := c.normalized().orthogonal()
	_worm.head.global_position = _world.to_global(c + side * 80.0)   # the worm on the + side
	_flock.step(1.0 / 60.0)
	assert_bool(_flock.is_scattered(1)).is_true()
	var head_local := _world.to_local(_worm.head.global_position)
	var d0 := _flock.centre(1).distance_to(head_local)
	for i in 60:
		_flock.step(1.0 / 60.0)
	assert_float(_flock.centre(1).distance_to(head_local)).is_greater(d0)


func test_they_never_move_or_eat_the_worm() -> void:
	_flock.place(0, 0.0, 1.2)
	var at := _world.to_global(_flock.centre(0))
	_worm.head.global_position = at
	var stage := _worm.model.stage
	for i in 200:
		_flock.step(1.0 / 60.0)
	assert_vector(_worm.head.global_position).is_equal(at)
	assert_int(_worm.model.stage).is_equal(stage)
	assert_int(Audio.played.get("bird_gulp", 0)).is_equal(0)
	assert_int(Audio.played.get("eaten", 0)).is_equal(0)


func test_sky_foods_draw_as_clouds_and_planes() -> void:
	var plane: RingFood = load("res://data/foods/toy_plane.tres")
	assert_int(plane.look).is_equal(RingFood.Look.PLANE)
	var cloud: RingFood = load("res://data/foods/cloud_puff.tres")
	assert_str(String(cloud.ring)).is_equal("sky")
	# a sky food left at BLOB draws as a cloud: drawing it must not error
	for f in [plane, cloud]:
		var p := RingPickup.new()
		p.data = f
		add_child(p)
		p.queue_redraw()
		await get_tree().process_frame
		p.queue_free()


func _spread(pts: PackedVector2Array) -> float:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= pts.size()
	var s := 0.0
	for p in pts:
		s += p.distance_to(mid)
	return s / pts.size()
