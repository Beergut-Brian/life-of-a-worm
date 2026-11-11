## The planet chomp: hold-to-confirm cancels on release, refuses inside a jar, jars before chomping,
## and planet_eaten fires exactly once.
extends GdUnitTestSuite

const SCENE := "res://scenes/levels/planet_chomp.tscn"
const DIR := "user://test_chomp_jars"


func before() -> void:
	SuiteSandbox.enter("chomp")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	var p := PlanetStandIn.generate("chomp_77", 77)
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)


func _chomp() -> PlanetChomp:
	var c: PlanetChomp = load(SCENE).instantiate()
	c.autostart = false
	c.auto_space = false
	add_child(c)
	c.set_process(false)
	c.jars.dir = DIR
	c.jars.clear()
	return auto_free(c)


func _run(c: PlanetChomp, seconds: float, held: bool) -> void:
	var dt := 1.0 / 60.0
	for i in int(seconds / dt):
		c.advance(dt, held)


func test_hold_confirm_cancels_on_release() -> void:
	var h := HoldConfirm.new()
	var log: Array = []
	h.started.connect(func(): log.append("start"))
	h.cancelled.connect(func(): log.append("cancel"))
	h.confirmed.connect(func(): log.append("yes"))
	for i in 60:
		h.step(1.0 / 60.0, true)       # 1 s of a 2 s hold
	assert_float(h.progress).is_equal_approx(0.5, 0.02)
	h.step(1.0 / 60.0, false)
	assert_array(log).is_equal(["start", "cancel"])
	for i in 60:
		h.step(1.0 / 60.0, false)
	assert_float(h.progress).is_equal(0.0)
	assert_bool(h.done).is_false()
	for i in 125:
		h.step(1.0 / 60.0, true)
	assert_array(log).is_equal(["start", "cancel", "start", "yes"])
	assert_bool(h.done).is_true()


func test_release_cancels_in_the_scene_and_nothing_is_eaten() -> void:
	var c := _chomp()
	var cancels := [0]
	c.confirm_cancelled.connect(func(): cancels[0] += 1)
	assert_bool(c.begin()).is_true()
	_run(c, 1.5, true)
	_run(c, 3.0, false)
	assert_int(cancels[0]).is_equal(1)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.CONFIRM)
	assert_bool(c.jars.has_jar(c.planet_id())).is_false()
	assert_int(int(Save.get_value("stage"))).is_equal(6)


func test_planet_eaten_fires_once_after_the_jar() -> void:
	var c := _chomp()
	var eaten := [0]
	var jarred_first := [false]
	c.planet_eaten.connect(func():
		eaten[0] += 1
		jarred_first[0] = c.jars.has_jar(c.planet_id()))
	assert_bool(c.begin()).is_true()
	_run(c, 2.2, true)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.JARRING)
	_run(c, 20.0, false)
	assert_int(eaten[0]).is_equal(1)
	assert_bool(jarred_first[0]).is_true()
	assert_int(c.phase).is_equal(PlanetChomp.Phase.DONE)
	assert_float(c.chomp_progress).is_equal(1.0)
	assert_int(int(Save.get_value("stage"))).is_equal(7)
	assert_bool(c.begin()).is_false()   # no second chomp
	_run(c, 5.0, true)
	assert_int(eaten[0]).is_equal(1)


func test_no_chomp_inside_a_jar() -> void:
	Save.set_value("stage6_disabled", true)
	var c := _chomp()
	assert_bool(c.begin()).is_false()
	_run(c, 3.0, true)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.IDLE)
	assert_bool(c.jars.has_jar(c.planet_id())).is_false()
