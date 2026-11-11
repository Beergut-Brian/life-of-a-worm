extends Node2D
## Art-direction preview (Life of a Worm, options round 1). Not game code; excluded from exports.
## Composes the layers baked by art/tools/make_frames.py and adds Godot lights, CanvasModulate,
## particles and glow. Pick the frame with user args:
##   scripts/tools/shots.sh res://art/preview/preview.tscn 1.2 <out_dir> --look=b --shot=xs
## shot: xs (ring cross-section), planet, dock.

const ROOT := "res://art/preview/"

var look := "a"
var shot := "xs"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look="):
			look = arg.trim_prefix("--look=")
		elif arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	var f := FileAccess.open(ROOT + look + "/" + shot + ".json", FileAccess.READ)
	if f == null:
		push_error("preview: no data for %s/%s" % [look, shot])
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var zoom := float(data.get("zoom", 2))
	var off: Array = data.get("offset", [0, 0])
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if data.get("glow", false):
		get_viewport().use_hdr_2d = true
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
	for layer_data in data["layers"]:
		var layer := CanvasLayer.new()
		layer.layer = int(layer_data["layer"])
		layer.scale = Vector2(zoom, zoom)
		layer.offset = -Vector2(off[0], off[1]) * zoom
		add_child(layer)
		if layer_data.has("modulate"):
			var cm := CanvasModulate.new()
			cm.color = Color(layer_data["modulate"])
			layer.add_child(cm)
		for item in layer_data["items"]:
			match item["t"]:
				"sprite": layer.add_child(_sprite(item))
				"light": layer.add_child(_light(item, int(layer_data["layer"])))
				"particles": layer.add_child(_particles(item))


func _tex(name: String) -> Texture2D:
	var path := ROOT + look + "/" + name
	if not FileAccess.file_exists(path):
		path = ROOT + name
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img)


func _sprite(item: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.position = Vector2(item["pos"][0], item["pos"][1])
	s.z_index = int(item.get("z", 0))
	var n = item.get("normal")
	if n != null:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = _tex(item["tex"])
		ct.normal_texture = _tex(n)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.texture = ct
	else:
		s.texture = _tex(item["tex"])
	var blend = item.get("blend")
	if blend != null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL if blend == "mul" else CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	return s


func _light(item: Dictionary, layer: int) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _tex(item["tex"])
	l.position = Vector2(item["pos"][0], item["pos"][1])
	l.color = Color(item["color"])
	l.energy = float(item["energy"])
	l.texture_scale = float(item["scale"])
	l.height = float(item.get("height", 24))
	l.range_layer_min = layer
	l.range_layer_max = layer
	l.range_z_min = -10
	l.range_z_max = 10
	return l


func _particles(item: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(item["pos"][0], item["pos"][1])
	p.z_index = 6
	p.amount = int(item["amount"])
	p.lifetime = float(item["lifetime"])
	p.preprocess = float(item["lifetime"])
	p.direction = Vector2(item["dir"][0], item["dir"][1])
	p.spread = float(item["spread"])
	p.initial_velocity_min = float(item["speed"][0])
	p.initial_velocity_max = float(item["speed"][1])
	p.gravity = Vector2(item["gravity"][0], item["gravity"][1])
	var sz := int(item["size"])
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	var g := Gradient.new()
	var cols: Array = item["colors"]
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in cols.size():
		g.add_point(float(i) / max(1, cols.size() - 1), Color(cols[i]))
	p.color_initial_ramp = g
	return p
