## Boot scene: lobby (start screen and main menu, ready-up) -> the bait-tin dock (pick a tin) ->
## the planet (scenes/levels/planet.tscn under Arena). Worm's customisations of the template are
## made here in code: the lobby's chooser is hidden (you play a worm), its podiums show Gulp and
## Burp, Select never restarts. A pad that joins mid-game hatches its worm from an egg at once.
## The open tin saves on pause, back to the lobby and quit (and every 30 s, and on sleep).
## --demo: no lobby or dock; the scripted demo plays in its own throwaway tin.
extends Node2D

const PLANET := preload("res://scenes/levels/planet.tscn")
const PODIUM := preload("res://scripts/planet/worm_podium.gd")
## The worm names (Docket D90, Kaden, 2026-11-11). Menus, podiums, pause and logs use these.
const NAMES := { 0: "Gulp", 1: "Burp" }   # = PlanetLevel.WORM_NAMES

@onready var arena: Node2D = $Arena
@onready var lobby: Node = $UI/Lobby

## Template-kit test suites (chooser, showtime, name plate) set this to boot the plain template
## lobby: no Worm skin, chooser shown, Select restarts. The game never sets it.
static var template_only := false

var level: PlanetLevel
var dock: Dock
var tin := -1
## While paused: level nodes that run through pauses (the tackle box, a cutscene) are held still and
## their overlays hidden, so the pause menu is on top and the only thing reading the pad.
## node -> process_mode / visible, as they were.
var _held_modes := {}
var _hidden_layers := {}


func _ready() -> void:
	if not template_only:
		UiStyle.use_skin(worm_skin())
	Game.select_restarts = template_only
	lobby.chooser = template_only
	if not template_only:
		# A persistent planet has nothing to restart: the bar goes back to the start screen (and the
		# tin is saved on the way), so it says so.
		$UI/PauseMenu/Card/Buttons/Restart.text = "Main menu"
	dock = Dock.new()
	dock.name = "Dock"
	$UI.add_child(dock)
	$UI.move_child(dock, lobby.get_index() + 1)
	dock.chosen.connect(open_tin)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.round_started.connect(_on_round_started)
	Game.back_to_lobby.connect(close_level)
	Game.state_changed.connect(_on_game_state)
	if Game.demo:
		(func() -> void:
			Players.join_virtual(Players.P1)
			Game.start_round()).call_deferred()
	elif OS.get_cmdline_user_args().has("--preview-dock"):   # frames of the tin select (shots.sh)
		(func() -> void:
			Players.join_virtual(Players.P1)
			Game.start_round()).call_deferred()
	elif Game.state != Game.State.LOBBY:
		Game.to_lobby()


func _exit_tree() -> void:
	if not template_only:
		UiStyle.use_skin(null)   # the skin (texture, podium scenes) is static: release it on exit


## The lobby's look: Gulp and Burp on the podiums, the dock as the backdrop, no round card.
static func worm_skin() -> MenuSkin:
	var sk := MenuSkin.new()
	sk.title_text = "LIFE OF A WORM"
	sk.p1_name = NAMES[0].to_upper()
	sk.p2_name = NAMES[1].to_upper()
	sk.p1_character = _podium_scene(0)
	sk.p2_character = _podium_scene(1)
	sk.round_card = false
	sk.accent = Color("ffc23a")
	sk.deep = Color("2a1a14")
	sk.backdrop = MenuSkin.Backdrop.TEXTURE
	sk.backdrop_texture = dock_texture()
	return sk


static func _podium_scene(p: int) -> PackedScene:
	var n := Node2D.new()
	n.set_script(PODIUM)
	n.set("player", p)
	var ps := PackedScene.new()
	ps.pack(n)
	n.free()
	return ps


## Placeholder dock at dawn with three bait tins on the rail (the lobby backdrop).
static func dock_texture() -> Texture2D:
	var img := Image.create_empty(480, 270, false, Image.FORMAT_RGBA8)
	img.fill(Color("f2b880"))
	img.fill_rect(Rect2i(0, 95, 480, 40), Color("f7d2a0"))
	for y in range(-22, 23):
		for x in range(-22, 23):
			if x * x + y * y <= 22 * 22:
				img.set_pixel(380 + x, 112 + y, Color("fff1c8"))
	img.fill_rect(Rect2i(0, 135, 480, 135), Color("3f6f8f"))
	img.fill_rect(Rect2i(0, 168, 480, 16), Color("8a5a34"))
	for x in range(10, 480, 30):
		img.fill_rect(Rect2i(x, 184, 5, 60), Color("5e3b20"))
	img.fill_rect(Rect2i(0, 164, 480, 4), Color("6e4527"))
	for i in 3:
		var x := 300 + i * 34
		img.fill_rect(Rect2i(x, 140, 26, 24), Color("9aa4ad"))
		img.fill_rect(Rect2i(x, 140, 26, 5), Color("c3ccd3"))
		img.fill_rect(Rect2i(x, 150, 26, 8), [Color("c94a3a"), Color("3a8f5a"), Color("d9a12b")][i])
	return ImageTexture.create_from_image(img)


func _on_round_started(_round: int) -> void:
	if level != null:
		return
	if Game.demo:
		BaitTins.open_demo()
		_open_level()
	else:
		dock.open()


## The dock picked tin i: open its planet (an empty tin is a new planet).
func open_tin(i: int) -> void:
	tin = i
	var fresh := BaitTins.summary(i).is_empty()
	BaitTins.open(i)
	_open_level()
	if fresh and not template_only:
		OpeningHook.start(level)   # Y-01: a new planet starts on Old Reel's opening


func _open_level() -> void:
	level = PLANET.instantiate()
	arena.add_child(level)
	# Old Reel's heirloom (S-12): a tin made after a sun gives its chosen trait to every worm in it.
	level.worm_spawned.connect(_on_worm_spawned)
	for p in Players.active_players():
		level.spawn_worm(p)
	print("tin: %s open (%s)" % [Save.slot, ", ".join(Players.active_players().map(func(p): return NAMES[p]))])


func _on_worm_spawned(w: Worm) -> void:
	if OldReelTin.give(w):
		HeirloomBubble.show_over(w)
		print("tin: %s keeps the heirloom %s" % [NAMES.get(w.player, w.player), OldReelTin.heirloom()])


func close_level() -> void:
	dock.close()
	if level == null:
		return
	level.save_now()
	level.queue_free()
	arena.remove_child(level)
	level = null
	tin = -1
	Save.use_slot("")


func _on_player_joined(player: int, _device: int) -> void:
	if level != null and Game.state != Game.State.LOBBY:
		level.drop_in(player)
		print("drop-in: %s hatches" % NAMES[player])


func _on_player_left(player: int) -> void:
	if level != null:
		level.remove_worm(player)


func _on_game_state(_from: int, to: int) -> void:
	if to == Game.State.PAUSED:
		hold_level_for_pause()
	else:
		release_level_after_pause()


## Freeze everything under the level that would keep running (or drawing above the pause menu).
func hold_level_for_pause() -> void:
	release_level_after_pause()
	if level == null:
		return
	var stack: Array = [[level, false]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var n: Node = top[0]
		var held: bool = top[1]
		if n.process_mode == Node.PROCESS_MODE_ALWAYS:
			_held_modes[n] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_PAUSABLE
			held = true
		if held and n is CanvasLayer and n.visible:
			_hidden_layers[n] = true
			n.visible = false
		for c in n.get_children():
			stack.append([c, held])


func release_level_after_pause() -> void:
	for n in _held_modes:
		if is_instance_valid(n):
			n.process_mode = _held_modes[n]
	for n in _hidden_layers:
		if is_instance_valid(n):
			n.visible = true
	_held_modes.clear()
	_hidden_layers.clear()
