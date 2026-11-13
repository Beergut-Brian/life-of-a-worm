## The home half of the vertical slice, hosted by the planet (PlanetLevel adds one): the trophy
## bonus on every worm, the burrow growing with the stage, wild ladybirds, glow-worms and an ant
## crew to bring home as pets (the ladybird list `wild` stays ladybirds only; the others are in
## `wild_more`),
## Old Reel's tackle box on Y (TackleLog + TackleBox), the Mole's swap shop, and the extra hint
## rows and blinking glyphs for all of it. Runs after the level each frame (it is the level's
## child), so its hints and glyphs win. Saved in the tin as "home_slice" (the burrow keeps its own
## "burrow" entry: trophies, pets, pantry, stage).
class_name HomeSlice
extends Node

const LADYBIRD := preload("res://data/pets/ladybird.tres")
const SAVE_KEY := "home_slice"
## The Mole's nook and the wild ladybirds, in the start area's frame (tiles right, tiles up).
const SHOP_AT := Vector2(26, -3)
const LADYBIRDS_AT: Array[Vector2] = [Vector2(9, -4), Vector2(17, 4), Vector2(34, -1)]
## The other wild pets (feature/pets-2): [pet id, tiles right, tiles up]. Glow-worms sit a little
## deeper, the one ant crew off to the side; all away from the demo's route.
const MORE_PETS_AT: Array = [[&"glowworm", -5.0, -9.0], [&"glowworm", 30.0, -11.0], [&"ant_crew", 21.0, -7.0]]

var level: PlanetLevel
var tlog: TackleLog
var box: TackleBox
var shop: SwapShop
var wild: Array[Dictionary] = []      # {node: WildPet, gone_at}
var wild_more: Array[Dictionary] = [] # {node: WildPet, gone_at}: glow-worms and the ant crew
var _charms := {}


func _init() -> void:
	name = "HomeSlice"


func _ready() -> void:
	var saved: Dictionary = Save.get_value(SAVE_KEY, {})
	var fresh: bool = Save.get_value("planet", {}).is_empty() or saved.is_empty()
	tlog = TackleLog.new()
	add_child(tlog)
	box = TackleBox.new()
	box.tlog = tlog
	add_child(box)
	box.rewatch.connect(rewatch)
	shop = SwapShop.new()
	shop.name = "SwapShop"
	shop.world = level.world
	shop.position = level.local_point(SHOP_AT.x, SHOP_AT.y)
	shop.z_index = 2
	level.add_child(shop)
	for a in level.apexes:
		a.add_to_group(&"creature")
		a.set_meta(&"creature_id", &"beetle")
	level.burrow.bonus_changed.connect(apply_bonus)
	level.worm_spawned.connect(_on_worm)
	for w in Worm.all():
		_on_worm(w)
	if fresh:
		shop.carve_nook()
		for p in LADYBIRDS_AT:
			var at := level.local_point(p.x, p.y)
			_pocket(at, 14.0)
			_add_wild(at, -1.0)
		_more_fresh()
	else:
		from_dict(saved)


func _pocket(at: Vector2, r: float) -> void:
	var w := level.world
	var c := w.shape.cell_at(at)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var cell := c + Vector2i(x, y)
			if w.shape.center_of(cell).distance_to(at) <= r and w.is_edible_by(1, cell):
				w.dig(cell)


func _add_wild(at: Vector2, gone_at: float) -> WildPet:
	var f := WildPet.new()
	f.pet = LADYBIRD
	f.position = at
	level.foods_root.add_child(f)
	f.home = at
	var e := { "node": f, "gone_at": gone_at }
	wild.append(e)
	f.taken.connect(func(_n: Node2D) -> void: e.gone_at = level.world.clock)
	if gone_at >= 0.0:
		f.take()
		e.gone_at = gone_at
	return f


func _more_fresh() -> void:
	for e in MORE_PETS_AT:
		var at := level.local_point(e[1], e[2])
		_pocket(at, 14.0)
		_add_more(e[0], at, -1.0)


func _add_more(id: StringName, at: Vector2, gone_at: float) -> WildPet:
	var path := Burrow.PETS % id
	if not ResourceLoader.exists(path):
		return null
	var f := WildPet.new()
	f.pet = load(path)
	f.position = at
	level.foods_root.add_child(f)
	f.home = at
	var e := { "node": f, "gone_at": gone_at }
	wild_more.append(e)
	f.taken.connect(func(_n: Node2D) -> void: e.gone_at = level.world.clock)
	if gone_at >= 0.0:
		f.take()
		e.gone_at = gone_at
	return f


func _on_worm(w: Worm) -> void:
	tlog.watch_worm(w)
	if not w.tackle_pressed.is_connected(open_box):
		w.tackle_pressed.connect(open_box)
		w.stage_changed.connect(func(_p: int, _f: int, to: int) -> void: level.burrow.grow_to(to))
	level.burrow.grow_to(w.model.stage)
	level.burrow.install_wall(w)   # the trait wall is the burrow's chooser (BurrowWall)
	TrophyBonus.apply(w, level.burrow.bonus())
	if not _charms.has(w.player) or not is_instance_valid(_charms[w.player]):
		var c := TrophyCharms.new()
		c.worm = w
		c.burrow = level.burrow
		c.z_index = 4
		level.add_child(c)
		_charms[w.player] = c


func apply_bonus(bonus: Dictionary) -> void:
	for w in Worm.all():
		TrophyBonus.apply(w, bonus)


## Y (outside the trait wall): Old Reel's tackle box for this worm's player.
func open_box(player: int) -> void:
	if box.is_open:
		return
	box.open(player)
	level.save_now()


## Watch a dock scene again (picked in the box). The game waits while it plays.
func rewatch(id: StringName) -> bool:
	var story := Story.find(get_tree())
	if story == null:
		story = Story.new()
		level.add_child(story)
	if not story.play(id):
		return false
	if box.pause_tree:
		get_tree().paused = true
		story.finished.connect(func(_i: StringName, _s: bool) -> void: get_tree().paused = false, CONNECT_ONE_SHOT)
	return true


func _physics_process(_delta: float) -> void:
	for e in wild:
		if e.gone_at >= 0.0 and level.world.clock >= e.gone_at + LADYBIRD.regrow:
			e.gone_at = -1.0
			e.node.respawn()
	for e in wild_more:
		var pd: PetData = e.node.pet
		if e.gone_at >= 0.0 and level.world.clock >= e.gone_at + pd.regrow:
			if pd.wild_max > 0 and level.burrow.pet_count(pd.id) >= pd.wild_max:
				continue   # the ant crew: only one at a time, and it lives at home now
			e.gone_at = -1.0
			e.node.respawn()
	# Hints: what can be done right now, over the level's own context.
	var ctx := { "carry_ready": false, "carrying": false, "has_home": level.burrow.has_home,
		"wall": false, "swap": false, "box_new": tlog.fresh > 0 }
	for w in Worm.all():
		if w.get_parent() != level.actors:
			continue
		var carrying := w.carrying != null and is_instance_valid(w.carrying)
		var swap := bool(shop.ready_for.get(w.player, false))
		ctx.carry_ready = ctx.carry_ready or (w.carry_ready and not carrying)
		ctx.carrying = ctx.carrying or carrying
		ctx.swap = ctx.swap or swap
		ctx.wall = ctx.wall or (w.in_burrow and not w.wall_open)
		if level._glyphs.has(w.player):
			level._glyphs[w.player].token = token_for(w, carrying, swap)
	level.hud.set_rows(ctx)


## The blinking glyph over a worm's head: A at the swap shop, X near something to carry, Y asleep
## in the bed (the trait wall), else nothing.
static func token_for(w: Worm, carrying: bool, swap: bool) -> String:
	if swap:
		return "a"
	if w.carry_ready and not carrying:
		return "x"
	if w.in_burrow and not w.wall_open:
		return "y"
	return ""


# --- save -----------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var wl := []
	for e in wild:
		var n: Node2D = e.node
		wl.append([n.home.x, n.home.y, e.gone_at])
	var more := []
	for e in wild_more:
		var n: WildPet = e.node
		more.append([n.home.x, n.home.y, e.gone_at, String(n.pet.id)])
	return { "tackle": tlog.to_dict(), "shop": shop.to_dict(), "wild": wl, "wild_more": more }


func from_dict(d: Dictionary) -> void:
	tlog.from_dict(d.get("tackle", {}))
	shop.from_dict(d.get("shop", {}))
	for e in d.get("wild", []):
		_add_wild(Vector2(e[0], e[1]), float(e[2]))
	if d.has("wild_more"):
		for e in d.wild_more:
			_add_more(StringName(e[3]), Vector2(e[0], e[1]), float(e[2]))
	else:   # a tin from before pets-2: the new wild pets turn up now
		_more_fresh()
