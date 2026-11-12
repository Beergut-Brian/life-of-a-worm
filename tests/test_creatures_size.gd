## Creature behaviour from size (feature/worm-creatures-1; PLAN-STATUS L-04, S-07, L-15, L-16, L-17).
## The size table picks flee / amble / ignore; an outgrown species flips to food exactly once and its
## first bite gets the sting and the grin; a Jarling is never food; the eaten path costs one
## segment and gives 0.5 s of invulnerability. Everything is staged in fixed places, far apart,
## stepped with a fixed delta; no physics piles.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const BEETLE := preload("res://scenes/creatures/beetle.tscn")
const GRUB := preload("res://scenes/creatures/grub.tscn")
const DT := 1.0 / 60.0
const F := CreatureSense.React.FLEE
const I := CreatureSense.React.IGNORE
const A := CreatureSense.React.AMBLE


func before_test() -> void:
	Audio.played.clear()
	Save.set_value(Outgrown.SAVE_KEY, {})


func after_test() -> void:
	Save.set_value(Outgrown.SAVE_KEY, {})


func _worm(at := Vector2.ZERO, stage := 1, player := Players.P1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	var m := WormGrowth.new()
	if stage > 1:
		m.start_at_stage(stage)
	while m.segments.size() < 4:
		m.segments.append(&"")
	w.model = m
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _make(scene: PackedScene, at: Vector2, data: CreatureData = null) -> Creature:
	var c: Creature = scene.instantiate()
	if data:
		c.data = data
	c.position = at
	add_child(c)
	c.set_physics_process(false)
	return auto_free(c)


func _steps(c: Creature, n: int) -> void:
	for i in n:
		c.step(DT)


# --- L-04: the size table ----------------------------------------------------------------------

func test_size_table_picks_flee_amble_or_ignore() -> void:
	# [creature size, worm size, reaction]
	var table := [
		[1, 1, I], [1, 2, F], [1, 7, F],
		[2, 1, A], [2, 2, I], [2, 3, F],
		[3, 2, A], [3, 3, I], [3, 4, F],
		[4, 1, A], [4, 4, I], [4, 5, F],
		[6, 5, A], [6, 6, I], [6, 7, F],
		[7, 6, A], [7, 7, I],
	]
	for row in table:
		assert_int(CreatureSense.react(row[0], row[1])) \
			.override_failure_message("creature %d vs worm %d" % [row[0], row[1]]).is_equal(row[2])
	for s in range(1, 8):
		assert_int(CreatureSense.react(1, s, true)).is_equal(CreatureSense.React.FRIEND)
		assert_int(CreatureSense.react(7, s, true)).is_equal(CreatureSense.React.FRIEND)


func test_worm_size_is_the_stage_tables_edible_size_and_agrees_with_can_eat() -> void:
	var rules := WormRules.default_rules()
	for stage in range(1, rules.max_stage() + 1):
		var w := _worm(Vector2(stage * 1000, 0), stage)
		for f in DirAccess.get_files_at("res://data/creatures"):
			if not f.ends_with(".tres"):
				continue
			var d: CreatureData = load("res://data/creatures/" + f)
			assert_int(CreatureSense.worm_size(w, d)).is_equal(rules.stage_info(stage).edible_size)
			assert_bool(CreatureSense.is_food(d, w)).override_failure_message("%s at stage %d" % [d.id, stage]) \
				.is_equal(w.can_eat(d))


func test_bigger_beetle_ambles_toward_a_smaller_worm() -> void:
	var w := _worm(Vector2.ZERO, 1)
	var b := _make(BEETLE, w.head_position() + Vector2(120, 0))
	var d0 := b.global_position.distance_to(w.head_position())
	_steps(b, 30)
	assert_int(b.mode).is_equal(Creature.Mode.STALK)
	assert_float(b.global_position.distance_to(w.head_position())).is_less(d0)
	# ambles: slower than the worm (which moves at its base speed)
	var moved := d0 - b.global_position.distance_to(w.head_position())
	assert_float(moved / (30 * DT)).is_less(w.model.stats.value("speed") * 0.5)


func test_equal_size_beetle_ignores_the_worm_but_is_still_food() -> void:
	var w := _worm(Vector2(3000, 0), 2)
	var b := _make(BEETLE, w.head_position() + Vector2(40, 0))
	for i in 120:
		b.step(DT)
		assert_int(b.mode).is_not_equal(Creature.Mode.STALK)
		assert_int(b.mode).is_not_equal(Creature.Mode.WINDUP)
		assert_int(b.mode).is_not_equal(Creature.Mode.FLEE)
	assert_int(b.react_to(w)).is_equal(I)
	assert_bool(w.can_eat(b.data)).is_true()
	assert_bool(b.is_in_group(&"food")).is_true()


func test_smaller_beetle_flees_slowly_from_a_bigger_worm() -> void:
	var w := _worm(Vector2(6000, 0), 3)
	var b := _make(BEETLE, w.head_position() + Vector2(40, 0))
	var d0 := b.global_position.distance_to(w.head_position())
	_steps(b, 60)
	assert_int(b.mode).is_equal(Creature.Mode.FLEE)
	var d1 := b.global_position.distance_to(w.head_position())
	assert_float(d1).is_greater(d0)
	assert_float((d1 - d0) / (60 * DT)).is_less(w.model.stats.value("speed") * 0.5)


func test_grub_stays_put_for_its_own_size_and_scoots_from_a_bigger_worm() -> void:
	var w := _worm(Vector2(9000, 0), 1)
	var g := _make(GRUB, w.head_position() + Vector2(30, 0))
	var p0 := g.global_position
	_steps(g, 60)
	assert_vector(g.global_position).is_equal(p0)
	w.model.start_at_stage(2)
	_steps(g, 60)
	assert_float(g.global_position.distance_to(w.head_position())).is_greater(30.0)


# --- S-07 / L-16: outgrown, exactly once ---------------------------------------------------------

func test_outgrown_bug_turns_to_food_exactly_once() -> void:
	var w := _worm(Vector2(12000, 0), 1)
	var mem := Outgrown.of(w)
	var flips := []
	var bites := []
	mem.flipped.connect(func(s: StringName) -> void: flips.append(s))
	mem.first_bite.connect(func(s: StringName) -> void: bites.append(s))
	var b := _make(BEETLE, w.head_position() + Vector2(200, 0))
	b.step(DT)
	assert_bool(mem.was_threat(&"beetle")).is_true()
	assert_bool(b.can_be_eaten_by(w)).is_false()
	assert_array(flips).is_empty()
	w.model.start_at_stage(2)
	_steps(b, 30)
	assert_array(flips).contains_exactly([&"beetle"])
	assert_bool(b.can_be_eaten_by(w)).is_true()
	assert_int(Audio.played.get("boing", 0)).is_equal(1)
	# growing more, or meeting another beetle, never flips it again
	w.model.start_at_stage(3)
	var b2 := _make(BEETLE, w.head_position() + Vector2(-200, 0))
	_steps(b, 30)
	_steps(b2, 30)
	assert_array(flips).contains_exactly([&"beetle"])
	assert_int(Audio.played.get("boing", 0)).is_equal(1)
	# the first bite of one: the sting and the grin, once
	b.global_position = w.mouth_position()
	b.take()
	assert_array(bites).contains_exactly([&"beetle"])
	assert_int(Audio.played.get("now_i_eat_you", 0)).is_equal(1)
	var grin := _find_grin()
	assert_object(grin).is_not_null()
	b2.global_position = w.mouth_position()
	b2.take()
	assert_array(bites).contains_exactly([&"beetle"])
	assert_int(Audio.played.get("now_i_eat_you", 0)).is_equal(1)
	if grin:
		grin.free()


func test_never_a_threat_means_no_sting_and_out_of_sight_does_not_count() -> void:
	var w := _worm(Vector2(15000, 0), 2)
	var g := _make(GRUB, w.head_position() + Vector2(20, 0))
	g.step(DT)
	g.global_position = w.mouth_position()
	g.take()
	assert_int(Audio.played.get("now_i_eat_you", 0)).is_equal(0)
	var w1 := _worm(Vector2(18000, 0), 1, Players.P2)
	var far := _make(BEETLE, w1.head_position() + Vector2(Outgrown.SIGHT + 200, 0))
	far.step(DT)
	assert_bool(Outgrown.of(w1).was_threat(&"beetle")).is_false()


func test_outgrown_memory_survives_a_reload_of_the_tin() -> void:
	var w := _worm(Vector2(21000, 0), 1)
	Outgrown.of(w).note(&"beetle", A, 10.0)
	Outgrown.of(w).note(&"beetle", I, 10.0)
	var again := Outgrown.new()
	again.from_dict(Save.get_value(Outgrown.SAVE_KEY, {}).get(str(Players.P1), {}))
	assert_bool(again.note(&"beetle", I, 10.0)).is_false()
	assert_bool(again.note_bite(&"beetle")).is_true()


func _find_grin() -> GrinCloseup:
	for n in get_tree().root.find_children("GrinCloseup*", "", true, false):
		if n is GrinCloseup:
			return n
	return null


# --- L-17: Jarlings are never food -----------------------------------------------------------------

func _jarling_data(size: int) -> CreatureData:
	var d := CreatureData.new()
	d.id = &"test_jarling"
	d.size_stage = size
	d.radius = 6.0
	d.behaviour = CreatureData.Behaviour.WIGGLE
	d.speed = 14.0
	d.bark = "mole_sorry"
	d.jarling = true
	return d


func test_a_jarling_is_never_food_and_never_a_threat() -> void:
	var rules := WormRules.default_rules()
	for stage in range(1, rules.max_stage() + 1):
		var w := _worm(Vector2(30000 + stage * 500, 0), stage)
		for size in [1, 3, 7]:
			var j := _make(GRUB, w.mouth_position(), _jarling_data(size))
			j.step(DT)
			assert_bool(j.is_in_group(&"food")).is_false()
			assert_bool(j.is_in_group(&"jarlings")).is_true()
			assert_bool(j.can_be_eaten_by(w)).is_false()
			assert_bool(j.threatens(w)).is_false()
			assert_int(j.react_to(w)).is_equal(CreatureSense.React.FRIEND)
			w._eat_and_carry(false, w.model.stats, DT)
			assert_bool(j.is_queued_for_deletion()).is_false()
			assert_bool(Outgrown.of(w).was_threat(&"test_jarling")).is_false()


func test_every_creature_except_a_jarling_becomes_food_eventually() -> void:
	var rules := WormRules.default_rules()
	var top := _worm(Vector2(40000, 0), rules.max_stage())
	for f in DirAccess.get_files_at("res://data/creatures"):
		if not f.ends_with(".tres"):
			continue
		var d: CreatureData = load("res://data/creatures/" + f)
		assert_bool(d.jarling).override_failure_message("%s is a Jarling in data/creatures" % d.id).is_false()
		assert_bool(CreatureSense.is_food(d, top)).override_failure_message("%s never becomes food" % d.id).is_true()


# --- L-15: eaten ------------------------------------------------------------------------------------

func test_eaten_costs_one_segment_and_sparkles_safe_for_half_a_second() -> void:
	var w := _worm(Vector2(50000, 0), 1)
	var n := w.model.segments.size()
	var b := _make(BEETLE, w.head_position() + Vector2(10, 0))
	b._eat_worm(w)
	assert_int(w.model.segments.size()).is_equal(n - 1)
	assert_int(w.model.stage).is_equal(1)
	assert_bool(b.is_gulping()).is_true()   # the cause is on screen: the beetle mid-gulp
	assert_int(Audio.played.get("eaten", 0)).is_equal(1)
	assert_int(Audio.played.get("creature_munch", 0)).is_equal(1)
	assert_bool(Gulp.is_safe(w)).is_true()
	assert_bool(b.threatens(w)).is_false()
	# a second beetle right there cannot eat it while it sparkles
	var b2 := _make(BEETLE, w.head_position() + Vector2(-10, 0))
	b2._eat_worm(w)
	assert_int(w.model.segments.size()).is_equal(n - 1)
	assert_bool(b2.is_gulping()).is_false()
	var s := Gulp.sparkle_of(w)
	s.step(0.45)
	assert_bool(Gulp.is_safe(w)).is_true()
	s.step(0.06)
	assert_bool(Gulp.is_safe(w)).is_false()
	await get_tree().process_frame
	b2._eat_worm(w)
	assert_int(w.model.segments.size()).is_equal(n - 2)


func test_eaten_worm_pops_out_the_far_end_or_next_to_a_close_partner() -> void:
	var w := _worm(Vector2(60000, 0), 1)
	var b := _make(BEETLE, w.head_position() + Vector2(10, 0))
	b._eat_worm(w)
	# far end: on the side of the beetle away from where it bit
	assert_float(w.head_position().x).is_greater(b.global_position.x)
	var w2 := _worm(Vector2(70000, 0), 1)
	var partner := _worm(Vector2(70060, 40), 1, Players.P2)
	var b2 := _make(BEETLE, w2.head_position() + Vector2(10, 0))
	b2._eat_worm(w2)
	assert_float(w2.head_position().distance_to(partner.head_position())).is_equal_approx(Gulp.PARTNER_SIDE, 0.5)
