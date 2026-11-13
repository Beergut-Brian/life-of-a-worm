## The burrow: home. Hollow out a chamber anywhere and sleep in it (hold still in a hollow for
## SLEEP_STILL s) and that is home; sleeping in another hollow moves home there (trophies, pets and
## the pantry come along: they are data). One burrow per bait tin, shared by both worms.
##
## Carried home (hold X), a thing becomes:
##  - a seed: a garden in the castings by the door;
##  - a small creature (a WildPet): a pet with a job (PetData), living by the bed. The first of a
##    kind plays the meet beat (Pet.meet). One past its kind's cap (PetData.max_kept, the ant crew
##    1) says hello to the one at home and runs back to the wild: still a "pet" homecoming;
##  - anything else: a trophy on a shelf. A shelf is any ledge the worm has dug inside the room (an
##    air cell with solid ground under it, toward the core); the trophy lands on the free ledge
##    nearest the worm. With no free ledge a notch is dug in the floor, so nobody is ever refused.
## Trophy families (data/trophies/) give every worm a small standing bonus (TrophyBonus).
## The bed is the sleep spot: falling asleep saves the tin, and Y while asleep opens the trait wall
## (it opens by itself when a newly earned trait is waiting). The wall hangs above the bed: one
## picture per earned trait (BurrowWall is the close-up chooser). A player who never makes a choice
## there gets the newest trait equipped when the wall shuts (auto_equip), once per trait.
## The room grows with the worm's stage (data/burrow/growth.tres, BurrowGrowth); from the house stage
## the chamber is a cavern with a buried house in it, and trophies brought home become its furniture.
## Nothing in a burrow ever regrows (the world's keep zone). Placeholder art, drawn here.
class_name Burrow
extends Node2D

signal home_set(player: int, at: Vector2)
signal brought_home(player: int, what: StringName, kind: StringName)   # trophy | seed | pet
## The family bonus changed (stat -> add); HomeSlice applies it to every worm.
signal bonus_changed(bonus: Dictionary)
## The room grew (a stage-up).
signal grew(stage: int)

const SLEEP_STILL := 2.0
## A hollow: at least HOLLOW_SHARE of the cells within HOLLOW_TILES of the head are air.
const HOLLOW_TILES := 2.0
const HOLLOW_SHARE := 0.75
## In the burrow: within room_tiles() of home. Sizes per stage live in data (BurrowGrowth).
const SHELF_SLOTS := 8
const MAX_PETS := 3
const FOODS := "res://data/foods/%s.tres"
const PETS := "res://data/pets/%s.tres"
const PET_SCRIPT := preload("res://scripts/pets/pet.gd")
const FOOD_SCRIPT := preload("res://scripts/arena/arena_food.gd")
const SEED := preload("res://data/foods/seed.tres")

var world: PolarWorld
var has_home := false
var home := Vector2.ZERO
var trophies: Array[StringName] = []
## Shelf cell of each trophy (parallel to trophies).
var trophy_cells: Array[Vector2i] = []
var seeds: Array[Dictionary] = []      # {flavour, cell}
## Pet nodes living here (Pet), saved by id.
var pets: Array[Node2D] = []
## Seeds the pets brought, waiting by the bed (ArenaFood nodes; eat them or carry them out).
var pantry: Array[Node2D] = []
## Pet kinds that have already had their meet beat in this tin (saved).
var met: Array[StringName] = []
## Night hook for the glow-worm lamp (Pet.is_dark): a day/night clock sets it; nothing does yet.
var night := false
## The biggest stage a worm of this tin has reached: the room's size.
var stage := 1
var families: Array[TrophyFamily] = []
var growth: BurrowGrowth
## player -> trait ids the wall already equipped by itself (each one only once, so a player who
## later takes it off keeps it off).
var offered := {}
## player -> seconds left on the "it equipped itself" flash on the wall.
var _flash := {}
var _t := 0.0
var _fallback := 0
## player -> the carried node it picked up inside the room (never "brought home" again).
var _picked_inside := {}
var _last_carry := {}


func _init() -> void:
	families = TrophyFamily.load_all()
	growth = BurrowGrowth.get_default()


## Pure rule, for tests: is the world hollow round pos (world-local px)?
static func is_hollow(w: PolarWorld, pos: Vector2, tiles := HOLLOW_TILES, share := HOLLOW_SHARE) -> bool:
	var cs := float(w.shape.cell_size)
	var c := pos / cs
	var r := tiles
	var total := 0
	var air := 0
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if (Vector2(x + 0.5, y + 0.5) - c).length_squared() <= r * r:
				total += 1
				if not w.is_solid(Vector2i(x, y)):
					air += 1
	return total > 0 and float(air) / total >= share


static func room_tiles_for(s: int) -> float:
	return BurrowGrowth.get_default().room_for(s)


## The chamber carved round the bed at stage s, in tiles.
func chamber_tiles() -> float:
	return growth.chamber_for(stage)


## By the house stage the burrow is a cavern with a buried house in it.
func has_house() -> bool:
	return has_home and growth.has_house(stage)


func room_tiles() -> float:
	return growth.room_for(stage)


func in_room(pos: Vector2) -> bool:
	return has_home and pos.distance_to(home) <= room_tiles() * 16.0


## Can this worm fall asleep here right now?
func can_sleep(w: Worm) -> bool:
	return w.still_time >= SLEEP_STILL and not w.asleep and is_hollow(world, world.to_local(w.head_position()))


## Sleep: home is here now (the level autosaves on home_set). A trait waiting on the wall opens it.
func sleep(w: Worm) -> void:
	w.asleep = true
	Audio.play("sleep")
	set_home(world.to_local(w.head_position()), w.player)
	if w.model.earned.size() > w.model.active.size() and w.model.slots() > 0 and not w.wall_open:
		install_wall(w)
		w.in_burrow = true   # asleep in the bed: the wall is open (the level keeps it so)
		w.set_wall_open(true)


func set_home(at: Vector2, player := 0) -> void:
	var moved := not has_home or at.distance_to(home) > room_tiles() * 16.0
	var shift := at - home if has_home else Vector2.ZERO
	has_home = true
	home = at
	if moved:
		_keep_zone()
		if stage > 1:
			_carve()   # a grown worm's new home gets its full-size chamber (and house) at once
		# Things are data: they come along to the new home, re-shelved there.
		if shift != Vector2.ZERO:
			var ids := trophies.duplicate()
			trophies.clear()
			trophy_cells.clear()
			for id in ids:
				_shelve(id, home)
			for p in pets:
				p.position = pet_spot(pets.find(p))
			for i in pantry.size():
				pantry[i].position = pantry_spot(i)
				pantry[i].home = pantry[i].position
	queue_redraw()
	home_set.emit(player, home)


func _keep_zone() -> void:
	if world:
		world.keep_zones.clear()
		world.add_keep_zone(home, (room_tiles() + 1.0) * 16.0)


## The level calls this each frame for each carrying worm in the room: true when the carried thing
## came from outside (picked up in the room, it is just being moved about).
func should_bring(w: Worm) -> bool:
	if w.carrying == null or not is_instance_valid(w.carrying):
		return false
	if w.carrying.has_method("pet_id"):   # a creature carried in is always a new pet
		return true
	return _picked_inside.get(w.player) != w.carrying


## The level calls this each frame for every worm: remembers whether the thing it carries now was
## picked up inside the room.
func note_pickup(w: Worm, inside: bool) -> void:
	var c: Node2D = w.carrying if w.carrying != null and is_instance_valid(w.carrying) else null
	if c == null:
		_last_carry.erase(w.player)
		_picked_inside.erase(w.player)
		return
	if _last_carry.get(w.player) != c:
		_last_carry[w.player] = c
		if inside:
			_picked_inside[w.player] = c
		else:
			_picked_inside.erase(w.player)


## The worm carrying `food` (a group-food node with data: FoodData) reached home.
func bring(w: Worm, food: Node2D) -> StringName:
	var data: FoodData = food.data
	var kind := &"trophy"
	var pid: StringName = food.call("pet_id") if food.has_method("pet_id") else &""
	if pid != &"" and can_keep(pid):
		kind = &"pet"
		var p: Node2D = add_pet(pid)
		Audio.play("pet_home")
		if p and not met.has(pid):
			met.append(pid)
			p.meet()
	elif pid != &"" and pet_count(pid) > 0:
		kind = &"pet"   # one of its kind lives here already: a hello, then back to the wild
		for p in pets:
			if p.data.id == pid:
				p.meet_t = Pet.MEET_SECS * 0.5
				break
		Audio.play("pet_hello")
	elif data.id == &"seed" and world and _plant(data.flavour):
		kind = &"seed"
		Audio.play("home_seed")
	else:
		_shelve(data.id, w.head_position() - global_position if world == null else world.to_local(w.head_position()))
		Audio.play("home_trophy")
	w.carrying = null
	food.call("take")
	brought_home.emit(w.player, data.id, kind)
	queue_redraw()
	return kind


# --- trophies -------------------------------------------------------------------------------------

## Puts trophy `id` on the free dug ledge nearest `near` (a notch in the floor if there is none).
func _shelve(id: StringName, near: Vector2) -> Vector2i:
	var cell := free_house_spot(near)
	if cell == Vector2i(-99999, -99999):
		cell = free_ledge(near)
	if cell == Vector2i(-99999, -99999):
		cell = _dig_notch()
	trophies.append(id)
	trophy_cells.append(cell)
	bonus_changed.emit(bonus())
	return cell


## A ledge: an air cell in the room with solid ground under it (toward the core), not the bed, not
## already holding a trophy. Nearest to `near`; Vector2i(-99999, -99999) if none.
func free_ledge(near: Vector2) -> Vector2i:
	var none := Vector2i(-99999, -99999)
	if world == null or not has_home:
		return none
	var best := none
	var best_d := INF
	var c := world.shape.cell_at(home)
	var n := ceili(room_tiles())
	var bed := bed_position()
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			var at := world.shape.center_of(cell)
			if at.distance_to(home) > room_tiles() * 16.0 - 6.0 or at.distance_to(bed) < 14.0:
				continue
			if world.is_solid(cell) or trophy_cells.has(cell):
				continue
			var below := world.shape.cell_at(at - at.normalized() * 16.0)
			if not world.is_solid(below):
				continue
			var d := at.distance_to(near)
			if d < best_d:
				best_d = d
				best = cell
	return best


func _dig_notch() -> Vector2i:
	while true:
		var p := slot_position(_fallback)
		_fallback += 1
		if world == null:
			return Vector2i(roundi(p.x), roundi(p.y))
		var cell := world.shape.cell_at(p)
		if not trophy_cells.has(cell):
			world.dig(cell)
			return cell
	return Vector2i.ZERO


## Where a trophy on `cell` sits (on the floor of its ledge, or on its furniture in the house).
func trophy_position(i: int) -> Vector2:
	var cell := trophy_cells[i]
	if world == null:
		return Vector2(cell)
	if has_house():
		var k := house_spot_cells().find(cell)
		if k >= 0:
			return house_spot(k)
	var at := world.shape.center_of(cell)
	return at - at.normalized() * 3.0


## Fallback floor notches along the burrow's floor (the side toward the core).
func slot_position(i: int) -> Vector2:
	var down := -home.normalized()
	var side := down.orthogonal()
	var k := (i % SHELF_SLOTS) - (SHELF_SLOTS - 1) * 0.5
	return home + down * 2.4 * 16.0 + side * k * 16.0 - down * floorf(i / SHELF_SLOTS) * 16.0


## Trophies per family on the shelf: family id -> count.
func family_counts() -> Dictionary:
	var out := {}
	for id in trophies:
		var f := TrophyFamily.family_of(families, id)
		if f:
			out[f.id] = int(out.get(f.id, 0)) + 1
	return out


## The standing bonus every worm gets from the shelf: stat -> add (each family up to its cap).
func bonus() -> Dictionary:
	var out := {}
	var counts := family_counts()
	for f in families:
		var n := mini(int(counts.get(f.id, 0)), f.cap)
		if n <= 0:
			continue
		for k in f.per_trophy:
			out[k] = float(out.get(k, 0.0)) + float(f.per_trophy[k]) * n
	return out


## Trades a shelf trophy away (the Mole's swap shop): removes the newest trophy of `id` (any if &"").
func remove_trophy(id: StringName = &"") -> StringName:
	for i in range(trophies.size() - 1, -1, -1):
		if id == &"" or trophies[i] == id:
			var got := trophies[i]
			trophies.remove_at(i)
			trophy_cells.remove_at(i)
			bonus_changed.emit(bonus())
			queue_redraw()
			return got
	return &""


# --- seeds, pets, pantry --------------------------------------------------------------------------

func _plant(flavour: StringName) -> bool:
	var c := world.shape.cell_at(home)
	for r in range(1, int(room_tiles()) + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var cell := c + Vector2i(x, y)
				if world.plant_seed(cell, flavour):
					seeds.append({ "flavour": String(flavour), "cell": [cell.x, cell.y] })
					return true
	return false


func bed_position() -> Vector2:
	return home - home.normalized() * 10.0


func pet_spot(i: int) -> Vector2:
	var up := home.normalized()
	return home + up * 12.0 + up.orthogonal() * (i - 1) * 14.0


func pantry_spot(i: int) -> Vector2:
	var up := home.normalized()
	return home - up * 4.0 - up.orthogonal() * (22.0 + i * 9.0)


func add_pet(id: StringName, t := 0.0) -> Node2D:
	var path := PETS % id
	if not ResourceLoader.exists(path):
		return null
	var p: Node2D = PET_SCRIPT.new()
	p.data = load(path)
	p.burrow = self
	p.t = t
	p.position = pet_spot(pets.size())
	p.z_index = 2
	pets.append(p)
	add_child(p)
	return p


func pet_count(id: StringName) -> int:
	var n := 0
	for p in pets:
		if p.data.id == id:
			n += 1
	return n


## Room for one more pet of kind `id` (the total cap, and its own PetData.max_kept)?
func can_keep(id: StringName) -> bool:
	var path := PETS % id
	if pets.size() >= MAX_PETS or not ResourceLoader.exists(path):
		return false
	var d: PetData = load(path)
	return pet_count(id) < d.max_kept


func pet_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in pets:
		out.append(p.data.id)
	return out


## A pet came back with a seed: it waits by the bed (eat it, or carry it out to castings).
func add_pantry(_what: StringName = &"seed") -> Node2D:
	var f: Node2D = FOOD_SCRIPT.new()
	f.data = SEED
	f.position = pantry_spot(pantry.size())
	add_child(f)
	f.home = f.position
	pantry.append(f)
	f.taken.connect(func(n: Node2D) -> void:
		pantry.erase(n)
		n.queue_free())
	return f


# --- growing --------------------------------------------------------------------------------------

## A worm reached stage s: the room grows (a bigger chamber is carved round the bed, the keep zone
## and the shelf area grow with it).
func grow_to(s: int) -> bool:
	if s <= stage:
		return false
	stage = s
	if has_home and world:
		_keep_zone()
		_carve()
		Audio.play("burrow_grow")
	grew.emit(stage)
	queue_redraw()
	return true


## Carves this stage's chamber round the bed (only what a worm of this stage could eat), and from
## the house stage the inside of the buried house too.
func _carve() -> void:
	if world == null or not has_home:
		return
	var r := chamber_tiles() * 16.0
	var c := world.shape.cell_at(home)
	var n := ceili(r / 16.0)
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if world.shape.center_of(cell).distance_to(home) <= r and world.is_edible_by(stage, cell) and not trophy_cells.has(cell):
				world.dig(cell)
	if has_house():
		var hs := house_size()
		var up := home.normalized()
		var side := up.orthogonal()
		var base := house_base()
		for fy in range(0, int(hs.y / 16.0)):
			for fx in range(0, int(hs.x / 16.0)):
				var at := base + up * (fy + 0.5) * 16.0 + side * ((fx + 0.5) * 16.0 - hs.x * 0.5)
				var cell := world.shape.cell_at(at)
				if world.is_edible_by(stage, cell) and not trophy_cells.has(cell):
					world.dig(cell)


# --- the buried house (from growth.house_stage) ---------------------------------------------------

func house_size() -> Vector2:
	return growth.house_tiles * 16.0


## The middle of the house's floor (world-local px). It stands on the cavern floor beside the bed,
## its far side sunk into the cavern wall: a house that was buried here long ago.
func house_base() -> Vector2:
	var up := home.normalized()
	var r := chamber_tiles() * 16.0
	return home - up * (r - 14.0) + up.orthogonal() * r * 0.45


## Furniture spot k (rooms across, then floors up): where a trophy stands in the house.
func house_spot(k: int) -> Vector2:
	var hs := house_size()
	var up := home.normalized()
	var side := up.orthogonal()
	var room := k % growth.house_rooms
	var fl := k / growth.house_rooms
	var rw := hs.x / growth.house_rooms
	var fh := hs.y / growth.house_floors
	return house_base() + side * (-hs.x * 0.5 + (room + 0.5) * rw) + up * (fl * fh + 9.0)


func house_spot_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if world == null or not has_house():
		return out
	for k in growth.house_spots():
		out.append(world.shape.cell_at(house_spot(k)))
	return out


## The free furniture spot nearest `near`; Vector2i(-99999, -99999) with no house or none free.
func free_house_spot(near: Vector2) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	var best_d := INF
	var cells := house_spot_cells()
	for k in cells.size():
		if trophy_cells.has(cells[k]):
			continue
		var d := house_spot(k).distance_to(near)
		if d < best_d:
			best_d = d
			best = cells[k]
	return best


# --- the trait wall (D-13) ------------------------------------------------------------------------

## Gives the worm the burrow's chooser (BurrowWall) instead of the placeholder panel. Safe to call
## again. Hook: this sets Worm._wall (scripts/worm/ has no public setter; see REPORT.md).
func install_wall(w: Worm) -> void:
	if w._wall is BurrowWall:
		(w._wall as BurrowWall).burrow = self
		return
	if w._wall != null:
		if w.wall_open:
			return   # never swap a wall that is open right now
		w._wall.queue_free()
	var bw := BurrowWall.new()
	bw.worm = w
	bw.burrow = self
	w._wall = bw
	w.add_child(bw)


## The wall shut and the player chose nothing: the newest earned trait equips itself (swapping out
## the oldest active one when every slot is full). Once per trait per player. Returns its id or &"".
func auto_equip(w: Worm) -> StringName:
	var m := w.model
	if m.slots() <= 0 or m.earned.is_empty():
		return &""
	var newest: StringName = m.earned[-1]
	var done: Array = offered.get(w.player, [])
	if m.is_active(newest) or newest in done:
		return &""
	done.append(newest)
	offered[w.player] = done
	if m.active.size() >= m.slots():
		m.toggle(m.active[0])
	if not m.toggle(newest):
		return &""
	Audio.play("trait_swap")
	_flash[w.player] = 0.8
	queue_redraw()
	return newest


# --- save -----------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var cells := []
	for c in trophy_cells:
		cells.append([c.x, c.y])
	var pet_list := []
	for p in pets:
		pet_list.append({ "id": String(p.data.id), "t": p.t })
	return { "has_home": has_home, "home": [home.x, home.y],
		"trophies": trophies.map(func(t): return String(t)), "cells": cells,
		"seeds": seeds.duplicate(true), "pets": pet_list, "pantry": pantry.size(),
		"met": met.map(func(m): return String(m)),
		"stage": stage, "fallback": _fallback, "offered": _offered_to_save() }


func _offered_to_save() -> Dictionary:
	var out := {}
	for p in offered:
		out[str(p)] = (offered[p] as Array).map(func(t): return String(t))
	return out


func from_dict(d: Dictionary) -> void:
	has_home = bool(d.get("has_home", false))
	var h: Array = d.get("home", [0, 0])
	home = Vector2(h[0], h[1])
	stage = int(d.get("stage", 1))
	_fallback = int(d.get("fallback", 0))
	offered.clear()
	var off: Dictionary = d.get("offered", {})
	for k in off:
		offered[int(k)] = (off[k] as Array).map(func(t): return StringName(t))
	trophies.clear()
	trophy_cells.clear()
	var cells: Array = d.get("cells", [])
	var list: Array = d.get("trophies", [])
	for i in list.size():
		trophies.append(StringName(list[i]))
		if i < cells.size():
			trophy_cells.append(Vector2i(int(cells[i][0]), int(cells[i][1])))
		elif world:
			trophy_cells.append(world.shape.cell_at(slot_position(i)))
		else:
			trophy_cells.append(Vector2i(i, 0))
	seeds.assign(d.get("seeds", []))
	for p in pets:
		p.queue_free()
	pets.clear()
	met.clear()
	for m in d.get("met", []):
		met.append(StringName(m))
	for e in d.get("pets", []):
		add_pet(StringName(e.get("id", "")), float(e.get("t", 0.0)))
		var id := StringName(e.get("id", ""))
		if not met.has(id):   # a tin from before the meet beat: these were met already
			met.append(id)
	for f in pantry:
		f.queue_free()
	pantry.clear()
	for i in int(d.get("pantry", 0)):
		add_pantry()
	if has_home:
		_keep_zone()
	bonus_changed.emit(bonus())
	queue_redraw()


# --- look -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for p in _flash.keys():
		_flash[p] = float(_flash[p]) - delta
		if _flash[p] <= 0.0:
			_flash.erase(p)
	if has_home and (not _flash.is_empty() or int(_t * 4.0) != int((_t - delta) * 4.0)):
		queue_redraw()


func _draw() -> void:
	if not has_home:
		return
	var down := -home.normalized()
	var rot := down.angle() - PI / 2.0   # "up" of the burrow points away from the core
	# Room outline: a faint warm ring shows how big home is (it grows with the stage).
	draw_arc(home, room_tiles() * 16.0, 0.0, TAU, 64, Color(1, 0.85, 0.55, 0.10), 2.0)
	if has_house():
		_draw_house()
	# Bed: a soft leaf mat where the worm sleeps.
	draw_set_transform(bed_position(), rot, Vector2.ONE)
	draw_rect(Rect2(-15, -3, 30, 6), Color(0.48, 0.7, 0.36, 0.9))
	draw_rect(Rect2(-15, -3, 30, 6), Color("2a1a14"), false, 1.0)
	draw_circle(Vector2(-12, -2), 3.5, Color(0.9, 0.85, 0.7))   # pillow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_wall()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in trophies.size():
		_draw_trophy(i)


func _draw_trophy(i: int) -> void:
	var p := trophy_position(i)
	var down := -p.normalized()
	var side := down.orthogonal()
	var f: FoodData = load(FOODS % trophies[i]) if ResourceLoader.exists(FOODS % trophies[i]) else null
	var col := f.color if f else Color.WHITE
	var fam := TrophyFamily.family_of(families, trophies[i])
	# The little plank it stands on, tagged in its family colour.
	draw_line(p + down * 5.0 - side * 7.0, p + down * 5.0 + side * 7.0, Color("7a5230"), 3.0)
	if fam:
		draw_line(p + down * 5.0 + side * 4.0, p + down * 5.0 + side * 7.0, fam.color, 3.0)
	var bob := -down * sin(_t * 2.0 + i) * 0.6
	var r := f.radius if f else 4.0
	draw_circle(p + bob, r + 1.0, Color("2a1a14"))
	draw_circle(p + bob, r, col)
	draw_circle(p + bob - side * 1.2 - down * 1.2, maxf(1.0, r * 0.28), col.lightened(0.5))
	# A sparkle now and then: it's a treasure.
	if fmod(_t + i * 0.7, 3.0) < 0.25:
		var s := p + bob - down * (r + 3.0) + side * 3.0
		draw_line(s - side * 2.0, s + side * 2.0, Color(1, 1, 0.8), 1.0)
		draw_line(s - down * 2.0, s + down * 2.0, Color(1, 1, 0.8), 1.0)


## The wall of pictures over the bed: a row per worm, one framed picture per earned trait (lit when
## active, dark while it waits), then an empty peg for each free slot. Placeholder, drawn in code.
func _draw_wall() -> void:
	var up := home.normalized()
	var rot := (-up).angle() - PI / 2.0
	var px := growth.picture_for(stage)
	var row := 0
	for w in Worm.all():
		var m := w.model
		if m == null or m.earned.is_empty() and m.slots() == 0:
			continue
		var n := m.earned.size() + maxi(0, m.slots() - m.active.size())
		var step := px * 1.35
		var y := 1.3 * 16.0 + px * 0.6 + row * (px * 1.5 + 4.0)
		draw_set_transform(home + up * y, rot, Vector2.ONE)
		var x := -step * (n - 1) * 0.5
		var col: Color = Players.COLOR[w.player]
		# The string the pictures hang from, in the player's colour.
		draw_line(Vector2(x - step * 0.6, -px * 0.75), Vector2(-x + step * 0.6, -px * 0.75), col, 1.5)
		var flash := float(_flash.get(w.player, 0.0))
		for id in m.earned:
			var t := m.rules.find_trait(id)
			_draw_picture(Vector2(x, 0), px, t, m.is_active(id), m.stage, flash if id == m.earned[-1] else 0.0)
			x += step
		for i in maxi(0, m.slots() - m.active.size()):
			draw_circle(Vector2(x, -px * 0.75), 1.6, Color("c8a070"))   # a free peg: room for one more
			draw_arc(Vector2(x, 0), px * 0.35, 0.0, TAU, 12, Color(1, 0.9, 0.7, 0.5), 1.0)
			x += step
		row += 1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_picture(at: Vector2, px: float, t: TraitData, on: bool, s: int, flash: float) -> void:
	var r := Rect2(at - Vector2.ONE * px * 0.5, Vector2.ONE * px)
	var col := t.color if t else Color.WHITE
	draw_line(at + Vector2(0, -px * 0.75), at + Vector2(0, -px * 0.5), Color("c8a070"), 1.0)
	draw_rect(r.grow(1.5), Color("7a5230"))
	draw_rect(r, col.darkened(0.2 if on else 0.7))
	var tex: Texture2D = t.part_texture(s) if t else null
	if tex != null:
		var k := px * 0.8 / maxf(tex.get_width(), tex.get_height())
		var size := tex.get_size() * k
		draw_texture_rect(tex, Rect2(at - size * 0.5, size), false, Color.WHITE if on else Color(0.45, 0.45, 0.45))
	else:
		draw_circle(at, px * 0.3, col if on else col.darkened(0.5))
	if on:
		draw_rect(r.grow(1.5), Color(1, 1, 0.8), false, 1.0)
	if flash > 0.0:
		draw_arc(at, px * (1.2 - flash * 0.5), 0.0, TAU, 20, Color(1, 1, 0.8, flash), 2.0)


## The buried house: an old little house sunk into the cavern wall, its rooms full of furniture
## (a trophy stands on each piece). Placeholder, drawn in code.
func _draw_house() -> void:
	var up := home.normalized()
	var rot := (-up).angle() - PI / 2.0
	var hs := house_size()
	draw_set_transform(house_base(), rot, Vector2.ONE)
	# House-local: x along the floor, y up is negative.
	var body := Rect2(-hs.x * 0.5, -hs.y, hs.x, hs.y)
	draw_rect(body, Color("8a6a4a"))
	draw_rect(body.grow(-3), Color("5a3f2a"))
	var roof := PackedVector2Array([Vector2(-hs.x * 0.5 - 6, -hs.y), Vector2(hs.x * 0.5 + 6, -hs.y),
		Vector2(0, -hs.y - hs.x * 0.32)])
	draw_colored_polygon(roof, Color("9a4a3a"))
	draw_polyline(PackedVector2Array([roof[0], roof[2], roof[1]]), Color("2a1a14"), 2.0)
	draw_rect(body, Color("2a1a14"), false, 2.0)
	# Chimney and a round attic window.
	draw_rect(Rect2(hs.x * 0.22, -hs.y - hs.x * 0.3, 8, 14), Color("7a3a2a"))
	draw_circle(Vector2(0, -hs.y - hs.x * 0.12), 5.0, Color("f0d890"))
	draw_arc(Vector2(0, -hs.y - hs.x * 0.12), 5.0, 0.0, TAU, 16, Color("2a1a14"), 1.5)
	# Floors and room walls.
	var fh := hs.y / growth.house_floors
	var rw := hs.x / growth.house_rooms
	for f in range(1, growth.house_floors):
		draw_line(Vector2(-hs.x * 0.5, -f * fh), Vector2(hs.x * 0.5, -f * fh), Color("8a6a4a"), 3.0)
	for rm in range(1, growth.house_rooms):
		var xx := -hs.x * 0.5 + rm * rw
		draw_line(Vector2(xx, 0), Vector2(xx, -hs.y), Color("8a6a4a"), 2.0)
	# Furniture: one piece in every room, the trophies stand on them.
	for k in growth.house_spots():
		var room := k % growth.house_rooms
		var fl := k / growth.house_rooms
		var cx := -hs.x * 0.5 + (room + 0.5) * rw
		var fy := -fl * fh
		match k % 3:
			0:   # a little table
				draw_rect(Rect2(cx - 8, fy - 6, 16, 2), Color("c8a070"))
				draw_line(Vector2(cx - 6, fy - 4), Vector2(cx - 6, fy), Color("c8a070"), 1.5)
				draw_line(Vector2(cx + 6, fy - 4), Vector2(cx + 6, fy), Color("c8a070"), 1.5)
			1:   # a rug
				draw_rect(Rect2(cx - 10, fy - 2, 20, 2), Color("b05050"))
			_:   # a stool
				draw_rect(Rect2(cx - 5, fy - 6, 10, 2), Color("d8b880"))
				draw_line(Vector2(cx, fy - 4), Vector2(cx, fy), Color("d8b880"), 2.0)
	# A door on the bed side.
	draw_rect(Rect2(-hs.x * 0.5 + 3, -14, 9, 14), Color("3a2414"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
