## S-18's book page per planet, shown where it is earned: when a whole themed planet is eaten in space
## (SpaceDrift.planet_done), a little open book pops up beside the worms with that planet's sketch on
## its right page (the same BookArt picture the collection book shows), rises, wiggles and fades,
## with the book's own "page_new" cue. The page itself is kept by the tin: SpaceDrift already saves
## the eaten type under "space" -> "done", and BookCatalog.found_set reads it from there.
## Made by `PlanetPagePop.watch(stage)` (StarAward hooks it); never moves a worm.
class_name PlanetPagePop
extends Node2D

signal popped(id: StringName)

const LIFE := 2.2          # s on screen
const RISE := 140.0        # screen px it floats up over its life
const LIFT := 90.0         # screen px above the worms it starts
const SIDE := 380.0        # screen px to the right, clear of the stage's own picture bubble
const PAPER := Color("f7efd9")
const COVER := Color("2f6e8e")

var stage: SpaceStage
var data: PlanetData
var age := 0.0


## Connects one stage's drift so every planet eaten whole pops its page.
static func watch(p_stage: SpaceStage) -> void:
	if p_stage == null or p_stage.drift == null:
		return
	var cb := func(id: StringName) -> void: pop(p_stage, id)
	p_stage.drift.planet_done.connect(cb)


## Shows the page for planet type `id` over the worms. Returns the pop (null if id is unknown).
static func pop(p_stage: SpaceStage, id: StringName) -> PlanetPagePop:
	var d: PlanetData = null
	for e in BookCatalog.entries(&"planets"):
		if e.id == id:
			d = e.data
	if d == null:
		return null
	var n := PlanetPagePop.new()
	n.stage = p_stage
	n.data = d
	n.z_index = 30
	p_stage.add_child(n)
	Audio.play("page_new")
	n.popped.emit(id)
	return n


func _ready() -> void:
	_place()


func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	_place()
	queue_redraw()


## World position over the worms, scaled so it reads the same size at any space zoom.
func _place() -> void:
	var z := 1.0
	if stage and stage.camera:
		z = maxf(0.05, stage.camera.zoom.x)
	scale = Vector2.ONE / z
	var k := clampf(age / LIFE, 0.0, 1.0)
	var at := stage.worms_centre() if stage else Vector2.ZERO
	position = at + Vector2(SIDE, -(LIFT + RISE * k)) / z


func _draw() -> void:
	var grow := clampf(age / 0.25, 0.0, 1.0)
	var fade := clampf((LIFE - age) / 0.5, 0.0, 1.0)
	var wig := sin(age * 9.0) * 0.06 * (1.0 - clampf(age / 1.2, 0.0, 1.0))
	draw_set_transform(Vector2.ZERO, wig, Vector2.ONE * (0.6 + 0.4 * grow) * (1.0 + 0.08 * sin(age * 3.0)))
	modulate.a = fade
	# An open book: cover, two pages, the spine.
	draw_rect(Rect2(-150, -95, 300, 190), COVER)
	draw_rect(Rect2(-140, -85, 136, 170), PAPER.darkened(0.05))
	draw_rect(Rect2(4, -85, 136, 170), PAPER)
	for j in 5:
		draw_line(Vector2(-128, -55 + j * 30), Vector2(-16, -55 + j * 30), Color(0.4, 0.55, 0.8, 0.25), 2.0)
	draw_rect(Rect2(-4, -95, 8, 190), COVER.darkened(0.3))
	# The planets tab icon on the left page, the planet's own sketch on the right.
	BookArt.tab_icon(self, &"planets", Vector2(-72, 0), age)
	draw_set_transform(Vector2(72, 0).rotated(wig) * (0.6 + 0.4 * grow), wig, Vector2.ONE * 0.95 * (0.6 + 0.4 * grow))
	BookArt.planet(self, Vector2.ZERO, data, true, age, 0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
