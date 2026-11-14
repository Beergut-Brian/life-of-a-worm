## Stage 6 in the real planet (S-09, S-16, S-10, C-04): watches the PlanetLevel, and when a stage-6
## worm reaches the planet (its head out past the surface for OUT_TIME) it cuts to the fixed planet
## shot: the disk is rendered to a texture (PolarWorld's overview, frozen), the giant worm curls round
## it and the picture bubble asks (hold A, or B for not yet). A full hold saves the tin, snapshots it
## into a jar (JarStore, the real save) and runs the chomp; then the shot cross-fades to the space
## stage (scenes/levels/space_stage.tscn). Inside a jar (stage6_disabled) it never offers.
## Nothing here moves a worm: the shot only appears where the player took the worm.
class_name ChompDirector
extends Node

signal shot_opened(player: int)
signal shot_closed()
signal entered_space()

enum State { WATCH, SHOT, SPACE }

const CHOMP_SCENE := preload("res://scenes/levels/planet_chomp.tscn")
const SPACE_SCENE := preload("res://scenes/levels/space_stage.tscn")
const OUT_TIME := 0.6            # s a stage-6 head must be past the surface
const MARGIN_TILES := 2.0        # past the surface by this much
const STAGE := 6

var level: PlanetLevel
var state := State.WATCH
var chomp: PlanetChomp
var space: SpaceStage
## Tests point the jar shelf elsewhere ("" = the shared `Jars` autoload, user://jars).
var jar_dir := ""
var _out := {}                   # player -> seconds outside
var _disarmed := {}              # player -> true until its head goes back inside after a "not yet"
var _hidden: Array = []          # [node, visible, process_mode] restored when the shot closes


func _ready() -> void:
	if eaten():
		enter_space.call_deferred(false)


## The tin's planet was chomped (it is a jar now); the tin plays in space.
static func eaten() -> bool:
	return bool(Save.get_value("planet_eaten", false))


func busy() -> bool:
	return state != State.WATCH


## The jar id for the open tin: <profile>[_<slot>]_<seed> (same as feature/worm-jar-1).
func planet_id() -> String:
	var who := Save.profile if Save.slot == "" else "%s_%s" % [Save.profile, Save.slot]
	return "%s_%d" % [who, level.planet_seed]


func surface_px() -> float:
	return (PlanetLevel.RADIUS + MARGIN_TILES) * float(level.world.shape.cell_size)


func _physics_process(delta: float) -> void:
	match state:
		State.WATCH:
			_watch(delta)
		State.SHOT:
			if chomp and chomp.phase == PlanetChomp.Phase.DONE:
				enter_space(true)


func _watch(delta: float) -> void:
	if level == null or level.world == null or not JarStore.stage6_allowed():
		return
	for w in Worm.all():
		if w.get_parent() != level.actors:
			continue
		var outside := level.world.to_local(w.head_position()).length() > surface_px()
		if not outside:
			_disarmed.erase(w.player)
			_out[w.player] = 0.0
			continue
		if w.model.stage < STAGE or _disarmed.has(w.player):
			continue
		_out[w.player] = float(_out.get(w.player, 0.0)) + delta
		if _out[w.player] >= OUT_TIME:
			open_shot(w)
			return


## Cut to the fixed planet shot and ask. Returns false if stage 6 can't happen here.
func open_shot(w: Worm) -> bool:
	if state != State.WATCH or not JarStore.stage6_allowed():
		return false
	level.save_now()                       # the jar will copy this, the real tin, as it is now
	var tex := frozen_planet_texture()
	chomp = CHOMP_SCENE.instantiate()
	chomp.autostart = false
	chomp.auto_space = false
	chomp.keep_planet_save = true
	chomp.source_texture = tex
	chomp.source_id = planet_id()
	chomp.source_colors = ring_colors(tex.get_image())
	chomp.worm_color = Players.COLOR.get(w.player, Color("3cc24a"))
	if jar_dir != "":                      # tests: a private store on a scratch shelf
		var own := JarStore.new()
		own.name = "Jars"
		own.dir = jar_dir
		chomp.add_child(own)
	_hide_level()
	level.add_child(chomp)
	chomp.position = level.world.position
	chomp.declined.connect(close_shot)
	(chomp.get_node("Camera") as Camera2D).make_current()
	state = State.SHOT
	chomp.begin()
	shot_opened.emit(w.player)
	print("chomp: planet shot for %s (%s)" % [PlanetLevel.WORM_NAMES[w.player], chomp.source_id])
	return true


## "Not yet": back to the worm, nothing changed. The bubble comes back once the worm has been
## inside the planet and comes out again.
func close_shot() -> void:
	if state != State.SHOT:
		return
	for w in Worm.all():
		_disarmed[w.player] = true
	_free_chomp()
	_show_level()
	level.camera.make_current()
	state = State.WATCH
	shot_closed.emit()


## The planet shot's picture: a frozen copy of the disk's overview (1 px per 2 tiles, every bite in it).
func frozen_planet_texture() -> ImageTexture:
	var src := level.world.planet_texture()
	var img := src.get_image() if src else Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


## Five colours from core to surface, read off the picture (for the chomp's debris).
static func ring_colors(img: Image) -> Array[Color]:
	var out: Array[Color] = []
	var c := img.get_size() / 2
	for k in 5:
		var y := c.y - int(c.y * (0.08 + 0.2 * k))
		var col := img.get_pixel(c.x, clampi(y, 0, img.get_height() - 1))
		out.append(col if col.a > 0.0 else Color("8a5a34"))
	return out


## After the chomp (or on loading an eaten tin): the space stage replaces the shot.
func enter_space(fade := true) -> void:
	if state == State.SPACE:
		return
	if fade:
		_fade_over()
	_free_chomp()
	if _hidden.is_empty():
		_hide_level()
	space = SPACE_SCENE.instantiate()
	for w in Worm.all():
		space.players.append(w.player)
	level.add_child(space)
	space.position = level.world.position
	state = State.SPACE
	Save.set_value("stage", 7)
	Save.set_value("planet_eaten", true)
	entered_space.emit()


## Hold the last frame of the shot over space and fade it out (skipped headless: no frame to grab).
func _fade_over() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := level.get_viewport().get_texture().get_image()
	var layer := CanvasLayer.new()
	layer.layer = 60
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	level.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(rect, "modulate:a", 0.0, 1.1)
	tw.tween_callback(layer.queue_free)


func _free_chomp() -> void:
	if chomp:
		level.remove_child(chomp)
		chomp.queue_free()
		chomp = null


func _hide_level() -> void:
	_hidden.clear()
	for c in level.get_children():
		if c == self or c == chomp or c == space:
			continue
		if c is CanvasItem:
			_hidden.append([c, (c as CanvasItem).visible, c.process_mode])
			(c as CanvasItem).visible = false
		elif c is CanvasLayer and (c as CanvasLayer).layer >= 0:
			_hidden.append([c, (c as CanvasLayer).visible, c.process_mode])
			(c as CanvasLayer).visible = false
		else:
			continue
		if c != level.camera:
			c.process_mode = Node.PROCESS_MODE_DISABLED


func _show_level() -> void:
	for h in _hidden:
		if is_instance_valid(h[0]):
			h[0].visible = h[1]
			h[0].process_mode = h[2]
	_hidden.clear()
