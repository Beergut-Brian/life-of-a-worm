## D105 content, stages 3 to 7 (Kaden's Docket answer D105 b, 2026-11-13): the new things of the
## big-worm stages. Each one exists in data, opens at its stage (its ring's stage, its size, or its
## stage gate, whichever is last) and is met in play: foods are placed in their ring on a real
## PolarWorld with the real RingsDirector (after every older static, so a saved tin keeps its
## slots); creatures spawn from their ring's counters only near a worm of their stage; ring events
## happen beside a worm of their stage in their ring; space sights drift in round the worms on the
## real space stage and are eaten (or bump) by the stage's own rule. The list is
## tests/d105_stage37_table.gd. Nothing here touches the pacing numbers.
extends GdUnitTestSuite

const T := preload("res://tests/d105_stage37_table.gd")
const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const SPACE := "res://scenes/levels/space_stage.tscn"
const SPACE_DIR := "res://.scratch/d105_s37_saves"
const RADIUS := 300
const SFX := "res://assets/audio/sfx/%s.ogg"
const FLAVOURS: Array[StringName] = [&"root", &"bug", &"stone", &"junk", &"water", &"crystal", &"cloud"]

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm
var _rules: WormRules
var _level: Node2D


## Every new thing of D105 stages 3 to 7 (the novelty test and the report read it).
static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in [T.FOODS, T.CREATURES, T.EVENTS, T.SIGHTS]:
		for k in d:
			out.append(k)
	return out


## The stage a worm first plays in a ring: the stage that opens it, the crust stage for the
## surface, the sky's own edible_from for the sky.
static func ring_stage(ring: StringName) -> int:
	var r := WormRules.default_rules()
	if ring == RingsDirector.SKY.ring:
		return RingsDirector.SKY.edible_from
	for s in range(1, 8):
		var d := r.stage_info(s)
		if d.opens_ring == ring or d.crust_ring == ring:
			return s
	return 99


static func rule_of(id: StringName) -> PopulationRule:
	for life in RingsDirector.all_lives():
		for r: PopulationRule in life.species:
			if r.id == id:
				return r
	return null


static func life_of(ring: StringName) -> RingLife:
	for l in RingsDirector.all_lives():
		if l.ring == ring:
			return l
	return null


func before() -> void:
	DirAccess.make_dir_recursive_absolute(SPACE_DIR)


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
	for f in DirAccess.get_files_at(SPACE_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SPACE_DIR + "/" + f))


func after_test() -> void:
	for n in [_dir, _worm, _world, _level]:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_dir = null
	_worm = null
	_world = null
	if _level != null:
		_level = null
		for s in get_tree().get_nodes_in_group(&"story"):
			s.free()
		Players.reset()
		Save.use_slot("")
		Save.dir = "user://saves"


## A real planet with the worm's head in `ring` at `stage`.
func _planet(ring: StringName, stage: int) -> void:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * _mid(ring)
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
	if ring == RingsDirector.SKY.ring:
		return (RingsDirector.SKY.inner + RingsDirector.SKY.outer) * 0.5
	var inner := 0.0
	for r in RINGS.rings:
		if r.id == ring:
			return (inner + r.outer) * 0.5
		inner = r.outer
	return 0.5


func _band(ring: StringName) -> Vector2:
	if ring == RingsDirector.SURFACE.ring:
		return Vector2(RingsDirector.SURFACE.scatter_inner, RingsDirector.SURFACE.scatter_outer)
	return _dir.ring_band(ring)


func _edible(f: FoodData, stage: int) -> bool:
	return f.size_stage <= _rules.stage_info(stage).edible_size


# --- the list ---------------------------------------------------------------------------------

func test_twenty_five_or_more_new_things_in_each_stage_and_no_copies() -> void:
	var per := { 3: 0, 4: 0, 5: 0, 6: 0, 7: T.SIGHTS.size() }
	for d in [T.FOODS, T.CREATURES, T.EVENTS]:
		for id in d:
			per[d[id]] = int(per[d[id]]) + 1
	for s in per:
		assert_int(int(per[s])).override_failure_message("stage %d has %d new things" % [s, per[s]]).is_between(25, 40)
	var seen := {}
	for id in all_ids():
		assert_bool(seen.has(id)).override_failure_message("%s twice" % id).is_false()
		seen[id] = true
	# none of them is an older thing
	for id in T.FOODS:
		assert_bool(ResourceLoader.exists("res://data/foods/%s.tres" % id)).is_true()
	for id in T.CREATURES:
		assert_bool(ResourceLoader.exists("res://data/creatures/%s.tres" % id)).is_true()


# --- foods ------------------------------------------------------------------------------------

func test_each_new_food_is_data_that_opens_at_its_stage() -> void:
	for id in T.FOODS:
		var stage: int = T.FOODS[id]
		var f := load("res://data/foods/%s.tres" % id) as RingFood
		assert_object(f).override_failure_message("%s is not a RingFood" % id).is_not_null()
		assert_str(String(f.id)).is_equal(String(id))
		var opens := maxi(ring_stage(f.ring), f.size_stage)
		assert_int(opens).override_failure_message("%s opens at %d" % [id, opens]).is_equal(stage)
		assert_bool(_edible(f, stage)).override_failure_message("%s not edible at %d" % [id, stage]).is_true()
		# and not before: the ring is shut, or it is a bonk
		assert_bool(ring_stage(f.ring) > stage - 1 or not _edible(f, stage - 1)) \
			.override_failure_message("%s already open at %d" % [id, stage - 1]).is_true()
		assert_bool(f.flavour in FLAVOURS).override_failure_message("%s flavour %s (no new flavour, no sweet: X-01)" % [id, f.flavour]).is_true()
		assert_bool(ResourceLoader.exists(SFX % f.eat_cue)).override_failure_message("%s eat_cue %s" % [id, f.eat_cue]).is_true()
		assert_float(f.growth).is_greater(0.0)
		assert_bool(life_of(f.ring).later_scatter.has(f)).override_failure_message("%s not in %s later_scatter" % [id, f.ring]).is_true()


func test_each_new_food_is_placed_in_its_ring_on_a_new_planet() -> void:
	_planet(&"dirt", 1)
	var seen := {}
	for s in _dir._statics:
		var id: StringName = s.food.id
		if T.FOODS.has(id):
			var band := _band(s.food.ring)
			assert_float(_dir.depth_of(s.node.position)).override_failure_message("%s depth" % id).is_between(band.x, band.y)
			seen[id] = int(seen.get(id, 0)) + 1
	for id in T.FOODS:
		assert_int(int(seen.get(id, 0))).override_failure_message("%s never placed" % id).is_greater_equal(2)


func test_older_tins_keep_their_static_slots() -> void:
	var keep := {}
	var added := 0
	for l in RingsDirector.all_lives():
		keep[l] = l.later_scatter_count
		added += l.later_scatter_count
		l.later_scatter_count = 0
	_planet(&"dirt", 1)
	var before: Array = _dir.to_dict().statics
	after_test()
	for l in keep:
		l.later_scatter_count = keep[l]
	_planet(&"dirt", 1)
	var now: Array = _dir.to_dict().statics
	assert_int(now.size()).is_equal(before.size() + added)
	for i in before.size():
		assert_str(String(now[i][0])).is_equal(String(before[i][0]))


func test_the_big_ones_come_back_bigger() -> void:
	# a size-6 time capsule in the dirt: a stage-5 worm bonks it, a stage-6 worm eats it
	var cap := load("res://data/foods/time_capsule.tres") as RingFood
	assert_bool(_edible(cap, 5)).is_false()
	assert_bool(_edible(cap, 6)).is_true()
	assert_str(String(cap.ring)).is_equal("dirt")
	# a size-3 rubber duck in the topsoil: a bonk at stage 2, food at 3
	var duck := load("res://data/foods/rubber_duck.tres") as RingFood
	assert_bool(_edible(duck, 2)).is_false()
	assert_bool(_edible(duck, 3)).is_true()


func test_the_seeds_plant_gardens_and_the_mole_keeps_giving_plain_seeds() -> void:
	var glow := load("res://data/foods/glow_seed.tres") as RingFood
	assert_str(String(glow.plants)).is_equal("crystal")
	assert_bool(RINGS.garden_tiles.has(glow.plants)).is_true()
	var bulb := load("res://data/foods/tulip_bulb.tres") as RingFood
	assert_str(String(bulb.plants)).is_equal("root")
	# the Mole's swap gift (SwapShop.seed_for) is still the plain seed for root and crystal finds
	for gave in [load("res://data/foods/carrot_tip.tres"), load("res://data/foods/core_crystal.tres")]:
		var got := SwapShop.seed_for(gave)
		assert_bool(got.id in [&"glow_seed", &"tulip_bulb"]).override_failure_message("%s -> %s" % [gave.id, got.id]).is_false()


func test_a_worm_of_its_stage_eats_a_new_food_on_the_planet() -> void:
	_planet(&"deep_rock", 4)
	var p: RingPickup = null
	for s in _dir._statics:
		if s.food.id == &"coal_lump":
			p = s.node
			break
	assert_object(p).is_not_null()
	assert_bool(_worm.can_eat(p.data)).is_true()
	assert_bool(_worm.can_eat(load("res://data/foods/fire_opal.tres"))).is_false()   # stage 5
	p.take()
	assert_float(p.gone_at).is_greater_equal(0.0)


# --- creatures --------------------------------------------------------------------------------

func test_each_new_creature_is_data_with_a_scene_a_counter_and_a_stage_gate() -> void:
	for id in T.CREATURES:
		var stage: int = T.CREATURES[id]
		var d := load("res://data/creatures/%s.tres" % id) as CreatureData
		assert_object(d).is_not_null()
		assert_bool(d.jarling).is_false()
		assert_float(d.telegraph_time()).is_greater_equal(1.0)
		assert_bool(ResourceLoader.exists(SFX % d.bark)).override_failure_message("%s bark" % id).is_true()
		var c: Creature = (load("res://scenes/creatures/%s.tscn" % id) as PackedScene).instantiate()
		assert_object(c.data).is_same(d)
		c.free()
		var rule := rule_of(id)
		assert_object(rule).override_failure_message("%s has no counter" % id).is_not_null()
		assert_str(String(rule.ring)).is_equal(String(d.ring))
		assert_str(rule.live).is_equal("res://scenes/creatures/%s.tscn" % id)
		assert_int(maxi(ring_stage(d.ring), rule.stage_from)).override_failure_message("%s opens" % id).is_equal(stage)
		# every creature but a Jarling becomes food in the disk (stage 6 at the latest)
		assert_int(d.size_stage).is_less_equal(6)
		# a threat at its stage telegraphs (a wind-up of 1.2 s or more and its cue)
		if d.is_threat_to(stage):
			assert_float(d.telegraph_time()).override_failure_message("%s wind-up" % id).is_greater_equal(1.2)
			assert_bool(ResourceLoader.exists(SFX % d.windup_cue)).is_true()
		if d.hunts != &"":
			assert_bool(T.CREATURES.has(d.hunts)).override_failure_message("%s hunts an old creature" % id).is_true()
			assert_float(float(rule.eats.get(d.hunts, 0.0))).is_greater(0.0)


func test_the_new_counters_eat_only_new_prey() -> void:
	for id in T.CREATURES:
		for prey in rule_of(id).eats:
			assert_bool(T.CREATURES.has(prey)).override_failure_message("%s eats old %s" % [id, prey]).is_true()


func _live_ids(ring: StringName, stage: int, ticks := 60) -> Dictionary:
	_planet(ring, stage)
	for i in ticks:
		_dir.fit_live()
	var out := {}
	for id in T.CREATURES:
		if (load("res://data/creatures/%s.tres" % id) as CreatureData).ring == ring:
			out[id] = _dir.live_of(id).size()
	return out


## ring -> the stages whose new creatures live there.
const CREATURE_RINGS := { &"dirt": [3], &"topsoil": [3], &"deep_rock": [4], &"core": [5, 6], &"surface": [5, 6] }


func test_new_creatures_wait_for_their_stage_then_spawn_near_a_worm() -> void:
	for ring in CREATURE_RINGS:
		for stage in CREATURE_RINGS[ring]:
			var before := _live_ids(ring, stage - 1, 30)
			for id in before:
				if T.CREATURES[id] == stage:
					assert_int(int(before[id])).override_failure_message("%s near a stage-%d worm" % [id, stage - 1]).is_equal(0)
			after_test()
			var now := _live_ids(ring, stage, 200 if ring == &"surface" else 60)
			for id in now:
				if T.CREATURES[id] == stage:
					assert_int(int(now[id])).override_failure_message("no %s near a stage-%d worm in the %s" % [id, stage, ring]).is_greater(0)
					var c: Creature = _dir.live_of(id)[0]
					var band := _dir.ring_band(ring)
					assert_float(_dir.depth_of(c.position)).is_between(band.x - 0.01, band.y + 0.01)
			after_test()


func test_a_worm_that_shrinks_below_the_gate_sees_them_go() -> void:
	_planet(&"core", 6)
	for i in 60:
		_dir.fit_live()
	assert_int(_dir.live_of(&"magma_eel").size()).is_greater(0)
	_worm.model = WormGrowth.new()
	_worm.model.start_at_stage(5)
	for i in 10:
		_dir.fit_live()
	await get_tree().process_frame
	var left := _dir.live_of(&"magma_eel").filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	assert_int(left.size()).is_equal(0)


func test_the_new_threats_are_telegraphed_and_become_food_a_stage_later() -> void:
	for pair in [[&"earwig", 3], [&"toad", 3], [&"gem_beetle", 4], [&"fire_beetle", 5]]:
		var d := load("res://data/creatures/%s.tres" % pair[0]) as CreatureData
		assert_bool(d.is_threat_to(pair[1])).is_true()
		assert_bool(d.is_threat_to(pair[1] + 1)).is_false()
		assert_float(d.telegraph_time()).is_greater_equal(1.2)


# --- ring events ------------------------------------------------------------------------------

func _event(id: StringName) -> RingEvent:
	for e in RingEvents.all_events(RingsDirector.all_lives()):
		if e.id == id:
			return e
	return null


func test_each_event_is_data_in_its_ring_with_a_cue_and_a_food() -> void:
	for id in T.EVENTS:
		var e := _event(id)
		assert_object(e).override_failure_message("%s missing" % id).is_not_null()
		assert_int(e.stage_from).is_equal(T.EVENTS[id])
		assert_int(ring_stage(e.ring)).is_less_equal(e.stage_from)
		assert_bool(ResourceLoader.exists(SFX % e.cue)).override_failure_message("%s cue %s" % [id, e.cue]).is_true()
		assert_object(e.food).is_not_null()
		assert_str(String(e.food.ring)).is_equal(String(e.ring))
		assert_int(e.count).is_greater(0)
		assert_bool(e.fx in [&"confetti", &"plant", &"leaf", &"yum"]).is_true()
		# what it brings is food for a worm of its stage
		assert_bool(_edible(e.food, e.stage_from)).override_failure_message("%s food too big" % id).is_true()


func _play_events(ring: StringName, stage: int) -> Dictionary:
	_planet(ring, stage)
	_dir.raining = true
	var heard := {}
	_dir.events.happened.connect(func(id: StringName, _at: Vector2) -> void: heard[id] = int(heard.get(id, 0)) + 1)
	for i in 1200:
		_dir.events.step(1.0)
	return heard


func test_events_wait_for_their_stage_then_happen_beside_a_worm_in_their_ring() -> void:
	var groups := {}
	for id in T.EVENTS:
		var e := _event(id)
		var key := "%s %d" % [e.ring, e.stage_from]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(id)
	for key in groups:
		var ring := StringName(key.split(" ")[0])
		var stage := int(key.split(" ")[1])
		var early := _play_events(ring, stage - 1)
		for id in groups[key]:
			assert_bool(early.has(id)).override_failure_message("%s happened to a stage-%d worm" % [id, stage - 1]).is_false()
		after_test()
		var heard := _play_events(ring, stage)
		for id in groups[key]:
			assert_int(int(heard.get(id, 0))).override_failure_message("%s never happened" % id).is_greater(0)
			assert_bool(Audio.played.has(_event(id).cue)).is_true()
		var band := _dir.ring_band(ring)
		for p in _dir.events.foods:
			assert_float(_dir.depth_of(p.home)).is_between(band.x, band.y)
		after_test()


func test_the_new_shapes_trail_roll_and_rise() -> void:
	_planet(&"deep_rock", 4)
	var head := _world.to_local(_worm.head_position())
	# TRAIL: one after another in a line leading off, popping up in turn
	var rail := _dir.events.play(_event(&"rail_line"), _worm)
	assert_int(rail.size()).is_equal(6)
	for i in range(1, rail.size()):
		assert_float(rail[i].home.distance_to(rail[i - 1].home)).is_equal_approx(RingEvents.TRAIL_GAP, 6.0)
		assert_float(rail[i].home.distance_to(head)).is_greater(rail[i - 1].home.distance_to(head))
	assert_float(rail.back().scale.x).is_less(0.05)
	# ROLL: starts off to the side, rolls onto its spot
	var carts := _dir.events.play(_event(&"cart_roll"), _worm)
	for p in carts:
		assert_float(p.position.distance_to(p.home)).is_equal_approx(RingEvents.ROLL_FROM, 1.0)
	# RISE: starts below (nearer the core) and bobs up
	var bubbles := _dir.events.play(_event(&"spring_bubbles"), _worm)
	for p in bubbles:
		assert_float(p.position.length()).is_less(p.home.length() - RingEvents.FALL_FROM * 0.5)
	await get_tree().create_timer(maxf(RingEvents.ROLL_TIME, RingEvents.FALL_TIME * 1.4) + RingEvents.TRAIL_STEP * 6 + 0.3).timeout
	for p in carts + bubbles:
		assert_float(p.position.distance_to(p.home)).is_less(1.0)
	assert_float(rail.back().scale.x).is_equal_approx(1.0, 0.01)
	assert_float(carts[0].rotation).is_not_equal(0.0)


func test_sky_and_surface_events_show_their_foods_where_a_big_worm_can_eat_them() -> void:
	_planet(&"sky", 5)
	var got := _dir.events.play(_event(&"kite_string"), _worm)
	var band := _dir.ring_band(&"sky")
	for p in got:
		assert_float(_dir.depth_of(p.home)).is_between(band.x, band.y)
		assert_bool(_worm.can_eat(p.data)).is_true()
		assert_bool(p.is_in_group(&"food")).is_true()


# --- space (stage 7) --------------------------------------------------------------------------

func test_each_space_sight_is_data_a_stage_seven_worm_can_meet() -> void:
	var sights := SpaceSights.all_sights()
	assert_int(sights.size()).is_equal(T.SIGHTS.size())
	for s in sights:
		assert_bool(T.SIGHTS.has(s.id)).override_failure_message("%s not in the table" % s.id).is_true()
		assert_int(s.after_planets).is_equal(T.SIGHTS[s.id])
		assert_object(s.food).is_not_null()
		assert_bool(ResourceLoader.exists(SFX % s.cue)).override_failure_message("%s cue %s" % [s.id, s.cue]).is_true()
		assert_int(s.count).is_greater(0)
		assert_int(s.after_planets).is_between(0, 5)
		# food for a stage-7 worm, or (the rogue moon) a bigger body it bumps, never "ignore"
		assert_int(StageRule.relation(7, s.food.size_stage)).is_not_equal(StageRule.IGNORE)
	var bumps := sights.filter(func(s: SpaceSight) -> bool: return StageRule.relation(7, s.food.size_stage) == StageRule.THREAT)
	assert_int(bumps.size()).is_equal(1)


func _space() -> SpaceStage:
	Save.dir = SPACE_DIR
	Game.demo = false
	Players.reset()
	Players.join_virtual(Players.P1)
	Save.use_slot("d105_s37")
	Save.wipe()
	Save.set_value("seed", 7)
	_level = Node2D.new()
	add_child(_level)
	var st: SpaceStage = load(SPACE).instantiate()
	st.players.append(Players.P1)
	_level.add_child(st)
	st.set_process(false)
	st.drift.set_process(false)
	(st.get_node("SpaceStory") as SpaceStory).auto = false
	(st.get_node("OldReelOffer") as OldReelOffer).auto = false
	(st.get_node("SpaceSights") as SpaceSights).auto = false
	return st


func test_the_space_stage_brings_sights_round_the_worms_as_planets_are_eaten() -> void:
	var st := _space()
	var sights := st.get_node("SpaceSights") as SpaceSights
	var heard := {}
	sights.happened.connect(func(id: StringName, _at: Vector2) -> void: heard[id] = true)
	for i in 1200:
		sights.step(1.0)
	for s in sights.sights:
		assert_bool(heard.has(s.id)).override_failure_message("%s (after %d planets) with none eaten" % [s.id, s.after_planets]) \
			.is_equal(s.after_planets == 0)
	# five themed planets eaten: the rest come too
	for d in st.drift.order:
		st.drift.done.append(d.id)
	for i in 1200:
		sights.step(1.0)
	for s in sights.sights:
		assert_bool(heard.has(s.id)).override_failure_message("%s never came" % s.id).is_true()
	assert_int(sights.bodies.size()).is_less_equal(SpaceSights.MAX_BODIES)
	assert_bool(Audio.played.has("space_drift") or Audio.played.has("burst")).is_true()


func test_a_space_worm_eats_a_sight_and_the_rogue_moon_bumps_it() -> void:
	var st := _space()
	var sights := st.get_node("SpaceSights") as SpaceSights
	var w: SpaceWorm = st.worms[0]
	var by := {}
	for s in sights.sights:
		by[s.id] = s
	var dust := sights.play(by[&"stardust_ring"])
	assert_int(dust.size()).is_equal(10)
	var c := st.worms_centre()
	for p in dust:
		assert_str(String(p.kind)).is_equal("sight")
		assert_float(p.position.distance_to(c)).is_equal_approx(by[&"stardust_ring"].distance, 1.0)
	var segs := w.segments
	assert_int(st.resolve_contact(w, dust[0])).is_equal(StageRule.FOOD)
	assert_bool(dust[0].eaten).is_true()
	assert_int(w.segments).is_greater(segs)
	var moon := sights.play(by[&"rogue_moon"])
	assert_int(st.resolve_contact(w, moon[0])).is_equal(StageRule.THREAT)
	assert_bool(moon[0].eaten).is_false()
	# a streak comes in a line, aimed past the worms (never straight at them)
	var streak := sights.play(by[&"meteor_shower"])
	var v: Vector2 = streak[0].linear_velocity
	for i in range(1, streak.size()):
		assert_float(streak[i].linear_velocity.distance_to(v)).is_less(0.01)
	var to_c := (c - streak[0].position).normalized()
	assert_float(absf(v.normalized().dot(to_c))).is_less(0.999)
