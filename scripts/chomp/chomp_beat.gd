## The planet chomp's camera beat (P-14). The chomp shot's camera used to stay fixed on the whole
## planet. Now on every bite it leans toward the giant worm's mouth and zooms in a little, so the jaw
## and the bitten edge (the cause) fill the screen. On the final gulp it pushes in on the mouth
## (GULP_TIME), then eases back to the whole shot so the empty sky and the burp are seen.
## Only the camera moves. The chomp and the giant worm are never touched, and the player's worm is
## hidden during the shot. GiantWorm makes one as its child when it sits in a PlanetChomp (so
## planet_chomp.gd/.tscn stay as they are). Bites are counted from the chomp's own per-bite counter
## (`_bite`, one per _do_bite call), the gulp from `planet_eaten` (emitted once, in _gulp). Tests drive
## it with step(); its _process runs after the chomp's (process_priority), so the chomp's shake
## offset stays the chomp's and the mouth read is the one the bite just used.
class_name ChompBeat
extends Node

## How far the camera slides from the planet's centre toward the mouth (0 = centre, 1 = on it).
const LEAN := 0.45
const BITE_ZOOM := 1.18
const GULP_ZOOM := 1.4
## Seconds a bite holds the lean. Longer than the gap between bites, so the camera stays leaned in
## and follows the mouth round the planet for the whole chomp.
const BITE_TIME := 0.55
const GULP_TIME := 1.0
## Ease rate (1/s) of the slide and zoom.
const EASE := 6.0

var chomp: PlanetChomp
var camera: Camera2D
## Where the camera leans to (the mouth at the last bite or the gulp), in the chomp's space.
var focus := Vector2.ZERO
var bites := 0
var gulps := 0
var _bite_t := 0.0
var _gulp_t := 0.0
var _seen_bites := 0
var _worm: GiantWorm


func _init() -> void:
	name = "ChompBeat"
	process_priority = 10


func _ready() -> void:
	var w := get_parent() as GiantWorm
	if w != null and w.get_parent() is PlanetChomp:
		watch(w.get_parent() as PlanetChomp, w)


func watch(p_chomp: PlanetChomp, p_worm: GiantWorm) -> void:
	chomp = p_chomp
	_worm = p_worm
	camera = chomp.get_node_or_null(^"Camera") as Camera2D
	if not chomp.planet_eaten.is_connected(_on_gulped):
		chomp.planet_eaten.connect(_on_gulped)


## The giant worm's mouth in the chomp's space.
func mouth() -> Vector2:
	return _worm.position + _worm.mouth_position() if _worm != null else Vector2.ZERO


func busy() -> bool:
	return _bite_t > 0.0 or _gulp_t > 0.0


func target_zoom() -> float:
	if _gulp_t > 0.0:
		return GULP_ZOOM
	return BITE_ZOOM if _bite_t > 0.0 else 1.0


func target_position() -> Vector2:
	return focus * LEAN if busy() else Vector2.ZERO


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_count_bites()
	_bite_t = maxf(0.0, _bite_t - delta)
	_gulp_t = maxf(0.0, _gulp_t - delta)
	if camera == null:
		return
	var k := 1.0 - exp(-EASE * delta)
	camera.position = camera.position.lerp(target_position(), k)
	camera.zoom = Vector2.ONE * lerpf(camera.zoom.x, target_zoom(), k)


## New bites since the last step, from the chomp's per-bite counter (it restarts at 0 for the chomp).
func _count_bites() -> void:
	if chomp == null:
		return
	var n: int = chomp._bite
	if n < _seen_bites:
		_seen_bites = 0
	if n > _seen_bites and chomp.phase == PlanetChomp.Phase.CHOMP:
		bites += n - _seen_bites
		focus = mouth()
		_bite_t = BITE_TIME
	_seen_bites = n


func _on_gulped() -> void:
	_count_bites()
	gulps += 1
	focus = mouth()
	_gulp_t = GULP_TIME
	_bite_t = 0.0
