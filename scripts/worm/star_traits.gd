## The Star traits (D-10, worm-star-trait-1): one rare TraitData per space planet type, files in
## data/traits/*_star.tres (`star = true`, `star_planet` = the PlanetData id), listed in
## WormRules.traits and referenced by each PlanetData.star_trait. Never earned from flavours (no
## `requires`), never offered as a choice, never a curse (only positive adds). Earned in space by
## eating that planet (StarAward); written into the tin's worm so the trait wall lists it and it
## re-equips like any other trait.
class_name StarTraits
extends RefCounted


## The five Star traits, in WormRules order.
static func all(rules: WormRules = null) -> Array[TraitData]:
	if rules == null:
		rules = WormRules.default_rules()
	var out: Array[TraitData] = []
	for t in rules.traits:
		if t.star:
			out.append(t)
	return out


static func is_star(id: StringName) -> bool:
	for t in all():
		if t.id == id:
			return true
	return false


## The Star a planet type gives (null if none).
static func for_planet(planet_id: StringName) -> TraitData:
	for t in all():
		if t.star_planet == planet_id:
			return t
	return null


## Put an earned Star on `player`'s planet worm: the live body if there is one (hidden while in
## space), and the tin's saved body. Equips itself when a slot is free, like any new trait. Silent:
## the space reveal already showed and played it. True if anything new was written.
static func record(player: int, id: StringName) -> bool:
	var wrote := false
	for w in Worm.all():
		if w.player == player and w.model != null and not id in w.model.earned:
			w.model.from_dict(_with(w.model.to_dict(), id, w.model.rules))
			w._refresh_parts(false)
			wrote = true
	var worms = Save.get_value("worms", {})
	if worms is Dictionary and worms.get(str(player)) is Dictionary:
		var d: Dictionary = worms[str(player)]
		if not String(id) in d.get("earned", []):
			worms[str(player)] = _with(d, id, WormRules.default_rules())
			Save.set_value("worms", worms)
			wrote = true
	return wrote


static func _with(d: Dictionary, id: StringName, rules: WormRules) -> Dictionary:
	d = d.duplicate(true)
	var earned: Array = d.get("earned", [])
	earned.append(String(id))
	d["earned"] = earned
	var active: Array = d.get("active", [])
	if active.size() < rules.slots_for(int(d.get("stage", 1))):
		active.append(String(id))
	d["active"] = active
	return d
