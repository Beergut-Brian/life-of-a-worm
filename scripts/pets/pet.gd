## A pet living in the burrow (Burrow.add_pet). Its job comes from PetData.job:
##  - &"fetch" (the ladybird): every PetData.every planet seconds, if fewer than max_waiting things
##    wait by the bed, it flies up out of the room, is away for PetData.trip seconds, and comes back
##    carrying PetData.fetch, which it drops by the bed (Burrow.add_pantry) with a chirp.
##  - &"lamp" (the glow-worm): while the room is dark (is_dark()) its PointLight2D brightens to
##    lamp_energy over lamp_radius tiles, its tail bulb glows and it does a short wiggle every
##    wiggle_every s. In daylight the light fades out and it dozes.
##  - &"tend" (the ant crew): every PetData.every s, if there is a garden in range, the crew walks
##    to its seed bed, works there PetData.work s and nudges it on (nudge_garden), then walks home.
## Between jobs it potters round the bed. The first time a kind arrives (Burrow.bring) it plays the
## meet beat (meet()): a picture bubble [pet][heart][job], then the job at once. Saved by id + t.
class_name Pet
extends Node2D

signal fetched(id: StringName, what: StringName)
## The ant crew nudged garden `garden` (its seed bed is `cell`).
signal tended(id: StringName, cell: Vector2i)
## The lamp came on (true) or went out (false).
signal lamp_changed(lit: bool)

## AWAY / BACK: the ladybird's trip. WALK / WORK / RETURN: the ant crew's walk to the garden.
enum State { HOME, AWAY, BACK, WALK, WORK, RETURN }

## How long the meet bubble shows before the job is shown.
const MEET_SECS := 2.5
## How fast the lamp comes on / goes out (share of full per second).
const LAMP_FADE := 1.5
const WIGGLE_SECS := 0.8

var data: PetData
var burrow: Burrow
## Seconds into the current wait (or trip).
var t := 0.0
var state := State.HOME
var trips := 0
## Times the ant crew nudged a seed bed.
var tends := 0
## Lamp: 0 (out) .. 1 (fully on), and whether it is lit (the room is dark).
var glow := 0.0
var lit := false
var light: PointLight2D
## Seconds into the meet beat, or -1 when not meeting.
var meet_t := -1.0
## The ant crew's current garden (index into PolarWorld.gardens()) and its seed bed.
var garden := -1
var target_cell := Vector2i.ZERO
var _anim := 0.0
var _work_pop := 0.0


func _ready() -> void:
	add_to_group(&"pets")
	add_to_group(&"creature")
	PetLook.register_pictures()
	if data and data.job == &"lamp":
		light = PointLight2D.new()
		light.name = "Lamp"
		light.texture = _radial()
		light.color = data.lamp_color
		var px := data.lamp_radius * 16.0
		light.texture_scale = px * 2.0 / 128.0
		light.height = px   # lights normal-mapped tiles from above, not edge-on
		light.energy = 0.0
		light.enabled = false
		add_child(light)


static func _radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


var creature_id: StringName:
	get:
		return data.id if data else &""


func _physics_process(delta: float) -> void:
	step(delta)


## Its place by the bed (follows home when home moves).
func spot() -> Vector2:
	return burrow.pet_spot(maxi(0, burrow.pets.find(self))) if burrow else position


## The meet beat: a picture bubble, then the job is shown at once (Burrow.bring, first of a kind).
func meet() -> void:
	meet_t = 0.0
	Audio.play("pet_meet")


## Is the room dark (the lamp's cue)? Night (Burrow.night), or home in one of data.dark_rings.
func is_dark() -> bool:
	if burrow == null:
		return false
	if burrow.night:
		return true
	var w := burrow.world
	if w == null or not burrow.has_home:
		return false
	var ring := w.ring_of(w.shape.cell_at(burrow.home))
	return ring != null and data.dark_rings.has(ring.id)


## The garden the ant crew tends: the one whose seed bed is nearest home, within tend_range; -1 none.
func pick_garden() -> int:
	var w := burrow.world if burrow else null
	if w == null or not burrow.has_home:
		return -1
	var best := -1
	var best_d := data.tend_range * 16.0
	var gs := w.gardens()
	for i in gs.size():
		var d := w.shape.center_of(gs[i].cell).distance_to(burrow.home)
		if d <= best_d:
			best_d = d
			best = i
	return best


## Pure rule: the garden whose seed bed is `cell` and still growing there, else -1.
static func seed_bed_at(w: PolarWorld, cell: Vector2i) -> int:
	var gs := w.gardens()
	for i in gs.size():
		if gs[i].cell == cell and w.get_tile(cell) == gs[i].tile:
			return i
	return -1


## Pure rule: garden `gi` grows its next cell `secs` planet seconds sooner.
static func nudge_garden(w: PolarWorld, gi: int, secs: float) -> void:
	w.gardens()[gi].next -= secs


func _cell_pos(cell: Vector2i) -> Vector2:
	var w := burrow.world
	return burrow.to_local(w.to_global(w.shape.center_of(cell)))


## Advances the job by delta seconds (tests call it directly).
func step(delta: float) -> void:
	var _spot := spot()
	_anim += delta
	var up := burrow.home.normalized() if burrow else Vector2.UP
	if data.job == &"lamp":
		_lamp(delta)
	if meet_t >= 0.0:
		meet_t += delta
		if meet_t >= MEET_SECS:   # the bubble is done: show the job right now
			meet_t = -1.0
			if data.job != &"lamp":
				t = data.every
		else:
			position = position.move_toward(_spot, 40.0 * delta)
			queue_redraw()
			return
	t += delta
	match state:
		State.HOME:
			var wob := Vector2(sin(_anim * 1.3) * 6.0, cos(_anim * 1.9) * 2.0)
			if data.job == &"lamp":
				wob *= 0.3   # a lamp mostly stays put
			position = _spot + wob.rotated(up.angle() + PI / 2.0)
			if data.job == &"fetch" and t >= data.every and burrow and burrow.pantry.size() < data.max_waiting:
				t = 0.0
				state = State.AWAY
				Audio.play("pet_away")
			elif data.job == &"tend" and t >= data.every:
				t = 0.0
				garden = pick_garden()
				if garden >= 0:
					target_cell = burrow.world.gardens()[garden].cell
					state = State.WALK
					Audio.play("pet_walk")
		State.AWAY:
			position += up * 40.0 * delta
			modulate.a = maxf(0.0, 1.0 - t / 0.6)
			if t >= data.trip:
				t = 0.0
				state = State.BACK
				position = _spot + up * 60.0
				modulate.a = 1.0
		State.BACK:
			position = position.move_toward(_spot, 50.0 * delta)
			if position.distance_to(_spot) < 1.0:
				state = State.HOME
				t = 0.0
				trips += 1
				burrow.add_pantry(data.fetch)
				Audio.play("pet_fetch")
				fetched.emit(data.id, data.fetch)
		State.WALK:
			var to := _cell_pos(target_cell)
			position = position.move_toward(to, data.walk_speed * delta)
			if position.distance_to(to) < 1.0:
				state = State.WORK
				t = 0.0
		State.WORK:
			if t >= data.work:
				var gi := seed_bed_at(burrow.world, target_cell)
				if gi >= 0:
					nudge_garden(burrow.world, gi, data.nudge)
					tends += 1
					_work_pop = 1.0
					Audio.play("pet_tend")
					tended.emit(data.id, target_cell)
				state = State.RETURN
				t = 0.0
		State.RETURN:
			position = position.move_toward(_spot, data.walk_speed * delta)
			if position.distance_to(_spot) < 1.0:
				state = State.HOME
				t = 0.0
		_:
			pass
	_work_pop = maxf(0.0, _work_pop - delta * 0.7)
	queue_redraw()


func _lamp(delta: float) -> void:
	var dark := is_dark()
	if dark != lit:
		lit = dark
		if lit:
			Audio.play("pet_lamp")
		lamp_changed.emit(lit)
	var rate := LAMP_FADE * (3.0 if meet_t >= 0.0 else 1.0)
	glow = move_toward(glow, 1.0 if lit else 0.0, delta * rate)
	if light:
		light.energy = data.lamp_energy * glow
		light.enabled = glow > 0.01


## The lamp's idle wiggle: 0..1, only while lit (a short shimmy every wiggle_every s).
func wiggle() -> float:
	if data.job != &"lamp" or not lit:
		return 0.0
	var ph := fmod(_anim, data.wiggle_every)
	return sin(ph / WIGGLE_SECS * PI) if ph < WIGGLE_SECS else 0.0


func _draw() -> void:
	if data == null:
		return
	var up := burrow.home.normalized() if burrow else Vector2.UP
	var r := data.food.radius
	match data.job:
		&"lamp":
			# Light pool on the room (also shows without the Lantern lights).
			if glow > 0.0:
				var px := data.lamp_radius * 16.0
				for k in 5:
					draw_circle(Vector2.ZERO, px * (1.0 - k * 0.17), Color(data.lamp_color, 0.045 * glow))
			var dir := up.angle() + PI / 2.0 + sin(_anim * 0.7) * 0.15
			PetLook.draw(self, data.look, Vector2.ZERO, r, dir, _anim, 0.0, data.color, 1.0, glow, wiggle())
			if not lit and fmod(_anim, 4.0) < 1.2:   # dozing by day
				_upright(up)
				PictoBubble.picture(self, &"zzz", Vector2(6, -12 - fmod(_anim, 4.0) * 4.0), 9.0, 0.7)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"tend":
			var dir := up.angle() + PI / 2.0 + sin(_anim) * 0.4
			var to_go := Vector2.ZERO
			if state == State.WALK:
				to_go = _cell_pos(target_cell) - position
			elif state == State.RETURN:
				to_go = spot() - position
			if to_go.length() > 0.5:
				dir = to_go.angle()
			var busy := 1.0 if state == State.WORK else 0.0
			PetLook.draw(self, data.look, Vector2.ZERO, r, dir, _anim, 0.0, data.color, 1.0, 0.0, busy)
			if state == State.WORK or _work_pop > 0.0:   # leaves popping on the bed: it's growing
				var k := 1.0 - _work_pop if _work_pop > 0.0 else fmod(_anim, 0.6) / 0.6
				for i in 3:
					var p := up.rotated((i - 1) * 0.7) * (6.0 + k * 10.0)
					draw_circle(p, 2.2, Color(0.45, 0.85, 0.3, 1.0 - k))
		_:
			var flying := state != State.HOME
			var dir := up.angle() if flying else up.angle() + PI / 2.0 + sin(_anim) * 0.6
			PetLook.draw(self, data.look, Vector2.ZERO, r, dir, _anim, (0.6 + 0.4 * sin(_anim * 30.0)) if flying else 0.0, data.color)
			if state == State.BACK:   # carrying the seed home
				draw_circle(-up * 6.0, 3.0, Color("2a1a14"))
				draw_circle(-up * 6.0, 2.2, Color(0.6275, 0.4392, 0.2353))
	if meet_t >= 0.0:   # the meet beat: who I am, I love it here, what I do
		_upright(up)
		var pop := minf(1.0, meet_t / 0.2)
		PictoBubble.draw(self, Vector2(0, -r - 6.0), [StringName("pet:" + String(data.look)), &"heart", StringName("job:" + String(data.job))], pop, 0.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif state == State.HOME and fmod(_anim, 5.0) < 0.6:   # a tiny heart now and then: it's home
		var h := up * (10.0 + fmod(_anim, 5.0) * 8.0)
		draw_circle(h + Vector2(-1.2, 0), 1.4, Color(1, 0.5, 0.6, 0.8))
		draw_circle(h + Vector2(1.2, 0), 1.4, Color(1, 0.5, 0.6, 0.8))


## Draw with local -y pointing away from the core (bubbles stand upright on the disk).
func _upright(up: Vector2) -> void:
	draw_set_transform(Vector2.ZERO, up.angle() + PI / 2.0, Vector2.ONE)
