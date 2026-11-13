## Juice (A-14): the feel of a bite and a stage-up. Code only, placeholder particles, no art or cues.
##   bite(worm, food)        a burst of specks in the food's colour (FoodData.color), more for bigger
##                           bites, and a camera nudge scaled to the bite (food radius against the
##                           worm's head), capped, on the camera that follows that worm only
##   tile(worm, cell)        crumbs in the ring's colour that fall toward the core (the world's own
##                           gravity_at, never a fixed down), throttled so tunnelling stays calm
##   worm_flash(worm)        the stage-up: the worm draws white for exactly two drawn frames
##                           (a shared white material lent to each drawn part, then given back)
## The WormHooks API (chomp, shake, stage_flash, debris) is here too with the stub's signatures, so
## WormHooks.JUICE_PATH can point at this file (see docs/contracts.md, Juice (worm-juice-1)).
## One switch turns everything off for a slow GPU: ENABLED (tests flip `on`, which starts from it).
class_name WormJuice
extends RefCounted

## The single switch. false = no particles, no shake, no flash anywhere.
const ENABLED := true

# Chomp burst (food bites).
const CHOMP_SPECKS_MIN := 3          # a tiny bite
const CHOMP_SPECKS_MAX := 22         # a bite as big as the worm's head or bigger
const CHOMP_LIFE := 0.35             # seconds a speck lives
const CHOMP_SPEED_MIN := 40.0        # px/s
const CHOMP_SPEED_MAX := 130.0
const CHOMP_SPECK_PX := Vector2(1.5, 3.0)   # speck scale range (CPUParticles2D quads, px)
const BURST_Z := 30

# Shake (food bites). ratio = food radius / worm head radius.
const SHAKE_FROM_RATIO := 0.5        # smaller bites than this never shake
const SHAKE_PER_RATIO := 0.18        # strength per ratio above SHAKE_FROM_RATIO
const SHAKE_CAP := 0.3               # PolarCamera.shake units (x24 px / zoom): about 7 px on screen
const BEAT_SHAKE_CAP := 1.0          # the hooks API (stage-up, crust burst) may ask for more

# Debris (tiles).
const DEBRIS_EVERY := 0.12           # seconds between crumb puffs per worm while tunnelling
const DEBRIS_AMOUNT := 6
const DEBRIS_LIFE := 0.6
const DEBRIS_GRAVITY := 420.0        # px/s^2 toward the core
const DEBRIS_KICK := Vector2(20.0, 60.0)   # initial speed range, thrown away from the core
const DEBRIS_SPREAD := 55.0          # degrees round "up"
const DEBRIS_COLOUR := Color(0.55, 0.38, 0.2)   # only when the cell has no ring

# Stage-up flash.
const FLASH_FRAMES := 2              # drawn frames, at any frame rate
const FLASH_COLOUR := Color(1, 1, 1)             # every drawn pixel of the worm, alpha kept
const FLASH_SHADER := "shader_type canvas_item;\nuniform vec4 flash : source_color = vec4(1.0);\nvoid fragment() { COLOR = vec4(flash.rgb, COLOR.a); }\n"
static var _flash_mat: ShaderMaterial


## The white material the flash lends every drawn part of the worm (one, shared).
static func flash_material() -> ShaderMaterial:
	if _flash_mat == null:
		var sh := Shader.new()
		sh.code = FLASH_SHADER
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = sh
		_flash_mat.set_shader_parameter(&"flash", FLASH_COLOUR)
	return _flash_mat


## True while this worm (or screen layer) is mid-flash.
static func is_flashing(worm: Node) -> bool:
	var f := worm.get_node_or_null(^"JuiceFlash") if worm != null else null
	return f != null and not f.is_queued_for_deletion()

## Runtime copy of ENABLED (tests and a settings toggle may flip it).
static var on := ENABLED
## What was asked for, in order: [fn, args] (the stub's format, tests read it).
static var calls: Array = []
static var _last_debris := {}        # worm instance id -> msec of its last crumb puff


## Kept short so hours of play never grow it.
const CALLS_KEPT := 64


static func _log(fn: String, args: Array) -> void:
	calls.append([fn, args])
	if calls.size() > CALLS_KEPT:
		calls.pop_front()


static func clear_cache() -> void:
	calls.clear()
	_last_debris.clear()
	_flash_mat = null   # no shader left in use at exit


# --- Per-worm hooks (scripts/worm/worm.gd calls these) -------------------------------------------

## The food's size against the worm's: food radius / the head's collision radius (px / px).
static func bite_ratio(worm: Node, food: FoodData) -> float:
	var head_r := 8.0
	if worm != null and "model" in worm and worm.model != null:
		head_r = maxf(1.0, float(worm.model.stage_info().collision_radius))
	return food.radius / head_r


## Shake strength for a bite of this ratio: 0 under SHAKE_FROM_RATIO, then linear, capped.
static func shake_for_ratio(ratio: float) -> float:
	return clampf((ratio - SHAKE_FROM_RATIO) * SHAKE_PER_RATIO, 0.0, SHAKE_CAP)


## Specks for a bite of this ratio: a few for crumbs, more for big bites.
static func specks_for_ratio(ratio: float) -> int:
	return int(round(lerpf(CHOMP_SPECKS_MIN, CHOMP_SPECKS_MAX, clampf(ratio, 0.0, 1.0))))


## A food bite: burst in the food's colour at the mouth, shake on this worm's camera.
static func bite(worm: Node2D, food: FoodData) -> CPUParticles2D:
	_log("bite", [food.id])
	if not on or worm == null or not worm.is_inside_tree():
		return null
	var ratio := bite_ratio(worm, food)
	var at: Vector2 = worm.call("mouth_position") if worm.has_method("mouth_position") else worm.global_position
	var p := _burst(worm, at, food.color, specks_for_ratio(ratio))
	shake_worm(worm, shake_for_ratio(ratio))
	return p


## Shake the camera that follows this worm, and no other (split screen, the other player's view).
static func shake_worm(worm: Node, strength: float) -> Camera2D:
	if not on or strength <= 0.0 or worm == null or not worm.is_inside_tree():
		return null
	if not SettingsPanel.screen_shake():
		return null
	var cam := worm.get_viewport().get_camera_2d()
	if cam == null or not "shake" in cam:
		return null
	if "targets" in cam and not (cam.get("targets") as Array).has(worm):
		return null   # this camera follows someone else
	cam.set("shake", maxf(float(cam.get("shake")), minf(strength, SHAKE_CAP)))
	return cam


## A tile swallowed: crumbs in the ring's colour falling toward the core (throttled per worm).
static func tile(worm: Node2D, cell: Vector2i) -> CPUParticles2D:
	if not on or worm == null or not worm.is_inside_tree():
		return null
	var world = worm.get("world")
	if world == null:
		return null
	var now := Time.get_ticks_msec()
	var key := worm.get_instance_id()
	if now - int(_last_debris.get(key, -100000)) < int(DEBRIS_EVERY * 1000.0):
		return null
	_last_debris[key] = now
	var cs := float(world.shape.cell_size)
	var local := (Vector2(cell) + Vector2(0.5, 0.5)) * cs
	var ring = world.ring_of(cell)
	var col: Color = ring.hue if ring != null else DEBRIS_COLOUR
	return _debris_at(worm, world, world.to_global(local), col)


## The world's own gravity at a global position, as a global direction (unit, or zero).
static func fall_direction(world: Node2D, global_pos: Vector2) -> Vector2:
	if world == null or not "shape" in world or world.shape == null:
		return Vector2.ZERO
	var g: Vector2 = world.shape.gravity_at(world.to_local(global_pos))
	return world.global_transform.basis_xform(g).normalized()


## The stage-up: the worm white for exactly FLASH_FRAMES drawn frames, then its own materials back.
static func worm_flash(worm: CanvasItem) -> Node:
	_log("worm_flash", [])
	if not on or worm == null or not worm.is_inside_tree():
		return null
	var old := worm.get_node_or_null(^"JuiceFlash")
	if old != null:
		old.call("restart")
		return old
	var f := _Flash.new()
	f.name = "JuiceFlash"
	f.target = worm
	worm.add_child(f)
	return f


# --- WormHooks API (stage beat, crust burst, props, loose fall) ----------------------------------

static func chomp(pos: Vector2, colour: Color, size: float) -> void:
	_log("chomp", [pos, colour, size])
	if not on:
		return
	var host := _world_host()
	if host != null:
		_burst(host, pos, colour, specks_for_ratio(size))


static func shake(strength: float) -> void:
	_log("shake", [strength])
	if not on or not SettingsPanel.screen_shake():
		return
	var tree := Engine.get_main_loop() as SceneTree
	var cam := tree.root.get_camera_2d() if tree else null
	if cam != null and "shake" in cam:
		cam.set("shake", maxf(float(cam.get("shake")), minf(strength, BEAT_SHAKE_CAP)))


## Whole screen white for exactly FLASH_FRAMES drawn frames (the stage-up beat).
static func stage_flash() -> void:
	_log("stage_flash", [])
	if not on:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "JuiceScreenFlash"
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0.9)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var f := _Flash.new()
	f.free_target = true
	f.target = layer
	layer.add_child(f)
	tree.root.add_child(layer)


static func debris(pos: Vector2) -> void:
	_log("debris", [pos])
	if not on:
		return
	var host := _world_host()
	if host == null:
		return
	var world: Node2D = null
	for w in Worm.all():
		if w.world != null:
			world = w.world
			break
	_debris_at(host, world, pos, DEBRIS_COLOUR)


# --- Internals ------------------------------------------------------------------------------------

static func _burst(near: Node, at: Vector2, colour: Color, amount: int) -> CPUParticles2D:
	var host := _host_for(near)
	if host == null:
		return null
	var p := CPUParticles2D.new()
	p.name = "JuiceBurst"
	p.one_shot = true
	p.amount = maxi(1, amount)
	p.lifetime = CHOMP_LIFE
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = CHOMP_SPEED_MIN
	p.initial_velocity_max = CHOMP_SPEED_MAX
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = CHOMP_SPECK_PX.x
	p.scale_amount_max = CHOMP_SPECK_PX.y
	p.color = colour
	p.z_index = BURST_Z
	_launch(host, p, at)
	return p


static func _debris_at(near: Node, world: Node2D, at: Vector2, colour: Color) -> CPUParticles2D:
	var host := _host_for(near)
	if host == null:
		return null
	var down := fall_direction(world, at)
	if down == Vector2.ZERO and world != null:
		down = (world.global_position - at).normalized()   # at the core itself: just inward
	var p := CPUParticles2D.new()
	p.name = "JuiceDebris"
	p.one_shot = true
	p.amount = DEBRIS_AMOUNT
	p.lifetime = DEBRIS_LIFE
	p.explosiveness = 0.9
	p.direction = -down if down != Vector2.ZERO else Vector2.UP
	p.spread = DEBRIS_SPREAD
	p.initial_velocity_min = DEBRIS_KICK.x
	p.initial_velocity_max = DEBRIS_KICK.y
	p.gravity = down * DEBRIS_GRAVITY
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = colour.darkened(0.15)
	p.z_index = BURST_Z
	_launch(host, p, at)
	return p


## Particles live in global space (local_coords off), so the rotating camera or a moving worm never
## drags them; they free themselves when done, with a timer as a backstop (headless, paused).
static func _launch(host: Node, p: CPUParticles2D, at: Vector2) -> void:
	p.local_coords = false
	host.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	var id := p.get_instance_id()
	var t := host.get_tree().create_timer(p.lifetime + 0.25, false)
	t.timeout.connect(func() -> void:
		var o := instance_from_id(id)
		if o != null and not o.is_queued_for_deletion():
			o.queue_free())


## Effects go next to the worm (its parent is the world's actors layer), never inside it, so a
## stage-up swell or warp does not carry them.
static func _host_for(near: Node) -> Node:
	if near == null or not near.is_inside_tree():
		return null
	if near is Worm and near.get_parent() != null:
		return near.get_parent()
	return near


static func _world_host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## Holds a CanvasItem white (or a screen layer up) for FLASH_FRAMES drawn frames, then clears.
## Frame counting: Engine.get_process_frames() is the same through one main-loop iteration
## (physics, then process, then the draw) and steps after it. The flash starts in iteration S, so
## S and S+1 draw white; the _process of S + FLASH_FRAMES clears it before that frame draws. That
## holds whether the stage-up came from physics (a bite) or from process, at any frame rate.
class _Flash extends Node:
	var target: Node
	var free_target := false
	var start_frame := 0
	var _saved := {}      # CanvasItem -> its own material, given back on clear
	var _mat: ShaderMaterial

	func _enter_tree() -> void:
		start_frame = Engine.get_process_frames()
		process_priority = -100   # before anything else this frame
		if not free_target and target is CanvasItem:
			_whiten(target)

	## Every drawn part of the worm (sprites, segments, face, parts) draws white; particles,
	## lights and other Juice nodes keep their look.
	func _whiten(n: Node) -> void:
		if n is CanvasItem and not (n is CPUParticles2D or n is GPUParticles2D or n is Light2D) \
				and not String(n.name).begins_with("Juice"):
			var ci := n as CanvasItem
			if _mat == null:
				_mat = WormJuice.flash_material()
			_saved[ci] = ci.material
			ci.material = _mat
		for c in n.get_children():
			if not (c is CPUParticles2D or c is GPUParticles2D):
				_whiten(c)

	## A second stage-up while white: keep white for FLASH_FRAMES from now.
	func restart() -> void:
		start_frame = Engine.get_process_frames()

	func frames_shown() -> int:
		return Engine.get_process_frames() - start_frame

	func _process(_delta: float) -> void:
		if frames_shown() >= FLASH_FRAMES:
			clear()

	func clear() -> void:
		set_process(false)
		if free_target:
			if is_instance_valid(target):
				target.queue_free()
			return
		for ci in _saved:
			if is_instance_valid(ci) and ci.material == _mat:
				ci.material = _saved[ci]
		_saved.clear()
		queue_free()

	func _exit_tree() -> void:
		if not _saved.is_empty():   # freed early (worm gone, level change): never leave it white
			for ci in _saved:
				if is_instance_valid(ci) and ci.material == _mat:
					ci.material = _saved[ci]
			_saved.clear()
