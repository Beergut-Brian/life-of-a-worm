## K-09: eating a house, a cow or a car is cartoon mayhem (scripts/mayhem/). Each kind plays its
## own pop from an existing cue file (the cow also squeaks, the house never does), one code-drawn
## burst in the prop's colours per eaten object that falls toward the core, nobody inside (nothing
## but the burst and the prop's own chunks appears, nothing else goes), and no voice or text.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const PLANET := preload("res://scenes/levels/planet.tscn")
const JUICE_STUB := preload("res://scripts/worm/stubs/juice_stub.gd")
const SFX_DIR := "res://assets/audio/sfx/"
const UP := -PI / 2.0
const KINDS: Array[StringName] = [&"house", &"cow", &"car"]


func before() -> void:
	SuiteSandbox.enter("mayhem")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	JUICE_STUB.clear_cache()


## A small planet with the whole town on it, watched by a Mayhem.
func _stage() -> Dictionary:
	var w := PolarWorld.new()
	w.setup_planet(RINGS, 160, 7)
	add_child(w)
	w.set_physics_process(false)
	auto_free(w)
	var foods := Node2D.new()
	add_child(foods)
	auto_free(foods)
	var m := Mayhem.new()
	add_child(m)
	auto_free(m)
	m.watch(w)
	var d := WorldDestruct.new()
	add_child(d)
	auto_free(d)
	d.setup(w, Vector2.from_angle(UP) * 1000.0, {}, foods)
	for p in d.props.values():
		p.set_physics_process(false)
		p.fall.set_physics_process(false)
	return { "world": w, "mayhem": m, "destruct": d, "foods": foods }


func _prop(s: Dictionary, kind: StringName) -> SurfaceProp:
	return (s.destruct as WorldDestruct).props["%s_0" % kind]


## Bites it until it breaks, as a big enough worm.
func _eat(prop: SurfaceProp) -> void:
	var big := prop.data.size_stage + 1
	for i in prop.data.hits:
		prop.bite(0, big)


func _bursts(w: Node) -> Array[MayhemBurst]:
	var out: Array[MayhemBurst] = []
	for c in w.get_children():
		if c is MayhemBurst and not c.is_queued_for_deletion():
			out.append(c)
	return out


static func _all(n: Node, out: Dictionary) -> Dictionary:
	out[n.get_instance_id()] = n
	for c in n.get_children():
		_all(c, out)
	return out


## The shared Juice chomp ring and dust, the burst, sound players, the test runner's own timers.
static func _effect(n: Node) -> bool:
	return n is MayhemBurst or n is WormRing or n is CPUParticles2D or n is AudioStreamPlayer \
		or (n is Timer and String(n.name).begins_with("gdunit"))


func _has_file(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists(SFX_DIR + cue + "_1.ogg")


# --- the sounds ------------------------------------------------------------------------------------

func test_each_kind_has_its_own_pop_and_every_cue_is_a_real_file() -> void:
	var pops := {}
	for k in KINDS:
		var cues := Mayhem.cues_for(k)
		assert_array(cues).is_not_empty()
		for cue in cues:
			assert_bool(_has_file(cue)).override_failure_message("%s: no file for %s" % [k, cue]).is_true()
		pops[cues[0]] = k
	assert_int(pops.size()).override_failure_message("each kind needs a different pop").is_equal(3)
	# Only the cow squeaks.
	assert_array(Mayhem.cues_for(&"cow")).contains(["grub_squeak"])
	assert_array(Mayhem.cues_for(&"house")).not_contains(["grub_squeak"])
	assert_array(Mayhem.cues_for(&"car")).not_contains(["grub_squeak"])


func test_eating_each_kind_plays_its_cues_and_the_house_never_squeaks() -> void:
	var s := _stage()
	var m: Mayhem = s.mayhem
	for k in KINDS:
		var before := Audio.played.duplicate()
		_eat(_prop(s, k))
		for cue in Mayhem.cues_for(k):
			assert_int(int(Audio.played.get(cue, 0)) - int(before.get(cue, 0))).is_equal(1)
		var squeaks := int(Audio.played.get("grub_squeak", 0)) - int(before.get("grub_squeak", 0))
		assert_int(squeaks).override_failure_message("%s squeaked %d times" % [k, squeaks]) \
			.is_equal(1 if k == &"cow" else 0)
	assert_array(m.history.map(func(h: Dictionary) -> StringName: return h.kind)).is_equal(KINDS)
	assert_array(m.history[0].cues).not_contains(["grub_squeak"])


# --- the burst -------------------------------------------------------------------------------------

func test_the_burst_plays_once_per_eaten_object() -> void:
	var s := _stage()
	var w: PolarWorld = s.world
	var house := _prop(s, &"house")
	# Bites that don't break it: no burst yet.
	for i in house.data.hits - 1:
		house.bite(0, house.data.size_stage + 1)
	assert_int(_bursts(w).size()).is_equal(0)
	house.bite(0, house.data.size_stage + 1)
	assert_int(_bursts(w).size()).is_equal(1)
	# A broken house can't be eaten again.
	house.bite(0, house.data.size_stage + 1)
	assert_int(_bursts(w).size()).is_equal(1)
	_eat(_prop(s, &"cow"))
	_eat(_prop(s, &"car"))
	assert_int(_bursts(w).size()).is_equal(3)
	assert_int((s.mayhem as Mayhem).history.size()).is_equal(3)


func test_a_too_small_worm_makes_no_mayhem() -> void:
	var s := _stage()
	var house := _prop(s, &"house")
	house.bite(0, house.data.size_stage)
	assert_int(_bursts(s.world).size()).is_equal(0)
	assert_bool(house.broken).is_false()


func test_other_props_keep_the_plain_break() -> void:
	var s := _stage()
	_eat(_prop(s, &"tree"))
	assert_int(_bursts(s.world).size()).is_equal(0)
	assert_array((s.mayhem as Mayhem).history).is_empty()


func test_the_burst_is_in_the_props_colours_and_falls_to_the_core() -> void:
	var s := _stage()
	var w: PolarWorld = s.world
	var car := _prop(s, &"car")
	var centre_r := w.to_local(car.centre()).length()
	_eat(car)
	var b: MayhemBurst = _bursts(w)[0]
	assert_array(b.colours).contains([Mayhem.tile_colour(car.data.tile)])
	for c in b.colours:
		assert_float(c.a).is_equal(1.0)
	b.set_process(false)
	# Up and out first ...
	for i in 10:
		b.step(1.0 / 60.0)
	var mean_r := func() -> float:
		var sum := 0.0
		for bit in b.bits:
			sum += w.to_local(b.to_global(bit.p)).length()
		return sum / b.bits.size()
	var early: float = mean_r.call()
	assert_float(early).is_greater(centre_r)
	# ... then falling back toward the core.
	for i in 60:
		b.step(1.0 / 60.0)
	assert_float(mean_r.call()).is_less(early)
	# It cleans itself up.
	for i in 30:
		b.step(1.0 / 60.0)
	assert_bool(b.is_queued_for_deletion()).is_true()


func test_the_house_colours_come_from_its_walls_and_roof() -> void:
	var house: PropData = load("res://data/props/house.tres")
	var cols := Mayhem.colours_of(house)
	assert_array(cols).contains([Mayhem.tile_colour(house.tile), Mayhem.tile_colour(house.top_tile)])
	assert_bool(Mayhem.tile_colour(&"clay") != Mayhem.tile_colour(&"core_rock")).is_true()


func test_the_chunks_still_fall_to_the_core() -> void:
	var s := _stage()
	var house := _prop(s, &"house")
	_eat(house)
	assert_int(house.chunks_out.size()).is_equal(house.data.chunks)
	for c in house.chunks_out:
		assert_bool(c.has_node(^"Fall")).is_true()


# --- nobody inside ---------------------------------------------------------------------------------

func test_nobody_is_inside_the_house() -> void:
	var s := _stage()
	var house := _prop(s, &"house")
	# Scope to this test's own nodes: the root also holds other suites' layers, which can be freed mid-test on a slow runner.
	var before := _all(self, {})
	var parts := _all(house, {})
	var names := {}
	var effects := {}   # the shared Juice rings and dust from earlier bites fade out on their own
	for id in before:
		var b: Node = before[id]
		names[id] = "%s (%s)" % [b.get_path(), b.get_class()]
		if _effect(b):
			effects[id] = true
	var chunk_food := house.data.chunk
	var chunk_count := house.data.chunks
	var worms := Worm.all().size()
	_eat(house)
	# Long enough for the house to pop away and free itself.
	await await_millis(500)
	var after := _all(self, {})
	# Everything new is the burst, or one of the house's own chunk foods (and their falls).
	for id in after:
		if before.has(id):
			continue
		var n: Node = after[id]
		var ok: bool = n is MayhemBurst or (n is RingPickup and n.data == chunk_food) \
			or (n is LooseFall and n.get_parent() is RingPickup and n.get_parent().data == chunk_food) \
			or _effect(n)
		assert_bool(ok).override_failure_message("something new came out of the house: %s (%s)" % [n.name, n.get_class()]).is_true()
		assert_bool(n is Worm or n is CharacterBody2D or n is CharacterBody3D or n is Node3D).is_false()
		for g in [&"creature", &"character", &"player", &"players", &"worm"]:
			assert_bool(n.is_in_group(g)).is_false()
	# Nothing went but the house itself (and its own parts).
	for id in before:
		if after.has(id):
			continue
		if effects.has(id):
			continue
		assert_bool(parts.has(id)).override_failure_message("something else went with the house: %s" % names[id]).is_true()
	assert_int(Worm.all().size()).is_equal(worms)
	assert_bool(is_instance_valid(house)).is_false()   # it popped away, empty
	var chunks := (s.foods as Node).get_children().filter(func(c: Node) -> bool: return c is RingPickup)
	assert_int(chunks.size()).is_equal(chunk_count)


# --- no voice, no text -----------------------------------------------------------------------------

func test_no_speech_or_text_on_screen() -> void:
	var s := _stage()
	var before := _all(get_tree().root, {})
	for k in KINDS:
		_eat(_prop(s, k))
	await get_tree().process_frame
	for n in _all(get_tree().root, {}).values():
		if before.has(n.get_instance_id()):
			continue
		assert_bool(n is Control or n is Label3D).override_failure_message("text or UI node: %s" % n.name).is_false()
	# The cues are a pop, a boop, a boing and a squeak: none is a voice or a bark.
	for k in KINDS:
		for cue in Mayhem.cues_for(k):
			for word in ["hello", "hi", "voice", "bark", "sorry", "say"]:
				assert_bool(cue.contains(word)).is_false()
	# The scripts never draw a string.
	for path in ["res://scripts/mayhem/mayhem.gd", "res://scripts/mayhem/mayhem_burst.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for bad in ["draw_string", "Label", "Audio.bark", "RichText"]:
			assert_bool(src.contains(bad)).override_failure_message("%s uses %s" % [path, bad]).is_false()


# --- in the planet ---------------------------------------------------------------------------------

func test_the_planet_scene_has_the_mayhem_node() -> void:
	var p := PLANET.instantiate()
	assert_bool(p.get_node_or_null(^"Mayhem") is Mayhem).is_true()
	p.free()
