## Traits you can see and hear (D-15, P-15, U-15): every trait shows on the worm the moment it is
## earned and while it is on, every trait's modifiers are read by game code (no hidden numbers),
## its sting plays once on earn and again on a re-equip, and a re-equip never replays the reveal.
class_name TestTraitsVisible
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
## Stats a trait may change that are read through a prefix ("bite_bonus/" + flavour).
const PREFIXED := ["bite_bonus/", "drag/"]


func before() -> void:
	SuiteSandbox.enter("traits_visible")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # stings still playing at exit leak their playbacks
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _rules() -> WormRules:
	return WormRules.default_rules()


## A worm node in the tree at `stage`, far from any other worm. Nothing earned yet.
func _worm(stage := 6, p := 0, at := Vector2.ZERO) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = WormGrowth.new()
	w.model.apex_gate = true
	w.model.start_at_stage(stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	auto_free(w)
	return w


## Everything about the worm's look a trait can touch: part sprites (by trait), the light, sheen.
func _look_of(w: Worm) -> Dictionary:
	var parts := {}
	var stack: Array[Node] = [w]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Sprite2D and n.has_meta("trait") and n.visible and (n as Sprite2D).texture != null:
			var id := StringName(n.get_meta("trait"))
			parts[id] = int(parts.get(id, 0)) + 1
	w._update_look(0.016, w.model.stats)
	return { "parts": parts, "light": w.light.enabled, "sheen": w.model.stats.value("sheen") }


func _ring_count(w: Worm) -> int:
	var n := 0
	for c in w.fx.get_children():
		if c is WormRing and not c.is_queued_for_deletion():
			n += 1
	return n


func _cues() -> Dictionary:
	return Audio.played.duplicate()


func _delta(before: Dictionary, cue: String) -> int:
	return int(Audio.played.get(cue, 0)) - int(before.get(cue, 0))


func test_every_trait_shows_a_part_on_the_worm_when_earned() -> void:
	assert_int(_rules().traits.size()).is_greater_equal(10)
	for t in _rules().traits:
		var w := _worm()
		var before := _look_of(w)
		w.model.grant(t.id)
		assert_bool(w.model.is_active(t.id)).override_failure_message("%s did not equip" % t.id).is_true()
		var after := _look_of(w)
		assert_bool(after != before).override_failure_message("%s changes nothing on the worm" % t.id).is_true()
		assert_int(int(after.parts.get(t.id, 0))).override_failure_message("%s has no part on the worm" % t.id).is_greater(0)


func test_unequipping_takes_the_part_off_and_re_equipping_puts_it_back() -> void:
	for t in _rules().traits:
		var w := _worm()
		w.model.grant(t.id)
		w.model.toggle(t.id)
		await get_tree().process_frame   # replaced part nodes are freed at the end of the frame
		assert_int(int(_look_of(w).parts.get(t.id, 0))).override_failure_message("%s part stays on when off" % t.id).is_equal(0)
		w.model.toggle(t.id)
		assert_int(int(_look_of(w).parts.get(t.id, 0))).is_greater(0)


func test_no_trait_is_a_hidden_number() -> void:
	# Every stat a trait changes must be read somewhere in game code; a stat nothing reads is a trait
	# the player can neither see nor feel.
	var code := ""
	for dir in ["res://scripts/"]:
		code += _read_tree(dir)
	for t in _rules().traits:
		assert_bool(t.add.size() + t.mul.size() > 0).override_failure_message("%s has no modifier" % t.id).is_true()
		for stat in t.add.keys() + t.mul.keys():
			var key := String(stat)
			var needle := "\"%s\"" % key
			for pre in PREFIXED:
				if key.begins_with(pre):
					needle = "\"%s\"" % pre
			assert_bool(code.contains(needle)).override_failure_message("%s: no code reads stat %s" % [t.id, key]).is_true()


func _read_tree(dir: String) -> String:
	var out := ""
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd" and not f in ["worm_stats.gd", "trait_data.gd", "worm_rules.gd"]:
			out += FileAccess.get_file_as_string(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out += _read_tree(dir + d + "/")
	return out


func test_every_trait_has_its_own_sound_file() -> void:
	for t in _rules().traits:
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % t.cue)).override_failure_message("%s: no %s.ogg" % [t.id, t.cue]).is_true()


func test_earning_plays_the_sting_once_with_the_reveal_ring() -> void:
	for t in _rules().traits:
		var w := _worm()
		var cues := _cues()
		var rings := _ring_count(w)
		w.model.grant(t.id)
		assert_int(_delta(cues, t.cue)).override_failure_message("%s sting count" % t.id).is_equal(1)
		assert_int(int(w.reveals.get(t.id, 0))).is_equal(1)
		assert_int(_ring_count(w)).is_equal(rings + 1)


func test_re_equip_plays_the_sting_again_but_not_the_reveal() -> void:
	var w := _worm()
	var t := _rules().find_trait(&"glow")
	w.model.grant(t.id)
	await get_tree().create_timer(0.7).timeout   # the reveal ring is gone
	var cues := _cues()
	w.model.toggle(t.id)   # off
	assert_int(_delta(cues, t.cue)).is_equal(0)
	w.model.toggle(t.id)   # back on, as from the burrow wall
	assert_int(_delta(cues, t.cue)).is_equal(1)
	assert_int(int(w.reveals.get(t.id, 0))).is_equal(1)
	assert_int(_ring_count(w)).is_equal(0)


func test_the_wall_re_equip_plays_the_sting() -> void:
	var w := _worm(2)   # one slot
	w.model.grant(&"wriggle")
	w.model.grant(&"magnet")   # waits for a slot
	w.set_wall_open(true)
	var cues := _cues()
	w._wall.cursor = 0
	w._wall.handle(0, true, false)   # wriggle off
	w._wall.cursor = 1
	w._wall.handle(0, true, false)   # magnet on
	assert_bool(w.model.is_active(&"magnet")).is_true()
	assert_int(_delta(cues, "trait_magnet")).is_equal(1)
	assert_int(int(w.reveals.get(&"magnet", 0))).is_equal(1)


func test_a_trait_waiting_for_a_slot_still_shows_its_picture() -> void:
	var w := _worm(2)
	w.model.grant(&"wriggle")
	var floats := w.fx.get_child_count()
	var cues := _cues()
	w.model.grant(&"stone_head")
	assert_bool(w.model.is_active(&"stone_head")).is_false()
	assert_int(_delta(cues, "trait_stone_head")).is_equal(1)
	var tex := _rules().find_trait(&"stone_head").part_texture(2)
	var found := false
	for c in w.fx.get_children():
		if c is Sprite2D and (c as Sprite2D).texture == tex:
			found = true
	assert_bool(found).is_true()
	assert_int(w.fx.get_child_count()).is_greater(floats)


func test_a_stage_up_equips_a_waiting_trait_with_its_sting() -> void:
	var w := _worm(2)
	w.model.grant(&"wriggle")
	w.model.grant(&"magnet")
	var cues := _cues()
	w.model.apex_gate = false
	w.model.apex_eaten.append(2)
	while w.model.stage < 3:
		w.model.add_segment(&"")
	assert_bool(w.model.is_active(&"magnet")).is_true()
	assert_int(_delta(cues, "trait_magnet")).is_equal(1)
	assert_int(int(_look_of(w).parts.get(&"magnet", 0))).is_greater(0)


func test_a_bite_only_a_trait_allows_shows_that_trait_at_work() -> void:
	var w := _worm(2)
	var boulder := FoodData.new()
	boulder.id = &"fake_boulder"
	boulder.flavour = &"stone"
	boulder.size_stage = w.model.stage_info().edible_size + 1
	assert_bool(w.needs_bonus(boulder)).is_false()   # too big: it bonks
	w.model.grant(&"stone_head")
	assert_bool(w.needs_bonus(boulder)).is_true()
	var cues := _cues()
	w._trait_moment("bite_bonus/stone")
	assert_int(_delta(cues, "trait_stone_head")).is_equal(1)
	assert_int(int(w.moments.get(&"stone_head", 0))).is_equal(1)
	w._trait_moment("bite_bonus/stone")   # throttled: no machine-gun clonks
	assert_int(_delta(cues, "trait_stone_head")).is_equal(1)


func test_the_showing_part_wins_the_moment() -> void:
	var w := _worm(6)
	w.model.grant(&"stone_head")
	w.model.grant(&"glow")
	w.model.grant(&"drill_head")
	assert_str(String(w._trait_for("bite_bonus/stone").id)).is_equal("drill_head")


func test_skate_is_faster_in_open_ground_and_leaves_a_trail() -> void:
	var plain := _worm(3, 0, Vector2(0, 0))
	var skater := _worm(3, 1, Vector2(0, 400))
	skater.model.grant(&"skater")
	for w in [plain, skater]:
		w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT}
	var x0 := [plain.head.position.x, skater.head.position.x]
	for i in 20:
		await get_tree().physics_frame
	var d_plain: float = plain.head.position.x - x0[0]
	var d_skate: float = skater.head.position.x - x0[1]
	assert_float(d_plain).is_greater(1.0)
	# speed x1.1 from data, x(1 + SKATE_BOOST) from skating: clearly more than the speed mul alone
	assert_float(d_skate).is_greater(d_plain * 1.3)
	assert_bool(skater._trail.emitting).is_true()
	assert_bool(plain._trail.emitting).is_false()


func test_a_floaty_burst_floats_on_in_open_ground() -> void:
	var plain := _worm(3, 0, Vector2(0, 0))
	var floaty := _worm(3, 1, Vector2(0, 400))
	floaty.model.grant(&"floaty")
	for w in [plain, floaty]:
		w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT, "burst": true}
	await get_tree().physics_frame
	await get_tree().physics_frame   # the signal comes before the nodes' step: two make sure
	for w in [plain, floaty]:
		w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT}
	var base := float(_rules().base_stats["burst_time"])
	assert_float(floaty._burst_left).is_greater(base * 1.5)
	assert_float(plain._burst_left).is_less_equal(base)
	assert_bool(floaty._trail.emitting).is_true()


func test_the_cart_carries_more_than_one_thing() -> void:
	var w := _worm(3)
	var foods: Array[ArenaFood] = []
	for i in 3:
		var f := ArenaFood.new()
		f.data = FoodData.new()
		f.data.id = StringName("fake_seed_%d" % i)
		f.data.size_stage = 1
		add_child(f)
		auto_free(f)
		foods.append(f)
	w.autopilot = func(_w: Worm) -> Dictionary: return {"carry": true}
	await get_tree().physics_frame
	for f in foods:
		f.global_position = w.mouth_position()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_object(w.carrying).is_not_null()
	assert_int(w.cart.size()).is_equal(0)   # no cart: one thing in the mouth
	for f in foods:
		if f != w.carrying:
			f.global_position = w.mouth_position()
	w.model.grant(&"garden_cart")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(w.cart.size()).is_equal(2)
	assert_int(int(w.moments.get(&"garden_cart", 0))).is_greater(0)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	await get_tree().physics_frame
	assert_int(w.cart.size()).is_equal(0)
	assert_object(w.carrying).is_null()
	for f in foods:
		assert_bool(f._carried).is_false()


func test_the_light_takes_the_colour_of_the_trait_that_lights_it() -> void:
	var w := _worm(3)
	w.model.grant(&"glow")
	w._update_look(0.016, w.model.stats)
	assert_bool(w.light.enabled).is_true()
	var c := _rules().find_trait(&"glow").color.lerp(Color.WHITE, 0.35)
	assert_bool(w.light.color.is_equal_approx(c)).is_true()
