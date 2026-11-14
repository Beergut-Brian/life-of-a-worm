## U-15: every trait is heard on its own: earning it plays its sting once (one case per trait), and
## every planet trait plays its sting again when it does its job (burst, wiggle, skate, a garden
## bite through TraitUse; bites, carries, pulls, light and water through Worm._trait_moment).
## Counted through Audio.played.
class_name TestTraitUse
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const SPACE := "res://scenes/levels/space_stage.tscn"
## Every trait id in data/traits (test_the_case_list_is_every_trait keeps it whole).
const ALL := [
	["anchor_star"], ["beetle_shell"], ["drill_head"], ["firefly"], ["floaty"], ["frost_star"],
	["garden_cart"], ["glow"], ["green_thumb"], ["lamp_fish"], ["lodestone"], ["magnet"],
	["radar"], ["rain_garden"], ["skater"], ["slick"], ["spring_tail"], ["stone_head"],
	["sugar_star"], ["sweet_tooth"], ["tick_star"], ["vine_star"], ["wriggle"],
]
## Stats the worm itself stings for when the trait does its job (Worm._trait_moment callers).
const WORM_MOMENTS: Array[String] = ["bite_bonus/stone", "carry_slots", "pull_radius", "light_radius", "drag/water"]

var _n := 0


func before() -> void:
	SuiteSandbox.enter("trait_use")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _rules() -> WormRules:
	return WormRules.default_rules()


func _trait(id: String) -> TraitData:
	for t in _rules().traits:
		if String(t.id) == id:
			return t
	var path := "res://data/traits/%s.tres" % id
	return load(path) as TraitData if ResourceLoader.exists(path) else null


func _worm(intent: Array) -> Worm:
	var m := WormGrowth.new()
	m.apex_gate = true
	m.start_at_stage(6)
	var w: Worm = WORM.instantiate()
	w.model = m
	w.autopilot = func(_w: Worm) -> Dictionary: return intent[0]
	_n += 1
	w.position = Vector2(900.0 * _n, 0)
	add_child(w)
	auto_free(w)
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _delta(before: Dictionary, cue: String) -> int:
	return int(Audio.played.get(cue, 0)) - int(before.get(cue, 0))


func test_the_case_list_is_every_trait() -> void:
	var ids: Array[String] = []
	for f in DirAccess.get_files_at("res://data/traits/"):
		var r = load("res://data/traits/" + f.trim_suffix(".remap"))
		if r is TraitData:
			ids.append(String(r.id))
	ids.sort()
	var listed: Array[String] = []
	for row in ALL:
		listed.append(row[0])
	listed.sort()
	assert_array(listed).is_equal(ids)


func test_earning_a_trait_plays_its_own_sting_once(id: String, test_parameters := ALL) -> void:
	var t := _trait(id)
	assert_object(t).is_not_null()
	assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % t.cue)).is_true()
	if t.star:
		# a Star is earned in space, by eating its planet: StarAward hears star_earned, once
		Save.wipe()
		var st: SpaceStage = load(SPACE).instantiate()
		st.players.append(Players.P1)
		add_child(st)
		auto_free(st)
		st.set_process(false)
		st.drift.set_process(false)
		var before_s := Audio.played.duplicate()
		st.drift.star_earned.emit(st.worms[0].player, t.id)
		assert_int(_delta(before_s, t.cue)).override_failure_message("%s: one sting per gain" % id).is_equal(1)
		assert_int(int((st.get_node("StarAward") as StarAward).reveals.get(t.id, 0))).is_equal(1)
		return
	var w := _worm([{}])
	await _frames(2)
	var before := Audio.played.duplicate()
	w.model.grant(t.id)
	await _frames(10)
	assert_int(_delta(before, t.cue)).override_failure_message("%s: one sting per gain" % id).is_equal(1)


func test_a_planet_trait_plays_its_sting_when_it_does_its_job(id: String, test_parameters := ALL) -> void:
	var t := _trait(id)
	if t.star:
		return   # Stars work in space: their sting there is the earn (StarAward); see PLAN-STATUS U-15
	var intent := [{}]
	var w := _worm(intent)
	await _frames(2)
	w.model.grant(t.id)
	assert_bool(w.model.is_active(t.id)).is_true()
	await _frames(int(Worm.TRAIT_MOMENT_COOLDOWN * Engine.physics_ticks_per_second) + 4)
	var use := w.get_node("TraitUse") as TraitUse
	var before := Audio.played.duplicate()
	var how := ""
	if t.add.has("glide") or t.add.has("burst_time") or t.mul.has("burst_time") \
			or t.mul.has("burst_speed") or t.mul.has("burst_cooldown"):
		how = "burst"
		intent[0] = {"burst": true}
	elif t.add.has("wiggle_radius") or t.mul.has("wiggle_hop"):
		how = "wiggle"
		intent[0] = {"wiggle": true}
	elif t.add.has("skate"):
		how = "skate"
		intent[0] = {"move": Vector2.RIGHT}
	elif t.add.has("garden_yield"):
		how = "garden"
		use.garden_bite()
	else:
		for s in WORM_MOMENTS:
			if t.add.has(s) or t.mul.has(s):
				how = s
				w._trait_moment(s)
				break
	assert_str(how).override_failure_message("%s does no job that is heard" % id).is_not_empty()
	await _frames(1)
	intent[0] = {}
	await _frames(3)
	assert_int(_delta(before, t.cue)).override_failure_message("%s at work (%s)" % [id, how]).is_equal(1)
	assert_int(int(w.moments.get(t.id, 0))).is_greater_equal(1)   # seen too: part pop + ring
	if how in ["burst", "wiggle", "skate", "garden"]:
		assert_int(int(use.heard.get(how, 0))).override_failure_message("%s: TraitUse %s" % [id, how]).is_equal(1)


func test_holding_still_after_the_press_is_silent() -> void:
	var intent := [{"burst": true}]
	var w := _worm(intent)
	w.model.grant(&"wriggle")
	await _frames(2)
	intent[0] = {}
	await _frames(20)
	var before := Audio.played.duplicate()
	await _frames(60)
	assert_int(_delta(before, _trait("wriggle").cue)).is_equal(0)


func test_skating_stings_once_per_start_not_every_frame() -> void:
	var intent := [{}]
	var w := _worm(intent)
	w.model.grant(&"skater")
	await _frames(int(Worm.TRAIT_MOMENT_COOLDOWN * Engine.physics_ticks_per_second) + 4)
	var before := Audio.played.duplicate()
	intent[0] = {"move": Vector2.RIGHT}
	await _frames(60)
	assert_int(_delta(before, "trait_skater")).is_equal(1)


func test_a_garden_patch_is_one_sting_not_one_per_tile() -> void:
	var w := _worm([{}])
	w.model.grant(&"green_thumb")
	await _frames(int(Worm.TRAIT_MOMENT_COOLDOWN * Engine.physics_ticks_per_second) + 4)
	var use := w.get_node("TraitUse") as TraitUse
	var before := Audio.played.duplicate()
	for i in 12:
		use.garden_bite()
	assert_int(_delta(before, "trait_green_thumb")).is_equal(1)


func test_a_bare_worm_bursting_plays_no_trait_sting() -> void:
	var intent := [{"burst": true}]
	var w := _worm(intent)
	await _frames(3)
	assert_bool((w.get_node("TraitUse") as TraitUse).heard.is_empty()).is_true()
