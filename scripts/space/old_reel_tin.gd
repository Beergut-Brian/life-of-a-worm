## Old Reel's next tin (S-12). After the sun, Reel offers another bait tin: a new planet (its own
## seed) on the dock rail, with one trait the player earned kept as an heirloom.
##
## In the tin whose sun was eaten, key "old_reel_tin" (KEY) remembers the offer, so it is made
## once per tin and never twice:
##   { seed, theme, slot, player, heirloom, picked }
##     seed     the new planet's seed (never the old tin's)
##     theme    a PlanetData id: the first planet of the new seed's space order (SpaceDrift.shuffled)
##     slot     "tin1".."tin3" it went into, "" while every rail spot is full (placed later)
##     heirloom the trait chosen ("" until picked; "" for good when nothing was earned)
## The new tin's own file holds only { seed, theme, heirloom: {trait, from} }: no "planet", so the
## dock shows it as a new planet and PlanetLevel builds it from the seed. On every worm that spawns
## in it, give() earns and equips the heirloom (an extra slot at stage 1, where there are none).
## Only real tins ("tin1".."tin3") make offers: the demo and the profile's own file never do.
class_name OldReelTin
extends RefCounted

const KEY := "old_reel_tin"
const HEIRLOOM_KEY := "heirloom"
const THEME_KEY := "theme"
const SEED_RANGE := 100000


## True when the open save is a real bait tin (only those make offers).
static func in_real_tin() -> bool:
	return Save.slot.begins_with("tin")


static func offer() -> Dictionary:
	var d = Save.get_value(KEY, {})
	return d if d is Dictionary else {}


static func offered() -> bool:
	return not offer().is_empty()


## The new planet's seed: from the old one, never equal to it.
static func next_seed(old_seed: int) -> int:
	var s := absi(hash([old_seed, "old_reel"])) % SEED_RANGE
	return (s + 1) % SEED_RANGE if s == old_seed else s


## The new tin's planet type: the first of its seed's space order (the existing random-order rule).
static func theme_for(seed_value: int) -> StringName:
	var life := load(SpaceDrift.LIFE_PATH) as SpaceLife
	if life == null or life.planets.is_empty():
		return &""
	return SpaceDrift.shuffled(life.planets, seed_value)[0].id


## Traits `player` has earned in this tin (the saved worm and any live planet worm), in earned
## order, only ones the rules know. Never anything not earned.
static func earned_traits(player: int, rules: WormRules = null) -> Array[StringName]:
	if rules == null:
		rules = WormRules.default_rules()
	var out: Array[StringName] = []
	var worms = Save.get_value("worms", {})
	if worms is Dictionary and worms.get(str(player)) is Dictionary:
		for t in (worms[str(player)] as Dictionary).get("earned", []):
			_add_known(out, StringName(t), rules)
	for w in Worm.all():
		if w.player == player and w.model != null:
			for t in w.model.earned:
				_add_known(out, t, rules)
	return out


static func _add_known(out: Array[StringName], id: StringName, rules: WormRules) -> void:
	if not out.has(id) and rules.find_trait(id) != null:
		out.append(id)


## A free spot on the rail: a tin slot with no file at all (never overwrites a tin), not this one.
static func free_slot() -> String:
	for i in BaitTins.COUNT:
		var s := BaitTins.slot_name(i)
		if s != Save.slot and not FileAccess.file_exists(Save.path_for(s)):
			return s
	return ""


## Make the offer once: the new seed, its planet type and a rail spot. A second call returns the
## first offer unchanged. {} outside a real tin.
static func make(player: int) -> Dictionary:
	if offered():
		return offer()
	if not in_real_tin():
		return {}
	var s := next_seed(int(Save.get_value("seed", 0)))
	var d := { "seed": s, "theme": String(theme_for(s)), "slot": "", "player": player,
			"heirloom": "", "picked": false }
	Save.set_value(KEY, d)
	place()
	return offer()


## Put the offered tin on the rail if it has no spot yet (all three were full when it was made).
static func place() -> bool:
	var d := offer()
	if d.is_empty() or String(d.get("slot", "")) != "":
		return false
	var s := free_slot()
	if s == "":
		return false
	d["slot"] = s
	Save.set_value(KEY, d)
	_write_tin(d)
	Save.flush()
	return true


## The player's choice. Only a trait they earned is accepted; once picked it stays.
static func choose(id: StringName) -> bool:
	var d := offer()
	if d.is_empty() or bool(d.get("picked", false)):
		return false
	if id != &"" and not id in earned_traits(int(d.get("player", 0))):
		return false
	d["heirloom"] = String(id)
	d["picked"] = true
	Save.set_value(KEY, d)
	_write_tin(d)
	Save.flush()
	return true


static func _write_tin(d: Dictionary) -> void:
	var slot := String(d.get("slot", ""))
	if slot == "":
		return
	var path := Save.path_for(slot)
	if FileAccess.file_exists(path):
		var have = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (have is Dictionary and have.has(HEIRLOOM_KEY)) or (have as Dictionary).has("planet"):
			return   # someone else's tin (or this one already played): never overwritten
	DirAccess.make_dir_recursive_absolute(Save.dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("OldReelTin: could not write %s" % path)
		return
	f.store_string(JSON.stringify({ "seed": int(d.seed), THEME_KEY: String(d.get("theme", "")),
			HEIRLOOM_KEY: { "trait": String(d.get("heirloom", "")), "from": Save.slot } }, "\t"))
	f.close()


## The heirloom of the tin open now (&"" when it has none).
static func heirloom() -> StringName:
	var h = Save.get_value(HEIRLOOM_KEY, {})
	return StringName(String(h.get("trait", ""))) if h is Dictionary else &""


## Hand the open tin's heirloom to a worm that just spawned: earned and equipped (the trait's own
## reveal plays: its sting, the ring, the part pops on). Once it is earned the normal slot rules
## apply, except at stage 1 (no slots yet), where the heirloom stays on. True if anything changed.
static func give(w: Worm) -> bool:
	var id := heirloom()
	if id == &"" or w == null or w.model == null or w.model.rules.find_trait(id) == null:
		return false
	var m := w.model
	if not id in m.earned:
		m.earned.append(id)
		if not id in m.active:
			m.active.append(id)
		m._resolve()
		m.trait_earned.emit(id, true)
		m.traits_changed.emit(m.active.duplicate())
		return true
	if not id in m.active and m.slots() == 0:
		m.active.append(id)
		m._resolve()
		m.traits_changed.emit(m.active.duplicate())
		return true
	return false
