## A-14 Juice (scripts/worm/juice.gd): a bite bursts in the food's colour and the burst frees
## itself; the camera nudge grows with the bite and is capped, on the eater's camera only; the
## stage-up flash is exactly two drawn frames; crumbs fall toward the core along the disk's own
## gravity; WormJuice.on = false (from the ENABLED constant) turns every effect off.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const RINGS := preload("res://data/rings/rings.tres")
const GRUB := preload("res://data/foods/grub.tres")
const SEED := preload("res://data/foods/seed.tres")


func before() -> void:
	SuiteSandbox.enter("juice")


func after() -> void:
	WormJuice.clear_cache()
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	WormJuice.on = WormJuice.ENABLED
	WormJuice.clear_cache()


func after_test() -> void:
	WormJuice.on = WormJuice.ENABLED


func _worm(player := Players.P1, at := Vector2.ZERO) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	w.position = at
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _food(radius: float, colour := Color(0.2, 0.9, 0.4)) -> FoodData:
	var f := FoodData.new()
	f.id = &"test_food"
	f.radius = radius
	f.color = colour
	return f


func _camera(targets: Array[Node2D]) -> PolarCamera:
	var c := PolarCamera.new()
	add_child(c)
	c.set_process(false)   # no decay while the test reads it
	c.targets = targets
	c.make_current()
	return auto_free(c)


func _named(prefix: String) -> Array:
	return get_children().filter(func(n: Node) -> bool:
		return String(n.name).begins_with(prefix) and not n.is_queued_for_deletion())


func _world(rot := 0.0) -> PolarWorld:
	var w := PolarWorld.new()
	w.setup_planet(RINGS, 160, 7)
	w.rotation = rot
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


# --- Chomp burst ----------------------------------------------------------------------------------

func test_a_bite_bursts_in_the_food_colour_and_frees_itself() -> void:
	var w := _worm()
	for food: FoodData in [GRUB, SEED]:
		w.feed(food)   # the real eat path: Worm.feed calls WormJuice.bite
		var bursts := _named("JuiceBurst")
		assert_int(bursts.size()).is_greater(0)
		var p: CPUParticles2D = bursts.back()
		assert_that(p.color).is_equal(food.color)
		assert_bool(p.one_shot).is_true()
		assert_vector(p.global_position).is_equal_approx(w.mouth_position(), Vector2.ONE * 0.01)
		await await_millis(int((WormJuice.CHOMP_LIFE + 0.45) * 1000.0))
		assert_bool(is_instance_valid(p)).override_failure_message("burst outlived its life").is_false()


func test_bigger_bites_get_more_specks() -> void:
	var w := _worm()
	var small := WormJuice.bite(w, _food(1.0))
	var big := WormJuice.bite(w, _food(12.0))
	assert_int(small.amount).is_greater_equal(WormJuice.CHOMP_SPECKS_MIN)
	assert_int(big.amount).is_greater(small.amount)
	assert_int(big.amount).is_less_equal(WormJuice.CHOMP_SPECKS_MAX)


# --- Shake ----------------------------------------------------------------------------------------

func test_shake_grows_with_the_bite_and_is_capped() -> void:
	var prev := -1.0
	for r in [0.0, 0.5, 0.8, 1.2, 1.8, 2.5]:
		var s := WormJuice.shake_for_ratio(r)
		assert_float(s).is_greater_equal(prev)
		assert_float(s).is_less_equal(WormJuice.SHAKE_CAP)
		prev = s
	assert_float(WormJuice.shake_for_ratio(0.2)).is_equal(0.0)   # crumbs never shake
	assert_float(WormJuice.shake_for_ratio(1.5)).is_greater(WormJuice.shake_for_ratio(1.0))
	assert_float(WormJuice.shake_for_ratio(50.0)).is_equal(WormJuice.SHAKE_CAP)
	# Through a real camera: a bigger bite shakes harder, a huge one stops at the cap.
	var w := _worm()
	var cam := _camera([w])
	WormJuice.bite(w, _food(7.0))
	var mid := cam.shake
	assert_float(mid).is_greater(0.0)
	cam.shake = 0.0
	WormJuice.bite(w, _food(12.0))
	assert_float(cam.shake).is_greater(mid)
	cam.shake = 0.0
	WormJuice.bite(w, _food(500.0))
	assert_float(cam.shake).is_equal(WormJuice.SHAKE_CAP)


func test_shake_is_only_on_the_camera_following_the_eater() -> void:
	var me := _worm(Players.P1)
	var other := _worm(Players.P2, Vector2(400, 0))
	var cam := _camera([other])   # this view follows the other worm
	WormJuice.bite(me, _food(500.0))
	assert_float(cam.shake).is_equal(0.0)
	WormJuice.bite(other, _food(500.0))
	assert_float(cam.shake).is_equal(WormJuice.SHAKE_CAP)


# --- Stage-up flash -------------------------------------------------------------------------------

## Coroutines wake on process_frame before any node's _process in that iteration (checked on
## 4.7.2), so at each wake the worm's materials are what the previous iteration drew.
func test_the_stage_up_flash_is_exactly_two_frames() -> void:
	var w := _worm()
	var head_mat := w.head_sprite.material
	w.model.apex_gate = false
	while w.model.stage < 2:
		w.model.add_segment(&"")   # the real stage_changed path
	var start := Engine.get_process_frames()
	assert_bool(WormJuice.is_flashing(w)).is_true()
	assert_object(w.head_sprite.material).is_same(WormJuice.flash_material())
	var drawn := {}
	for i in 5:
		await get_tree().process_frame
		drawn[Engine.get_process_frames() - 1 - start] = w.head_sprite.material == WormJuice.flash_material()
	assert_dict(drawn).is_equal({ 0: true, 1: true, 2: false, 3: false, 4: false })
	assert_object(w.head_sprite.material).is_same(head_mat)   # the sheen comes back
	for seg in w.body.get_children():
		assert_object((seg as CanvasItem).material).is_not_same(WormJuice.flash_material())
	assert_object(w.get_node_or_null(^"JuiceFlash")).is_null()


func test_the_screen_flash_is_two_frames_too() -> void:
	WormJuice.stage_flash()
	var start := Engine.get_process_frames()
	var drawn := {}
	for i in 4:
		await get_tree().process_frame
		var layer := get_tree().root.get_node_or_null(^"JuiceScreenFlash")
		drawn[Engine.get_process_frames() - 1 - start] = layer != null and not layer.is_queued_for_deletion()
	assert_dict(drawn).is_equal({ 0: true, 1: true, 2: false, 3: false })


# --- Debris ---------------------------------------------------------------------------------------

func test_debris_falls_toward_the_core_not_straight_down() -> void:
	var world := _world(0.6)   # turned, so world-local and screen directions differ too
	var w := _worm()
	w.set_world(world)
	var cs := float(world.shape.cell_size)
	for ang in [0.0, PI * 0.5, PI, -PI * 0.25]:
		WormJuice.clear_cache()   # the per-worm throttle
		var cell := world.shape.cell_at(Vector2.from_angle(ang) * 120.0 * cs)
		var p := WormJuice.tile(w, cell)
		assert_object(p).is_not_null()
		var to_core := (world.global_position - p.global_position).normalized()
		assert_float(p.gravity.normalized().dot(to_core)).is_greater(0.99)
		assert_float(p.gravity.length()).is_equal_approx(WormJuice.DEBRIS_GRAVITY, 0.01)
		assert_vector(p.direction.normalized()).is_equal_approx(-to_core, Vector2.ONE * 0.001)
		assert_that(p.color).is_equal(world.ring_of(cell).hue.darkened(0.15))
	# On the disk's right-hand side (after the turn), "toward the core" is far from screen-down.
	var side := world.shape.cell_at(world.to_local(world.global_position + Vector2(120.0 * cs, 0)))
	WormJuice.clear_cache()
	var q := WormJuice.tile(w, side)
	assert_float(q.gravity.normalized().dot(Vector2.DOWN)).is_less(0.2)
	assert_float(q.gravity.normalized().dot(Vector2.LEFT)).is_greater(0.99)


func test_a_swallowed_tile_drops_crumbs_through_the_hook() -> void:
	var world := _world()
	var w := _worm()
	w.set_world(world)
	var cs := float(world.shape.cell_size)
	var cell := world.shape.cell_at(Vector2(0, -120.0 * cs))
	assert_bool(world.is_solid(cell)).is_true()
	world.eat_tile(cell, w.player)   # World.tile_eaten -> Worm._on_tile_eaten -> WormJuice.tile
	assert_int(_named("JuiceDebris").size()).is_equal(1)


# --- The switch -----------------------------------------------------------------------------------

func test_the_switch_turns_every_effect_off() -> void:
	WormJuice.on = false
	var w := _worm()
	var cam := _camera([w])
	var world := _world()
	w.set_world(world)
	var mod := w.modulate
	var before_n := _named("Juice").size()   # earlier tests' bursts may still be fading
	w.feed(GRUB)
	assert_object(WormJuice.bite(w, _food(500.0))).is_null()
	assert_float(cam.shake).is_equal(0.0)
	assert_object(WormJuice.worm_flash(w)).is_null()
	assert_bool(WormJuice.is_flashing(w)).is_false()
	assert_that(w.modulate).is_equal(mod)
	assert_object(WormJuice.tile(w, world.shape.cell_at(Vector2(0, -120.0 * world.shape.cell_size)))).is_null()
	WormJuice.stage_flash()
	WormJuice.shake(1.0)
	WormJuice.chomp(Vector2.ZERO, Color.RED, 1.0)
	WormJuice.debris(Vector2.ZERO)
	assert_float(cam.shake).is_equal(0.0)
	assert_int(_named("Juice").size()).is_equal(before_n)
	assert_object(get_tree().root.get_node_or_null(^"JuiceScreenFlash")).is_null()
