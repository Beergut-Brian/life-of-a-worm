## The HUD's size-stage icon (W-30) and the text-free gameplay screen (K-10): each worm's icon is
## its own segment sprites, one more segment and a bigger sprite per stage, popping at a stage-up;
## the HUD never draws a number or a word.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const HUD_SRC := "res://scripts/planet/planet_hud.gd"
const TEXT_NODES := ["Label", "RichTextLabel", "LineEdit", "TextEdit", "Button"]

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("hud_stage_icon")


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


## Grows a worm to `stage` the honest way: segments, with the apex gate open.
func _grow_to(w: Worm, stage: int) -> void:
	w.model.apex_gate = false
	while w.model.stage < stage:
		w.model.add_segment(&"")


func test_icon_grows_every_stage() -> void:
	var rules := WormRules.default_rules()
	for s in range(1, rules.max_stage()):
		assert_int(PlanetHud.icon_segments(s + 1)).is_greater(PlanetHud.icon_segments(s))
		assert_float(PlanetHud.icon_px(s + 1)).is_greater(PlanetHud.icon_px(s))


func test_icon_follows_the_worm_and_pops_at_stage_up() -> void:
	var w := _level.spawn_worm(Players.P1)
	var hud := _level.hud
	hud._process(0.016)
	assert_int(hud.icon_stage(Players.P1)).is_equal(1)
	assert_float(hud.icon_scale(Players.P1)).is_equal(1.0)   # first sight: no pop
	_grow_to(w, 3)
	hud._process(0.016)
	assert_int(hud.icon_stage(Players.P1)).is_equal(3)
	hud._process(PlanetHud.ICON_PULSE * 0.4)
	assert_float(hud.icon_scale(Players.P1)).is_greater(1.1)   # the pop is on
	hud._process(PlanetHud.ICON_PULSE)
	assert_float(hud.icon_scale(Players.P1)).is_equal(1.0)   # and settles


func test_icon_draws_the_worm_segment_sprite() -> void:
	var w := _level.spawn_worm(Players.P1)
	var tex: Texture2D = WormHooks.look().segment_texture(w.player, w.model.stage, &"body")
	assert_object(tex).is_not_null()
	var src := FileAccess.get_file_as_string(HUD_SRC)
	assert_str(src).contains("segment_texture(")


func test_hud_has_no_numbers_or_words() -> void:
	_level.spawn_worm(Players.P1)
	_level.spawn_worm(Players.P2)
	_level.hud._process(0.016)
	for t in TEXT_NODES:
		assert_array(_level.hud.find_children("*", t, true, false)).is_empty()
	var src := FileAccess.get_file_as_string(HUD_SRC)
	for call in ["draw_string(", "draw_char(", "draw_multiline_string(", "Label.new", "str(", "% "]:
		assert_bool(src.contains(call)).override_failure_message("planet_hud.gd uses " + call).is_false()


## K-10: nothing on the playing screen is a text node (menus are separate scenes and may use type).
func test_gameplay_screen_has_no_visible_text() -> void:
	var w := _level.spawn_worm(Players.P1)
	_grow_to(w, 2)
	await get_tree().process_frame
	var shown: Array = []
	for t in ["Label", "RichTextLabel", "Label3D"]:
		for n in _level.find_children("*", t, true, false):
			if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
				shown.append(n.get_path())
	assert_array(shown).is_empty()
