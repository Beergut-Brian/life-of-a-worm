## After the sun (S-12): a child of the SpaceStage scene that hooks `SpaceDrift.sun_eaten`. Once per
## tin (OldReelTin.KEY), in a real bait tin only:
##   t = 0       the sun's own beat plays (flash, glow, the five-planets = sun bubble); the offer is
##               made at once (new seed, planet type, rail spot), so quitting now loses nothing;
##   t = DELAY   the ending, "Still out there" (Story, data/cutscenes/ending.json, Y-07; once per
##               tin, skippable), then Old Reel's "another tin" dock scene (data/cutscenes/new_tin.json):
##               letterbox, input locked, skippable, his voiced line with a picture bubble;
##   then        the heirloom choice (HeirloomPick): an earned trait into the new tin, onto the rail.
## While the scene or the choice is up the worms hold still (their stick is ignored), nothing moves
## them. A tin reloaded with the offer made but no trait picked opens the choice again (no scene).
class_name OldReelOffer
extends Node2D

signal offered(info: Dictionary)
signal picked(id: StringName)
## The choice is over (the new tin is on the rail): NextTinTrip takes the players to the dock.
signal done()

const SCENE := &"new_tin"
## Y-07: the run's ending plays first, unless this tin has seen it already.
const ENDING := &"ending"
const DELAY := 5.5          # s: after the sun bubble (SpaceStage.SUN_WHY_TIME) has been seen
const RESUME_DELAY := 1.5

var stage: SpaceStage
var story: Story
var pick: HeirloomPick
## &"idle" | &"waiting" | &"story" | &"pick" | &"done"
var state := &"idle"
## Off in tests that drive it by hand: no timers.
var auto := true
var _wait := 0.0


func _ready() -> void:
	name = "OldReelOffer"
	stage = get_parent() as SpaceStage
	process_priority = 100   # after the stage has read the stick this frame
	if stage == null:
		return
	if stage.is_node_ready():
		_hook()
	else:
		stage.ready.connect(_hook, CONNECT_ONE_SHOT)


func _hook() -> void:
	stage.drift.sun_eaten.connect(on_sun_eaten)
	if OldReelTin.offered():
		OldReelTin.place()
		if not bool(OldReelTin.offer().get("picked", false)):
			state = &"waiting"
			_wait = RESUME_DELAY
			set_meta("resume", true)


func on_sun_eaten(player: int) -> void:
	if state != &"idle" or OldReelTin.offered() or not OldReelTin.in_real_tin():
		return
	var info := OldReelTin.make(player)
	Save.flush()
	offered.emit(info)
	state = &"waiting"
	_wait = DELAY


## Old Reel's scene now (the timer calls it; tests call it directly).
func play_scene() -> void:
	if has_meta("resume"):
		remove_meta("resume")
		open_pick()
		return
	story = Story.find(get_tree())
	if story == null:
		story = Story.new()
		stage.add_child(story)
	state = &"story"
	if not story.has_seen(ENDING):
		story.play(ENDING)   # the offer's scene queues behind it (Story.play)
	if not story.play(SCENE):
		open_pick()
		return
	if not story.finished.is_connected(_on_story_finished):
		story.finished.connect(_on_story_finished)


func _on_story_finished(id: StringName, _skipped: bool) -> void:
	if id == SCENE and state == &"story":
		open_pick()


func open_pick() -> void:
	var d := OldReelTin.offer()
	pick = HeirloomPick.new()
	pick.player = int(d.get("player", 0))
	pick.traits = OldReelTin.earned_traits(pick.player)
	var theme := String(d.get("theme", ""))
	var path := "res://data/planets/%s.tres" % theme
	if theme != "" and ResourceLoader.exists(path):
		var pd := load(path) as PlanetData
		pick.band = pd.accent
		pick.planet_color = pd.color
	pick.chosen.connect(_on_chosen)
	pick.finished.connect(_on_pick_finished)
	state = &"pick"
	add_child(pick)


func _on_pick_finished() -> void:
	state = &"done"
	done.emit()


func _on_chosen(id: StringName) -> void:
	OldReelTin.choose(id)
	picked.emit(id)


## The worms hold still while Reel talks and while the choice is up.
func holding() -> bool:
	return state == &"story" or state == &"pick"


func _process(delta: float) -> void:
	if state == &"waiting" and auto:
		_wait -= delta
		if _wait <= 0.0:
			play_scene()
	if holding() and stage != null:
		for w in stage.worms:
			w.steer = Vector2.ZERO
