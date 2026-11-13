## S-17 / C-03 in space: the co-op camera fit. SpaceStage centres its camera between the worms at
## a fixed zoom (SPACE_ZOOM), so two worms that drift apart leave the screen. This child of the
## stage (scenes/levels/space_stage.tscn) runs after the stage has placed its camera each frame and
## pulls the zoom back until every worm fits, down to MIN_ZOOM. Past that it does what the planet's
## FarCamera does: it follows one worm (the solo pad's worm, else the bigger, a tie keeps the
## current one, P1 first) and the far worm gets an edge arrow in its colour, pointing at it, until
## they are close enough to share the screen again (REJOIN). Nobody is ever moved.
## Only writes the camera: it never steers a worm. StarAward (priority 10) leans in on top of it.
class_name SpaceFit
extends Node2D

## Widest the camera pulls back to (the stage's own is SpaceStage.SPACE_ZOOM).
const MIN_ZOOM := 0.32
## World px kept round each worm's centre (its head, trail and mouth reach).
const PAD := 300.0
## Screen px kept clear at the edges.
const MARGIN := 60.0
## Fit both again once their spread needs this share of the widest view (hysteresis).
const REJOIN := 0.85
## How fast the zoom and the centre ease (per s).
const EASE := 3.0

var stage: SpaceStage
var split := false
## The player the camera follows while split, -1 when it frames everyone.
var anchor := -1
## The zoom this node eases (written as the camera zoom when it is wider than the stage's).
var zoom := -1.0
## Where the camera looks while split (the anchor worm), and 0..1 how far it has moved there.
var centre := Vector2.ZERO
var _blend := 0.0
var _t := 0.0
var _arrows: Control
var _layer: CanvasLayer


func _ready() -> void:
	stage = get_parent() as SpaceStage
	process_priority = 5          # after the stage places its camera, before StarAward's lean
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_arrows = Control.new()
	_arrows.name = "Arrows"
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.draw.connect(_draw_arrows)
	_layer.add_child(_arrows)


func _process(delta: float) -> void:
	step(delta)


func view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)


## The zoom that fits every worm (with PAD) on screen around their centre.
func fit_zoom(worms: Array) -> float:
	if worms.size() < 2:
		return INF
	var c := Vector2.ZERO
	for w in worms:
		c += w.position
	c /= worms.size()
	var half := Vector2.ZERO
	for w in worms:
		half = half.max((w.position - c).abs() + Vector2.ONE * PAD)
	var room := view_size() * 0.5 - Vector2.ONE * MARGIN
	return minf(room.x / half.x, room.y / half.y)


## Once a frame, after the stage set its camera: widen the zoom to fit, or split and follow one.
func step(delta: float) -> void:
	_t += delta
	if stage == null or stage.camera == null:
		return
	var cam := stage.camera
	var worms: Array = stage.worms.filter(func(w): return is_instance_valid(w))
	var want_zoom := cam.zoom.x
	if worms.size() < 2:
		split = false
		anchor = -1
	else:
		var z := fit_zoom(worms)
		if not split and z < MIN_ZOOM:
			split = true
		elif split and z >= MIN_ZOOM / REJOIN:
			split = false
		if split:
			anchor = pick_anchor(worms, Players.solo_focus if Players.solo else -1, anchor)
			want_zoom = MIN_ZOOM
			for w in worms:
				if w.player == anchor:
					centre = w.position if _blend <= 0.0 else centre.lerp(w.position, minf(1.0, delta * EASE * 2.0))
		else:
			anchor = -1
			want_zoom = minf(want_zoom, maxf(z, MIN_ZOOM))
	if zoom < 0.0:
		zoom = cam.zoom.x
	var k := minf(1.0, delta * EASE)
	zoom = lerpf(zoom, want_zoom, k)
	_blend = move_toward(_blend, 1.0 if split else 0.0, delta * EASE)
	# the stage's own zoom wins while it is closer in (the arrival shot); never zoom in past it
	cam.zoom = Vector2.ONE * minf(cam.zoom.x, zoom)
	if _blend > 0.0:
		cam.position = cam.position.lerp(centre, smoothstep(0.0, 1.0, _blend))
	_arrows.queue_redraw()


## Solo: the pad's worm. Co-op: the bigger worm; a tie keeps whoever the camera follows, else P1.
static func pick_anchor(worms: Array, focus: int, current: int) -> int:
	var players: Array = worms.map(func(o): return o.player)
	if focus in players:
		return focus
	var best: Node2D = null
	for w in worms:
		if best == null or w.size_stage > best.size_stage:
			best = w
	for w in worms:
		if w != best and w.size_stage == best.size_stage:
			return current if current in players else players.min()
	return best.player


## Worms the camera does not see right now (the edge arrows point at these).
func off_screen() -> Array:
	var out := []
	if stage == null or stage.camera == null:
		return out
	var cam := stage.camera
	var half := view_size() * 0.5 / cam.zoom.x
	for w in stage.worms:
		if not is_instance_valid(w):
			continue
		var q: Vector2 = w.position - cam.position
		if absf(q.x) > half.x - 20.0 or absf(q.y) > half.y - 20.0:
			out.append(w)
	return out


func _draw_arrows() -> void:
	if stage == null or stage.camera == null:
		return
	var view := view_size()
	for w in off_screen():
		var dir: Vector2 = (w.position - stage.camera.position).normalized()
		var half := view * 0.5 - Vector2(70, 70)
		var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var p := view * 0.5 + dir * k
		var col: Color = w.body_color()
		var pulse := 1.0 + 0.15 * sin(_t * 6.0)
		var tip := p + dir * 34.0 * pulse
		var side := dir.orthogonal() * 22.0 * pulse
		_arrows.draw_colored_polygon(PackedVector2Array([tip, p + side, p - side]), col)
		_arrows.draw_circle(p - dir * 10.0, 18.0, col)
		_arrows.draw_circle(p - dir * 10.0, 7.0, Color.WHITE)
