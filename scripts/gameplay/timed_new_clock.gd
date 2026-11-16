## D108 a (K-06): the kid-mode timed "new" clock. Pure, no nodes: TimedNew (in the game) and
## tests/pacing_sim.gd (the pacing audit) step the same clock.
##   var clock := TimedNewClock.new()
##   clock.reset()                       # any real new event: a food, a trait, a secret, a page,
##                                       # a cutscene (the timed new only fills gaps)
##   if clock.step(dt, playing): ...     # true once EVERY_S of play passed with nothing new
## It counts only while `playing` is true. Any step that is not playing (a menu, the pause screen,
## a cutscene, asleep in the burrow), or interrupt(), is a break: on resume it starts again from 0,
## so there is never a catch-up burst. Firing resets it too: at most one timed new per EVERY_S.
class_name TimedNewClock
extends RefCounted

## The one timer length (D108 a, 12 minutes of play). No other tuning lives here.
const EVERY_S := 720.0

## Seconds of play since the last new event (or the last break).
var elapsed := 0.0
## Timed news fired by this clock.
var fired := 0
var _broken := false


## A real new event happened: wait a full EVERY_S again.
func reset() -> void:
	elapsed = 0.0


## The game stopped (paused, a menu, a scene): the next playing step starts from 0.
func interrupt() -> void:
	_broken = true


## Adds `dt` seconds. Returns true when a timed new is due (and resets for the next one).
func step(dt: float, playing: bool) -> bool:
	if not playing:
		_broken = true
		return false
	if _broken:
		_broken = false
		elapsed = 0.0
	elapsed += dt
	if elapsed >= EVERY_S:
		elapsed = 0.0
		fired += 1
		return true
	return false
