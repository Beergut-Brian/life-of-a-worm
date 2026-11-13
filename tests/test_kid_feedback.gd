## Kid-check notes N1, N3 and N4 (docs/kid-check.md), each a thing that happened with no sound or
## picture: A pressed while the burst recharges (BurstNudge), the partner's share of a dug tile
## (PartnerStars) and ground growing back on the real planet (RegrowWatch). Every count comes from
## the hook's own per-call counter; the worm and the hooks are stepped by hand, never by polling.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 160
const DT := 1.0 / 60.0
const DIRT := Vector2i(100, 7)    # radius ~100 of 160: the dirt ring

var _press := false
var _world: PolarWorld
var _worms: Array[Worm] = []


func after_test() -> void:
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	if is_instance_valid(_world):
		remove_child(_world)
		_world.free()
	for p in Audio._pool:
		p.stop()


func _worm(player: int, at := Vector2.ZERO) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	w.position = at
	w.autopilot = func(_w: Worm) -> Dictionary: return { "burst": _press }
	add_child(w)
	w.set_physics_process(false)
	for n in ["BurstNudge", "PartnerStars", "CastingsHook"]:
		w.get_node(n).set_physics_process(false)
	_worms.append(w)
	return w


func _nudge(w: Worm) -> BurstNudge:
	var n: BurstNudge = w.get_node("BurstNudge")
	n.pressed_now = func() -> bool: return _press
	return n


## One physics frame in tree order: the worm first, then its child hook.
func _frame(w: Worm, n: BurstNudge, press: bool) -> void:
	_press = press
	w._physics_process(DT)
	n.step(w, DT)


func _planet() -> PolarWorld:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 7)
	add_child(_world)
	_world.set_physics_process(false)
	var eye := Node2D.new()
	eye.position = Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.9
	_world.add_child(eye)
	_world.track(eye)
	_world.update_chunks(-1)
	return _world


func _topsoil(i: int) -> Vector2i:
	return _world.shape.cell_at(Vector2.from_angle(-PI / 2.0 + i * 0.012) * RADIUS * 16.0 * 0.9)


# --- N1: A during the recharge ----------------------------------------------------------------


func test_a_press_that_bursts_is_not_a_nudge() -> void:
	var w := _worm(Players.P1)
	var n := _nudge(w)
	_frame(w, n, true)
	assert_float(w._burst_cool).is_greater(0.0)   # the burst started
	assert_int(n.count).is_equal(0)
	assert_bool(n.showing()).is_false()


func test_a_press_while_recharging_puffs_shows_the_ring_and_beeps() -> void:
	var w := _worm(Players.P1)
	var n := _nudge(w)
	_frame(w, n, true)
	_frame(w, n, false)
	var cool_before := w._burst_cool
	_frame(w, n, true)                              # mashed during the recharge
	assert_float(w._burst_cool).is_less(cool_before)   # still recharging: no new burst
	assert_int(n.count).is_equal(1)
	assert_bool(n.showing()).is_true()               # the ring and the puff are on screen
	assert_float(n.ready_fraction()).is_less(0.1)     # and the ring has barely started filling
	var voice: AudioStreamPlayer = n.get_node("Voice")
	assert_object(voice.stream).is_not_null()        # the burst cue, small and high
	assert_bool(voice.playing).is_true()
	assert_float(voice.volume_db).is_less(0.0)
	voice.stop()


func test_the_ring_fills_as_the_burst_comes_back() -> void:
	var w := _worm(Players.P1)
	var n := _nudge(w)
	_frame(w, n, true)
	var total := w._burst_cool
	var half := int(total / DT / 2.0)
	for i in half:
		_frame(w, n, false)
	_frame(w, n, true)
	assert_int(n.count).is_equal(1)
	assert_float(n.ready_fraction()).is_between(0.4, 0.6)
	n.get_node("Voice").stop()
	# Once it is back, the next press is a real burst again, not a nudge.
	for i in int(total / DT) + 2:
		_frame(w, n, false)
	_frame(w, n, true)
	assert_int(n.count).is_equal(1)
	assert_float(w._burst_cool).is_greater(total * 0.9)


func test_mashing_is_fine_but_capped() -> void:
	var w := _worm(Players.P1)
	var n := _nudge(w)
	_frame(w, n, true)
	for i in 30:                                    # half a second of mashing every frame
		_frame(w, n, true)
	n.get_node("Voice").stop()
	assert_int(n.count).is_greater_equal(3)
	assert_int(n.count).is_less_equal(int(30 * DT / BurstNudge.MIN_GAP) + 1)


func test_no_nudge_while_the_trait_wall_has_the_buttons() -> void:
	var w := _worm(Players.P1)
	var n := _nudge(w)
	_frame(w, n, true)
	w.wall_open = true                              # A toggles traits there; the wall beeps itself
	_press = true
	n.step(w, DT)
	assert_int(n.count).is_equal(0)


# --- N3: the partner's share of a dug tile ------------------------------------------------------


func test_a_partner_digging_twinkles_a_star_on_me_at_a_steady_pace() -> void:
	_planet()
	var me := _worm(Players.P1, Vector2(0, -RADIUS * 16.0 * 0.5))
	var digger := _worm(Players.P2, Vector2(0, -RADIUS * 16.0 * 0.5))
	me.set_world(_world)
	digger.set_world(_world)
	_world.set_stage(Players.P2, 2)
	var mine: PartnerStars = me.get_node("PartnerStars")
	var theirs: PartnerStars = digger.get_node("PartnerStars")
	mine.step(me, DT)
	theirs.step(digger, DT)                         # both hooks watch the world now
	var growth_before := me.model.growth
	for i in 10:
		assert_bool(_world.eat_tile(_topsoil(i), Players.P2)).is_true()
	mine.step(me, DT)
	theirs.step(digger, DT)
	assert_float(me.model.growth).is_greater(growth_before)   # the share itself (worm.gd)
	assert_int(mine.count).is_equal(1)              # ten tiles in one frame: one star, not ten
	assert_int(theirs.count).is_equal(0)            # the digger's own tiles never star it
	# Still digging: the next star waits EVERY seconds.
	for i in int(PartnerStars.EVERY / DT) - 2:
		_world.eat_tile(_topsoil(20 + i), Players.P2)
		mine.step(me, DT)
	assert_int(mine.count).is_equal(1)
	for i in 4:
		_world.eat_tile(_topsoil(80 + i), Players.P2)
		mine.step(me, DT)
	assert_int(mine.count).is_equal(2)
	# Stops when the digging stops (one last star at most, for the last tiles dug).
	for i in int(PartnerStars.EVERY / DT) + 2:
		mine.step(me, DT)
	var settled := mine.count
	assert_int(settled).is_between(2, 3)
	for i in 120:
		mine.step(me, DT)
	assert_int(mine.count).is_equal(settled)


func test_digging_by_something_that_is_not_a_worm_shares_nothing_and_shows_nothing() -> void:
	_planet()
	var me := _worm(Players.P1, Vector2(0, -RADIUS * 16.0 * 0.5))
	me.set_world(_world)
	var mine: PartnerStars = me.get_node("PartnerStars")
	mine.step(me, DT)
	_world.set_stage(7, 2)
	_world.eat_tile(_topsoil(3), 7)                 # no worm plays as player 7
	mine.step(me, DT)
	assert_int(mine.count).is_equal(0)


# --- N4: ground growing back on the planet ------------------------------------------------------


func test_every_worm_world_gets_exactly_one_watch() -> void:
	_planet()
	var a := _worm(Players.P1)
	var b := _worm(Players.P2)
	a.set_world(_world)
	b.set_world(_world)
	a.get_node("CastingsHook")._physics_process(DT)
	b.get_node("CastingsHook")._physics_process(DT)
	var watches := _world.get_children().filter(func(c: Node) -> bool: return c is RegrowWatch)
	assert_int(watches.size()).is_equal(1)
	assert_object(RegrowWatch.ensure(_world)).is_same(watches[0])


func test_real_regrowth_sparkles_where_the_tile_grows_back() -> void:
	_planet()
	var anchor := Node2D.new()
	anchor.position = _world.shape.center_of(DIRT)
	_world.add_child(anchor)
	_world.track(anchor)
	_world.update_chunks(-1)
	var watch := RegrowWatch.ensure(_world)
	await get_tree().process_frame                  # _ready connects the world's signals
	assert_bool(_world.eat_tile(DIRT, 0)).is_true()
	var t := _world.regrow_time(DIRT)
	for i in int(ceil((t + 1.0) / 0.5)):
		_world.advance(0.5)
	_world.regrow_pass(-1)
	assert_int(watch.sparkled).is_greater_equal(1)
	assert_int(watch.sparkles._items.size()).is_greater_equal(1)
	var at := Vector2(watch.sparkles._items[0].x, watch.sparkles._items[0].y)
	assert_float(at.distance_to(_world.shape.center_of(DIRT))).is_less(1.0)


func test_a_worm_nearby_hears_one_soft_sound_per_pass_far_away_only_sees_it() -> void:
	_planet()
	var near := _world.shape.center_of(_topsoil(0))
	var w := _worm(Players.P1, near)
	w.set_world(_world)
	var watch := RegrowWatch.ensure(_world)
	await get_tree().process_frame
	for i in 6:                                     # one regrowth pass refills six tiles at once
		watch.grew(_topsoil(i), "world_regrow")
	assert_int(watch.sparkled).is_equal(6)
	assert_int(watch.cues).is_equal(1)
	watch._process(RegrowWatch.CUE_GAP + 0.01)
	watch.grew(_topsoil(7), "world_regrow")
	assert_int(watch.cues).is_equal(2)
	watch.grew(_topsoil(8), "world_sprout")         # a garden cell filling has its own sound
	assert_int(watch.cues).is_equal(3)
	watch._process(RegrowWatch.CUE_GAP + 0.01)
	var far := _world.shape.cell_at(Vector2.from_angle(PI / 2.0) * RADIUS * 16.0 * 0.9)
	watch.grew(far, "world_regrow")                 # the other side of the planet
	assert_int(watch.sparkled).is_equal(9)
	assert_int(watch.cues).is_equal(3)
	for cue in ["world_regrow", "world_sprout"]:
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % cue)).is_true()
