## D105 content, stages 1 and 2 (Kaden's Docket answer D105 b, 2026-11-13): the new things of the
## dirt and the topsoil. Each one exists in data, opens at the stage that opens its ring, and is met
## in play on a real PolarWorld with the real RingsDirector: the foods are placed in their ring
## (after every older static, so a saved tin keeps its slots), the creatures spawn from their ring's
## counters near a worm there, and the events happen beside a worm of their stage in their ring.
## Nothing here touches the pacing numbers (data/stages.tres, worm_rules.tres).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300
const SFX := "res://assets/audio/sfx/%s.ogg"

## Food id -> the stage that opens it (its ring's stage).
const FOODS := {
	&"carrot_tip": 1, &"snail_shell": 1, &"marble": 1, &"button": 1, &"clay_lump": 1,
	&"potato": 1, &"old_spoon": 1,
	&"wild_berry": 2, &"cherry_pit": 2, &"clover_leaf": 2, &"lost_coin": 2, &"glass_bead": 2,
	&"chalk_bit": 2, &"walnut": 2, &"crayon": 2,
}
## Creature id -> the stage whose ring it lives in.
const CREATURES := {
	&"mite": 1, &"wireworm": 1,
	&"aphid": 2, &"caterpillar": 2, &"snail": 2, &"shield_bug": 2,
}
## Event id -> the stage it happens from.
const EVENTS := {
	&"root_burst": 1, &"marble_spill": 1, &"egg_clutch": 1,
	&"seed_shower": 2, &"fairy_ring": 2, &"dew_drip": 2,
}

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm
var _rules: WormRules


## Every new thing of D105 stages 1 and 2, as "kind id" (the novelty test and the report read it).
static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in [FOODS, CREATURES, EVENTS]:
		for k in d:
			out.append(k)
	return out


func before_test() -> void:
	Audio.played.clear()
	_rules = WormRules.default_rules()


## Drain the cues the events played (long ones still playing at exit leak their playbacks).
func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_dir = null
	_worm = null
	_world = null


## A real planet with the worm's head in `ring` at `stage`.
func _planet(ring: StringName, stage: int) -> void:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var depth := _mid(ring)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * depth
	_worm = WORM.instantiate()
	_worm.player = Players.P1
	_worm.model = WormGrowth.new()
	if stage > 1:
		_worm.model.start_at_stage(stage)
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


func _mid(ring: StringName) -> float:
	var inner := 0.0
	for r in RINGS.rings:
		if r.id == ring:
			return (inner + r.outer) * 0.5
		inner = r.outer
	return 0.5


func _ring_of_stage(stage: int) -> StringName:
	return _rules.stage_info(stage).opens_ring


func _life(ring: StringName) -> RingLife:
	for l in RingsDirector.LIVES:
		if l.ring == ring:
			return l
	return null


# --- foods ------------------------------------------------------------------------------------

func test_each_new_food_is_data_in_the_ring_its_stage_opens() -> void:
	for id in FOODS:
		var stage: int = FOODS[id]
		var f := load("res://data/foods/%s.tres" % id) as RingFood
		assert_object(f).override_failure_message("%s is not a RingFood" % id).is_not_null()
		assert_str(String(f.id)).is_equal(String(id))
		assert_str(String(f.ring)).override_failure_message("%s ring" % id).is_equal(String(_ring_of_stage(stage)))
		# edible from its stage, never before the ring opens; size 2 ones are a bonk at stage 1
		assert_bool(f.size_stage <= _rules.stage_info(stage + (1 if f.size_stage > stage else 0)).edible_size) \
			.override_failure_message("%s size %d" % [id, f.size_stage]).is_true()
		assert_bool(f.flavour in [&"root", &"bug", &"stone", &"junk", &"water"]) \
			.override_failure_message("%s flavour %s (no new flavour, no sweet: X-01)" % [id, f.flavour]).is_true()
		assert_bool(ResourceLoader.exists(SFX % f.eat_cue)) \
			.override_failure_message("%s eat_cue %s has no file (reuse a cue)" % [id, f.eat_cue]).is_true()
		assert_float(f.growth).is_greater(0.0)


func test_the_big_ones_are_a_bonk_at_stage_one_and_food_at_two() -> void:
	for id in [&"potato", &"old_spoon"]:
		var f := load("res://data/foods/%s.tres" % id) as RingFood
		assert_int(f.size_stage).is_equal(2)
		assert_bool(f.size_stage <= _rules.stage_info(1).edible_size).is_false()
		assert_bool(f.size_stage <= _rules.stage_info(2).edible_size).is_true()


func test_the_cherry_pit_plants_a_root_garden() -> void:
	var f := load("res://data/foods/cherry_pit.tres") as RingFood
	assert_str(String(f.plants)).is_equal("root")
	assert_bool(RINGS.garden_tiles.has(f.plants)).is_true()


func test_each_new_food_is_placed_in_its_ring_on_a_new_planet() -> void:
	_planet(&"dirt", 1)
	var seen := {}
	for s in _dir._statics:
		var id: StringName = s.food.id
		if FOODS.has(id):
			var band := _dir.ring_band(s.food.ring)
			var d := _dir.depth_of(s.node.position)
			assert_float(d).is_between(band.x, band.y)
			seen[id] = int(seen.get(id, 0)) + 1
	for id in FOODS:
		assert_int(int(seen.get(id, 0))).override_failure_message("%s never placed" % id).is_greater_equal(2)


func test_older_tins_keep_their_static_slots() -> void:
	var dirt := _life(&"dirt")
	var top := _life(&"topsoil")
	var keep := [dirt.late_scatter_count, top.late_scatter_count]
	# the second D105 slice (stages 3 to 7) comes after these: leave it out of both runs
	var later := {}
	for l in RingsDirector.all_lives():
		later[l] = l.later_scatter_count
		l.later_scatter_count = 0
	dirt.late_scatter_count = 0
	top.late_scatter_count = 0
	_planet(&"dirt", 1)
	var before: Array = _dir.to_dict().statics
	after_test()
	dirt.late_scatter_count = keep[0]
	top.late_scatter_count = keep[1]
	_planet(&"dirt", 1)
	var now: Array = _dir.to_dict().statics
	for l in later:
		l.later_scatter_count = later[l]
	assert_int(now.size()).is_equal(before.size() + keep[0] + keep[1])
	for i in before.size():
		assert_str(String(now[i][0])).is_equal(String(before[i][0]))
		assert_vector(_dir._statics[i].node.position).is_not_null()


func test_a_worm_eats_a_new_food_and_a_tin_keeps_it_eaten() -> void:
	_planet(&"dirt", 1)
	var p: RingPickup = null
	for s in _dir._statics:
		if s.food.id == &"carrot_tip":
			p = s.node
			break
	assert_bool(_worm.can_eat(p.data)).is_true()
	p.take()
	var saved := _dir.to_dict()
	after_test()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * _mid(&"dirt"), 4, saved)
	var gone := 0
	for s in _dir._statics:
		if s.food.id == &"carrot_tip" and s.node.gone_at >= 0.0:
			gone += 1
	assert_int(gone).is_equal(1)


# --- creatures --------------------------------------------------------------------------------

func test_each_new_creature_is_data_with_a_scene_and_a_counter() -> void:
	for id in CREATURES:
		var stage: int = CREATURES[id]
		var d := load("res://data/creatures/%s.tres" % id) as CreatureData
		assert_object(d).is_not_null()
		assert_str(String(d.ring)).is_equal(String(_ring_of_stage(stage)))
		assert_bool(d.jarling).is_false()
		assert_float(d.telegraph_time()).is_greater_equal(1.0)
		assert_bool(ResourceLoader.exists(SFX % d.bark)).override_failure_message("%s bark" % id).is_true()
		var c: Creature = (load("res://scenes/creatures/%s.tscn" % id) as PackedScene).instantiate()
		assert_object(c.data).is_same(d)
		c.free()
		var rule: PopulationRule = null
		for r in _life(d.ring).species:
			if r.id == id:
				rule = r
		assert_object(rule).override_failure_message("%s has no counter in %s_life" % [id, d.ring]).is_not_null()
		assert_str(rule.live).is_equal("res://scenes/creatures/%s.tscn" % id)
		# every creature but a Jarling becomes food: at the latest by the stage after its own
		assert_bool(d.size_stage <= _rules.stage_info(maxi(stage, d.size_stage)).edible_size).is_true()


func test_the_shield_bug_is_a_telegraphed_stage_two_threat_that_eats_aphids() -> void:
	var d := load("res://data/creatures/shield_bug.tres") as CreatureData
	assert_bool(d.is_threat_to(2)).is_true()
	assert_bool(d.is_threat_to(3)).is_false()
	assert_str(String(d.hunts)).is_equal("aphid")
	assert_float(d.telegraph_time()).is_greater_equal(1.2)
	assert_bool(ResourceLoader.exists(SFX % d.windup_cue)).is_true()


func test_the_new_counters_leave_the_old_food_chains_alone() -> void:
	var old := [&"root", &"grub", &"beetle", &"centipede", &"mushroom", &"ant", &"bird"]
	for ring in [&"dirt", &"topsoil"]:
		for r: PopulationRule in _life(ring).species:
			if r.id in CREATURES:
				for prey in r.eats:
					assert_bool(prey in old).override_failure_message("%s eats old %s" % [r.id, prey]).is_false()


func _met_live(ring: StringName, stage: int) -> void:
	_planet(ring, stage)
	for i in 30:
		_dir.fit_live()
	for id in CREATURES:
		if load("res://data/creatures/%s.tres" % id).ring != ring:
			continue
		var live := _dir.live_of(id)
		assert_int(live.size()).override_failure_message("no live %s near a stage-%d worm in the %s" % [id, stage, ring]).is_greater(0)
		var c: Creature = live[0]
		var band := _dir.ring_band(ring)
		assert_float(_dir.depth_of(c.position)).is_between(band.x - 0.01, band.y + 0.01)


func test_the_dirt_creatures_spawn_near_a_stage_one_worm() -> void:
	_met_live(&"dirt", 1)
	# a stage-1 worm eats a mite; the wireworm is too big until stage 2
	assert_bool(_worm.can_eat(load("res://data/creatures/mite.tres"))).is_true()
	assert_bool(_worm.can_eat(load("res://data/creatures/wireworm.tres"))).is_false()


func test_the_topsoil_creatures_spawn_near_a_stage_two_worm() -> void:
	_met_live(&"topsoil", 2)
	for id in [&"aphid", &"caterpillar", &"snail"]:
		assert_bool(_worm.can_eat(load("res://data/creatures/%s.tres" % id))).is_true()
	assert_bool(_worm.can_eat(load("res://data/creatures/shield_bug.tres"))).is_false()


# --- events -----------------------------------------------------------------------------------

func _event(id: StringName) -> RingEvent:
	for e in RingEvents.all_events(RingsDirector.LIVES):
		if e.id == id:
			return e
	return null


func test_each_event_is_data_in_its_ring_with_a_cue_and_a_food() -> void:
	for id in EVENTS:
		var e := _event(id)
		assert_object(e).override_failure_message("%s missing" % id).is_not_null()
		assert_str(String(e.ring)).is_equal(String(_ring_of_stage(EVENTS[id])))
		assert_int(e.stage_from).is_equal(EVENTS[id])
		assert_bool(ResourceLoader.exists(SFX % e.cue)).override_failure_message("%s cue" % id).is_true()
		assert_object(e.food).is_not_null()
		assert_str(String(e.food.ring)).is_equal(String(e.ring))
		assert_int(e.count).is_greater(0)
		assert_bool(e.fx in [&"confetti", &"plant", &"leaf", &"yum"]).is_true()


func _play_events(ring: StringName, stage: int) -> Dictionary:
	_planet(ring, stage)
	_dir.raining = true
	var heard := {}
	_dir.events.happened.connect(func(id: StringName, _at: Vector2) -> void: heard[id] = int(heard.get(id, 0)) + 1)
	for i in 1200:
		_dir.events.step(1.0)
	return heard


func test_the_dirt_events_happen_beside_a_stage_one_worm() -> void:
	var heard := _play_events(&"dirt", 1)
	for id in [&"root_burst", &"marble_spill", &"egg_clutch"]:
		assert_int(int(heard.get(id, 0))).override_failure_message("%s never happened" % id).is_greater(0)
		assert_bool(Audio.played.has(_event(id).cue)).is_true()
	assert_bool(heard.has(&"seed_shower")).is_false()
	var band := _dir.ring_band(&"dirt")
	assert_int(_dir.events.foods.size()).is_greater(0)
	for p in _dir.events.foods:
		assert_float(_dir.depth_of(p.home)).is_between(band.x, band.y)
		assert_str(String((p.data as RingFood).ring)).is_equal("dirt")


func test_the_topsoil_events_wait_for_stage_two() -> void:
	var heard := _play_events(&"topsoil", 1)
	for id in [&"seed_shower", &"fairy_ring", &"dew_drip"]:
		assert_bool(heard.has(id)).override_failure_message("%s happened to a stage-1 worm" % id).is_false()


func test_the_topsoil_events_happen_beside_a_stage_two_worm() -> void:
	var heard := _play_events(&"topsoil", 2)
	for id in [&"seed_shower", &"fairy_ring", &"dew_drip"]:
		assert_int(int(heard.get(id, 0))).override_failure_message("%s never happened" % id).is_greater(0)


func test_the_first_one_comes_at_first_after_then_every() -> void:
	_planet(&"dirt", 1)
	var e := _event(&"root_burst")
	var at: Array[float] = []
	var t := [0.0]
	_dir.events.happened.connect(func(id: StringName, _p: Vector2) -> void:
		if id == e.id:
			at.append(t[0]))
	for i in int(e.first_after + 2.0 * e.every) + 2:
		t[0] += 1.0
		_dir.events.step(1.0)
	assert_int(at.size()).is_equal(3)
	assert_float(at[0]).is_equal_approx(e.first_after, 1.0)
	assert_float(at[1] - at[0]).is_equal_approx(e.every, 1.0)


func test_the_fairy_ring_needs_rain_and_rings_the_worm() -> void:
	_planet(&"topsoil", 2)
	var e := _event(&"fairy_ring")
	assert_bool(e.after_rain).is_true()
	_dir.raining = false
	for i in 600:
		_dir.events.step(1.0)
	assert_int(int(_dir.events.times[e.id])).is_equal(0)
	_dir.raining = true
	_dir.events.step(1.0)
	assert_int(int(_dir.events.times[e.id])).is_equal(1)
	var head := _world.to_local(_worm.head_position())
	var mushrooms := _dir.events.foods.filter(func(p: RingPickup) -> bool: return p.get_meta("ring_event") == e.id)
	assert_int(mushrooms.size()).is_equal(e.count)
	for p in mushrooms:
		assert_float(p.home.distance_to(head)).is_less(e.distance + 30.0)


func test_falling_foods_are_seen_falling_from_above() -> void:
	_planet(&"topsoil", 2)
	var e := _event(&"seed_shower")
	assert_int(e.shape).is_equal(RingEvent.Shape.FALL)
	var got := _dir.events.play(e, _worm)
	assert_int(got.size()).is_equal(e.count)
	for p in got:
		# it starts above where it lands (farther from the core) and lands on its home
		assert_float(p.position.length()).is_greater(p.home.length() + RingEvents.FALL_FROM * 0.5)
	await get_tree().create_timer(RingEvents.FALL_TIME + 0.2).timeout
	for p in got:
		assert_float(p.position.distance_to(p.home)).is_less(1.0)


func test_event_foods_are_food_and_capped() -> void:
	_planet(&"dirt", 1)
	var e := _event(&"marble_spill")
	for i in 8:
		_dir.events.play(e, _worm)
	assert_int(_dir.events.foods.size()).is_less_equal(RingEvents.MAX_FOODS)
	var p: RingPickup = _dir.events.foods.back()
	assert_bool(p.is_in_group(&"food")).is_true()
	assert_bool(_worm.can_eat(p.data)).is_true()
