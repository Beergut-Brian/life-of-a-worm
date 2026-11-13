## U-12: one theme in seven layers, one more per stage. Every layer starts together and loops (so they
## stay in step); a stage-up fades the next layer in, never restarts one; missing files are silent;
## a dock cutscene ducks the theme; the planet level follows the tin's biggest stage.
## Uses silent in-memory streams, so it runs before the Audio lane has any music files.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _music: MusicLayers


func before() -> void:
	SuiteSandbox.enter("music_layers")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func after_test() -> void:
	if is_instance_valid(_music):
		for p in _music.players:
			if p != null:
				p.stop()
				p.stream = null
		_music.free()
	_music = null


static func _silence() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(8000)
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = 8000
	return w


func _make(streams: Array, stage := 0) -> MusicLayers:
	_music = MusicLayers.new()
	_music.streams = streams
	if stage > 0:
		_music.set_stage(stage)
	add_child(_music)
	return _music


func _all_layers() -> Array:
	var out := []
	for i in MusicLayers.LAYERS:
		out.append(_silence())
	return out


func test_stage_n_plays_layers_one_to_n_all_running_together() -> void:
	var m := _make(_all_layers(), 3)
	await get_tree().process_frame
	assert_bool(m.has_music()).is_true()
	for i in MusicLayers.LAYERS:
		var p: AudioStreamPlayer = m.players[i]
		assert_bool(p.playing).override_failure_message("layer %d must run (in step) even when quiet" % (i + 1)).is_true()
		if i < 3:
			assert_float(p.volume_db).is_equal_approx(0.0, 0.01)
		else:
			assert_float(p.volume_db).is_equal_approx(MusicLayers.QUIET_DB, 0.01)


func test_a_stage_up_fades_the_next_layer_in_without_restarting_it() -> void:
	var m := _make(_all_layers(), 2)
	await get_tree().process_frame
	var p: AudioStreamPlayer = m.players[2]
	await get_tree().create_timer(0.3).timeout
	var pos_before := p.get_playback_position()
	m.set_stage(3)
	assert_bool(m.layer_on(3)).is_true()
	await get_tree().create_timer(0.5).timeout
	assert_float(p.volume_db).is_greater(MusicLayers.QUIET_DB + 1.0)   # on its way up
	assert_float(p.volume_db).is_less(-1.0)                            # but a fade, not a jump
	assert_float(p.get_playback_position()).is_greater(pos_before)    # never restarted
	await get_tree().create_timer(MusicLayers.FADE_IN).timeout
	assert_float(p.volume_db).is_equal_approx(0.0, 0.01)


func test_missing_layers_are_skipped_and_no_files_is_silent() -> void:
	var some := _all_layers()
	some[1] = null
	var m := _make(some, 4)
	await get_tree().process_frame
	assert_object(m.players[1]).is_null()
	assert_bool(m.players[0].playing).is_true()
	m.free()
	_music = MusicLayers.new()
	_music.streams = [null, null, null, null, null, null, null]
	add_child(_music)
	assert_bool(_music.has_music()).is_false()
	assert_int(_music.get_child_count()).is_equal(0)


func test_a_cutscene_ducks_the_theme() -> void:
	var m := _make(_all_layers(), 2)
	m.follow_story = false
	await get_tree().process_frame
	m.set_ducked(true)
	assert_float(m.target_db(1)).is_equal(MusicLayers.DUCK_DB)
	assert_float(m.target_db(5)).is_equal(MusicLayers.QUIET_DB)
	await get_tree().create_timer(0.6).timeout
	assert_float(m.players[0].volume_db).is_equal_approx(MusicLayers.DUCK_DB, 0.01)
	m.set_ducked(false)
	assert_float(m.target_db(1)).is_equal(0.0)


func test_the_planet_plays_the_tins_biggest_stage() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	var level: PlanetLevel = PLANET.instantiate()
	add_child(level)
	level.stage_beat.make_story = false
	var w := level.spawn_worm(Players.P1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(level.music.stage).is_equal(1)
	w.model.apex_gate = false
	while w.model.stage < 3:
		w.model.add_segment(&"")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(level.music.stage).is_equal(3)
	assert_bool(level.music.layer_on(3)).is_true()
	assert_bool(level.music.layer_on(4)).is_false()
	remove_child(level)
	level.free()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")
