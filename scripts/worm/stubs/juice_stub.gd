## STUB of Juice (scripts/fx/juice.gd belongs to the rings-art lane). Same signatures, plain
## placeholder effects so the beat reads on screen; WormHooks uses it only while the real file is
## missing. Delete it once Juice lands.
extends RefCounted

## What the stub was asked for, in order (tests read it): [fn, args].
static var calls: Array = []


static func clear_cache() -> void:
	calls.clear()


static func chomp(pos: Vector2, colour: Color, size: float) -> void:
	calls.append(["chomp", [pos, colour, size]])
	var host := _world_host()
	if host == null:
		return
	var r := WormRing.new()
	r.color = colour
	r.max_radius = 18.0 * size
	r.life = 0.35
	r.position = pos
	r.z_index = 30
	host.add_child(r)


static func shake(strength: float) -> void:
	calls.append(["shake", [strength]])
	if not SettingsPanel.screen_shake():
		return
	var tree := Engine.get_main_loop() as SceneTree
	var cam := tree.root.get_camera_2d() if tree else null
	if cam != null and "shake" in cam:
		cam.set("shake", maxf(float(cam.get("shake")), strength))


## Two white frames, then a quick fade (the stage-up only).
static func stage_flash() -> void:
	calls.append(["stage_flash", []])
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 80
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0.9)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	tree.root.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_interval(2.0 / 60.0)
	tw.tween_property(rect, "color:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)


static func debris(pos: Vector2) -> void:
	calls.append(["debris", [pos]])
	var host := _world_host()
	if host == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(0.55, 0.38, 0.2)
	p.position = pos
	p.z_index = 30
	host.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _world_host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root
