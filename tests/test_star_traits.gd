## Star traits (D-10, worm-star-trait-1): one rare TraitData per space planet type, earned by eating
## that planet (SpaceDrift's star path, revealed by StarAward), never from flavours or as a choice,
## never a curse, listed on the planet worm's trait wall and re-equipped like any other trait.
## Contacts are resolved directly (resolve_contact / on_eaten), never through a pile of bodies.
class_name TestStarTraits
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const WORM := preload("res://scenes/players/worm.tscn")
const PLANETS := [&"ice", &"jungle", &"junk", &"candy", &"clockwork"]


func before() -> void:
	SuiteSandbox.enter("star_traits")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()


func _stage() -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	s.set_process(false)          # no stick
	s.drift.set_process(false)    # no spawning or drifting off
	return auto_free(s)


func _award(s: SpaceStage) -> StarAward:
	return s.get_node("StarAward") as StarAward


## Ripen and eat the current big planet with the first worm (no physics involved).
func _eat_planet(s: SpaceStage) -> void:
	var big := s.drift.big
	big.ripen(big.data.ripe_stage)
	assert_int(s.resolve_contact(s.worms[0], big)).is_equal(StageRule.FOOD)
	s.drift.begin()


func _planet_worm(stage := 6) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	w.model.apex_gate = true
	w.model.start_at_stage(stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	auto_free(w)
	return w


func test_five_star_traits_one_per_planet_type() -> void:
	var ids: Array[StringName] = []
	var rules := WormRules.default_rules()
	for pid in PLANETS:
		var d: PlanetData = load("res://data/planets/%s.tres" % pid)
		var t := d.star_trait
		assert_bool(t.star).override_failure_message("%s: star_trait is not a Star" % pid).is_true()
		assert_str(String(t.star_planet)).is_equal(String(pid))
		assert_object(StarTraits.for_planet(pid)).is_same(rules.find_trait(t.id))
		assert_bool(t.resource_path.begins_with("res://data/traits/")).is_true()
		assert_bool(t.id in ids).override_failure_message("%s twice" % t.id).is_false()
		ids.append(t.id)
		assert_float(d.star_chance).is_equal(0.0)     # only the planet itself gives it
		# never a curse: one positive add, nothing multiplied down
		assert_int(t.add.size()).is_equal(1)
		assert_float(float(t.add.values()[0])).is_greater(0.0)
		assert_bool(t.mul.is_empty()).is_true()
		assert_object(t.part_texture(1)).is_not_null()
		assert_str(t.cue).is_not_empty()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % t.cue)).is_true()
	assert_int(StarTraits.all().size()).is_equal(5)
	# each Star has its own stat, part and cue
	var stats := {}
	var cues := {}
	var shapes := {}
	for t in StarTraits.all():
		stats[t.add.keys()[0]] = true
		cues[t.cue] = true
		shapes[t.part_shape] = true
	assert_int(stats.size()).is_equal(5)
	assert_int(cues.size()).is_equal(5)
	assert_int(shapes.size()).is_equal(5)


func test_each_planet_gives_exactly_its_star_when_eaten() -> void:
	var s := _stage()
	var w := s.worms[0]
	var got: Array = []
	s.drift.star_earned.connect(func(p, id): got.append([p, id]))
	for i in 5:
		var d := s.drift.big.data
		assert_object(s.drift.big.star_trait).override_failure_message("%s shows no star before" % d.id).is_same(d.star_trait)
		assert_bool(w.has_star(d.star_trait.id)).is_false()
		var before := got.size()
		_eat_planet(s)
		assert_int(got.size() - before).override_failure_message("%s gave %d" % [d.id, got.size() - before]).is_equal(1)
		assert_array(got.back()).is_equal([w.player, d.star_trait.id])
		assert_bool(w.has_star(d.star_trait.id)).is_true()
	assert_int(w.stars.size()).is_equal(5)
	assert_object(s.drift.sun).is_not_null()
	var sun_before := got.size()
	assert_int(s.resolve_contact(w, s.drift.sun)).is_equal(StageRule.FOOD)
	assert_int(got.size()).is_equal(sun_before)        # the sun carries no Star


func test_foods_never_carry_a_star() -> void:
	var s := _stage()
	for i in 60:
		s.drift._top_up(s.worms_centre())
		for f in s.drift.smalls(&"food"):
			assert_object(f.star_trait).is_null()
			f.queue_free()
		await get_tree().process_frame


func test_a_star_is_never_earned_from_flavours_or_offered() -> void:
	var m := WormGrowth.new()
	m.apex_gate = true
	m.start_at_stage(6)
	for f in m.rules.flavour_colors:
		for i in 12:
			m.add_segment(StringName(f))
	for t in StarTraits.all():
		assert_bool(t.requires.is_empty()).is_true()
		assert_bool(t.id in m.earned).override_failure_message("%s earned from flavours" % t.id).is_false()
	for t in StarTraits.all():
		assert_bool(StarTraits.is_star(t.id)).is_true()
	assert_bool(StarTraits.is_star(&"glow")).is_false()


func test_the_reveal_fires_once_per_earn() -> void:
	var s := _stage()
	var award := _award(s)
	var w := s.worms[0]
	var shown: Array = []
	award.revealed.connect(func(p, id): shown.append([p, id]))
	var t := s.drift.big.data.star_trait
	var cues := Audio.played.duplicate()
	var rings := _rings(s)
	var zoom := s.camera.zoom
	_eat_planet(s)
	assert_array(shown).is_equal([[w.player, t.id]])
	assert_int(int(award.reveals.get(t.id, 0))).is_equal(1)
	assert_int(int(Audio.played.get(t.cue, 0)) - int(cues.get(t.cue, 0))).is_equal(1)
	assert_int(_rings(s) - rings).is_equal(2)
	assert_bool(award.beat_showing()).is_true()
	award._process(0.9)                                 # mid-beat: the camera leans in
	assert_float(s.camera.zoom.x).is_greater(zoom.x * 1.2)
	award._process(0.5)
	award._process(0.5)                                 # past REVEAL_TIME: the beat is over
	assert_bool(award.beat_showing()).is_false()
	# the same star can't come again this run, so no second reveal
	var fake := SpacePlanet.new()
	fake.kind = &"food"
	fake.star_trait = t
	s.drift.add_child(fake)
	s.drift.on_eaten(w, fake)
	assert_int(shown.size()).is_equal(1)
	# back from the tin: the star is worn again, silently
	var saved: Dictionary = Save.get_value(SpaceDrift.SAVE_KEY, {})
	assert_int(saved.get("stars", []).size()).is_equal(1)
	s.queue_free()
	await get_tree().process_frame
	var again := _stage()
	assert_bool(again.worms[0].has_star(t.id)).is_true()
	assert_int(_award(again).reveals.size()).is_equal(0)
	assert_object(again.drift.big.data.star_trait).is_not_same(t)          # the next planet...
	assert_object(again.drift.big.star_trait).is_same(again.drift.big.data.star_trait)   # ...shows its own


func _rings(s: SpaceStage) -> int:
	var n := 0
	for c in s.get_children():
		if c is WormRing and not c.is_queued_for_deletion():
			n += 1
	return n


func test_turn_and_pull_stars_are_felt() -> void:
	var s := _stage()
	var award := _award(s)
	var w := s.worms[0]
	w.collision_layer = 0
	w.collision_mask = 0
	var accel := w.accel
	var tick := StarTraits.for_planet(&"clockwork")
	w.add_star(tick)
	award._apply(w, tick)
	award._apply(w, tick)                                # applying twice never stacks
	assert_float(w.accel).is_equal_approx(accel * (1.0 + float(tick.add["space_turn"])), 0.01)
	# sugar: a small food near the mouth drifts in
	w.add_star(StarTraits.for_planet(&"candy"))
	for c in s.drift.get_children():
		c.queue_free()
	await get_tree().process_frame
	var f: SpacePlanet = s.drift._small(&"food", s.drift.order[0].foods[0], w.mouth.global_position - s.drift.global_position + Vector2(200, 0), Vector2.ZERO)
	f.collision_layer = 0
	f.collision_mask = 0
	award._physics_process(0.1)
	assert_float(f.linear_velocity.x).is_less(-10.0)     # toward the mouth (it is to the left)
	var far: SpacePlanet = s.drift._small(&"food", s.drift.order[0].foods[0], w.mouth.global_position - s.drift.global_position + Vector2(900, 0), Vector2.ZERO)
	award._physics_process(0.1)
	assert_float(far.linear_velocity.length()).is_equal(0.0)   # out of reach: left alone


func test_an_earned_star_sits_on_the_wall_and_re_equips() -> void:
	var w := _planet_worm()
	var t := StarTraits.for_planet(&"ice")
	Save.set_value("worms", { "0": w.to_dict() })
	assert_bool(StarTraits.record(Players.P1, t.id)).is_true()
	assert_bool(t.id in w.model.earned).is_true()
	assert_bool(w.model.is_active(t.id)).is_true()       # a free slot: it equips itself
	var tin: Dictionary = Save.get_value("worms", {})["0"]
	assert_bool(String(t.id) in tin["earned"]).is_true()
	assert_bool(StarTraits.record(Players.P1, t.id)).is_false()   # never twice
	assert_int(w.model.earned.count(t.id)).is_equal(1)
	assert_int(_parts(w, t.id)).is_greater(0)            # its part shows on the planet worm
	# re-equip: off, then on again, like any trait; never lost, sting again, no new reveal
	var cues := Audio.played.duplicate()
	assert_bool(w.model.toggle(t.id)).is_true()
	assert_bool(w.model.is_active(t.id)).is_false()
	assert_bool(t.id in w.model.earned).is_true()
	assert_bool(w.model.toggle(t.id)).is_true()
	assert_bool(w.model.is_active(t.id)).is_true()
	assert_int(int(Audio.played.get(t.cue, 0)) - int(cues.get(t.cue, 0))).is_equal(1)
	assert_int(int(w.reveals.get(t.id, 0))).is_equal(0)
	# a worm loaded from the tin keeps it
	var w2 := _planet_worm()
	w2.from_dict(tin)
	assert_bool(t.id in w2.model.earned).is_true()
	assert_bool(w2.model.is_active(t.id)).is_true()
	# and the wall lists it among the pictures it toggles (drawn with a gold star: TraitData.star)
	var wall := TraitWall.new()
	wall.worm = w2
	add_child(wall)
	auto_free(wall)
	wall.set_open(true)
	wall.cursor = w2.model.earned.find(t.id)
	wall.handle(0, true, false)                          # A on its picture: unequip
	assert_bool(w2.model.is_active(t.id)).is_false()
	wall.handle(0, true, false)                          # and on again
	assert_bool(w2.model.is_active(t.id)).is_true()


func _parts(w: Worm, id: StringName) -> int:
	var n := 0
	var stack: Array[Node] = [w]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is Sprite2D and c.has_meta("trait") and StringName(c.get_meta("trait")) == id and c.visible and (c as Sprite2D).texture != null:
			n += 1
	return n
