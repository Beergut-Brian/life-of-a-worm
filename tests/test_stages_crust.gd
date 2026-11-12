## The crust burst (S-08) on the real planet, read from dev's data/stages.tres (crust_ring and its
## stage): the crust is food only from that stage (below it the worm bonks off); the first bite
## through is the breakthrough (cue, why-bubble, camera pull-back, Worm.breakthrough), once per worm
## per tin and saved; crust tiles eaten never grow back, so the disk shrinks, while topsoil regrows.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel
var _table: StageTable


func before() -> void:
	SuiteSandbox.enter("stages_crust")
	_table = StageTable.default_table()


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	SuiteSandbox.leave()


func before_test() -> void:
	_open(true)


func after_test() -> void:
	_close()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(fresh: bool) -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()
	BaitTins.open(0)
	if fresh:
		Save.wipe()
		Save.set_value("seed", 77)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false


## Placeholder beeps still playing when a suite ends leak their playbacks at exit: stop them.
func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


func _close() -> void:
	_hush()
	if is_instance_valid(_level):
		for p in _level.find_children("*", "AudioStreamPlayer", true, false):
			(p as AudioStreamPlayer).stop()
		remove_child(_level)
		_level.free()
	_level = null


func _grow_to(w: Worm, stage: int) -> void:
	while w.model.stage < stage:
		if w.model.size_stage() > w.model.stage:
			w.model.eat_apex(w.model.stage)
		else:
			w.model.add_segment(&"")


## The n-th solid cell of ring `ring_id` straight up from the core, a few tiles either side of the spawn.
func _cell_of(ring_id: StringName, n := 0) -> Vector2i:
	var world := _level.world
	var up := _level.spawn_point.normalized().rotated(float(n) * 0.002)
	var r := float(world.shape.radius) * float(world.shape.cell_size)
	for i in range(0, 4000):
		var c: Vector2i = world.shape.cell_at(up * (r - float(i)))
		if world.shape.contains(c) and world.is_solid(c) and world.ring_of(c).id == ring_id:
			return c
	return Vector2i(999999, 999999)


func _solid_crust_cells(cells: Array[Vector2i]) -> int:
	return cells.filter(func(c: Vector2i) -> bool: return _level.world.is_solid(c)).size()


func test_the_table_names_the_crust_and_its_stage() -> void:
	var s := _table.crust_stage()
	assert_int(s).is_greater(0)
	assert_str(String(_table.crust_ring())).is_equal("surface")
	assert_int(s).is_equal(5)   # GAME.md "Past stage 4 the worm bursts through the crust"
	var ring: RingDef = null
	for r in _level.world.rings.rings:
		if r.id == _table.crust_ring():
			ring = r
	assert_object(ring).is_not_null()
	assert_int(ring.edible_from).is_equal(s)
	assert_float(ring.regrow_time).is_equal(0.0)
	# the shared, loaded rings resource is never changed
	for r in PlanetLevel.RINGS.rings:
		if r.id == _table.crust_ring():
			assert_float(r.regrow_time).is_greater(0.0)


func test_the_crust_is_food_only_from_its_stage() -> void:
	var w := _level.spawn_worm(Players.P1)
	var cell := _cell_of(_table.crust_ring())
	assert_bool(_level.world.shape.contains(cell)).is_true()
	var blocked := [0]
	_level.world.dig_blocked.connect(func(_c: Vector2i, _b: StringName, _p: int) -> void: blocked[0] += 1)
	var below := _table.crust_stage() - 1
	for s in range(1, below + 1):
		_grow_to(w, s)
		assert_bool(_level.world.is_edible_by(s, cell)).is_false()
		assert_bool(_level.world.eat_tile(cell, Players.P1)).is_false()
	assert_int(blocked[0]).is_equal(below)   # the bonk: the cause the player sees
	assert_array(_level.crust.broken).is_empty()
	_grow_to(w, _table.crust_stage())
	assert_bool(_level.crust.can_burst(_table.crust_stage())).is_true()
	assert_bool(_level.crust.can_burst(below)).is_false()
	assert_bool(_level.world.eat_tile(cell, Players.P1)).is_true()
	assert_array(_level.crust.broken).contains([Players.P1])


func test_breakthrough_is_once_per_worm_per_tin_and_saved() -> void:
	var w := _level.spawn_worm(Players.P1)
	_grow_to(w, _table.crust_stage())
	var heard := [0]
	w.breakthrough.connect(func(_p: int) -> void: heard[0] += 1)
	var base_cap := _level.stage_beat.zoom_cap()
	assert_bool(_level.world.eat_tile(_cell_of(_table.crust_ring(), 0), Players.P1)).is_true()
	# the visible cause: the why-bubble over the worm, the cue and the camera pull-back
	assert_int(_level.find_children("*", "CrustWhy", true, false).size()).is_equal(1)
	assert_int(Audio.played.get(CrustBurst.CUE, 0)).is_equal(1)
	assert_int(_level.crust.cap(base_cap)).is_equal(maxi(0, base_cap - 1))
	assert_bool(_level.world.eat_tile(_cell_of(_table.crust_ring(), 40), Players.P1)).is_true()
	assert_int(heard[0]).is_equal(1)
	assert_int(Audio.played.get(CrustBurst.CUE, 0)).is_equal(1)
	assert_int(_level.crust.history.size()).is_equal(1)
	assert_int(_level.crust.eaten).is_equal(2)
	# the beat ends: the camera's cap goes back
	_level.crust._process(CrustBurst.PULL_TIME + 0.1)
	assert_int(_level.crust.cap(base_cap)).is_equal(base_cap)
	_level.save_now()
	_close()
	_open(false)
	assert_array(_level.crust.broken).contains([Players.P1])
	assert_int(_level.crust.eaten).is_equal(2)
	var again := _level.spawn_worm(Players.P1)
	assert_int(again.model.stage).is_equal(_table.crust_stage())
	var heard2 := [0]
	again.breakthrough.connect(func(_p: int) -> void: heard2[0] += 1)
	Audio.played.clear()
	assert_bool(_level.world.eat_tile(_cell_of(_table.crust_ring(), 80), Players.P1)).is_true()
	assert_int(heard2[0]).is_equal(0)   # the reloaded tin remembers: no second breakthrough
	assert_int(Audio.played.get(CrustBurst.CUE, 0)).is_equal(0)
	assert_int(_level.crust.eaten).is_equal(3)


func test_each_worm_breaks_through_once() -> void:
	var w1 := _level.spawn_worm(Players.P1)
	var w2 := _level.spawn_worm(Players.P2)
	_grow_to(w1, _table.crust_stage())
	_grow_to(w2, _table.crust_stage())
	var heard := []
	_level.crust.breakthrough.connect(func(p: int) -> void: heard.append(p))
	_level.world.eat_tile(_cell_of(_table.crust_ring(), 0), Players.P1)
	_level.world.eat_tile(_cell_of(_table.crust_ring(), 30), Players.P2)
	_level.world.eat_tile(_cell_of(_table.crust_ring(), 60), Players.P1)
	assert_array(heard).is_equal([Players.P1, Players.P2])


func test_eaten_crust_never_grows_back_so_the_disk_shrinks() -> void:
	var w := _level.spawn_worm(Players.P1)
	_grow_to(w, _table.crust_stage())
	var world := _level.world
	var crust: Array[Vector2i] = []
	for n in 6:
		var c := _cell_of(_table.crust_ring(), n * 12)
		if not c in crust:
			crust.append(c)
	var soil := _cell_of(&"topsoil")
	var before := _solid_crust_cells(crust)
	assert_int(before).is_equal(crust.size())
	# A live chunk there (regrowth only runs near a tracked eater), the eater far enough not to block it.
	var watcher := Node2D.new()
	world.add_child(watcher)
	watcher.position = world.shape.center_of(soil) - _level.spawn_point.normalized() * 16.0 * 8.0
	world.track_eater(watcher)
	world.update_chunks()
	for c in crust:
		assert_bool(world.eat_tile(c, Players.P1)).is_true()
	assert_bool(world.eat_tile(soil, Players.P1)).is_true()
	assert_int(_level.crust.eaten).is_equal(crust.size())
	assert_float(world.regrow_time(crust[0])).is_equal(INF)
	for i in 40:
		world.advance(60.0)
		world.regrow_pass()
	assert_int(_solid_crust_cells(crust)).is_equal(0)   # the surface is gone for good: the disk shrank
	assert_bool(world.is_solid(soil)).is_true()          # the topsoil under it still grows back
	world.untrack_eater(watcher)
	watcher.free()
