## The blinking controller glyph over a worm's head when an interaction is ready (X: carry this;
## Y: the trait wall in the burrow; A: the swap shop; B: hold to warp back to a lost partner; see
## HintRules.glyph_for). Upright on screen whatever the camera's rotation; constant screen size
## whatever the zoom. refuse(tok) shakes a pressed button's glyph there when the press did nothing.
class_name ReadyGlyph
extends Node2D

const REFUSE_TIME := 0.6

var worm: Worm
var camera: Camera2D
var token := ""
## The glyph a refused press shows (wins over `token` while refuse_left > 0).
var refused := ""
var refuse_left := 0.0
var _t := 0.0


## A press that did nothing: shake its glyph over the head for a moment.
func refuse(tok: String) -> void:
	refused = tok
	refuse_left = REFUSE_TIME if tok != "" else 0.0


## What is drawn right now: a refused press first, else the ready glyph.
func shown() -> String:
	return refused if refuse_left > 0.0 else token


func _process(delta: float) -> void:
	_t += delta
	refuse_left = maxf(0.0, refuse_left - delta)
	visible = shown() != "" and worm != null and is_instance_valid(worm)
	if not visible:
		return
	position = worm.cam_position()
	if camera:
		rotation = camera.rotation
		scale = Vector2.ONE / camera.zoom.x
	queue_redraw()


func _draw() -> void:
	var tok := shown()
	if tok == "":
		return
	var up := Vector2(0, -70)
	if refuse_left > 0.0:   # a no-no shake, steady (no blink) so the pressed button reads
		up.x += sin(_t * 50.0) * 7.0 * (refuse_left / REFUSE_TIME)
		draw_circle(up, 26.0, Color(0, 0, 0, 0.45))
		UiStyle.draw_glyph(self, up, 40.0, tok, 0.9)
		return
	var a := 0.35 + 0.65 * absf(sin(_t * 5.0))   # blink
	draw_circle(up, 26.0, Color(0, 0, 0, 0.35 * a))
	UiStyle.draw_glyph(self, up, 40.0, tok, a)
