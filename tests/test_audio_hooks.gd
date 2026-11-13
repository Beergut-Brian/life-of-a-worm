## Audio hooks (worm-audio-hooks-1, PLAN-STATUS U-09, U-11, U-14): the three sound files that had
## no call site. U-09 the crust breakthrough plays the real breakthrough.ogg once per worm per tin;
## U-11 space_drift loops while the space stage is in the tree and stops when it leaves; U-14 the
## ring bed (amb_<RingDef.id>) follows the worm's head ring, crossfades on a change, and a ring with
## no file is silent. Runs in its own sandbox profile with settings under .scratch/.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const SPACE := "res://scenes/levels/space_stage.tscn"
const SCRATCH_SETTINGS := "res://.scratch/test_settings_audio_hooks.json"

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("audio_hooks")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.scratch"))
	Save.settings_path = SCRATCH_SETTINGS
	Save.wipe_settings()


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	for i in 3:
		await get_tree().process_frame
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()


func after_test() -> void:
	_close()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


func _open() -> void:
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("seed", 77)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false


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


## The first solid cell of ring `ring_id` straight up from the core (n nudges the angle).
func _cell_of(ring_id: StringName, n := 0) -> Vector2i:
	var world := _level.world
	var up := _level.spawn_point.normalized().rotated(float(n) * 0.002)
	var r := float(world.shape.radius) * float(world.shape.cell_size)
	for i in range(0, 4000):
		var c: Vector2i = world.shape.cell_at(up * (r - float(i)))
		if world.shape.contains(c) and world.is_solid(c) and world.ring_of(c).id == ring_id:
			return c
	return Vector2i(999999, 999999)


func _ambience() -> RingAmbience:
	var a := RingAmbience.new()
	a.set_process(false)   # the tests drive follow() and step()
	add_child(a)
	return auto_free(a)


func _bed(a: RingAmbience, id: StringName) -> AudioStreamPlayer:
	return a.beds.get(id) as AudioStreamPlayer


# --- U-09 breakthrough ---------------------------------------------------------------------------

func test_breakthrough_plays_the_real_file_once_per_worm_per_tin() -> void:
	_open()
	var table := StageTable.default_table()
	var w := _level.spawn_worm(Players.P1)
	_grow_to(w, table.crust_stage())
	assert_bool(ResourceLoader.exists(Audio.SFX_DIR + CrustBurst.CUE + ".ogg")).is_true()
	_hush()
	assert_bool(_level.world.eat_tile(_cell_of(table.crust_ring(), 0), Players.P1)).is_true()
	assert_int(Audio.played.get("breakthrough", 0)).is_equal(1)
	var heard := Audio._pool.filter(func(p: AudioStreamPlayer) -> bool:
		return p.stream != null and p.stream.resource_path.ends_with("breakthrough.ogg"))
	assert_int(heard.size()).is_equal(1)   # the file, not the placeholder beep
	assert_bool(_level.world.eat_tile(_cell_of(table.crust_ring(), 40), Players.P1)).is_true()
	assert_bool(_level.world.eat_tile(_cell_of(table.crust_ring(), 80), Players.P1)).is_true()
	assert_int(Audio.played.get("breakthrough", 0)).is_equal(1)   # more crust, no second one


# --- U-11 space drift ----------------------------------------------------------------------------

func test_space_drift_loops_while_the_space_stage_is_up_and_stops_on_leave() -> void:
	Save.wipe()
	Save.set_value("seed", 4242)
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	s.set_process(false)
	s.drift.set_process(false)
	var bed := s.drift_bed
	assert_object(bed).is_not_null()
	assert_str(bed.stream.resource_path).ends_with("space_drift.ogg")
	assert_bool((bed.stream as AudioStreamOggVorbis).loop).is_true()
	assert_bool(bed.playing).is_true()
	assert_float(bed.volume_db).is_equal(SpaceStage.DRIFT_DB)
	await get_tree().process_frame
	assert_bool(bed.playing).is_true()
	remove_child(s)                      # leaving space
	assert_bool(bed.playing).is_false()
	add_child(s)                         # back again: it loops again
	assert_bool(bed.playing).is_true()
	remove_child(s)
	s.free()
	# nowhere else: the planet never starts it
	_open()
	for p in _level.find_children("*", "AudioStreamPlayer", true, false):
		var st: AudioStream = (p as AudioStreamPlayer).stream
		assert_bool(st != null and st.resource_path.ends_with("space_drift.ogg")).is_false()


# --- U-14 ring ambience --------------------------------------------------------------------------

func test_every_ring_in_the_data_has_a_bed_file() -> void:
	var a := _ambience()
	for r in PlanetLevel.RINGS.rings:
		assert_str(a.cue_for(r.id)).is_equal("amb_" + String(r.id))


func test_the_bed_fades_in_to_the_level_constant() -> void:
	var a := _ambience()
	a.follow(&"dirt")
	var p := _bed(a, &"dirt")
	assert_object(p).is_not_null()
	assert_str(p.stream.resource_path).ends_with("amb_dirt.ogg")
	assert_bool((p.stream as AudioStreamOggVorbis).loop).is_true()
	assert_bool(p.playing).is_true()
	assert_float(p.volume_db).is_equal(RingAmbience.SILENT_DB)   # starts silent, fades in
	a.step(RingAmbience.FADE * 0.5)
	assert_float(p.volume_db).is_between(RingAmbience.SILENT_DB + 1.0, RingAmbience.LEVEL_DB - 1.0)
	a.step(RingAmbience.FADE)
	assert_float(p.volume_db).is_equal(RingAmbience.LEVEL_DB)
	assert_float(RingAmbience.LEVEL_DB).is_less(0.0)   # low, under the music


func test_a_ring_change_crossfades() -> void:
	var a := _ambience()
	a.follow(&"dirt")
	a.step(RingAmbience.FADE * 2.0)
	a.follow(&"topsoil")
	var old := _bed(a, &"dirt")
	var new := _bed(a, &"topsoil")
	a.step(RingAmbience.FADE * 0.5)
	# both at once: the old one on its way down, the new one on its way up
	assert_bool(old.playing and new.playing).is_true()
	assert_float(old.volume_db).is_less(RingAmbience.LEVEL_DB)
	assert_float(new.volume_db).is_greater(RingAmbience.SILENT_DB)
	a.step(RingAmbience.FADE)
	assert_float(new.volume_db).is_equal(RingAmbience.LEVEL_DB)
	assert_bool(old.playing).is_false()   # faded out and stopped
	a.follow(&"dirt")                     # back down: the old bed comes back
	assert_bool(old.playing).is_true()
	a.step(RingAmbience.FADE * 2.0)
	assert_float(old.volume_db).is_equal(RingAmbience.LEVEL_DB)
	assert_bool(new.playing).is_false()


func test_an_unknown_ring_is_silent_not_an_error() -> void:
	var a := _ambience()
	a.follow(&"dirt")
	a.step(RingAmbience.FADE * 2.0)
	a.follow(&"no_such_ring")
	assert_str(String(a.current)).is_equal("")
	assert_bool(a.beds.has(&"no_such_ring")).is_false()
	a.follow(RingAmbience.SKY_ID)      # no amb_sky file yet: same rule
	assert_bool(a.beds.has(RingAmbience.SKY_ID)).is_false()
	a.step(RingAmbience.FADE * 2.0)
	assert_bool(_bed(a, &"dirt").playing).is_false()
	assert_int(a.beds.size()).is_equal(1)
	assert_int(Audio.played.size()).is_equal(0)   # no placeholder beep either


func test_the_planet_bed_follows_the_worms_head_ring() -> void:
	_open()
	var a: RingAmbience = _level.get_node("RingAmbience")
	assert_object(a).is_not_null()
	var w := _level.spawn_worm(Players.P1)
	for i in 4:
		await get_tree().process_frame
	assert_object(a.world).is_same(_level.world)
	var here := _level.world.ring_of(_level.world.shape.cell_at(_level.world.to_local(w.head_position()))).id
	assert_str(String(a.current)).is_equal(String(here))
	assert_bool(_bed(a, here).playing).is_true()
	# the head in each ring picks that ring's bed
	for id in [&"dirt", &"topsoil", &"deep_rock"]:
		var c := _cell_of(id)
		assert_str(String(a.ring_id_at(_level.world.shape.center_of(c)))).is_equal(String(id))
	# above the grass, in the sky: no bed yet
	var up := _level.spawn_point.normalized()
	var r := float(_level.world.shape.radius) * float(_level.world.shape.cell_size)
	assert_str(String(a.ring_id_at(up * r * 1.2))).is_equal(String(RingAmbience.SKY_ID))
	assert_str(a.cue_for(RingAmbience.SKY_ID)).is_equal("")
	# the worm goes: the bed fades out
	a.set_process(false)
	w.get_parent().remove_child(w)
	a.follow(a._wanted())
	assert_str(String(a.current)).is_equal("")
	a.step(RingAmbience.FADE * 2.0)
	assert_bool(_bed(a, here).playing).is_false()
	w.free()
