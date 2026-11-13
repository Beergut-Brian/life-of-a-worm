## Y-15 / P-17 guardrail: Worm keeps the template's vendored chooser characters out of play. The
## lobby's chooser is hidden, its podiums are the two worms, and whatever the shared picks file says,
## the planet spawns worms (worm.tscn), never a roster character scene from assets/characters/.
extends GdUnitTestSuite

const WORM_SCENE := "res://scenes/players/worm.tscn"

var _main: Node
var _level: Node


func before() -> void:
	SuiteSandbox.enter("no_template_jarlings")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)


func after_test() -> void:
	for n in [_main, _level]:
		if is_instance_valid(n):
			n.free()
	_main = null
	_level = null
	UiStyle.use_skin(null)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _roster_nodes(root: Node) -> Array:
	var found: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.scene_file_path.begins_with("res://assets/characters/"):
			found.append(n.scene_file_path)
		stack.append_array(n.get_children())
	return found


func test_the_lobby_hides_the_chooser_and_shows_the_two_worms() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	assert_bool(_main.get_node("UI/Lobby").chooser).is_false()
	var skin: MenuSkin = _main.worm_skin()
	assert_str(skin.p1_name).is_equal("GULP")
	assert_str(skin.p2_name).is_equal("BURP")
	assert_array(_roster_nodes(_main)).is_empty()


func test_a_roster_pick_never_changes_what_hatches_on_the_planet() -> void:
	# Pick someone other than the default for P1 (scratch picks file, SuiteSandbox).
	var ids: Array[String] = Roster.roster()
	assert_int(ids.size()).is_greater(2)
	assert_bool(Roster.set_pick(Players.P1, ids[2])).is_true()
	assert_str(Roster.pick(Players.P1)).is_equal(ids[2])
	_level = load("res://scenes/levels/planet.tscn").instantiate()
	add_child(_level)
	await get_tree().process_frame
	var a: Worm = _level.spawn_worm(Players.P1, null, 0)
	var b: Worm = _level.spawn_worm(Players.P2, null, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for w in [a, b]:
		assert_object(w).is_not_null()
		assert_str(w.scene_file_path).is_equal(WORM_SCENE)
	assert_array(_roster_nodes(_level)).is_empty()
