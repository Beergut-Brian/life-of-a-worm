## The sky ring (W-07, part) and the balloon stuck in the sky (X-06). The sky is data
## (data/rings/sky_life.tres, a SkyLife): a band of air above the grass with its counters and its
## scattered clouds, toy planes and balloons, edible from stage 5, no threats. The stuck balloon pops
## once per tin when a big enough worm eats its tie, with the cause on screen (cue, burst, nudge).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const SKY_PATH := "res://data/rings/sky_life.tres"
const RADIUS := 300

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm
var _extra: Array[Node] = []


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_worm = _make_worm(start)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	_dir = _make_dir(start, {})


func after_test() -> void:
	for p in Audio._pool:
		p.stop()
	for n in _extra + [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()
	_extra.clear()


func _make_dir(start: Vector2, saved: Dictionary) -> RingsDirector:
	var d := RingsDirector.new()
	d.auto_tick = false
	add_child(d)
	d.setup(_world, start, 4, saved)
	return d


func _make_worm(at: Vector2, stage := 1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	if stage > 1:
		w.model.start_at_stage(stage)
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return w


func _sky() -> SkyLife:
	return load(SKY_PATH) as SkyLife


## Puts the worm's mouth on the tie and lets it take one bite.
func _bite_tie(stage: int) -> void:
	if stage > 1:
		_worm.model.start_at_stage(stage)
	var tie := _dir.balloon.tie
	_worm.head.global_position += tie.global_position - _worm.mouth_position()
	_worm._eat_and_carry(false, _worm.model.stats, 0.1)


func test_the_sky_is_ring_data_above_the_grass_with_no_threats() -> void:
	var sky := _sky()
	assert_bool(sky is RingLife).is_true()
	assert_str(String(sky.ring)).is_equal("sky")
	assert_float(sky.inner).is_greater_equal(1.0)
	assert_float(sky.outer).is_greater(sky.inner)
	assert_int(sky.edible_from).is_equal(5)
	assert_float(sky.regrow_time).is_greater(0.0)
	var ids := {}
	for life in RingsDirector.LIVES:
		for r: PopulationRule in life.species:
			ids[r.id] = true
	var kinds := {}
	for r: PopulationRule in sky.species:
		assert_str(String(r.ring)).is_equal("sky")
		assert_bool(ids.has(r.id)).override_failure_message("sky id %s clashes" % r.id).is_false()
		# no threats: nothing in the sky is a creature that can chase or eat a worm
		assert_bool(r.live.ends_with(".tscn")).override_failure_message("%s is a creature" % r.id).is_false()
		assert_dict(r.eats).is_empty()
		kinds[r.id] = true
	for id in [&"cloud_puff", &"toy_plane", &"sky_balloon"]:
		assert_bool(kinds.has(id)).override_failure_message("missing %s" % id).is_true()
	assert_int(sky.scatter_count).is_greater(0)
	var tie := load("res://data/foods/%s.tres" % sky.balloon_tie)
	for f in sky.scatter + [tie]:
		assert_bool(f is RingFood).is_true()
		assert_str(String(f.ring)).is_equal("sky")
		assert_int(f.size_stage).is_equal(sky.edible_from)
	for f in sky.scatter:
		assert_float(f.regrow_time).is_equal(sky.regrow_time)


func test_the_director_counts_the_sky_and_scatters_it_in_its_band() -> void:
	var sky := _sky()
	for r: PopulationRule in sky.species:
		assert_bool(_dir.ecology.rules.has(r.id)).is_true()
		assert_str(String(_dir.ecology.ring_of(r.id))).is_equal("sky")
	assert_vector(_dir.ring_band(&"sky")).is_equal(Vector2(sky.inner, sky.outer))
	var in_sky := 0
	for s in _dir._statics:
		if (s.food as RingFood).ring == &"sky":
			in_sky += 1
			var d := _dir.depth_of(s.node.position)
			assert_float(d).is_between(sky.inner, sky.outer)
			# nothing in the sky sits in tiles: it is air
			assert_int(_world.get_tile(_world.shape.cell_at(s.node.position))).is_equal(0)
	assert_int(in_sky).is_equal(sky.scatter_count)


func test_a_small_worm_bumps_a_cloud_and_a_big_one_pops_it() -> void:
	var cloud: RingFood = load("res://data/foods/cloud_puff.tres")
	var plane: RingFood = load("res://data/foods/toy_plane.tres")
	assert_bool(_worm.can_eat(cloud)).is_false()
	assert_bool(_worm.can_eat(plane)).is_false()
	_worm.model.start_at_stage(5)
	assert_bool(_worm.can_eat(cloud)).is_true()
	assert_bool(_worm.can_eat(plane)).is_true()


func test_the_balloon_hangs_in_the_sky_on_a_tie() -> void:
	var b := _dir.balloon
	assert_object(b).is_not_null()
	assert_bool(b.is_popped).is_false()
	assert_float(_dir.depth_of(b.position)).is_between(_sky().inner, _sky().outer)
	assert_bool(is_instance_valid(b.tie)).is_true()
	assert_bool(b.tie.is_in_group("food")).is_true()
	assert_float(_dir.depth_of(b.position + b.tie.position)).is_greater(1.0)


func test_a_small_worm_bonks_the_tie_and_the_balloon_stays() -> void:
	_bite_tie(1)
	assert_bool(_dir.balloon.is_popped).is_false()
	assert_int(int(Audio.played.get("bonk", 0))).is_equal(1)
	assert_int(int(Audio.played.get(SkyBalloon.CUE, 0))).is_equal(0)


func test_eating_the_tie_pops_the_balloon_with_its_cause_on_screen() -> void:
	var b := _dir.balloon
	var popped := []
	b.popped.connect(func(p: int) -> void: popped.append(p))
	_bite_tie(5)
	var head_after_bite := _worm.head.global_position
	assert_bool(b.is_popped).is_true()
	assert_array(popped).is_equal([Players.P1])
	assert_int(b.popped_by).is_equal(Players.P1)
	assert_int(int(Audio.played.get(SkyBalloon.CUE, 0))).is_equal(1)
	# the beat plays (burst, snapped string) and then ends
	assert_float(b.pop_t).is_greater_equal(0.0)
	b._process(SkyBalloon.POP_TIME * 0.5)
	assert_float(b.pop_t).is_greater(0.0)
	b._process(SkyBalloon.POP_TIME)
	assert_float(b.pop_t).is_less(0.0)
	# nothing moves the worm
	assert_vector(_worm.head.global_position).is_equal(head_after_bite)
	# once only
	b.pop(Players.P1)
	assert_int(int(Audio.played.get(SkyBalloon.CUE, 0))).is_equal(1)


func test_a_popped_balloon_is_saved_and_stays_popped() -> void:
	assert_bool(_dir.to_dict().get("balloon", true)).is_false()
	_bite_tie(5)
	var saved := _dir.to_dict()
	assert_bool(saved.get("balloon", false)).is_true()
	var again := _make_dir(_dir.spawn_point, saved)
	_extra.append(again)
	assert_bool(again.balloon.is_popped).is_true()
	assert_bool(is_instance_valid(again.balloon.tie)).is_false()


func test_an_old_tin_without_the_sky_gets_its_balloon_and_keeps_its_statics() -> void:
	var saved := _dir.to_dict()
	saved.erase("balloon")
	var sky_n := _sky().scatter_count
	var old_statics: Array = saved.statics.slice(0, saved.statics.size() - sky_n)
	old_statics[0] = [old_statics[0][0], 5.0]   # the first static was eaten in the old tin
	saved.statics = old_statics
	var again := _make_dir(_dir.spawn_point, saved)
	_extra.append(again)
	assert_bool(again.balloon.is_popped).is_false()
	assert_float(again._statics[0].node.gone_at).is_equal(5.0)
	assert_str(String(again._statics[0].food.id)).is_equal(String(old_statics[0][0]))
	for i in range(again._statics.size() - sky_n, again._statics.size()):
		assert_float(again._statics[i].node.gone_at).is_less(0.0)
