## The in-play hint panel per player (P-13, C-24), the ready glyph over the head (C-25) and the
## answer to a press that does nothing (C-26 / K-15). HintRules is pure, so most cases drive it
## directly; the live cases spawn worms in a real planet and read each player's own panel.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const SOURCES := ["res://scripts/ui/hint_rules.gd", "res://scripts/ui/player_hints.gd",
	"res://scripts/ui/press_answer.gd", "res://scripts/planet/ready_glyph.gd"]

var _level: PlanetLevel
var _intent := {}


func before() -> void:
	SuiteSandbox.enter("hint_rules")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	_intent = {}
	_level = PLANET.instantiate()
	add_child(_level)
	_level.stage_beat.make_story = false


func after_test() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _spawn(player: int) -> Worm:
	var w := _level.spawn_worm(player)
	w.autopilot = func(_w: Worm) -> Dictionary: return _intent
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _pad(button: int, device: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	e.pressed = true
	return e


func _tokens(rows: Array) -> Array:
	return rows.map(func(r: Array) -> String: return r[0])


func _pictures(rows: Array) -> Array:
	return rows.map(func(r: Array) -> String: return r[1])


# --- pure rules ---------------------------------------------------------------------------------

## C-24: the panel's rows follow what this worm can do right now, glyph by glyph.
func test_rows_change_with_context() -> void:
	assert_array(_tokens(HintRules.rows_for({}))).contains_exactly(["stick", "a", "b", "y"])
	assert_array(_pictures(HintRules.rows_for({}))).contains_exactly(["worm", "zip", "notes", "box"])
	assert_array(_pictures(HintRules.rows_for({ "carry_ready": true }))).contains(["mouth"])
	var carrying := _pictures(HintRules.rows_for({ "carry_ready": true, "carrying": true }))
	assert_array(carrying).contains(["drop"])
	assert_array(carrying).not_contains(["mouth"])
	assert_array(_pictures(HintRules.rows_for({ "swap": true }))).contains(["swap"])
	assert_array(_pictures(HintRules.rows_for({ "wall": true }))).contains(["wall"])
	assert_array(_pictures(HintRules.rows_for({ "wall": true }))).not_contains(["box"])
	assert_array(_pictures(HintRules.rows_for({ "warp": "home" }))).contains(["home"])
	assert_array(_pictures(HintRules.rows_for({ "warp": "partner" }))).contains(["partner"])
	assert_array(_pictures(HintRules.rows_for({ "has_home": true }))).contains(["home"])
	# Held B rows draw the hold ring.
	assert_bool(HintRules.HOME[2] and HintRules.PARTNER[2]).is_true()


## C-24: only what is ready right now is lit, and a lost partner lights the held-B row.
func test_lit_rows_are_the_ready_ones() -> void:
	var hot := HintRules.hot_for({ "carry_ready": true })
	assert_bool(hot.mouth).is_true()
	assert_bool(hot.drop or hot.swap or hot.wall or hot.box or hot.partner).is_false()
	assert_bool(HintRules.hot_for({ "carry_ready": true, "carrying": true }).mouth).is_false()
	assert_bool(HintRules.hot_for({ "warp": "partner", "partner_far": true }).partner).is_true()
	assert_bool(HintRules.hot_for({ "warp": "home", "partner_far": true }).partner).is_false()


## C-24: a quiet panel folds down to its lit rows; awake it shows them all.
func test_a_quiet_panel_folds_to_its_lit_rows() -> void:
	var ctx := { "carry_ready": true, "warp": "home" }
	assert_int(HintRules.visible_rows(ctx, true).size()).is_equal(HintRules.rows_for(ctx).size())
	assert_array(_pictures(HintRules.visible_rows(ctx, false))).contains_exactly(["mouth"])
	assert_array(HintRules.visible_rows({}, false)).is_empty()
	assert_bool(HintRules.signature({}) == HintRules.signature({ "carry_ready": true })).is_false()
	assert_bool(HintRules.signature({ "warp": "home" }) == HintRules.signature({ "has_home": true })).is_true()


## C-25: the glyph over the head picks the one press that does something special here.
func test_the_head_glyph_picks_the_ready_press() -> void:
	assert_str(HintRules.glyph_for({})).is_equal("")
	assert_str(HintRules.glyph_for({ "carry_ready": true })).is_equal("x")
	assert_str(HintRules.glyph_for({ "carry_ready": true, "carrying": true })).is_equal("")
	assert_str(HintRules.glyph_for({ "swap": true, "carry_ready": true })).is_equal("a")
	assert_str(HintRules.glyph_for({ "wall": true })).is_equal("y")
	assert_str(HintRules.glyph_for({ "warp": "partner", "partner_far": true })).is_equal("b")
	for ctx in [{ "carry_ready": true }, { "swap": true }, { "wall": true }, { "warp": "partner", "partner_far": true }]:
		assert_array(UiStyle.GLYPHS).contains([HintRules.glyph_for(ctx)])


## C-26: buttons the game uses are never refused; Select alone, shoulders and stick clicks are.
func test_only_presses_that_do_nothing_are_refused() -> void:
	for b in HintRules.PLAY_BUTTONS:
		assert_dict(HintRules.refusal_for(b, false)).is_empty()
		assert_dict(HintRules.refusal_for(b, true)).is_empty()
	assert_str(HintRules.refusal_for(JOY_BUTTON_BACK, false).glyph).is_equal("select")
	assert_dict(HintRules.refusal_for(JOY_BUTTON_BACK, true)).is_empty()   # solo: Select hands over
	assert_str(HintRules.refusal_for(JOY_BUTTON_LEFT_STICK, false).glyph).is_equal("stick")
	assert_str(HintRules.refusal_for(JOY_BUTTON_LEFT_SHOULDER, false).glyph).is_equal("")
	assert_bool(HintRules.refusal_for(JOY_BUTTON_RIGHT_SHOULDER, false).wake).is_true()
	assert_dict(HintRules.refusal_for(JOY_BUTTON_GUIDE, false)).is_empty()


## K-10: the new HUD pieces never draw words or numbers.
func test_hint_pieces_draw_no_text() -> void:
	for path in SOURCES:
		var src := FileAccess.get_file_as_string(path)
		for call in ["draw_string(", "draw_char(", "draw_multiline_string(", "Label.new", "str(", "% "]:
			assert_bool(src.contains(call)).override_failure_message(path + " uses " + call).is_false()


# --- live -------------------------------------------------------------------------------------

## C-24: each worm's player gets their own panel, green bottom-left and red bottom-right, below
## the stage icons and inside the screen; a player who leaves loses theirs.
func test_each_player_has_their_own_panel_in_their_corner() -> void:
	_spawn(Players.P1)
	_spawn(Players.P2)
	await _frames(3)
	var view := _level.hud._root.size
	var p1: PlayerHints = _level.hud.panel_of(Players.P1)
	var p2: PlayerHints = _level.hud.panel_of(Players.P2)
	assert_object(p1).is_not_null()
	assert_object(p2).is_not_null()
	assert_float(p1.position.x + p1.size.x).is_less(view.x * 0.5)
	assert_float(p2.position.x).is_greater(view.x * 0.5)
	for p in [p1, p2]:
		assert_float(p.position.y).is_greater(200.0)   # clear of the stage icons
		assert_float(p.position.y + p.size.y).is_less_equal(view.y)
		assert_array(p.tokens()).contains(["stick", "a", "b"])
	_level.remove_worm(Players.P2)
	await _frames(2)
	assert_object(_level.hud.panel_of(Players.P2)).is_null()


## C-24 / C-25: food at one worm's mouth lights that player's X row and glyph only.
func test_food_in_reach_lights_only_that_players_panel() -> void:
	var w := _spawn(Players.P1)
	_spawn(Players.P2)
	await _frames(2)
	# Just outside the bite, inside the carry band (Worm._eat_and_carry), so it stays in reach.
	var f := _level._add_food(&"bottle_cap", w.mouth_position())
	var away: Vector2 = Vector2.from_angle(w.heading) * (8.0 + f.data.radius + 10.0)
	f.global_position = w.mouth_position() + away
	await _frames(3)
	assert_bool(w.carry_ready).is_true()
	assert_bool(_level.hud.panel_of(Players.P1).is_hot("mouth")).is_true()
	assert_bool(_level.hud.panel_of(Players.P2).is_hot("mouth")).is_false()
	assert_array(_level.hud.panel_of(Players.P2).pictures()).not_contains(["mouth"])
	assert_str(_level._glyphs[Players.P1].token).is_equal("x")
	assert_str(_level._glyphs[Players.P2].token).is_equal("")


## C-24: after the quiet time the panel folds; Select alone opens it again (and is answered).
func test_a_quiet_panel_folds_and_select_opens_it() -> void:
	_spawn(Players.P1)
	await _frames(2)
	var p: PlayerHints = _level.hud.panel_of(Players.P1)
	p._process(HintRules.QUIET_AFTER + 0.1)
	assert_bool(p.is_awake()).is_false()
	assert_array(p.rows).is_empty()
	assert_float(p.panel_size().y).is_less(PlayerHints.ROW_H)
	Players._device_of[Players.P1] = 0
	_level.hud.answer._unhandled_input(_pad(JOY_BUTTON_BACK, 0))
	assert_bool(p.is_awake()).is_true()
	assert_array(p.tokens()).contains(["stick", "a", "b", "y"])


## C-26: Select alone, a shoulder or a stick click in play bonks, shakes its glyph over that
## player's worm and shakes their panel; A, the partner's pad and solo Select are left alone.
func test_a_press_that_does_nothing_is_answered() -> void:
	_spawn(Players.P1)
	_spawn(Players.P2)
	await _frames(2)
	Players._device_of[Players.P1] = 0
	Players._device_of[Players.P2] = 1
	var answer: PressAnswer = _level.hud.answer
	var bonks := int(Audio.played.get("bonk", 0))
	answer._unhandled_input(_pad(JOY_BUTTON_BACK, 1))
	assert_int(int(Audio.played.get("bonk", 0))).is_equal(bonks + 1)
	assert_array(answer.answered.back()).contains_exactly([Players.P2, "select"])
	assert_str(_level._glyphs[Players.P2].shown()).is_equal("select")
	assert_str(_level._glyphs[Players.P1].shown()).is_equal("")
	assert_bool(_level.hud.panel_of(Players.P2).shaking()).is_true()
	assert_bool(_level.hud.panel_of(Players.P1).shaking()).is_false()
	answer._unhandled_input(_pad(JOY_BUTTON_RIGHT_STICK, 0))
	assert_array(answer.answered.back()).contains_exactly([Players.P1, "stick"])
	answer._unhandled_input(_pad(JOY_BUTTON_LEFT_SHOULDER, 0))
	assert_array(answer.answered.back()).contains_exactly([Players.P1, ""])
	assert_bool(_level.hud.panel_of(Players.P1).shaking()).is_true()
	var n := answer.answered.size()
	answer._unhandled_input(_pad(JOY_BUTTON_A, 0))
	answer._unhandled_input(_pad(JOY_BUTTON_BACK, 7))   # nobody's pad
	assert_int(answer.answered.size()).is_equal(n)
	# The refused glyph fades back to the ready glyph.
	_level._glyphs[Players.P2]._process(ReadyGlyph.REFUSE_TIME + 0.05)
	assert_str(_level._glyphs[Players.P2].shown()).is_equal("")
