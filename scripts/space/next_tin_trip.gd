## The run is over, on to the next tin (S-12, R-08): a child of the SpaceStage scene. When Old Reel's
## offer is done (OldReelOffer.done: the heirloom dropped in, the lid shut, the tin slid onto the
## rail), DELAY s later the game goes back to the bait-tin dock with the new tin picked out, so a
## player who can't read the pause menu is never left in an empty sky after the sun. The dock opens
## with its own sound and picture (Dock.open, `ui_card`); A opens the tin (a new planet with the
## heirloom, and Old Reel's opening), B goes back to the lobby, left / right picks another. Nothing
## moves a worm: the trip only swaps the screen, after the player's own A on the heirloom.
## The boot scene (scenes/main.gd) is the host: `close_level()` saves the tin and frees the level,
## `dock` is its Dock. Tests set `host` to a stand-in.
class_name NextTinTrip
extends Node

signal left(focus: int)

## s after the tin is on the rail (HeirloomPick's "out" fade has finished).
const DELAY := 1.2

var offer: OldReelOffer
## The boot scene by default (anything with close_level() and a `dock`).
var host: Object
## &"idle" | &"waiting" | &"leaving" (go() is deferred) | &"gone"
var state := &"idle"
## Off in tests that drive it by hand: no timer.
var auto := true
var _wait := 0.0


func _ready() -> void:
	name = "NextTinTrip"
	offer = get_parent().get_node_or_null("OldReelOffer") as OldReelOffer if get_parent() else null
	if offer != null:
		offer.done.connect(_on_offer_done)


func _on_offer_done() -> void:
	if state != &"idle":
		return
	state = &"waiting"
	_wait = DELAY


## The dock tin the new planet went into (0..2), or -1 while every rail spot was full.
static func new_tin_index() -> int:
	var slot := String(OldReelTin.offer().get("slot", ""))
	for i in BaitTins.COUNT:
		if BaitTins.slot_name(i) == slot:
			return i
	return -1


func _host() -> Object:
	if host != null:
		return host
	var cur := get_tree().current_scene if is_inside_tree() else null
	if cur != null and cur.has_method(&"close_level") and cur.get(&"dock") is Dock:
		return cur
	return null


## Back to the dock now (the timer calls it; tests call it directly). False with no host to go to.
func go() -> bool:
	if state == &"gone":
		return false
	var h := _host()
	if h == null:
		return false
	state = &"gone"
	var focus := new_tin_index()
	h.call(&"close_level")   # saves this tin (Save.flush) and frees the level, this node with it
	var dock = h.get(&"dock")
	if dock != null:
		if focus >= 0:
			dock.focus = focus
		dock.open()
	left.emit(focus)
	return true


func _process(delta: float) -> void:
	if state == &"waiting" and auto:
		_wait -= delta
		if _wait <= 0.0:
			go.call_deferred()   # never free the level from inside its own frame
			state = &"leaving"

