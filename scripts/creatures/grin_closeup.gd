## The close-up for the first bite of a creature that used to chase you (GAME.md: "a special sting
## and a close-up of the worm grinning"). A round inset pops up on that player's side of the screen
## (P1 left, P2 right) with the worm's head big, eyes squeezed happy, a huge toothy grin and the
## outgrown creature, tiny and wide-eyed, in front of its mouth. No words. About 1.6 s, then it
## shrinks away. The sting itself (`now_i_eat_you`) is played by whoever calls show_for().
class_name GrinCloseup
extends CanvasLayer

const LIFE := 1.6
const RADIUS := 120.0
const INK := Color("2a1a14")

var player := 0
var worm_tex: Texture2D
var prey_color := Color(0.24, 0.44, 0.7)
var prey_radius := 12.0
var color := Color.WHITE
var _t := 0.0
var _draw_node: Control


## Puts a close-up on screen for this worm. `prey` is the CreatureData (or anything with color).
static func show_for(w: Node, prey: Resource = null) -> GrinCloseup:
	var g := GrinCloseup.new()
	g.player = int(w.get("player"))
	g.color = Players.COLOR.get(g.player, Color.WHITE)
	if w.get("head_sprite") != null:
		g.worm_tex = w.head_sprite.texture
	if prey != null and prey.get("color") != null:
		g.prey_color = prey.color
	var host: Node = w.get_tree().current_scene if w.get_tree().current_scene else w.get_parent()
	host.add_child(g)
	return g


func _ready() -> void:
	layer = 55
	name = "GrinCloseup"
	_draw_node = Control.new()
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_paint)
	add_child(_draw_node)


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	if _draw_node:
		_draw_node.queue_redraw()


func scale_now() -> float:
	var grow := ease(clampf(_t / 0.18, 0.0, 1.0), -2.0)
	var shrink := 1.0 - ease(clampf((_t - (LIFE - 0.25)) / 0.25, 0.0, 1.0), 2.0)
	return grow * shrink * (1.0 + 0.04 * sin(_t * 14.0))


func _paint() -> void:
	var vp := _draw_node.get_viewport_rect().size
	var r := RADIUS * minf(vp.y / 1080.0, vp.x / 1920.0) * 1.6
	var c := Vector2(r + vp.x * 0.04, r + vp.y * 0.06)
	if player == Players.P2:
		c.x = vp.x - c.x
	var k := scale_now()
	if k <= 0.01:
		return
	r *= k
	var ci := _draw_node
	ci.draw_circle(c, r + 8.0 * k, color)
	ci.draw_circle(c, r, Color("fff6dc"))
	# rays behind the head: the "ta-da"
	for i in 12:
		var a := TAU * i / 12.0 + _t * 1.5
		var p1 := c + Vector2.from_angle(a) * r * 0.55
		var p2 := c + Vector2.from_angle(a + 0.13) * r * 0.95
		var p3 := c + Vector2.from_angle(a - 0.13) * r * 0.95
		ci.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1.0, 0.85, 0.4, 0.45))
	# the worm's head, big (its own pixel head, nearest filtered)
	var hr := r * 0.62
	var hc := c + Vector2(-r * 0.12, r * 0.02)
	if worm_tex:
		ci.draw_texture_rect(worm_tex, Rect2(hc - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false)
	else:
		ci.draw_circle(hc, hr, Color("f29aa0"))
	# happy squeezed eyes ^ ^
	for sx in [-1.0, 1.0]:
		var e: Vector2 = hc + Vector2(sx * hr * 0.32, -hr * 0.25)
		var w := hr * 0.16
		ci.draw_polyline(PackedVector2Array([e + Vector2(-w, w * 0.6), e + Vector2(0, -w * 0.4), e + Vector2(w, w * 0.6)]), INK, maxf(3.0, hr * 0.06))
	# the grin: a wide open smile with a row of teeth
	var gm := hc + Vector2(0, hr * 0.22)
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(0.15, PI - 0.15, i / 16.0)
		pts.append(gm + Vector2(cos(a) * hr * 0.62, sin(a) * hr * 0.42))
	pts.append(gm + Vector2(-hr * 0.6, 0))
	ci.draw_colored_polygon(pts, Color("5a1a24"))
	for i in 5:
		var tx := lerpf(-hr * 0.45, hr * 0.45, i / 4.0)
		ci.draw_rect(Rect2(gm + Vector2(tx - hr * 0.07, -1.0), Vector2(hr * 0.14, hr * 0.12)), Color.WHITE)
	ci.draw_polyline(pts, INK, maxf(3.0, hr * 0.05))
	# the outgrown bug, tiny now, wide-eyed in front of the grin
	var bc := c + Vector2(r * 0.58, r * 0.38)
	var br := r * 0.17
	ci.draw_circle(bc, br + 3.0, INK)
	ci.draw_circle(bc, br, prey_color.lerp(Color.WHITE, 0.3))
	for sx in [-1.0, 1.0]:
		var ec: Vector2 = bc + Vector2(sx * br * 0.38 - br * 0.3, -br * 0.2)
		ci.draw_circle(ec, br * 0.3, Color.WHITE)
		ci.draw_circle(ec, br * 0.13, INK)
	# sweat drop
	var sd := bc + Vector2(br * 0.9, -br * 1.0) + Vector2(0, fmod(_t * 30.0, 8.0))
	ci.draw_circle(sd, br * 0.22, Color(0.55, 0.8, 1.0))
