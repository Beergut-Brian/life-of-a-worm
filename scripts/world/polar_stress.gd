## Prototype R-a stress run: a 1,000-tile disk (radius 500, ~785k tiles), two eaters on opposite
## sides each streaming its own 5x5 chunk neighbourhood, regrowth and castings running.
##   1. Fast-forward: --sim-minutes (10) of planet time stepped at 60 Hz with no rendering between
##      steps (chunk builds, eating, regrowth all real), then the save is written and sized.
##   2. Real time: --seconds (20) of ordinary frames with everything live; frame times measured.
## Args after --: --sim-minutes=10 --seconds=20 --radius=500 --band=32 --speed=12 --seed=4
##   --out=<path> (default user://polar_stress.json). Prints one JSON line and quits.
extends Node2D

const RINGS := preload("res://data/rings/rings.tres")

var sim_minutes := 10.0
var seconds := 20.0
var radius := 500
var band := 32
var speed := 12.0
var planet_seed := 4
var out_path := "user://polar_stress.json"

var world: PolarWorld
var camera: PolarCamera
var eaters: Array[StandInEater] = []
var result := {}

var _phase := 0
var _sim_left := 0
var _frames: PackedFloat32Array = []
var _load_frames: PackedFloat32Array = []
var _quiet_frames: PackedFloat32Array = []
var _loads_seen := 0
var _last_us := 0
var _t := 0.0
var _phys_max := 0.0
var _sim_start_us := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--sim-minutes="): sim_minutes = float(v)
		elif a.begins_with("--seconds="): seconds = float(v)
		elif a.begins_with("--radius="): radius = int(v)
		elif a.begins_with("--band="): band = int(v)
		elif a.begins_with("--speed="): speed = float(v)
		elif a.begins_with("--seed="): planet_seed = int(v)
		elif a.begins_with("--out="): out_path = v
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0 := Time.get_ticks_usec()
	world = PolarWorld.new()
	world.name = "World"
	world.setup_planet(RINGS, radius, planet_seed, band)
	result["overview_build_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	add_child(world)
	for i in 2:
		var e := StandInEater.new()
		e.world = world
		e.player = i
		e.color = Players.COLOR[i]
		e.path_angle = -PI / 2.0 + PI * i
		e.path_radius = radius * 0.85
		e.path_wobble = radius * 0.08
		e.path_wobble_turns = 7.0
		e.speed_tiles = speed
		add_child(e)
		world.track_eater(e)
		eaters.append(e)
	camera = PolarCamera.new()
	camera.targets = [eaters[0]]
	add_child(camera)
	camera.snap()
	camera.make_current()
	world.update_chunks(-1)
	# The TileMapLayer's own deferred work (physics bodies, render quadrants), forced and timed, per
	# chunk: this is the part a frame pays after update_chunks returns.
	var layers := world.get_children().filter(func(c): return c is TileMapLayer and String(c.name).begins_with("Chunk_"))
	var ti := Time.get_ticks_usec()
	for l in layers:
		l.update_internals()
	result["tilemap_internals_ms_per_chunk"] = (Time.get_ticks_usec() - ti) / 1000.0 / maxi(layers.size(), 1)
	result["cells_per_chunk_mean"] = _cells_mean()
	world.chunk_build_ms.clear()  # the first 50 at once are not streaming
	result["mem_static_start_mb"] = OS.get_static_memory_usage() / 1048576.0
	result["tiles"] = _tile_count()
	world.set_physics_process(false)
	_sim_left = int(sim_minutes * 60.0 * 60.0)
	_phase = 1
	_sim_start_us = Time.get_ticks_usec()
	_last_us = _sim_start_us


func _process(delta: float) -> void:
	if _phase == 1:
		_fast_forward()
	elif _phase == 2:
		var now := Time.get_ticks_usec()
		var ms := (now - _last_us) / 1000.0
		_frames.append(ms)
		_last_us = now
		# Frames in which a chunk was built (the TileMapLayer finishes its quadrants this frame).
		if world.chunk_build_ms.size() != _loads_seen:
			_loads_seen = world.chunk_build_ms.size()
			_load_frames.append(ms)
		else:
			_quiet_frames.append(ms)
		_phys_max = maxf(_phys_max, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_t += delta
		if _t >= seconds:
			_finish()


## Steps a batch of 1/60 s ticks per frame (about 100 ms of work) so the window stays alive.
func _fast_forward() -> void:
	var dt := 1.0 / 60.0
	var start := Time.get_ticks_usec()
	while _sim_left > 0 and Time.get_ticks_usec() - start < 100000:
		for e in eaters:
			e.step(dt)
		world.update_chunks(world.chunk_budget_per_frame)
		world.advance(dt)
		_sim_left -= 1
	if _sim_left > 0:
		return
	result["sim_wall_s"] = (Time.get_ticks_usec() - _sim_start_us) / 1e6
	result["sim_minutes"] = sim_minutes
	result["sim_chunk_loads"] = world.chunk_build_ms.size()
	result["sim_chunk_build_ms"] = _stats(world.chunk_build_ms)
	result["sim_regrow_frame_ms_max"] = world.regrow_frame_ms_max
	result["eaten_tiles"] = eaters[0].eaten_total + eaters[1].eaten_total
	result["regrown_tiles"] = world.regrown_total
	result["edits_now"] = world.edits.tiles.size()
	result["castings_now"] = world.castings_count()
	result["live_chunks"] = world.loaded_chunks().size()
	var t0 := Time.get_ticks_usec()
	var data := world.to_save()
	var json := JSON.stringify(data)
	result["save_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	result["save_json_bytes"] = json.length()
	result["save_gzip_bytes"] = json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP).size()
	t0 = Time.get_ticks_usec()
	var w2 := PolarWorld.new()
	w2.build_overview = false
	w2.setup_planet(RINGS, radius, planet_seed, band)
	w2.load_save(JSON.parse_string(json))
	result["load_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	result["load_roundtrip_equal"] = w2.edits.tiles == world.edits.tiles and w2.castings_count() == world.castings_count()
	w2.free()
	world.chunk_build_ms.clear()
	world.regrow_frame_ms_max = 0.0
	_loads_seen = 0
	world.set_physics_process(true)
	_phase = 2
	_last_us = Time.get_ticks_usec()


func _finish() -> void:
	_phase = 3
	var f := _frames.duplicate()
	f.sort()
	result["rt_seconds"] = seconds
	result["rt_frames"] = f.size()
	result["rt_frame_ms"] = _stats(_frames)
	result["rt_frame_ms_p50"] = f[f.size() / 2] if f.size() > 0 else 0.0
	result["rt_frame_ms_p99"] = f[int(f.size() * 0.99)] if f.size() > 0 else 0.0
	result["rt_physics_ms_max"] = _phys_max
	result["rt_frame_ms_chunk_frames"] = _stats(_load_frames)
	result["rt_frame_ms_quiet_frames"] = _stats(_quiet_frames)
	result["rt_chunk_loads"] = world.chunk_build_ms.size()
	result["rt_chunk_build_ms"] = _stats(world.chunk_build_ms)
	result["rt_regrow_frame_ms_max"] = world.regrow_frame_ms_max
	result["mem_static_end_mb"] = OS.get_static_memory_usage() / 1048576.0
	result["video_mem_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	result["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	result["band"] = band
	result["radius"] = radius
	result["renderer"] = RenderingServer.get_current_rendering_driver_name() + " / " + RenderingServer.get_video_adapter_name()
	var line := JSON.stringify(result)
	print("polar_stress: ", line)
	var fa := FileAccess.open(out_path, FileAccess.WRITE)
	if fa:
		fa.store_string(line)
	get_tree().quit()


func _stats(a: PackedFloat32Array) -> Dictionary:
	if a.is_empty():
		return {"n": 0}
	var s := 0.0
	var mx := 0.0
	for v in a:
		s += v
		mx = maxf(mx, v)
	return {"n": a.size(), "mean": snappedf(s / a.size(), 0.01), "max": snappedf(mx, 0.01)}


func _cells_mean() -> float:
	var n := 0
	var keys := world.loaded_chunks()
	for k in keys:
		n += world.shape.chunk_cells(k).size()
	return float(n) / maxi(keys.size(), 1)


func _tile_count() -> int:
	var n := 0
	var r2 := radius * radius
	for y in range(-radius, radius):
		for x in range(-radius, radius):
			if (x + 0.5) * (x + 0.5) + (y + 0.5) * (y + 0.5) < r2:
				n += 1
	return n
