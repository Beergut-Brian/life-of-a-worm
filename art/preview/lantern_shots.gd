## Frames of the Lantern look in the real game (art-lantern-1). Boots the real main scene in --demo
## and stages one view, then scripts/tools/shots.sh takes the frames:
##   scripts/tools/shots.sh res://art/preview/lantern_shots.tscn 6 out --demo --lantern-shot=xs
## Shots: xs (ring cross-section, sky to core, both worms, an eaten hole with its daylight shaft).
## Add --lantern=off for the same frame without the Lantern look (the "before" of compare.png).
extends Node

var shot := "xs"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lantern-shot="):
			shot = a.get_slice("=", 1)
	add_child(load("res://scenes/main.tscn").instantiate())
	await get_tree().create_timer(1.5).timeout
	var level := get_tree().root.find_children("*", "PlanetLevel", true, false)
	if level.is_empty():
		push_warning("lantern_shots: no planet")
		return
	if shot == "xs":
		_xs(level[0])


func _xs(level: PlanetLevel) -> void:
	var rings: RingsDirector = get_tree().get_first_node_in_group(&"rings")
	var world := level.world
	var a := 0.0
	# an eaten hole through the crust (the daylight shaft) and a tunnel down from it
	for i in 30:
		var c := world.shape.cell_at(rings.polar(a + 0.004, 1.0 - i * 0.004))
		world.dig(c, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(2, 0)])
	level._carve(rings.polar(a - 0.01, 0.62), 70.0)      # a dirt pocket for P1
	level._carve(rings.polar(a + 0.01, 0.33), 70.0)      # a rock pocket for P2
	level._carve(rings.polar(a, 0.13), 110.0)            # a core cave: crystals, the core glow
	var p1: Worm = Worm.of(Players.P1)
	if p1:
		p1.warp_to(rings.polar(a - 0.01, 0.62))
	var p2 := level.spawn_worm(Players.P2, rings.polar(a + 0.01, 0.33), 3)
	p2.warp_to(rings.polar(a + 0.01, 0.33))
	for d in [0.12, 0.3, 0.5, 0.7, 0.9, 0.99]:
		for off in [-150.0, -75.0, 0.0, 75.0, 150.0]:
			var anchor := Node2D.new()
			anchor.position = rings.polar(a + clampf(off / (d * 300.0), -1.2, 1.2), d)
			world.add_child(anchor)
			world.track(anchor)
	world.update_chunks(-1)
	var cam := Camera2D.new()
	cam.position = rings.polar(a, 0.5)
	cam.rotation = PolarCamera.up_rotation(cam.position)
	cam.ignore_rotation = false
	cam.zoom = Vector2.ONE * 0.21
	world.add_child(cam)
	cam.make_current()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_cam = cam


var _cam: Camera2D


func _process(_d: float) -> void:
	if _cam and not _cam.is_current():
		_cam.make_current()
