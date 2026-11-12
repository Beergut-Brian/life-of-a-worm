## The stage-up beat (S-03): the biggest sound and picture in the slice. On a worm's stage_changed:
##   t = 0     the stage_up sting, white flash, screen shake, a chomp burst and dirt debris (Juice);
##             the worm swells head to tail; the camera's zoom cap drops to the new stage's step
##             (data/stages.tres), so the shared camera pulls back one whole-pixel step at a time;
##   t = 0     the "why" picture pops over the worm: the apex creature it ate + the body it grew,
##             the one that finished it bouncing; no words;
##   t = 0.5   the ring that opens at this stage (StageData.opens_ring) pulses round the planet:
##             that is the new food;
##   t = 1.6   the stage's dock cutscene (Story, once per tin; story scenes are the story lane's).
## Every number is in data/stages.tres or here; the level only connects and saves.
class_name StageBeat
extends Node2D

signal beat(player: int, from: int, to: int, cause: StringName)

const WHY_LIFE := 1.6
const RING_DELAY := 0.5
const RING_LIFE := 2.4
const STORY_DELAY := 1.6
const SWELL := 2.2

var camera: PolarCamera
var world: PolarWorld
## Make a Story node when the tree has none (off in tests that only check the beat).
var make_story := true
## Every beat played: {player, from, to, cause, zoom_cap, ring}.
var history: Array[Dictionary] = []

var _rings: Array[Dictionary] = []   # {radius, color, t}


func _init() -> void:
	name = "StageBeat"
	z_index = 40


## Hook a worm: its stage-ups play the beat.
func watch(w: Worm) -> void:
	if not w.stage_changed.is_connected(_on_stage_changed):
		w.stage_changed.connect(_on_stage_changed)


func _on_stage_changed(player: int, from: int, to: int) -> void:
	var w := Worm.of(player)
	if w != null and to > from:
		play(w, from, to)


func play(w: Worm, from: int, to: int) -> void:
	var rules := w.model.rules
	var info := rules.stage_info(to)
	var cause := w.model.last_cause
	var juice := WormHooks.juice()
	var at := w.head_position()
	var col: Color = Players.COLOR[w.player]
	juice.stage_flash()
	juice.shake(1.0)
	juice.chomp(at, col, 3.0)
	juice.debris(at)
	w.swell(SWELL)
	var cap := zoom_cap()
	if camera != null:
		camera.max_fit_index = cap
	var why := StageWhy.new()
	why.worm = w
	why.cause = cause
	why.segments = rules.stage_segments[to]
	why.color = col
	why.life = WHY_LIFE
	get_parent().add_child(why) if get_parent() else add_child(why)
	var ring := _ring_radius(info.opens_ring)
	if ring > 0.0:
		var t := get_tree().create_timer(RING_DELAY, false) if is_inside_tree() else null
		var entry := { "radius": ring, "color": _ring_color(info.opens_ring), "t": -RING_DELAY }
		_rings.append(entry)
		if t:
			t.timeout.connect(func() -> void: Audio.play("ring_open"))
	history.append({ "player": w.player, "from": from, "to": to, "cause": cause, "zoom_cap": cap, "ring": info.opens_ring })
	beat.emit(w.player, from, to, cause)
	if is_inside_tree():
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = STORY_DELAY
		timer.timeout.connect(_story.bind(w.player, from, to))
		timer.timeout.connect(timer.queue_free)
		add_child(timer)
		timer.start()


## The camera's zoom cap: the biggest worm's stage row decides (data/stages.tres).
func zoom_cap() -> int:
	var s := 1
	var rules := WormRules.default_rules()
	for w in Worm.all():
		s = maxi(s, w.model.stage)
		rules = w.model.rules
	return rules.stage_info(s).zoom_index


func _story(player: int, from: int, to: int) -> void:
	var story := Story.find(get_tree())
	if story == null and make_story:
		story = Story.new()
		get_parent().add_child(story)
	if story != null:
		story.on_stage_changed(player, from, to)


func _ring_radius(id: StringName) -> float:
	if world == null or world.rings == null or id == &"":
		return 0.0
	var inner := 0.0
	for r in world.rings.rings:
		if r.id == id:
			return inner * world.shape.radius * world.shape.cell_size
		inner = r.outer
	return 0.0


func _ring_color(id: StringName) -> Color:
	for r in world.rings.rings:
		if r.id == id:
			return r.hue.lightened(0.55)
	return Color.WHITE


func _process(delta: float) -> void:
	if _rings.is_empty():
		return
	for e in _rings:
		e.t += delta
	_rings = _rings.filter(func(e: Dictionary) -> bool: return e.t < RING_LIFE)
	queue_redraw()


## The opened ring's edge glows: three bright pulses running round the whole planet.
func _draw() -> void:
	var px := 1.0 / (camera.zoom.x if camera else 1.0)
	for e in _rings:
		if e.t < 0.0:
			continue
		var k: float = e.t / RING_LIFE
		var pulse := 0.5 + 0.5 * sin(e.t * TAU * 1.25)
		var c: Color = e.color
		c.a = (1.0 - k) * (0.45 + 0.55 * pulse)
		draw_arc(Vector2.ZERO, e.radius, 0.0, TAU, 720, c, (6.0 + 6.0 * pulse) * px)
		var glow := c
		glow.a *= 0.35
		draw_arc(Vector2.ZERO, e.radius, 0.0, TAU, 720, glow, 22.0 * px)
		# sparkles running round the edge
		for i in 48:
			var a: float = TAU * i / 48.0 + e.t * 0.8
			draw_circle(Vector2.from_angle(a) * e.radius, (3.0 + 2.0 * pulse) * px, Color(1, 1, 1, c.a))
