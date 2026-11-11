## The worm on a lobby podium (MenuSkin.p1_character / p2_character): Gulp (green, one big eye) or
## Burp (red, two cross-eyes), placeholder art from assets/proto/worm/. A Node2D: the slot stands
## it on the podium. The lobby calls set_joined / wave / cheer; it never offers a chooser.
extends Node2D

const SEG := preload("res://assets/proto/worm/segment.png")
const HEAD := preload("res://assets/proto/worm/head.png")

@export var player := 0
var _joined := false
var _wave := 0.0
var _cheer := 0.0
var _t := 0.0
var _face0: Texture2D
var _face2: Texture2D


func _ready() -> void:
	_face0 = load("res://assets/proto/worm/face_p%d_0.png" % (player + 1))
	_face2 = load("res://assets/proto/worm/face_p%d_2.png" % (player + 1))
	scale = Vector2.ONE * 9.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_joined(on: bool) -> void:
	_joined = on


func wave() -> void:
	_wave = 1.0


func cheer() -> void:
	_cheer = 1.5


func _process(delta: float) -> void:
	_t += delta
	_wave = maxf(0.0, _wave - delta)
	_cheer = maxf(0.0, _cheer - delta)
	queue_redraw()


func _draw() -> void:
	var col: Color = Players.COLOR[player]
	if not _joined:
		col = col.darkened(0.6)
	var flip := -1.0 if player == 1 else 1.0
	var n := 5
	for i in range(n - 1, -1, -1):
		var x := flip * (-i * 7.0)
		var hop := sin(_t * (10.0 if _cheer > 0.0 else 3.0) - i * 0.7) * (3.0 if _cheer > 0.0 else 1.0)
		var y := -6.0 - i * 2.2 - hop - (_wave * sin(_t * 20.0) * 2.0 if i == 0 else 0.0)
		var tex := HEAD if i == 0 else SEG
		draw_set_transform(Vector2(x, y - i * 1.5), 0.0, Vector2(flip, 1))
		draw_texture(tex, -tex.get_size() * 0.5, col)
		if i == 0:
			var f := _face2 if (_cheer > 0.0 or _wave > 0.0) else _face0
			draw_texture(f, -f.get_size() * 0.5, Color.WHITE if _joined else Color(0.4, 0.4, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
