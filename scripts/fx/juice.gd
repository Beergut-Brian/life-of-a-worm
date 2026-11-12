## Juice (A-14, docs/art-direction.md): every lane calls these, nobody builds its own.
##   Juice.chomp(pos, colour, size)  crumbs in the food's colour burst from the mouth
##   Juice.shake(strength)           camera shake (0..1), scaled by the caller to the bite
##   Juice.stage_flash()             the stage-up: the screen whites out for exactly two frames
##   Juice.debris(pos)               bits of ground that tumble down toward the planet's core
## Positions are global. Particles live under `Juice.host` (LookDirector sets the planet; else the
## current scene) and fall toward `Juice.core` (global). Pooled: at most POOL emitters exist.
class_name Juice
extends RefCounted

const CHUNK := preload("res://assets/sprites/fx/chunk.png")
const DEBRIS := preload("res://assets/sprites/fx/debris.png")
const POOL := 12
const FALL := 240.0

static var host: Node
static var core := Vector2.ZERO
## Counters for tests and the report.
static var chomps := 0
static var flashes := 0
static var shakes := 0
static var _pool: Array[CPUParticles2D] = []
static var _next := 0
static var _flash: CanvasLayer


static func _host() -> Node:
	if host != null and is_instance_valid(host) and host.is_inside_tree():
		return host
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null


static func _emitter() -> CPUParticles2D:
	var h := _host()
	if h == null:
		return null
	var live := _pool.filter(func(p) -> bool: return is_instance_valid(p) and p.get_parent() == h)
	_pool.assign(live)
	var p: CPUParticles2D
	if _pool.size() < POOL:
		p = CPUParticles2D.new()
		p.name = "Juice%d" % _pool.size()
		p.one_shot = true
		p.emitting = false
		p.local_coords = false
		p.explosiveness = 0.92
		p.z_index = 6
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.add_child(p)
		_pool.append(p)
	else:
		p = _pool[_next % _pool.size()]
		_next += 1
	return p


static func _down(pos: Vector2) -> Vector2:
	var d := core - pos
	return d.normalized() if d.length_squared() > 1.0 else Vector2.DOWN


## Crumbs in the food's colour, more and faster for a bigger bite (size: 1 = a stage-1 mouthful).
static func chomp(pos: Vector2, colour: Color, size := 1.0) -> CPUParticles2D:
	var p := _emitter()
	if p == null:
		return null
	chomps += 1
	var k := clampf(size, 0.3, 4.0)
	var down := _down(pos)
	p.global_position = pos
	p.texture = CHUNK
	p.amount = clampi(roundi(6 + 6 * k), 4, 32)
	p.lifetime = 0.45 + 0.1 * k
	p.direction = -down
	p.spread = 80.0
	p.initial_velocity_min = 40.0 + 15.0 * k
	p.initial_velocity_max = 90.0 + 35.0 * k
	p.gravity = down * FALL
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0 + 0.35 * k
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.color = colour
	p.color_ramp = _fade(colour)
	p.restart()
	return p


## Bits of ground tumbling toward the core (they fall "down" wherever you are on the disk).
static func debris(pos: Vector2, colour := Color(0.42, 0.28, 0.17), amount := 6) -> CPUParticles2D:
	var p := _emitter()
	if p == null:
		return null
	var down := _down(pos)
	p.global_position = pos
	p.texture = DEBRIS
	p.amount = clampi(amount, 1, 24)
	p.lifetime = 1.1
	p.direction = -down
	p.spread = 50.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 45.0
	p.gravity = down * FALL * 1.4
	p.damping_min = 0.0
	p.damping_max = 5.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.color = colour
	p.color_ramp = _fade(colour)
	p.restart()
	return p


static func _fade(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c.lightened(0.15))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	g.add_point(0.7, c)
	return g


## Camera shake, 0..1 (1 = the stage-up). Off when the player turned shake off in Settings.
static func shake(strength: float) -> void:
	shakes += 1
	if not SettingsPanel.screen_shake():
		return
	var h := _host()
	if h == null or h.get_viewport() == null:
		return
	var cam := h.get_viewport().get_camera_2d()
	if cam and &"shake" in cam:
		cam.shake = maxf(float(cam.shake), clampf(strength, 0.0, 1.0))


## The stage-up flash: the whole screen white for exactly two rendered frames.
static func stage_flash() -> void:
	flashes += 1
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _flash == null or not is_instance_valid(_flash):
		_flash = _Flash.new()
		tree.root.add_child(_flash)
	(_flash as _Flash).frames = 2


static func flash_visible() -> bool:
	return _flash != null and is_instance_valid(_flash) and (_flash as _Flash).rect.visible


class _Flash extends CanvasLayer:
	var rect := ColorRect.new()
	var frames := 0

	func _init() -> void:
		name = "JuiceFlash"
		layer = 120
		process_mode = Node.PROCESS_MODE_ALWAYS
		rect.color = Color.WHITE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.visible = false
		add_child(rect)

	func _process(_delta: float) -> void:
		rect.visible = frames > 0
		if frames > 0:
			frames -= 1
