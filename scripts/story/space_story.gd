## Stage 7's dock scene in space (Y-08, R-08): a child of the SpaceStage scene. Reaching space is the
## stage-6 -> 7 step, but the chomp swaps the planet for this scene instead of growing a worm, so no
## worm's `stage_changed` says 7 and StageBeat never asks Story for `stage_7` ("Up it went").
## This node does: ARRIVE_DELAY s after the stage opens (the "nothing pulls down any more" bubble has
## been seen), Story plays `stage_7` once per tin (Story.seen, the tin key `story_seen`). A tin
## reloaded in space that already saw it plays nothing; one past the sun plays nothing either (the
## ending belongs to the sun, OldReelOffer). While Reel talks the worms hold still, as for his offer.
class_name SpaceStory
extends Node

const SCENE := &"stage_7"
## s: just after SpaceStage's first why bubble (WHY_TIME 4.5 s).
const ARRIVE_DELAY := SpaceStage.WHY_TIME + 0.3

var stage: SpaceStage
var story: Story
## &"waiting" | &"story" | &"done"
var state := &"waiting"
## Off in tests that drive it by hand: no timer.
var auto := true
var _wait := ARRIVE_DELAY


func _ready() -> void:
	name = "SpaceStory"
	process_priority = 100   # after the stage has read the stick this frame
	stage = get_parent() as SpaceStage
	if stage == null:
		state = &"done"


## Reel's "Up it went" now (the timer calls it; tests call it directly). False if nothing plays.
func play_scene() -> bool:
	if state != &"waiting":
		return false
	state = &"done"
	if stage != null and stage.drift != null and stage.drift.sun_gone:
		return false
	story = Story.find(get_tree())
	if story == null:
		story = Story.new()
		(stage if stage != null else get_parent()).add_child(story)
	if story.has_seen(SCENE) or story.current() == SCENE:
		return false
	if not story.play(SCENE):
		return false
	state = &"story"
	story.finished.connect(_on_story_finished)
	return true


func _on_story_finished(id: StringName, _skipped: bool) -> void:
	if id == SCENE and state == &"story":
		state = &"done"
		story.finished.disconnect(_on_story_finished)


func holding() -> bool:
	return state == &"story"


func _process(delta: float) -> void:
	if state == &"waiting" and auto:
		_wait -= delta
		if _wait <= 0.0:
			play_scene()
	if holding() and stage != null:
		for w in stage.worms:
			w.steer = Vector2.ZERO
