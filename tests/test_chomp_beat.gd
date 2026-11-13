## P-14, the planet chomp's camera beat (scripts/chomp/chomp_beat.gd): on each bite the chomp shot's
## camera leans toward the giant worm's mouth and zooms in, keeping the mouth on screen; on the gulp it
## pushes in on the mouth, then lets go back to the whole shot. Only the camera moves. Bites are counted
## against the chomp's own per-bite counter, the gulp against `planet_eaten` (signals, not a poll).
extends GdUnitTestSuite

const SCENE := "res://scenes/levels/planet_chomp.tscn"
const DIR := "user://test_chomp_beat_jars"
const DT := 1.0 / 60.0


func before() -> void:
	SuiteSandbox.enter("chomp_beat")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	var p := PlanetStandIn.generate("chomp_beat_77", 77)
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)


func _chomp(dir := DIR) -> PlanetChomp:
	var c: PlanetChomp = load(SCENE).instantiate()
	c.autostart = false
	c.auto_space = false
	add_child(c)
	c.set_process(false)
	_beat(c).set_process(false)
	c.jars.dir = dir
	c.jars.clear()
	return auto_free(c)


func _beat(c: PlanetChomp) -> ChompBeat:
	return c.get_node_or_null(^"GiantWorm/ChompBeat") as ChompBeat


## Runs the chomp and its beat together, the way _process does (chomp first, then the beat).
func _run(c: PlanetChomp, seconds: float, held: bool, beat := true) -> void:
	for i in int(seconds / DT):
		c.advance(DT, held)
		if beat:
			_beat(c).step(DT)


## The camera's view rect in the chomp's space (zoom > 1 shows less).
func _view(cam: Camera2D) -> Rect2:
	var half := Vector2(1920.0, 1080.0) * 0.5 / cam.zoom
	return Rect2(cam.position - half, half * 2.0)


func _mouth(c: PlanetChomp) -> Vector2:
	var w: GiantWorm = c.get_node("GiantWorm")
	return w.position + w.mouth_position()


## Holds A through the picture and the jar, up to the first bite.
func _to_first_bite(c: PlanetChomp) -> void:
	assert_bool(c.begin()).is_true()
	_run(c, 2.2, true)
	while c.phase != PlanetChomp.Phase.CHOMP:
		_run(c, DT, false)


func test_the_planet_shot_carries_the_beat() -> void:
	var c := _chomp()
	var b := _beat(c)
	assert_object(b).is_not_null()
	assert_object(b.chomp).is_same(c)
	assert_object(b.camera).is_same(c.get_node("Camera"))
	assert_bool(c.planet_eaten.is_connected(b._on_gulped)).is_true()


func test_each_bite_leans_the_camera_toward_the_mouth_with_the_mouth_on_screen() -> void:
	var c := _chomp()
	var cam: Camera2D = c.get_node("Camera")
	var b := _beat(c)
	_to_first_bite(c)
	# Before the chomp the shot is the whole planet, unmoved.
	assert_vector(cam.position).is_equal(Vector2.ZERO)
	assert_float(cam.zoom.x).is_equal_approx(1.0, 0.001)
	_run(c, 0.4, false)
	assert_int(c._bite).is_greater_equal(1)
	assert_int(b.bites).is_equal(c._bite)   # one lean per bite, from the chomp's per-bite counter
	var at := b.focus
	assert_float(cam.position.length()).is_greater(40.0)
	assert_float(cam.position.distance_to(at)).is_less(at.length() - 40.0)   # it moved toward the bite
	assert_float(cam.zoom.x).is_greater(1.05)
	# The cause stays on screen: the jaw and the planet's centre side of it.
	assert_bool(_view(cam).grow(-60.0).has_point(_mouth(c))).is_true()
	assert_bool(_view(cam).has_point(at * 0.5)).is_true()


func test_the_lean_follows_the_mouth_round_the_planet() -> void:
	var c := _chomp()
	var cam: Camera2D = c.get_node("Camera")
	_to_first_bite(c)
	_run(c, 0.6, false)
	var early := cam.position
	_run(c, 3.0, false)
	var later := cam.position
	assert_float(absf(early.angle_to(later))).is_greater(0.3)   # it went round with the mouth
	for t in 20:
		_run(c, 0.25, false)
		if c.phase != PlanetChomp.Phase.CHOMP:
			break
		assert_bool(_view(cam).grow(-40.0).has_point(_mouth(c))).is_true()


func test_the_gulp_pushes_in_on_the_mouth_then_lets_go() -> void:
	var c := _chomp()
	var cam: Camera2D = c.get_node("Camera")
	var b := _beat(c)
	var gulp_at: Array[Vector2] = []
	c.planet_eaten.connect(func() -> void: gulp_at.append(b.mouth()))
	_to_first_bite(c)
	while c.phase == PlanetChomp.Phase.CHOMP:
		_run(c, DT, false)
	assert_int(gulp_at.size()).is_equal(1)
	assert_int(b.gulps).is_equal(1)
	assert_int(b.bites).is_equal(PlanetChomp.BITES)
	_run(c, 0.6, false)
	assert_float(cam.zoom.x).is_greater(ChompBeat.BITE_ZOOM)   # the push-in, past a bite's lean
	assert_bool(_view(cam).grow(-60.0).has_point(gulp_at[0])).is_true()
	# Then the beat ends and the shot is the whole sky again (the burp, the empty space).
	_run(c, 3.4, false)
	assert_bool(b.busy()).is_false()
	assert_float(cam.position.length()).is_less(10.0)
	assert_float(cam.zoom.x).is_equal_approx(1.0, 0.02)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.DONE)
	assert_int(b.gulps).is_equal(1)


func test_only_the_camera_moves() -> void:
	# Two chomps, one with its beat and one without: the chomp and the giant worm play the same.
	var a := _chomp()
	var b := _chomp(DIR + "_b")
	var wa: GiantWorm = a.get_node("GiantWorm")
	var wb: GiantWorm = b.get_node("GiantWorm")
	var nb := _beat(b)
	wb.remove_child(nb)
	nb.free()
	a.begin()
	b.begin()
	for i in int(5.5 / DT):
		a.advance(DT, i < 140)
		_beat(a).step(DT)
		b.advance(DT, i < 140)
		assert_float(a.chomp_progress).is_equal(b.chomp_progress)
		assert_float(wa.head_angle).is_equal(wb.head_angle)
		assert_float(wa.orbit).is_equal(wb.orbit)
	assert_vector(wa.position).is_equal(wb.position)
	assert_vector((b.get_node("Camera") as Camera2D).position).is_equal(Vector2.ZERO)
	assert_float((a.get_node("Camera") as Camera2D).position.length()).is_greater(40.0)
