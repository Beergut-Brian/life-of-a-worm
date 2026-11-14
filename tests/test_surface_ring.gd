## W-06 / W-13: the surface ring loads from data (data/rings/surface_life.tres, SurfaceLife), its
## town props (trees, fences, houses, cars, cows, hills, the water tower, the diner, the basketball
## court, the dock shed) are PropData stood by WorldDestruct, every one of them breaks the way the
## destruct lane defines (a small worm bonks, a big one bites it into chunks, the break shows its
## cause), and nothing on a prop is text.
extends GdUnitTestSuite

const D105_37 := preload("res://tests/d105_stage37_table.gd")
const RINGS := preload("res://data/rings/rings.tres")
const SURFACE_PATH := "res://data/rings/surface_life.tres"
const CRATE := preload("res://data/props/crate.tres")
const JUICE_STUB := preload("res://scripts/worm/stubs/juice_stub.gd")
const UP := -PI / 2.0
const TOWN: Array[StringName] = [&"tree", &"fence", &"house", &"car", &"cow", &"hill", &"water_tower",
		&"diner", &"court", &"dock_shed"]


func before() -> void:
	SuiteSandbox.enter("surface_ring")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	JUICE_STUB.clear_cache()


func _surface() -> SurfaceLife:
	var r := load(SURFACE_PATH)
	assert_bool(r is SurfaceLife).is_true()
	return r


func _world() -> PolarWorld:
	var w := PolarWorld.new()
	w.setup_planet(RINGS, 160, 7)
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _destruct(w: PolarWorld) -> WorldDestruct:
	var d := WorldDestruct.new()
	add_child(d)
	auto_free(d)
	var foods := Node2D.new()
	add_child(foods)
	auto_free(foods)
	d.setup(w, Vector2.from_angle(UP) * 1000.0, {}, foods)
	for p in d.props.values():
		p.set_physics_process(false)
		p.fall.set_physics_process(false)
	return d


func _ring_def(id: StringName) -> RingDef:
	for r in RINGS.rings:
		if r.id == id:
			return r
	return null


# --- W-06: the ring from data ----------------------------------------------------------------------

func test_the_surface_ring_loads_from_data() -> void:
	var s := _surface()
	assert_bool(s is RingLife).is_true()
	assert_bool(RingsDirector.SURFACE == s).is_true()
	assert_str(String(s.ring)).is_equal("surface")
	var def := _ring_def(&"surface")
	assert_object(def).is_not_null()
	assert_bool(RINGS.rings[RINGS.rings.size() - 1] == def).is_true()   # still the last tile ring
	assert_int(s.edible_from).is_equal(4)
	assert_int(s.edible_to).is_equal(5)
	assert_int(def.edible_from).is_equal(s.edible_from)
	assert_float(s.regrow_time).is_equal(def.regrow_time)
	# Populations: counters only (no bodies yet), ids unique and in this ring.
	var ids := {}
	for sp in s.species:
		assert_bool(sp is PopulationRule).is_true()
		assert_str(String(sp.ring)).is_equal("surface")
		assert_bool(ids.has(sp.id)).is_false()
		ids[sp.id] = true
		# D105 stages 3 to 7 gave the grass its first bodies (frog, hedgehog, tortoise, jackrabbit)
		if not D105_37.CREATURES.has(sp.id):
			assert_int(sp.live_max).is_equal(0)
	assert_bool(ids.has(&"apple")).is_true()
	assert_bool(ids.has(&"lawnmower")).is_true()
	# Scattered foods sit on the grass, regrow at the ring's rate, and a stage-4 worm can eat them.
	assert_int(s.scatter_count).is_greater(0)
	assert_float(s.scatter_inner).is_greater(1.0)
	assert_float(s.scatter_outer).is_greater(s.scatter_inner)
	for f in s.scatter:
		assert_bool(f is RingFood).is_true()
		assert_str(String(f.ring)).is_equal("surface")
		assert_float(f.regrow_time).is_equal(s.regrow_time)
		assert_int(f.size_stage).is_less_equal(s.edible_from)
		assert_bool((auto_free(WorldDestruct.new()) as WorldDestruct).loose_foods.has(f.id)).override_failure_message("%s loose" % f.id).is_true()
	# The ecology runs its counters next to every other ring.
	var eco := RingEcology.from_lives(RingsDirector.LIVES + [RingsDirector.SKY, s], 3)
	assert_object(eco).is_not_null()


func test_every_surface_prop_is_town_data_with_a_scene() -> void:
	var s := _surface()
	var listed := {}
	for d in s.props:
		assert_bool(d is PropData).is_true()
		listed[d.id] = d
	for id in TOWN:
		assert_bool(listed.has(id)).override_failure_message("%s missing" % id).is_true()
	var loaded := {}
	for d in WorldDestruct.load_props():
		loaded[d.id] = d
	var rows: Dictionary = LanternTileArt.load_meta().get("solid_rows", {})
	for id in listed:
		var d: PropData = listed[id]
		assert_bool(loaded.has(id)).override_failure_message("%s not in data/props" % id).is_true()
		assert_str(String(d.look)).is_equal(String(id))
		assert_bool(rows.has(String(d.tile))).override_failure_message("%s tile" % id).is_true()
		if d.top_tile != &"":
			assert_bool(rows.has(String(d.top_tile))).is_true()
			assert_int(d.top_rows).is_between(1, d.size.y - 1)
		# 4 to 5: fences, trees, cows and hills from stage 4; the buildings and cars from stage 5.
		assert_int(d.size_stage + 1).is_between(s.edible_from, s.edible_to)
		assert_bool(d.chunk is RingFood).is_true()
		assert_str(String((d.chunk as RingFood).ring)).is_equal("surface")
		assert_int(d.chunk.size_stage).is_less_equal(d.size_stage + 1)
		assert_int(d.chunks).is_greater_equal(d.hits)
		assert_int(d.size.x * d.size.y).is_greater(1)
		# It stands on something drawn: its bottom row has cells (the water tower's are its legs).
		var feet := range(d.size.x).filter(func(x: int) -> bool: return PropLook.filled(d.look, d.size, x, d.size.y - 1))
		assert_int(feet.size()).override_failure_message("%s feet" % id).is_greater(0)
		var scene := load("res://scenes/props/%s.tscn" % id) as PackedScene
		assert_object(scene).is_not_null()
		var n := scene.instantiate()
		assert_bool(n is SurfaceProp).is_true()
		n.free()


func test_the_town_does_not_overlap_on_the_planet() -> void:
	var r := float(PlanetLevel.RADIUS)
	var spans: Array[Vector3] = []   # (from, to, index)
	for d in WorldDestruct.load_props():
		var half := float(d.size.x) * 0.5 / r
		for a in d.angles:
			spans.append(Vector3(a - half, a + half, 0))
	spans.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	for i in range(1, spans.size()):
		assert_float(spans[i].x - spans[i - 1].y).override_failure_message("props %d overlap" % i).is_greater(1.0 / r)
	# And clear of the picnic sandwich in the grass (RingsDirector, -0.06 rad).
	for sp in spans:
		assert_bool(sp.y < -0.06 - 1.0 / r or sp.x > -0.06 + 1.0 / r).is_true()


# --- every prop breaks as the destruct lane defines -----------------------------------------------

func test_every_surface_prop_stands_bonks_and_breaks_into_chunks() -> void:
	var w := _world()
	var d := _destruct(w)
	var s := _surface()
	for data in s.props:
		var key := "%s_0" % data.id
		assert_bool(d.props.has(key)).override_failure_message("%s placed" % key).is_true()
		var p: SurfaceProp = d.props[key]
		var up := Vector2.from_angle(UP + data.angles[0])
		assert_float(p.position.normalized().dot(up)).is_greater(0.9999)
		assert_bool(w.is_solid(w.shape.cell_at(p.position - up * 2.0))).is_true()
		assert_bool(w.is_solid(w.shape.cell_at(p.position + up * 2.0))).is_false()
		assert_bool(p.fall.step(1.0 / 60.0)).is_false()
		# A worm its size bonks off.
		var bonks0 := int(Audio.played.get(SurfaceProp.BONK_CUE, 0))
		assert_bool(p.bite(0, data.size_stage)).is_false()
		assert_int(p.hp).is_equal(data.hits)
		assert_int(int(Audio.played.get(SurfaceProp.BONK_CUE, 0))).is_greater(bonks0)
		# A bigger one cracks it once per bite, then breaks it.
		var big := data.size_stage + 1
		var broke := []
		p.broke.connect(func(_p: SurfaceProp, pl: int, chunks: Array) -> void: broke.append([pl, chunks.size()]))
		var cracks0 := int(Audio.played.get(SurfaceProp.CRACK_CUE, 0))
		var breaks0 := int(Audio.played.get(SurfaceProp.BREAK_CUE, 0))
		JUICE_STUB.clear_cache()
		for i in data.hits - 1:
			assert_bool(p.bite(1, big)).is_true()
			assert_int(p.chunks_out.size()).is_equal(i + 1)
		var calls := JUICE_STUB.calls.map(func(e: Array) -> String: return e[0])
		if data.hits > 1:
			assert_array(calls).contains(["chomp", "debris"])
			assert_array(calls).not_contains(["shake"])
		assert_int(int(Audio.played.get(SurfaceProp.CRACK_CUE, 0)) - cracks0).is_equal(data.hits - 1)
		assert_bool(p.bite(1, big)).is_true()
		assert_bool(p.broken).override_failure_message("%s broken" % data.id).is_true()
		assert_array(broke).is_equal([[1, data.chunks]])
		assert_int(int(Audio.played.get(SurfaceProp.BREAK_CUE, 0)) - breaks0).is_equal(1)
		assert_array(JUICE_STUB.calls.map(func(e: Array) -> String: return e[0])).contains(["shake"])
		assert_int(d.to_dict().props[key]).is_equal(0)
		for f in p.chunks_out:
			assert_bool(f.is_in_group(&"food")).is_true()
			assert_bool(f.data == data.chunk).is_true()
			assert_bool(f.get_node_or_null(^"Fall") is LooseFall).is_true()


# --- gameplay stays text-free ----------------------------------------------------------------------

func test_no_prop_shows_text() -> void:
	var w := _world()
	var d := _destruct(w)
	assert_int(d.props.size()).is_greater(TOWN.size())
	for p in d.props.values():
		var stack: Array[Node] = [p]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			assert_bool(n is Label or n is RichTextLabel or n is Label3D or n is LineEdit or n is Button) \
					.override_failure_message("%s has text node %s" % [p.key, n.name]).is_false()
			stack.append_array(n.get_children())
	for path in ["res://scripts/world/prop_look.gd", "res://scripts/world/surface_prop.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for word in ["draw_string", "draw_char", "draw_multiline_string", "Label.new", "RichTextLabel"]:
			assert_bool(src.contains(word)).override_failure_message("%s uses %s" % [path, word]).is_false()


# --- W-10: a cow is a loose thing too ------------------------------------------------------------

func test_a_cow_falls_toward_the_core_when_the_ground_under_it_is_eaten() -> void:
	var w := _world()
	var cow: SurfaceProp = _destruct(w).props["cow_0"]
	var up := cow.position.normalized()
	var side := up.orthogonal()
	var top := cow.position.length()
	assert_bool(cow.fall.step(1.0 / 60.0)).is_false()   # standing on grass, it stays
	w.set_stage(0, 7)
	for k in range(-2, 3):
		for depth in range(0, 5):
			w.eat_tile(w.shape.cell_at(cow.position + side * (k * 16.0) - up * (depth * 16.0 + 8.0)), 0)
	# P-26: the cow alone over its own pit; its landing is counted through LooseFall.landed.
	var landed := []
	cow.fall.landed.connect(func(_b: Node2D, speed: float) -> void: landed.append(speed))
	assert_bool(cow.fall.step(1.0 / 60.0)).is_true()
	for i in 600:
		if not landed.is_empty():
			break
		cow.fall.step(1.0 / 60.0)
	for i in 30:   # resting stays resting: no second touchdown, no roll
		assert_bool(cow.fall.step(1.0 / 60.0)).is_false()
	assert_bool(cow.fall.resting).is_true()
	assert_bool(cow.fall.supported_at(cow.position)).is_true()
	assert_float(cow.position.length()).is_between(top - 6.0 * 16.0, top - 4.0 * 16.0)
	assert_float(cow.position.normalized().dot(up)).is_greater(0.9999)   # straight down
	assert_int(landed.size()).override_failure_message("landings %s" % [landed]).is_equal(1)
	assert_bool(cow.broken).is_false()   # it lands, it is not hurt
