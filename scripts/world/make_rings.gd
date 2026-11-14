## Writes data/rings/rings.tres, the prototype's ring recipe. The .tres is the source of truth once
## written (Content lane edits it in the inspector); this script only makes the first version.
##   godot --headless --path . -s res://scripts/world/make_rings.gd
extends SceneTree


func _init() -> void:
	var set := RingSet.new()
	# id, outer, tile, alt, hue, alt hue, alt share, edible from, regrow s, flavour
	var rows := [
		[&"core", 0.12, &"core_rock", &"crystal", "d8642c", "6ae8ff", 0.22, 5, 900.0, &"crystal"],
		[&"deep_rock", 0.45, &"stone", &"ore", "919fc1", "e5b854", 0.10, 4, 600.0, &"stone"],
		[&"dirt", 0.82, &"dirt", &"clay", "c48047", "c48659", 0.15, 1, 240.0, &"root"],
		[&"topsoil", 0.988, &"topsoil", &"mushroom", "b8854a", "d9c2a0", 0.08, 2, 180.0, &"root"],
		[&"surface", 1.0, &"grass", &"flower", "8bb04a", "e8d84a", 0.08, 4, 120.0, &"junk"],
	]
	for r in rows:
		var d := RingDef.new()
		d.id = r[0]; d.outer = r[1]; d.tile = r[2]; d.alt_tile = r[3]
		d.hue = Color(r[4]); d.alt_hue = Color(r[5]); d.alt_share = r[6]
		d.edible_from = r[7]; d.regrow_time = r[8]; d.flavour = r[9]
		set.rings.append(d)
	set.castings_factor = 0.25
	set.garden_interval = 4.0
	set.garden_max_radius = 10
	set.garden_tiles = {&"root": &"garden_root", &"crystal": &"garden_crystal", &"stone": &"garden_stone"}
	set.garden_hues = {&"root": Color("f0a830"), &"crystal": Color("c46cff"), &"stone": Color("dfe6f0")}
	var err := ResourceSaver.save(set, "res://data/rings/rings.tres")
	print("make_rings: ", error_string(err))
	quit(0 if err == OK else 1)
