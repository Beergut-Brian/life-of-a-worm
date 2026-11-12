## Creatures (CreatureData + scenes/creatures/): bigger eats smaller, read by size at a glance; the
## beetle and the bird both telegraph for at least a full second before they can reach a worm; a
## bird can never eat a worm at or above its stage (boing); a worm that moved off the shadow is
## missed (boing, offended); beetles eat grubs they bump into. Objects are staged in fixed places;
## steps use a fixed delta.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const BEETLE := preload("res://scenes/creatures/beetle.tscn")
const GRUB := preload("res://scenes/creatures/grub.tscn")
const BIRD := preload("res://scenes/creatures/bird.tscn")
const DT := 1.0 / 60.0
const CREATURES := ["grub", "ant", "beetle", "bird", "boot"]
const HEAD_R := 8.0   # a stage-1 worm's head (16 px segment); grows Worm.SIZE_STEP per stage


func before_test() -> void:
	Audio.played.clear()


func _worm(at := Vector2.ZERO, stage := 1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	var m := WormGrowth.new()
	if stage > 1:
		m.start_at_stage(stage)
	w.model = m
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _make(scene: PackedScene, at: Vector2) -> Creature:
	var c: Creature = scene.instantiate()
	c.position = at
	add_child(c)
	c.set_physics_process(false)
	return auto_free(c)


func test_bigger_than_me_is_obvious_by_size() -> void:
	for id in CREATURES:
		var d: CreatureData = load("res://data/creatures/%s.tres" % id)
		for s in range(1, d.size_stage):
			var head := HEAD_R * (1.0 + Worm.SIZE_STEP * (s - 1))
			assert_float(d.radius).override_failure_message("%s should look bigger than a stage-%d worm" % [id, s]) \
				.is_greater_equal(head * 1.25)
		if d.size_stage == 1:
			assert_float(d.radius).is_less(HEAD_R)
	for f in DirAccess.get_files_at("res://data/foods"):
		if f.ends_with(".tres"):
			var food: FoodData = load("res://data/foods/" + f)
			if food is RingFood and food.size_stage == 1:
				assert_float(food.radius).override_failure_message("%s should look smaller than a stage-1 worm" % food.id).is_less(HEAD_R)


func test_every_creature_telegraphs_at_least_a_second() -> void:
	for id in CREATURES:
		var d: CreatureData = load("res://data/creatures/%s.tres" % id)
		assert_float(d.telegraph_time()).is_greater_equal(1.0)
		assert_str(d.bark).is_not_empty()


func test_food_or_threat_by_stage() -> void:
	var beetle: CreatureData = load("res://data/creatures/beetle.tres")
	var small := _worm(Vector2.ZERO, 1)
	assert_bool(small.can_eat(beetle)).is_false()
	assert_bool(beetle.is_threat_to(1)).is_true()
	small.model.start_at_stage(2)
	assert_bool(small.can_eat(beetle)).is_true()
	assert_bool(beetle.is_threat_to(2)).is_false()


func test_beetle_winds_up_a_full_second_before_it_can_eat() -> void:
	var w := _worm(Vector2.ZERO)
	var segs := w.model.segments.size()
	var b := _make(BEETLE, w.head_position() + Vector2(40, 0))
	var eaten := []   # lambdas capture locals by value: collect in an array
	var windup_at := -1.0
	var eaten_at := -1.0
	var t := 0.0
	w.eaten_by.connect(func(_p: int, _c: StringName) -> void: eaten.append(true))
	for i in 240:
		b.step(DT)
		t += DT
		if windup_at < 0.0 and b.mode == Creature.Mode.WINDUP:
			windup_at = t
		if not eaten.is_empty():
			eaten_at = t
			break
	assert_float(windup_at).is_greater_equal(0.0)
	assert_float(eaten_at).is_greater(0.0)
	assert_float(eaten_at - windup_at).is_greater_equal(1.0)
	assert_int(w.model.segments.size()).is_equal(segs - 1)
	assert_int(w.model.stage).is_equal(1)
	assert_int(Audio.played.get("beetle_windup", 0)).is_greater_equal(1)


## A worm its own size (stage 2) is ignored, not fled (GAME.md "Equal size ignores you";
## tests/test_creatures_size.gd): the beetle runs from a worm bigger than it.
func test_beetle_runs_from_a_worm_that_outgrew_it() -> void:
	var w := _worm(Vector2.ZERO, 3)
	var b := _make(BEETLE, w.head_position() + Vector2(40, 0))
	var d0 := b.global_position.distance_to(w.head_position())
	for i in 60:
		b.step(DT)
	assert_int(b.mode).is_equal(Creature.Mode.FLEE)
	assert_float(b.global_position.distance_to(w.head_position())).is_greater(d0)
	assert_bool(b.is_in_group(&"food")).is_true()


func test_beetle_eats_a_grub_it_bumps_into() -> void:
	var b := _make(BEETLE, Vector2(5000, 0))
	var g := _make(GRUB, Vector2(5012, 0))
	var ate := []
	b.ate_creature.connect(func(prey: Creature) -> void: ate.append(prey.data.id))
	b.step(DT)
	assert_array(ate).contains([&"grub"])
	assert_bool(g.is_queued_for_deletion()).is_true()


func _bird_at(w: Worm) -> Bird:
	var bird: Bird = BIRD.instantiate()
	add_child(bird)
	bird.set_physics_process(false)
	bird.aim(w.head_position(), Vector2.UP)
	return auto_free(bird)


func test_bird_shadow_shows_a_full_second_before_the_peck() -> void:
	var w := _worm(Vector2.ZERO, 1)
	var segs := w.model.segments.size()
	var bird := _bird_at(w)
	var shadow_at := -1.0
	var eaten_at := -1.0
	var eaten := []
	var t := 0.0
	w.eaten_by.connect(func(_p: int, _c: StringName) -> void: eaten.append(true))
	for i in 300:
		bird.step(DT)
		t += DT
		if shadow_at < 0.0 and bird.phase == Bird.Peck.SHADOW:
			shadow_at = t
		if not eaten.is_empty():
			eaten_at = t
			break
	assert_float(shadow_at).is_greater_equal(0.0)
	assert_float(eaten_at - shadow_at).is_greater_equal(1.0)
	assert_bool(bird.caught).is_true()
	assert_int(w.model.segments.size()).is_equal(segs - 1)


func test_bird_cannot_eat_a_worm_bigger_than_it() -> void:
	for stage in [3, 4]:
		var w := _worm(Vector2(stage * 400, 0), stage)
		var segs := w.model.segments.size()
		var bird := _bird_at(w)
		for i in 180:
			bird.step(DT)
		assert_bool(bird.caught).is_false()
		assert_int(w.model.segments.size()).is_equal(segs)
	assert_int(Audio.played.get("boing", 0)).is_greater_equal(2)
	assert_int(Audio.played.get("bird_offended", 0)).is_greater_equal(2)


func test_a_worm_that_wriggles_off_the_shadow_is_missed() -> void:
	var w := _worm(Vector2.ZERO, 1)
	var segs := w.model.segments.size()
	var bird := _bird_at(w)
	for i in 50:   # into the shadow
		bird.step(DT)
	w.head.position += Vector2(60, 0)   # the kid tunnels away during the telegraph
	for i in 130:
		bird.step(DT)
	assert_bool(bird.caught).is_false()
	assert_int(w.model.segments.size()).is_equal(segs)
	assert_int(Audio.played.get("boing", 0)).is_greater_equal(1)
