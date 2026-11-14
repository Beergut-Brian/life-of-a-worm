## Nothing in play draws over the pause menu (C-08, gap-close-36). main.gd hides the CanvasLayers
## of nodes that keep running while paused (the tackle box, the book), but a paused level still drew
## its own screen layers on top of the menu: the trait wall (50), the planet HUD's glyph strip (20),
## the chomp and space overlays (5 to 85). While Game is PAUSED this hides every visible CanvasLayer
## in the arena that sits above the menu's own layer, and shows exactly those again on resume, so
## the menu is never half covered. Layers under the menu (the sky at -10 / -9) stay: the game stays
## visible behind it. A child of main.tscn's UI layer (main.gd is rewritten on another branch).
class_name PauseCover
extends Node

## The arena whose layers it covers. Set in tests; found from main.tscn otherwise.
var arena: Node
## The menu's layer: anything above it is hidden while paused.
var menu_layer := 1
## The layers this hid, shown again on resume.
var hidden: Array[CanvasLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if arena == null:
		arena = get_node_or_null("../../Arena")
	var ui := get_parent() as CanvasLayer
	if ui != null:
		menu_layer = ui.layer
	Game.state_changed.connect(_on_state)


func _on_state(_from: int, to: int) -> void:
	if to == Game.State.PAUSED:
		cover()
	else:
		uncover()


func cover() -> void:
	uncover()
	if arena == null or not is_instance_valid(arena):
		return
	for n in arena.find_children("*", "CanvasLayer", true, false):
		var l := n as CanvasLayer
		if l.visible and l.layer > menu_layer:
			l.visible = false
			hidden.append(l)


func uncover() -> void:
	for l in hidden:
		if is_instance_valid(l):
			l.visible = true
	hidden.clear()
