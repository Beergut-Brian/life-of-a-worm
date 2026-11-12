## Stage 6, the planet chomp, as one scripted sequence on a fixed planet shot:
## picture + hold A (2 s, release cancels) -> jar snapshot -> one long chomp eating the planet texture
## with a shader mask -> final gulp (white flash 2 frames, planet_gone: gulp, silence, burp) -> space.
## advance(delta, held) drives everything so tests can run it without frames or input.
## --demo-chomp runs it hands-free in a sandbox profile ("demo_chomp") with its own jar shelf.
class_name PlanetChomp
extends Node2D

signal confirm_started()
signal confirm_cancelled()
signal planet_eaten()

enum Phase { IDLE, CONFIRM, JARRING, CHOMP, GONE, FADE, DONE }

const SPACE_SCENE := "res://scenes/levels/space.tscn"
const TEX_SIZE := 288
const PLANET_SCALE := 3.0
const JAR_TIME := 1.1
const CHOMP_TIME := 6.0
const BITES := 14
const BURP_AT := 2.2           # seconds into planet_gone.wav
const GONE_TIME := 3.6
const DEMO_PROFILE := "demo_chomp"
const DEMO_HOLDS := [[1.2, 2.0], [2.8, 6.0]]   # a false start (cancels), then the real hold

@export var autostart := true
@export var auto_space := true

var phase := Phase.IDLE
var planet: PlanetStandIn
var planet_texture: Texture2D
var confirm := HoldConfirm.new()
var demo := false
var jars: JarStore
var chomp_progress := 0.0
var shake := 0.0
var eaten_count := 0
var frame_ms_max := 0.0
var frame_ms_sum := 0.0
var frame_count := 0
var delta_sum := 0.0
var delta_max := 0.0
var texture_ms := 0.0

var _t := 0.0          # time in the current phase
var _clock := 0.0      # time since ready (demo script)
var _bite := 0
var _flash_frames := 0
var _burped := false
var _debris: Array[CPUParticles2D] = []
var _debris_next := 0

@onready var _camera: Camera2D = $Camera
@onready var _planet_sprite: Sprite2D = $Planet
@onready var _worm: GiantWorm = $GiantWorm
@onready var _picture: ConfirmPicture = $Picture
@onready var _jar: Node2D = $Jar
@onready var _flash: ColorRect = $FlashLayer/Flash
@onready var _sfx: ProtoSfx = $Sfx


func _ready() -> void:
	jars = get_node_or_null("Jars") as JarStore
	demo = "--demo-chomp" in OS.get_cmdline_user_args()
	if demo:
		_setup_demo()
	_load_planet()
	for i in 4:
		_debris.append(_make_debris())
	confirm.started.connect(_on_confirm_started)
	confirm.cancelled.connect(_on_confirm_cancelled)
	confirm.confirmed.connect(_on_confirmed)
	_picture.visible = false
	_flash.visible = false
	_worm.orbit = TEX_SIZE * PLANET_SCALE * 0.5 + 50.0
	if autostart and not demo:
		begin()


func _setup_demo() -> void:
	Save.use_profile(DEMO_PROFILE)
	Save.wipe()
	var p := PlanetStandIn.generate("", 4242)
	p.id = "%s_%d" % [DEMO_PROFILE, p.seed_value]
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)
	Save.flush()
	jars.dir = "user://jars_demo"   # never put a demo jar on the family's shelf
	jars.clear()


func _load_planet() -> void:
	var d = Save.get_value("planet", null)
	if d is Dictionary:
		planet = PlanetStandIn.from_save(d)
	else:
		planet = PlanetStandIn.generate("", 1)
	if planet.id == "":
		planet.id = String(JarStore.current_planet_id(int(Save.get_value("seed", planet.seed_value))))
	var t0 := Time.get_ticks_usec()
	planet_texture = planet.texture(TEX_SIZE)
	texture_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_planet_sprite.texture = planet_texture
	_planet_sprite.scale = Vector2.ONE * PLANET_SCALE
	(_planet_sprite.material as ShaderMaterial).set_shader_parameter("tex_px", float(TEX_SIZE))
	_set_progress(0.0)
	_picture.planet_texture = planet_texture
	_jar.set("planet_texture", planet_texture)


## Show the picture and wait for the hold. False if stage 6 is disabled here (inside a jar).
func begin() -> bool:
	if not JarStore.stage6_allowed():
		return false
	if phase != Phase.IDLE:
		return false
	phase = Phase.CONFIRM
	_t = 0.0
	_picture.visible = true
	_picture.scale = Vector2.ZERO
	create_tween().tween_property(_picture, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sfx.play("confirm_yes", 0.7)
	return true


func planet_id() -> StringName:
	return StringName(planet.id)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_clock += delta
	if demo and phase == Phase.IDLE and _clock > 0.6:
		begin()
	advance(delta, _held())
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if phase == Phase.CHOMP or phase == Phase.GONE:
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		frame_ms_max = maxf(frame_ms_max, ms)
		frame_ms_sum += ms
		frame_count += 1
		delta_sum += delta
		delta_max = maxf(delta_max, delta)


func _held() -> bool:
	if demo:
		for h in DEMO_HOLDS:
			if _clock >= h[0] and _clock < h[1]:
				return true
		return false
	return Input.is_action_pressed("p1_action") or Input.is_action_pressed("p2_action")


func advance(delta: float, held: bool) -> void:
	_t += delta
	shake = maxf(0.0, shake - delta * (30.0 + shake * 3.0))
	if _flash_frames > 0:
		_flash_frames -= 1
		_flash.visible = _flash_frames > 0
	match phase:
		Phase.CONFIRM:
			confirm.step(delta, held)
			_picture.progress = confirm.progress
			_picture.holding = confirm.is_holding()
			_worm.mouth_open = confirm.progress * 0.8
		Phase.JARRING:
			_advance_jar()
		Phase.CHOMP:
			_advance_chomp(delta)
		Phase.GONE:
			_advance_gone()
		Phase.FADE:
			pass


func _on_confirm_started() -> void:
	confirm_started.emit()
	_sfx.play("confirm_hold")


func _on_confirm_cancelled() -> void:
	_sfx.stop("confirm_hold")
	_sfx.play("confirm_cancel")
	confirm_cancelled.emit()


func _on_confirmed() -> void:
	_sfx.stop("confirm_hold")
	_sfx.play("confirm_yes")
	var path := jars.snapshot(planet_id()) if jars else ""
	if path == "":
		push_warning("PlanetChomp: no jar, no chomp")   # nothing built is ever lost
		confirm = _fresh_confirm()
		return
	phase = Phase.JARRING
	_t = 0.0
	var tw := create_tween()
	tw.tween_property(_picture, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_jar.call("fly_in", global_position, PLANET_SCALE * TEX_SIZE, JAR_TIME * 0.8)


func _fresh_confirm() -> HoldConfirm:
	var c := HoldConfirm.new()
	c.started.connect(_on_confirm_started)
	c.cancelled.connect(_on_confirm_cancelled)
	c.confirmed.connect(_on_confirmed)
	return c


func _advance_jar() -> void:
	_worm.mouth_open = 0.8
	if _t >= JAR_TIME:
		_picture.visible = false
		phase = Phase.CHOMP
		_t = 0.0
		_bite = 0


func _advance_chomp(delta: float) -> void:
	var per := CHOMP_TIME / BITES
	while _bite < BITES and _t >= _bite * per:
		_do_bite(_bite)
		_bite += 1
	var target := float(_bite) / BITES
	_set_progress(move_toward(chomp_progress, target, delta * 2.5 / CHOMP_TIME))
	# jaw: snaps shut on each bite, opens wide before the next
	var k := fmod(_t, per) / per
	_worm.mouth_open = 1.0 - exp(-k * 4.0) if k > 0.15 else 0.1
	_worm.squash = maxf(0.0, 1.0 - k * 5.0)
	_worm.head_angle = -PI / 2.0 + chomp_progress * TAU + 0.18
	_worm.orbit = lerpf(TEX_SIZE * PLANET_SCALE * 0.5 + 50.0, TEX_SIZE * PLANET_SCALE * 0.5 - 40.0, minf(1.0, _t * 2.0))
	_worm.belly = chomp_progress * 0.6
	if _t >= CHOMP_TIME + per * 0.6:
		_gulp()


func _do_bite(i: int) -> void:
	var size := 0.5 + 0.5 * float(i) / BITES      # bites get bigger as the planet goes
	shake = maxf(shake, 6.0 + 22.0 * size)
	_sfx.play("chomp_bite", randf_range(1.15, 0.85) - size * 0.2)
	var e := _debris[_debris_next]
	_debris_next = (_debris_next + 1) % _debris.size()
	e.position = _worm.mouth_position()
	e.direction = _worm.head_position().normalized()
	e.amount = int(24 + 40 * size)
	e.restart()


func _gulp() -> void:
	_set_progress(1.0)
	_planet_sprite.visible = false
	phase = Phase.GONE
	_t = 0.0
	_flash_frames = 2       # this frame and the next: exactly 2 frames
	_flash.visible = true
	shake = 48.0
	_worm.mouth_open = 0.0
	_worm.belly = 1.0
	_sfx.play("planet_gone")
	if eaten_count == 0:
		eaten_count += 1
		Save.set_value("stage", 7)
		Save.set_value("planet", null)
		Save.set_value("planet_eaten", true)
		Save.flush()
		planet_eaten.emit()


func _advance_gone() -> void:
	# huge gulp, then silence (nothing moves but the belly sliding down), then a tiny burp
	_worm.belly_at = lerpf(0.35, 0.8, minf(1.0, _t / BURP_AT))
	_worm.orbit = lerpf(_worm.orbit, 150.0, 0.03)
	_worm.head_angle += 0.004
	_worm.eye_closed = clampf((_t - 0.8) * 2.0, 0.0, 1.0) if _t < BURP_AT else 0.0
	if not _burped and _t >= BURP_AT:
		_burped = true
		_worm.mouth_open = 0.5
		_worm.belly = 0.25
		var tw := create_tween()
		tw.tween_property(_worm, "scale", Vector2.ONE * 1.08, 0.08)
		tw.tween_property(_worm, "scale", Vector2.ONE, 0.2)
		tw.tween_property(_worm, "mouth_open", 0.0, 0.3)
	if _t >= GONE_TIME:
		phase = Phase.FADE if auto_space else Phase.DONE
		if auto_space:
			_cross_fade()


func _set_progress(p: float) -> void:
	chomp_progress = clampf(p, 0.0, 1.0)
	(_planet_sprite.material as ShaderMaterial).set_shader_parameter("progress", chomp_progress)


## Hold the last frame over the space scene and fade it out.
func _cross_fade() -> void:
	if frame_count > 0:
		print("chomp: %d frames, frame ms avg %.1f max %.1f, script ms avg %.3f max %.3f, texture %dx%d built in %.0f ms" % [
			frame_count, delta_sum * 1000.0 / frame_count, delta_max * 1000.0, frame_ms_sum / frame_count,
			frame_ms_max, TEX_SIZE, TEX_SIZE, texture_ms])
	var tree := get_tree()
	var layer := CanvasLayer.new()
	layer.layer = 60
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(img)
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		tree.root.add_child(layer)
		var tw := layer.create_tween()
		tw.tween_interval(0.15)
		tw.tween_property(rect, "modulate:a", 0.0, 1.1)
		tw.tween_callback(layer.queue_free)
	else:
		layer.free()
	tree.change_scene_to_file(SPACE_SCENE)


func _make_debris() -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.one_shot = true
	e.emitting = false
	e.explosiveness = 0.85
	e.lifetime = 1.3
	e.spread = 70.0
	e.gravity = Vector2.ZERO
	e.initial_velocity_min = 180.0
	e.initial_velocity_max = 620.0
	e.damping_min = 120.0
	e.damping_max = 260.0
	e.angular_velocity_min = -360.0
	e.angular_velocity_max = 360.0
	e.scale_amount_min = 7.0
	e.scale_amount_max = 18.0
	var g := Gradient.new()
	var cols := planet.ring_colors()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray(cols)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	e.color_initial_ramp = g
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	e.color_ramp = fade
	e.z_index = 2
	add_child(e)
	return e
