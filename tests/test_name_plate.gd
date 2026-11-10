## The podium name plate: long names shrink to fit between the chooser arrows, never below
## NAME_MIN; a 12-letter name next to the arrows fits (narrowed if it must); short names stay big.
class_name TestNamePlate
extends GdUnitTestSuite

const P1 := Players.P1
const Spot := preload("res://scenes/ui/lobby_spot.gd")
const LONG := "res://tests/fixtures/roster_long.json"

var _main: Node


func before() -> void:
	SuiteSandbox.enter("name_plate", LONG)


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Roster.reload()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	UiStyle.use_skin(null)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()


func _drawn_width(text: String, room: float) -> float:
	return UiStyle.show_width(text, Spot.name_size(text, room)) * Spot.name_squeeze(text, room)


func test_short_names_keep_the_full_size() -> void:
	assert_int(Spot.name_size("JEFF", 170.0)).is_equal(Spot.NAME_SIZE)
	assert_float(Spot.name_squeeze("JEFF", 170.0)).is_equal(1.0)


func test_long_names_shrink_but_not_below_the_minimum() -> void:
	var s := Spot.name_size("SPROCKET", 170.0)
	assert_int(s).is_less(Spot.NAME_SIZE)
	assert_int(s).is_greater_equal(Spot.NAME_MIN)
	assert_float(_drawn_width("SPROCKET", 170.0)).is_less_equal(170.0)
	assert_int(Spot.name_size("WWWWWWWWWWWWWWWWWWWW", 170.0)).is_equal(Spot.NAME_MIN)
	assert_float(Spot.name_squeeze("WWWWWWWWWWWWWWWWWWWW", 170.0)).is_equal(Spot.NAME_SQUEEZE_MIN)


func test_twelve_letters_fit_between_the_arrows_on_the_podium() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var lobby := _main.get_node("UI/Lobby")
	Players.join_virtual(P1)
	lobby.press_b(P1)                                   # joined, not ready: the arrows show
	assert_bool(lobby.choose(P1, 1)).is_true()          # jeff -> (chuck is P2's) -> bartholomews
	var who := UiStyle.skin().player_name(P1)
	assert_int(who.length()).is_equal(12)
	var spot: Control = lobby.get_node("Spots/P1")
	assert_bool(spot.can_change).is_true()
	var room: float = spot.name_room()
	assert_float(room).is_greater(100.0)
	assert_int(Spot.name_size(who, room)).is_greater_equal(Spot.NAME_MIN)
	assert_float(_drawn_width(who, room)).is_less_equal(room)
	# Ready: no arrows, so the same name gets more room and is drawn at least as big.
	spot.can_change = false
	assert_float(spot.name_room()).is_greater(room)
	assert_int(Spot.name_size(who, spot.name_room())).is_greater_equal(Spot.name_size(who, room))
	await get_tree().process_frame                      # it draws without errors
