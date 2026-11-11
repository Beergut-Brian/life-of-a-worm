## Plays one dock scene on its own, for frames and for Kaden: a grey stand-in for the game behind a
## Story node. Args after `--`: --story=<id> (default opening), --speed=<x>, --no-quit.
##   godot --path . res://scenes/story/story_preview.tscn -- --story=stage_4
##   scripts/tools/shots.sh res://scenes/story/story_preview.tscn 4,14,24,40 .scratch/shots --story=opening
extends Node

var story: Story
var quit_at_end := true
var _t0 := 0


func _ready() -> void:
	var id := &"opening"
	story = Story.new()
	story.persist = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--story="):
			id = StringName(a.get_slice("=", 1))
		elif a.begins_with("--speed="):
			story.speed = float(a.get_slice("=", 1))
		elif a == "--no-quit" or a.begins_with("--shots="):
			quit_at_end = false
	add_child(story)
	story.finished.connect(_on_finished)
	story.handoff.connect(func(sid: StringName, what: String) -> void: print("story: handoff %s %s" % [sid, what]))
	_t0 = Time.get_ticks_msec()
	story.play.call_deferred(id)


func _on_finished(id: StringName, skipped: bool) -> void:
	print("story: finished %s skipped=%s length=%.1fs said=%s" % [id, skipped, (Time.get_ticks_msec() - _t0) / 1000.0 * story.speed, story.said])
	if quit_at_end:
		get_tree().quit()
