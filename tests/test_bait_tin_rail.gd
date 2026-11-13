## C-22, one test per bait tin (worm-gap-close-27): picking a tin on the dock rail (main.tscn ->
## lobby -> Dock.pick) opens that tin's own planet, and playing it never changes the other two tins'
## files. A family tin (green + red) and a solo tin (green alone) live side by side: reopening each
## gives back its own worms, segments, seed and bitten ground. A family tin opened by one player
## keeps the absent partner's worm. (Seed, edits and burrow per tin straight through PlanetLevel are
## test_greybox_planet's; rings, pages and jars per tin are test_tin_keys'.)
## Boots main.tscn with virtual players, in its own Save profile (SuiteSandbox).
class_name TestBaitTinRail
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node


func before() -> void:
	SuiteSandbox.enter("bait_tin_rail")
	Game.quit_exits = false
	_remove_tins()


func after() -> void:
	_remove_tins()
	Save.use_slot("")
	Game.quit_exits = true
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	_remove_tins()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	_shut()
	_remove_tins()
	Save.use_slot("")
	UiStyle.use_skin(null)   # main sets Worm's skin; the next suite expects the template's
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func test_tin_1_keeps_its_own_planet() -> void:
	await _check_tin(0)


func test_tin_2_keeps_its_own_planet() -> void:
	await _check_tin(1)


func test_tin_3_keeps_its_own_planet() -> void:
	await _check_tin(2)


func test_a_family_tin_opened_alone_keeps_the_partner() -> void:
	var want := await _play(0, [P1, P2], 3)
	var red: Array = want.segs[P2]
	await _play(0, [P1], 2, false)          # green plays the family tin alone for a bit
	assert_int(int(BaitTins.summary(0).worms)).is_equal(2)
	var got := await _reopen(0, [P1, P2])
	assert_array(got.segs[P2]).is_equal(red)
	_shut()


# --- helpers -----------------------------------------------------------------------------------

func _remove_tins() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


## Boot, ready up `players` (one alone holds A), and pick tin `i` on the dock rail.
func _pick(i: int, players: Array) -> void:
	_shut()
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	for p in players:
		Players.join_virtual(p)
	if players.size() == 1:
		_lobby().hold_step(players[0], true, Lobby.HOLD_TO_START)
	_lobby().count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	assert_bool(_main.dock.visible).override_failure_message("no dock after the lobby").is_true()
	_main.dock.focus = 0
	for k in i:
		_main.dock.move(1)                  # right along the rail, as the stick does
	assert_int(_main.dock.focus).is_equal(i)
	_main.dock.pick()
	assert_str(Save.slot).is_equal(BaitTins.slot_name(i))
	assert_object(_main.level).is_not_null()


## Pick tin i, grow each worm by `segs` (+1 for red) and bite the ground in this tin's own spot,
## then leave the tin the way the game does (main.close_level saves it). Returns what it left.
func _play(i: int, players: Array, segs: int, fresh := true) -> Dictionary:
	await _pick(i, players)
	await get_tree().process_frame        # a frame of play in it
	var level: PlanetLevel = _main.level
	if fresh:
		assert_int(BaitTins.summary(i).size()).is_equal(0)   # an empty tin was a new planet
	for p in players:
		var w := Worm.of(p)
		for k in segs + (1 if p == P2 else 0):
			w.model.add_segment(&"bug")
	level.world.eat_circle(level.local_point(6 + i * 4, 0), 18.0 + i * 8.0, P1)
	var out := _snapshot()
	_main.close_level()
	_shut()
	return out


## Reopen tin i through the dock and read it back, still open, before a frame of play digs more.
func _reopen(i: int, players: Array) -> Dictionary:
	await _pick(i, players)
	return _snapshot()


func _snapshot() -> Dictionary:
	var level: PlanetLevel = _main.level
	var segs := {}
	for w in Worm.all():
		segs[w.player] = w.model.segments.duplicate()
	return { "segs": segs, "seed": level.planet_seed, "edits": level.world.to_save().edits.size() }


func _shut() -> void:
	if is_instance_valid(_main):
		if _main.level != null:
			_main.close_level()
		remove_child(_main)
		_main.free()
	_main = null
	Save.use_slot("")


func _file(i: int) -> String:
	var path := Save.path_for(BaitTins.slot_name(i))
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Tin 1 is the family's (green + red), the others are solo planets. Fill the other two first, play
## tin i, and check the other two files are byte for byte what they were; then reopen all three.
func _check_tin(i: int) -> void:
	var want := {}
	var cast := func(t: int) -> Array: return [P1, P2] if t == 0 else [P1]
	for t in BaitTins.COUNT:
		if t != i:
			want[t] = await _play(t, cast.call(t), 2 + t * 2)
	var before := {}
	for t in want:
		before[t] = _file(t)
		assert_str(before[t]).is_not_empty()
	want[i] = await _play(i, cast.call(i), 2 + i * 2)
	for t in before:
		assert_str(_file(t)).override_failure_message("playing tin %d changed tin %d" % [i + 1, t + 1]).is_equal(before[t])
	assert_int(int(BaitTins.summary(i).worms)).is_equal(cast.call(i).size())
	for t in BaitTins.COUNT:
		var got := await _reopen(t, cast.call(t))
		assert_int(got.seed).override_failure_message("tin %d seed" % (t + 1)).is_equal(want[t].seed)
		assert_int(got.edits).override_failure_message("tin %d ground %d vs %d" % [t + 1, got.edits, want[t].edits]).is_equal(want[t].edits)
		for p in cast.call(t):
			assert_array(got.segs[p]).override_failure_message("tin %d worm %d" % [t + 1, p]).is_equal(want[t].segs[p])
		assert_int(got.segs.size()).is_equal(cast.call(t).size())
		_shut()
