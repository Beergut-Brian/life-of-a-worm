## Trait depth 1 (D-05, D-06), the parts a kid feels, each staged on its own spot:
##  - D-05 a rock bite a stage early kicks stone chips with a clack (the bite beat);
##  - D-05 a big boulder bumps a Stone head softly (a boop, it is nudged aside, no bonk), while a
##    plain worm still bonks off it;
##  - D-06 a hidden hall twinkles for a glowing worm only, once per approach, and stops once found;
##  - D-06 every shimmer colour is light and never opaque (it can't make a ring darker).
## Events are counted through signals or per-call counters.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const BIG_BOULDER := preload("res://data/foods/big_boulder.tres")
const ANT_CITY := preload("res://data/secrets/ant_city.tres")
const RADIUS := 300


## An ArenaFood that counts each bonk (smug() is what a worm calls when it bonks off a thing).
class CountFood extends ArenaFood:
	var smugs := 0

	func smug() -> void:
		smugs += 1
		super()


var _world: PolarWorld
var _worms: Array[Worm] = []
var _extra: Array[Node] = []


func before() -> void:
	SuiteSandbox.enter("trait_depth")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	TraitKnacks._attach(_world)


func after_test() -> void:
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	for n in _extra:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_extra.clear()
	if is_instance_valid(_world):
		remove_child(_world)
		_world.free()


func _r_px() -> float:
	return float(RADIUS * _world.shape.cell_size)


func _worm(p: int, stage: int, at: Vector2, traits: Array = []) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = WormGrowth.new()
	w.model.start_at_stage(stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	_worms.append(w)
	for id in traits:
		w.model.grant(StringName(id))
	w.set_world(_world)
	_world.track(w.head)
	_world.update_chunks(-1)
	return w


func _steer(w: Worm, dir: Vector2) -> void:
	w.heading = dir.angle()
	w.autopilot = func(_w: Worm) -> Dictionary: return {"move": dir}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_world.update_chunks(-1)


# --- D-05: the rock bite beat ------------------------------------------------------------------

func test_d05_a_rock_bite_a_stage_early_kicks_stone_chips_with_a_clack() -> void:
	var edge := RINGS.rings[1].outer * _r_px()   # deep rock's outer edge
	var plain := _worm(Players.P1, 3, Vector2.from_angle(0.4) * (edge + 20.0))
	var stone := _worm(Players.P2, 3, Vector2.from_angle(2.4) * (edge + 20.0), ["stone_head"])
	var chipped := {Players.P1: 0, Players.P2: 0}
	for w in [plain, stone]:
		(w.get_node("Knacks") as TraitKnacks).rock_chipped.connect(
			func(p: int, _c: Vector2i) -> void: chipped[p] += 1)
	_steer(plain, -Vector2.from_angle(0.4))
	_steer(stone, -Vector2.from_angle(2.4))
	await _frames(90)
	assert_int(chipped[Players.P1]).is_equal(0)   # a plain worm stops at the rock: no chips
	assert_int(chipped[Players.P2]).is_greater(1)
	# Throttled: fewer sprays than rock tiles bitten, so it reads as chewing, not a fountain.
	var knacks: TraitKnacks = stone.get_node("Knacks")
	assert_int(chipped[Players.P2]).is_less(knacks.rock_bites)
	assert_int(knacks.chips).is_equal(chipped[Players.P2])
	assert_bool(Audio.played.has(TraitKnacks.CHIP_CUE)).is_true()


# --- D-05: boulders stop bonking you -----------------------------------------------------------

func _boulder_ahead(w: Worm, dir: Vector2) -> CountFood:
	var f := CountFood.new()
	f.data = BIG_BOULDER
	add_child(f)
	_extra.append(f)
	f.global_position = w.mouth_position() + dir * 40.0
	return f


## One worm alone in the dirt, a big boulder 40 px ahead, steered straight at it for 70 steps.
## Returns {bonks, bumps, moved (head px), shoved (boulder px)}.
func _drive_at_boulder(traits: Array) -> Dictionary:
	var w := _worm(Players.P1, 3, Vector2.from_angle(0.3) * 0.7 * _r_px(), traits)
	var dir := Vector2.from_angle(0.3 + PI / 2.0)   # along the dirt, not down into rock
	w.heading = dir.angle()
	await _frames(2)
	var b := _boulder_ahead(w, dir)
	var b0 := b.global_position
	var h0 := w.head.global_position
	var bumps := []
	(w.get_node("Knacks") as TraitKnacks).bumped.connect(
		func(p: int, what: StringName) -> void: bumps.append([p, what]))
	_steer(w, dir)
	await _frames(70)
	return {"worm": w, "bonks": b.smugs, "bumps": bumps,
		"moved": (w.head.global_position - h0).length(), "shoved": (b.global_position - b0).length()}


func test_d05_a_big_boulder_still_bonks_a_plain_stage_3_worm() -> void:
	var r: Dictionary = await _drive_at_boulder([])
	assert_int(int(r.bonks)).is_greater(0)
	assert_array(r.bumps).is_empty()
	assert_float(float(r.shoved)).is_equal(0.0)
	assert_bool(Audio.played.has("bonk")).is_true()


func test_d05_a_big_boulder_bumps_a_stone_head_softly_instead_of_bonking() -> void:
	assert_bool(_worm_can_eat_big_boulder(["stone_head"])).is_false()   # too big even a stage early
	var r: Dictionary = await _drive_at_boulder(["stone_head"])
	assert_int(int(r.bonks)).is_equal(0)   # never knocked back
	assert_int((r.bumps as Array).size()).is_greater(0)
	for b in r.bumps:
		assert_int(int(b[0])).is_equal(Players.P1)
		assert_str(String(b[1])).is_equal("big_boulder")
	assert_float(float(r.shoved)).is_greater(10.0)   # nudged along ahead of the head
	assert_float(float(r.moved)).is_greater(30.0)    # and the worm keeps going
	assert_bool(Audio.played.has(TraitKnacks.BUMP_CUE)).is_true()
	assert_bool(Audio.played.has("bonk")).is_false()
	var w: Worm = r.worm
	assert_int(int(w.moments.get(&"stone_head", 0))).is_greater(0)   # the helmet pops: why


func _worm_can_eat_big_boulder(traits: Array) -> bool:
	var m := WormGrowth.new()
	m.start_at_stage(3)
	for id in traits:
		m.grant(StringName(id))
	var w: Worm = WORM.instantiate()
	w.model = m
	var ok := w.can_eat(BIG_BOULDER)
	w.free()
	return ok


# --- D-06: secrets shimmer ---------------------------------------------------------------------

func _hall(at: Vector2) -> SecretSpot:
	var spot := SecretSpot.new()
	spot.name = "Secret_test_hall"
	spot.data = ANT_CITY
	spot.director = RingsDirector.new()
	_extra.append(spot.director)
	spot.position = at
	_world.add_child(spot)
	return spot


func test_d06_a_hidden_hall_twinkles_for_a_glowing_worm_only_and_stops_once_found() -> void:
	var shimmer: SecretShimmer = _world.get_node("SecretShimmer")
	var at := Vector2.from_angle(1.2) * 0.6 * _r_px()
	var spot := _hall(at)
	var seen := []
	shimmer.shimmered.connect(func(p: int, id: StringName) -> void: seen.append([p, id]))
	var cs := float(_world.shape.cell_size)
	var near := at + Vector2.from_angle(2.0) * (ANT_CITY.radius_tiles + 4.0) * cs
	_worm(Players.P1, 3, near)   # a plain worm right beside it
	await _frames(70)            # past one rescan
	assert_array(seen).is_empty()
	assert_float(shimmer.glow_of(ANT_CITY.id)).is_equal(0.0)
	_worm(Players.P2, 3, near + Vector2(0, 8), ["glow"])
	await _frames(40)
	assert_int(seen.size()).is_equal(1)   # once per approach, not every frame
	assert_int(int(seen[0][0])).is_equal(Players.P2)
	assert_str(String(seen[0][1])).is_equal(String(ANT_CITY.id))
	assert_float(shimmer.glow_of(ANT_CITY.id)).is_greater(0.5)
	assert_bool(Audio.played.has("trait_glow")).is_true()
	spot.director.found[ANT_CITY.id] = true   # found: nothing left to point at
	await _frames(40)
	assert_float(shimmer.glow_of(ANT_CITY.id)).is_equal(0.0)
	assert_int(seen.size()).is_equal(1)


func test_d06_a_glowing_worm_far_from_a_hall_sees_no_twinkle() -> void:
	var shimmer: SecretShimmer = _world.get_node("SecretShimmer")
	var at := Vector2.from_angle(1.2) * 0.6 * _r_px()
	_hall(at)
	var far := at + Vector2.from_angle(2.0) * (ANT_CITY.radius_tiles + SecretShimmer.SHIMMER_TILES + 6.0) \
		* float(_world.shape.cell_size)
	_worm(Players.P1, 3, far, ["glow"])
	await _frames(70)
	assert_int(shimmer.approaches).is_equal(0)
	assert_float(shimmer.glow_of(ANT_CITY.id)).is_equal(0.0)


func test_d06_every_shimmer_colour_is_light_and_never_opaque() -> void:
	var bases := [Color(0.05, 0.02, 0.1), Color(0.2, 0.1, 0.05), GeodeSeams.GEM,
		Color(0.4353, 0.9412, 1.0), Color.WHITE]
	var bad := []
	var n := 0
	for base in bases:
		for g in [0.2, 0.6, 1.0, 1.5]:
			for k in 24:
				var cols := SecretShimmer.spark_colors(base, g, k * 0.37)
				cols.append(GlowCap.tint(base, g))   # what GeodeSeams draws with
				for c in cols:
					n += 1
					# Color is float32: allow its rounding on the cap.
					if GlowCap.luma(c) < GlowCap.MIN_LUMA - 0.001 or c.a > GlowCap.MAX_ALPHA + 0.0001:
						bad.append([base, g, c])
	assert_int(n).is_greater(1000)
	assert_array(bad).is_empty()
