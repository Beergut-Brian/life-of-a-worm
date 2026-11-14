## L-20 / L-21 (gap-close-41): "Every creature except a Jarling becomes food eventually" (GAME.md
## "Bugs and threats"), for the two that used to leave the food list for good. The topsoil bird is
## food to a worm that outgrew it (it cowers, its shadow shrinks, a worm whose mouth meets it
## swallows it, with the outgrow sting the first time) and never bonks a small worm under its
## shadow; the director still sends it at an outgrown worm near the top and counts an eaten one off
## the bird counter. The gardener's boot is food to a worm that outgrew it for the moment it is down
## after its stomp, never before and never to a smaller worm. Both ride in the mouth when carried.
## Staged in fixed places, stepped with a fixed delta; the worm's bite is called directly.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const BIRD := preload("res://scenes/creatures/bird.tscn")
const BOOT := preload("res://scenes/creatures/boot.tscn")
const RINGS := preload("res://data/rings/rings.tres")
const DT := 1.0 / 60.0


func before_test() -> void:
	Audio.played.clear()
	Save.set_value(Outgrown.SAVE_KEY, {})


func after_test() -> void:
	Save.set_value(Outgrown.SAVE_KEY, {})
	for n in get_tree().root.find_children("GrinCloseup*", "", true, false):
		n.free()


func _worm(at: Vector2, stage := 1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
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


## A bird aimed at the worm's mouth (up = -y), its physics off.
func _bird_at(w: Worm) -> Bird:
	var b: Bird = BIRD.instantiate()
	add_child(b)
	b.set_physics_process(false)
	b.aim(w.mouth_position(), Vector2.UP)
	return auto_free(b)


## A boot passing over the worm's mouth, its physics off.
func _boot_at(w: Worm) -> BootShadow:
	var b: BootShadow = BOOT.instantiate()
	add_child(b)
	b.set_physics_process(false)
	b.pass_over(w.mouth_position() + Vector2(0, -6), Vector2.UP)
	return auto_free(b)


## One frame of the bird and one bite of the worm (Worm._eat_and_carry, no stick, no carry).
func _frame(c: Creature, w: Worm, carry := false) -> void:
	if is_instance_valid(c) and not c.is_queued_for_deletion():
		c.step(DT)
	w._eat_and_carry(carry, w.model.stats, DT)


# --- L-20: the bird ---------------------------------------------------------------------------

func test_a_bird_is_food_only_to_a_worm_that_outgrew_it() -> void:
	var small := _worm(Vector2(0, 0), 2)
	var b := _bird_at(small)
	b.step(DT)
	assert_bool(b.is_in_group(&"food")).is_true()
	assert_bool(b.is_available()).is_false()
	var big := _worm(Vector2(5000, 0), 3)
	var b2 := _bird_at(big)
	b2.step(DT)
	assert_bool(b2.is_available()).is_true()
	assert_bool(CreatureSense.is_food(b2.data, big)).is_true()


func test_an_outgrown_bird_diving_at_a_worm_is_swallowed_with_the_sting() -> void:
	var w := _worm(Vector2(10000, 0), 2)
	var mem := Outgrown.of(w)
	var b := _bird_at(w)
	while b.phase == Bird.Peck.ARRIVE:   # flies in; over the worm it is in sight
		b.step(DT)
	assert_bool(mem.was_threat(&"bird")).is_true()   # it loomed once, so its first bite stings
	w.model.start_at_stage(3)
	var ate := []
	w.ate.connect(func(_p: int, id: StringName, _g: float) -> void: ate.append(id))
	var counted := []
	b.taken.connect(func(c: Creature) -> void: counted.append((c as Bird).eaten))
	for i in 240:
		if not is_instance_valid(b) or b._gone:
			break
		_frame(b, w)
	assert_bool(b._gone).is_true()
	assert_bool(b.caught).is_false()   # it never got its peck in
	assert_array(counted).contains_exactly([true])
	assert_array(ate).contains_exactly([&"bird"])
	assert_int(int(Audio.played.get("now_i_eat_you", 0))).is_equal(1)
	assert_int(int(Audio.played.get("bird_offended", 0))).is_equal(0)


func test_a_small_worm_under_its_shadow_never_bonks_on_it() -> void:
	var w := _worm(Vector2(15000, 0), 1)
	var segs := w.model.segments.size()
	var b := _bird_at(w)
	for i in 150:
		if b._gone or b.phase == Bird.Peck.LEAVE:
			break
		_frame(b, w)
	assert_int(int(Audio.played.get("bonk", 0))).is_equal(0)
	assert_bool(b.caught).is_true()   # the peck still lands, the one eaten way
	assert_int(w.model.segments.size()).is_equal(segs - 1)


func test_an_outgrown_birds_shadow_is_smaller() -> void:
	var small := _worm(Vector2(20000, 0), 2)
	var big := _worm(Vector2(25000, 0), 4)
	var a := _bird_at(small)
	var c := _bird_at(big)
	for i in 40:
		a.step(DT)
		c.step(DT)
	assert_bool(a._scared).is_false()
	assert_bool(c._scared).is_true()
	assert_float(Bird.OUTGROWN_SHADOW).is_less(1.0)


func test_a_carried_bird_rides_in_the_mouth_then_flies_off() -> void:
	var w := _worm(Vector2(30000, 0), 4)
	var b := _bird_at(w)
	for i in 3:
		b.step(DT)
	b.global_position = w.mouth_position()
	w._eat_and_carry(true, w.model.stats, DT)
	assert_object(w.carrying).is_same(b)
	var at := b.global_position
	for i in 30:
		b.step(DT)
	assert_vector(b.global_position).is_equal(at)   # the bird no longer drives itself
	var counted := []
	b.taken.connect(func(c: Creature) -> void: counted.append((c as Bird).eaten))
	w._eat_and_carry(false, w.model.stats, DT)   # let go
	assert_object(w.carrying).is_null()
	for i in 200:
		if b._gone:
			break
		b.step(DT)
	assert_array(counted).contains_exactly([false])   # it flew off: not counted as eaten


func test_the_director_sends_a_bird_at_an_outgrown_worm_and_counts_it_eaten() -> void:
	var world := PolarWorld.new()
	world.build_overview = false
	world.setup_planet(RINGS, 300, 4)
	add_child(world)
	world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * 300 * 16.0 * 0.76
	var w := _worm(start, 1)
	world.track(w.head)
	world.update_chunks(-1)
	var dir := RingsDirector.new()
	dir.auto_tick = false
	add_child(dir)
	dir.setup(world, start, 4, {})
	for b in dir.live_of(&"beetle"):   # no beetle near the top to peck instead
		b.position = b.position.normalized() * 16.0 * 40.0
	w.head.global_position = dir.polar(0.0, 0.0) + Vector2.from_angle(dir.spawn_point.angle()) * (dir.topsoil_top() - 32.0)
	w.model.start_at_stage(3)
	assert_object(dir.bird_target()).is_null()   # it is no longer a worm the bird hunts
	assert_object(dir.bird_meal_target()).is_same(w)
	var bird := dir.send_bird()
	assert_object(bird).is_not_null()
	var before := dir.ecology.count(&"bird")
	bird.take()   # swallowed
	assert_float(dir.ecology.count(&"bird")).is_equal_approx(before - 1.0, 0.001)
	for n in [dir, world]:
		remove_child(n)
		n.free()


# --- L-21: the gardener's boot ----------------------------------------------------------------

func test_an_outgrown_boot_is_food_only_while_it_is_down() -> void:
	var w := _worm(Vector2(40000, 0), 5)
	var b := _boot_at(w)
	b.step(DT)
	assert_bool(b.is_in_group(&"food")).is_true()
	while b._life < BootShadow.STOMP_AT - 0.1:
		b.step(DT)
	assert_bool(b.is_available()).is_false()   # only a shadow before the stomp
	while not b.did_stomp:
		b.step(DT)
	assert_bool(b.is_available()).is_true()
	assert_float(b.show_time()).is_equal(BootShadow.OUTGROWN_SHOW)
	while b._life < BootShadow.STOMP_AT + BootShadow.OUTGROWN_SHOW + 0.05:
		b.step(DT)
	assert_bool(b.is_available()).is_false()   # lifted again


func test_a_boot_is_never_food_to_a_smaller_worm() -> void:
	var w := _worm(Vector2(45000, 0), 3)
	w.head.global_position += Vector2(0, 400)   # deep: out of the stomp
	var b := _boot_at(w)
	var ever := false
	while not b._gone:
		b.step(DT)
		ever = ever or b.is_available()
	assert_bool(ever).is_false()


func test_an_outgrown_boot_is_swallowed_with_the_sting() -> void:
	var w := _worm(Vector2(50000, 0), 3)
	var mem := Outgrown.of(w)
	var b := _boot_at(w)
	w.head.global_position += Vector2(0, 200)   # under the stomp's reach, in sight: still a threat
	b.step(DT)
	assert_bool(mem.was_threat(&"boot")).is_true()
	w.head.global_position -= Vector2(0, 200)
	w.model.start_at_stage(5)
	var ate := []
	w.ate.connect(func(_p: int, id: StringName, _g: float) -> void: ate.append(id))
	for i in 400:
		if b._gone:
			break
		_frame(b, w)
	assert_bool(b._gone).is_true()
	assert_bool(b._life < BootShadow.FADE * 2.0 + BootShadow.HOLD).is_true()   # eaten, not faded
	assert_array(ate).contains_exactly([&"boot"])
	assert_int(int(Audio.played.get("now_i_eat_you", 0))).is_equal(1)


func test_a_carried_boot_rides_in_the_mouth() -> void:
	var w := _worm(Vector2(55000, 0), 5)
	var b := _boot_at(w)
	while not b.did_stomp:
		b.step(DT)
	b.global_position = w.mouth_position()
	w._eat_and_carry(true, w.model.stats, DT)
	assert_object(w.carrying).is_same(b)
	for i in 300:
		b.step(DT)
	assert_bool(b._gone).is_false()   # it waits in the mouth, never fades away mid-carry
	assert_bool(b.stomp_age() >= 0.0).is_true()
