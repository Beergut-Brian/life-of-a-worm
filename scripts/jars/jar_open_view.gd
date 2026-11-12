## Opening a jar from Old Reel's shelf, shown not told: the jar sits on the shelf with its planet inside
## (the jar's own planet picture, or a disk in the planet's colours), the lid pops off, the view dives
## into the glass until the planet fills the screen, and only then JarStore.open() loads it.
## No words. A sound on every beat. Nothing is asked of the player and nothing moves the worm.
## advance(delta) drives it so tests run it without frames; _process calls it.
## --jar-open-demo (scenes/jars/jar_open.tscn alone) stages a sandbox jar for frames.
class_name JarOpenView
extends Node2D

signal entered(planet_id: StringName)

const OUTLINE := Color("2a1a14")
const WALL := Color("3b2a22")
const PLANET_PX := 92.0       # the planet's size inside the jar, as jar_view.gd draws it
const PLANET_AT := Vector2(0, 12)
const SHELF_SCALE := 2.2      # the shelf drawn at jar_view.gd's size x2.2 so the jar reads on a TV
const SETTLE := 0.45          # the jar pops onto the shelf
const LID_AT := 0.8           # the lid pops off
const DIVE_AT := 1.15         # the view starts diving into the glass
const ENTER_AT := 2.4         # the planet fills the screen: open the jar
const DEMO_PROFILE := "demo_jar_open"
const DEMO_DIR := "user://jars_demo_open"

## Where to go once the jar is open ("" = stay; the host listens to `entered`).
@export var next_scene := ""

var jars: JarStore
var planet_id: StringName = &""
var planet_texture: Texture2D
var planet_color := Color("5fb04a")
var t := -1.0                 # -1 idle, else seconds since show_jar()
var opened := false
var demo := false
var _beats := 0


func _ready() -> void:
	position = get_viewport_rect().size / 2.0
	demo = "--jar-open-demo" in OS.get_cmdline_user_args()
	if demo:
		_setup_demo()


## Start the opening for one jar on the shelf. False if there is no such jar.
func show_jar(store: JarStore, id: StringName) -> bool:
	var data := store.peek(id) if store else {}
	if data.is_empty():
		return false
	jars = store
	planet_id = id
	var p = data.get("planet", null)
	var stand := PlanetStandIn.from_save(p if p is Dictionary else {})
	if stand.seed_value == 0:
		stand.seed_value = int(data.get("seed", 0))
	planet_color = stand.ring_colors()[1]
	planet_texture = stand.texture(192) if p is Dictionary else null
	t = 0.0
	opened = false
	_beats = 0
	scale = Vector2.ONE
	return true


func _process(delta: float) -> void:
	if t >= 0.0:
		advance(delta)
	queue_redraw()


func advance(delta: float) -> void:
	if t < 0.0 or opened:
		return
	t += delta
	if _beats == 0:
		_beats = 1
		Audio.play("jar_clink")          # the jar lands on the shelf
	if _beats == 1 and t >= LID_AT:
		_beats = 2
		Audio.play("burst")              # the lid pops (no jar_open file yet: reuse burst)
	if _beats == 2 and t >= DIVE_AT:
		_beats = 3
		Audio.play("tunnel")             # the dive into the glass (no jar_enter file yet: reuse tunnel)
	if t >= ENTER_AT:
		opened = true
		jars.open(planet_id)
		entered.emit(planet_id)
		if demo:
			return
		if next_scene != "":
			get_tree().change_scene_to_file(next_scene)


## 0 on the shelf .. 1 the planet fills the screen.
func dive() -> float:
	if t < DIVE_AT:
		return 0.0
	var k := clampf((t - DIVE_AT) / (ENTER_AT - DIVE_AT), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _draw() -> void:
	var half := get_viewport_rect().size / 2.0
	draw_rect(Rect2(-half, half * 2.0), WALL)
	if t < 0.0:
		return
	var s := _s()
	draw_set_transform(-PLANET_AT * s, 0.0, Vector2.ONE * s)
	# shelf plank and the other jars' silhouettes either side
	draw_rect(Rect2(-260, 78, 520, 22), OUTLINE)
	draw_rect(Rect2(-254, 80, 508, 14), Color("a86b3c"))
	for x in [-190.0, 190.0]:
		var sb_other := StyleBoxFlat.new()
		sb_other.bg_color = Color(0.75, 0.9, 1.0, 0.12)
		sb_other.border_color = Color(0.9, 0.96, 1.0, 0.35)
		sb_other.set_border_width_all(5)
		sb_other.set_corner_radius_all(20)
		draw_style_box(sb_other, Rect2(x - 40, -10, 80, 88))
	# glass behind, the planet inside turning slowly, the rim in front; the glass fades as the view
	# goes in, so the planet is all that is left
	var glass := 1.0 - dive()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.9, 1.0, 0.18 * glass)
	sb.set_corner_radius_all(28)
	draw_style_box(sb, Rect2(-62, -60, 124, 138))
	_draw_planet(PLANET_AT, PLANET_PX, t * 0.4)
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = Color(0.91, 0.96, 1.0, glass)
	rim.set_border_width_all(6)
	rim.set_corner_radius_all(28)
	draw_style_box(rim, Rect2(-62, -60, 124, 138))
	draw_line(Vector2(-40, -40), Vector2(-40, 40), Color(1, 1, 1, 0.6 * glass), 6.0)
	# lid: on, then off up and away with a spin
	var lid_k := clampf((t - LID_AT) / 0.5, 0.0, 1.0)
	var lid_c := Vector2(0, -71) + Vector2(140.0 * lid_k, -260.0 * lid_k + 120.0 * lid_k * lid_k)
	draw_set_transform((lid_c - PLANET_AT) * s, lid_k * 1.6, Vector2.ONE * s)
	draw_rect(Rect2(-56, -15, 112, 30), Color(OUTLINE, glass))
	draw_rect(Rect2(-50, -11, 100, 22), Color(Color("c9a23a"), glass))
	draw_set_transform(Vector2.ZERO)


func _draw_planet(c: Vector2, size: float, angle: float) -> void:
	draw_set_transform(-PLANET_AT * _s() + c * _s(), angle, Vector2.ONE * _s())
	if planet_texture:
		draw_texture_rect(planet_texture, Rect2(-Vector2(size, size) / 2.0, Vector2(size, size)), false)
	else:
		draw_circle(Vector2.ZERO, size / 2.0 + 3.0, OUTLINE)
		draw_circle(Vector2.ZERO, size / 2.0, planet_color)
	var s := _s()
	draw_set_transform(-PLANET_AT * s, 0.0, Vector2.ONE * s)


## Draw scale: SHELF_SCALE on the shelf, diving until the planet fills the screen's short side.
func _s() -> float:
	var half := get_viewport_rect().size / 2.0
	var zoom := lerpf(1.0, minf(half.x, half.y) * 2.0 * 0.92 / PLANET_PX / SHELF_SCALE, dive())
	var pop := 1.0 + 0.15 * sin(clampf(t / SETTLE, 0.0, 1.0) * PI) if t < SETTLE else 1.0
	return zoom * pop * SHELF_SCALE


func _setup_demo() -> void:
	Save.use_profile(DEMO_PROFILE)
	Save.wipe()
	var p := PlanetStandIn.generate("", 4242, 12)
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)
	var store := JarStore.new()
	store.dir = DEMO_DIR    # never put a demo jar on the family's shelf
	add_child(store)
	store.clear()
	var id := JarStore.current_planet_id(p.seed_value)
	store.snapshot(id)
	entered.connect(func(_id):
		store.close()
		store.clear()
		Save.wipe())
	show_jar(store, id)
