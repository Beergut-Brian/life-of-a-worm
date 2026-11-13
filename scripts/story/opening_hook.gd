## Y-01: a new bait tin opens on Old Reel's opening (data/cutscenes/opening.json), and the game takes
## its handoff ("follow_worm_underground"):
##   SCENE  the opening plays over the planet; the worms wait still under it (any button skips);
##   GLIDE  the scene fades out on the worms plopping into the dirt, so the planet picks up on the
##          grass above the start and the camera follows them down through the dirt to the worm;
##   HINT   a stick glyph blinks and wiggles over the worm ("you have the stick", no words) until the
##          worm moves or HINT_MAX passes.
## Nothing here moves a worm: during the glide and the hint the player already has the stick.
## Plays once per tin (Story's `story_seen`), and only on a tin that was new when it was opened.
class_name OpeningHook
extends Node2D

enum State { IDLE, SCENE, GLIDE, HINT, DONE }

const SCENE_ID := &"opening"
const HANDOFF := "follow_worm_underground"
## Seconds from the grass down to the worm.
const GLIDE := 3.2
## The stick hint gives up after this long without the worm moving.
const HINT_MAX := 15.0
## The worm has "moved" once its head is this far (px) from where the hint started.
const MOVED_PX := 24.0

## Test suites switch the opening off (SuiteSandbox); the game never does.
static var enabled := true

var level: PlanetLevel
var story: Story
var state := State.IDLE
## The surface point the glide starts from (world px).
var glide_from := Vector2.ZERO
var _t := 0.0
var _held := {}            # Worm -> its own autopilot, while the scene plays
var _hint_from := Vector2.INF
var _blink := 0.0


## Starts the opening on a level whose tin is new. Null when it doesn't play.
static func start(on: PlanetLevel, speed := 1.0) -> OpeningHook:
	if not enabled or on == null:
		return null
	var h := OpeningHook.new()
	h.level = on
	on.add_child(h)
	if not h.begin(speed):
		h.queue_free()
		return null
	return h


func _init() -> void:
	name = "OpeningHook"
	z_index = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin(speed := 1.0) -> bool:
	story = Story.find(get_tree())
	if story == null:
		story = Story.new()
		level.add_child(story)
	if story.has_seen(SCENE_ID):
		state = State.DONE
		return false
	story.speed = speed
	story.handoff.connect(_on_handoff)
	story.finished.connect(_on_finished)
	if not story.play(SCENE_ID):
		state = State.DONE
		return false
	state = State.SCENE
	return true


func _on_handoff(id: StringName, what: String) -> void:
	if id == SCENE_ID and what == HANDOFF:
		glide()


func _on_finished(id: StringName, _skipped: bool) -> void:
	if id == SCENE_ID and state == State.SCENE:
		glide()   # a scene that ended without its handoff call still hands the stick back


## The scene is over: let go of the worms and follow them down from the grass.
func glide() -> void:
	if state != State.SCENE:
		return
	_release()
	state = State.GLIDE
	_t = 0.0
	var w := _worm()
	var cam := level.camera
	var at := w.cam_position() if w != null else level.spawn_point
	glide_from = at.normalized() * float(PlanetLevel.RADIUS * level.world.shape.cell_size) if level.world else at
	cam.fit = false
	cam.zoom_index = cam.max_fit_index
	cam.centre_override = glide_from
	cam.position = glide_from
	cam.rotation = PolarCamera.up_rotation(glide_from)
	Audio.play("round_start")


func _process(delta: float) -> void:
	_blink += delta
	match state:
		State.SCENE:
			for w in Worm.all():
				_hold(w)
		State.GLIDE:
			_t += delta
			var w := _worm()
			var to := w.cam_position() if w != null else level.spawn_point
			var f := smoothstep(0.0, 1.0, minf(_t / GLIDE, 1.0))
			level.camera.centre_override = glide_from.lerp(to, f)
			if _t >= GLIDE:
				level.camera.centre_override = null
				level.camera.fit = true
				state = State.HINT
				_t = 0.0
				_hint_from = to
		State.HINT:
			_t += delta
			var w := _worm()
			if w == null or _t >= HINT_MAX or w.cam_position().distance_to(_hint_from) >= MOVED_PX:
				state = State.DONE
				queue_free()
	queue_redraw()


func _draw() -> void:
	if state != State.HINT:
		return
	var w := _worm()
	if w == null:
		return
	var cam := level.camera
	var s := 1.0 / cam.zoom.x
	draw_set_transform(w.cam_position(), cam.rotation, Vector2(s, s))
	var a := 0.4 + 0.6 * absf(sin(_blink * 4.0))
	var nudge := Vector2(sin(_blink * 6.0) * 14.0, 0)   # the stick wiggling: push me
	var up := Vector2(0, -80)
	draw_circle(up, 34.0, Color(0, 0, 0, 0.35 * a))
	UiStyle.draw_glyph(self, up + nudge, 52.0, "stick", a)
	for sx in [-1.0, 1.0]:                               # little arrows either side
		var tip := up + Vector2(sx * 56.0, 0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-sx * 12.0, -10.0), tip + Vector2(-sx * 12.0, 10.0)]), Color(1, 1, 1, a))


func _exit_tree() -> void:
	_release()
	if level != null and is_instance_valid(level.camera) and state == State.GLIDE:
		level.camera.centre_override = null
		level.camera.fit = true


func _worm() -> Worm:
	var ws := Worm.all()
	for w in ws:
		if w.player == Players.P1:
			return w
	return ws[0] if not ws.is_empty() else null


func _hold(w: Worm) -> void:
	if _held.has(w):
		return
	_held[w] = w.autopilot
	w.autopilot = func(_w) -> Dictionary: return {}


func _release() -> void:
	for w in _held:
		if is_instance_valid(w):
			w.autopilot = _held[w]
	_held.clear()
