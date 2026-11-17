## D108 a (K-06, kid mode only): the timed "new". When TimedNewClock.EVERY_S (12 min) of play pass
## with nothing new (a food, a trait, a secret, a page, a cutscene, or a timed new itself), this
## worm puts on a new look from TimedLooks: a hat on its head, a colour stripe on a few segments, a
## pattern (collar or tail), all from the worm's existing art. It pops on with the `trait_swap` cue
## (fwip-fwip and a click) and a few stars at the head: the cause is on screen, at the worm.
## Cosmetic only: no growth, no stat, no speed. Segments alone still drive stage-up.
##
## A child of scenes/players/worm.tscn (worm.gd and planet_level.gd stay untouched). New events it
## hears: the worm's own trait_earned / stage_changed (a stage-up is its cutscene), the TackleLog's
## `unlocked` (first food, creature, trait, secret, cutscene, thing) and `page_completed`, and the
## Story's `started`. The clock only counts while playing: not paused, not in a round end, not
## asleep in the burrow (the autosave state), not at the trait wall, not in the tackle box. Any
## frame gap longer than BREAK_MS (the level held for the pause menu, a cutscene holding the
## planet) or an unpause also counts as a break: the clock starts again from 0, no catch-up burst.
## Saved in the tin ("timed_new"): how far each stage's pool got, and the look on now.
class_name TimedNew
extends Node

signal fired(player: int, look: Dictionary)

const SAVE_KEY := "timed_new"
const CUE := "trait_swap"
## The hat's on-screen width on a stage-1 head (the head art is 20 px).
const HAT_PX := 20.0
const HAT_AT := Vector2(-1, -16)
## Stacked on top of what already sits on the head: the stage feature or a crown part, then a part
## floating above it (Worm.SLOT_OFFSET), so the hat never covers either.
const HAT_OVER_FEATURE := Vector2(-1, -27)
const HAT_OVER_ABOVE := Vector2(-2, -37)
const BAND_NAME := "TimedBand"
## A frame gap longer than this means the game was not playing (held, paused, a scene).
const BREAK_MS := 1000
const FIND_EVERY := 2.0

var worm: Worm
var clock := TimedNewClock.new()
## Kid mode (the default). Adult mode: the timed new never fires and no look shows.
var enabled := true
## stage -> how many of that stage's pool were shown (the pool cycles after TimedLooks.SIZE).
var shown := {}
## The look on now ({} = none yet): TimedLooks.look() plus "k".
var current := {}
var _hat: Sprite2D
var _band_sig := ""
var _tlog: TackleLog
var _story: Story
var _find_t := 0.0
var _last_ms := -1


## Kid mode unless the session is in solo playtest mode (one adult driving both worms, the
## template's Select + Start) or the game was started with `--adult`.
static func kid_mode() -> bool:
	return not Players.solo and not OS.get_cmdline_user_args().has("--adult")


func _ready() -> void:
	worm = get_parent() as Worm
	if worm == null:
		return
	enabled = kid_mode()
	worm.trait_earned.connect(func(_p: int, _t: StringName) -> void: note_new())
	worm.stage_changed.connect(func(_p: int, _f: int, _t: int) -> void: note_new())
	_load.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_ENABLED:
		clock.interrupt()


## A real new event: the timed new waits a full 12 minutes again.
func note_new(_a = null, _b = null) -> void:
	clock.reset()


func _process(delta: float) -> void:
	if worm == null or not enabled:
		return
	var now := Time.get_ticks_msec()
	if _last_ms >= 0 and now - _last_ms > BREAK_MS:
		clock.interrupt()
	_last_ms = now
	_find_t -= delta
	if _find_t <= 0.0:
		_find_t = FIND_EVERY
		_find_sources()
	if clock.step(delta, is_playing()):
		fire()
	_sync_bands()


## Is the worm in play right now (the clock counts)?
func is_playing() -> bool:
	if worm == null or not worm.is_inside_tree() or not is_inside_tree():
		return false
	if get_tree().paused or Game.state == Game.State.PAUSED or Game.state == Game.State.ROUND_END:
		return false
	if worm.asleep or worm.wall_open:
		return false
	if _tlog != null and is_instance_valid(_tlog):
		var hs := _tlog.get_parent()
		var box = hs.get("box") if hs != null else null
		if box != null and is_instance_valid(box) and box.is_open:
			return false
	return true


## Show the next look of this stage's pool now (the clock calls this; tests may too).
func fire() -> void:
	if worm == null or not enabled:
		return
	var s := worm.stage
	var k: int = int(shown.get(s, 0))
	shown[s] = k + 1
	current = TimedLooks.look(s, k)
	current["k"] = k
	clock.reset()
	_apply(true)
	Audio.play(CUE)
	_save()
	fired.emit(worm.player, current)


func _find_sources() -> void:
	if _tlog == null or not is_instance_valid(_tlog):
		_tlog = get_tree().root.find_child("TackleLog", true, false) as TackleLog
		if _tlog != null:
			_tlog.unlocked.connect(note_new)
			_tlog.page_completed.connect(note_new)
	if _story == null or not is_instance_valid(_story):
		_story = Story.find(get_tree())
		if _story != null:
			_story.started.connect(note_new)


func _apply(pop: bool) -> void:
	if current.is_empty() or worm == null or worm.look == null:
		return
	if _hat == null or not is_instance_valid(_hat):
		_hat = Sprite2D.new()
		_hat.name = "TimedHat"
		_hat.z_index = 2
		worm.look.add_child(_hat)
	var tex: Texture2D = TimedLooks.HAT_TEX[current.hat]
	_hat.texture = tex
	_hat.position = hat_spot()
	var sc := HAT_PX / float(maxi(1, tex.get_width()))
	_hat.modulate = Color.WHITE.lerp(current.colour, 0.45)
	_band_sig = ""
	_sync_bands()
	if pop:
		_hat.scale = Vector2.ONE * sc * 2.4
		var tw := _hat.create_tween()
		tw.tween_property(_hat, "scale", Vector2.ONE * sc, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in 4:
			worm._float_fx(Worm.STAR_TEX, worm.head.position + Vector2.from_angle(TAU * i / 4.0) * 14.0, current.colour, 0.9)
	else:
		_hat.scale = Vector2.ONE * sc


## The look's stripes follow the body (segments come and go, a stage-up swaps the band art).
func _sync_bands() -> void:
	if current.is_empty() or worm == null:
		return
	var segs: Array = worm._seg_nodes
	var sig := "%d|%d|%s|%d|%s" % [segs.size(), worm.stage, current.pattern, current.index, worm._parts_sig]
	if sig == _band_sig:
		return
	_band_sig = sig
	if hat() != null:
		_hat.position = hat_spot()
	var on := TimedLooks.striped(current.pattern, segs.size())
	var tex: Texture2D = WormHooks.look().segment_texture(worm.player, worm.stage, &"band")
	for i in segs.size():
		var seg: Node2D = segs[i]
		var b := seg.get_node_or_null(BAND_NAME) as Sprite2D
		if not i in on:
			if b != null:
				b.queue_free()
			continue
		if b == null:
			b = Sprite2D.new()
			b.name = BAND_NAME
			seg.add_child(b)
		b.texture = tex
		b.scale = Vector2.ONE * (WormSegment.BASE_PX / float(maxi(1, tex.get_width() if tex else 1)))
		b.modulate = current.colour


## Where the hat sits on the head (Look space) given what the worm already wears there.
func hat_spot() -> Vector2:
	var parts: Dictionary = worm._part_nodes
	if parts.has(&"above"):
		return HAT_OVER_ABOVE
	var feat := worm.look.get_node_or_null("Feature") as Sprite2D
	if parts.has(&"crown") or (feat != null and feat.visible and feat.texture != null):
		return HAT_OVER_FEATURE
	return HAT_AT


## Every stripe and the hat on screen now (tests read this).
func stripe_count() -> int:
	var n := 0
	if worm != null:
		for seg in worm._seg_nodes:
			var b = seg.get_node_or_null(BAND_NAME)
			if b != null and not b.is_queued_for_deletion():
				n += 1
	return n


func hat() -> Sprite2D:
	return _hat if _hat != null and is_instance_valid(_hat) else null


func _save() -> void:
	var all: Dictionary = Save.get_value(SAVE_KEY, {}).duplicate(true)
	var counts := {}
	for s in shown:
		counts[str(s)] = shown[s]
	all[str(worm.player)] = { "shown": counts, "stage": current.get("stage", 0), "k": current.get("k", -1) }
	Save.set_value(SAVE_KEY, all)


func _load() -> void:
	if worm == null or not enabled:
		return
	var all: Dictionary = Save.get_value(SAVE_KEY, {})
	var mine: Dictionary = all.get(str(worm.player), {})
	shown.clear()
	for s in mine.get("shown", {}):
		shown[int(s)] = int(mine.shown[s])
	var k := int(mine.get("k", -1))
	if k >= 0:
		current = TimedLooks.look(int(mine.get("stage", 1)), k)
		current["k"] = k
		_apply(false)
