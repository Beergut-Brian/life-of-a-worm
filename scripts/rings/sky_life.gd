## The sky ring (GAME.md Rings, W-07): a RingLife for the band of air above the surface. The sky
## has no tiles (rings.tres stops at the surface), so its band, the stage that can eat in it and its
## regrow time live here with its species and scattered foods (data/rings/sky_life.tres).
## No threats: clouds, toy planes and balloons are things a worm bumps (too small: it bonks off,
## the food looks smug) or pops (big enough: it eats them). The stuck balloon (X-06) is SkyBalloon.
class_name SkyLife
extends RingLife

## The band of air, as fractions of the planet radius (1.0 = the top of the grass).
@export var inner := 1.03
@export var outer := 1.45
## Smallest worm stage that can eat (pop) the sky's foods; every sky food has this size_stage.
@export var edible_from := 5
## Planet seconds before an eaten cloud, plane or balloon is back where it was.
@export var regrow_time := 150.0
## The stuck balloon (SkyBalloon): angle from the start (radians), its height as a fraction of
## the planet radius, the string length in px, and the tie (data/foods/<tie>.tres) that pops it.
@export var balloon_angle := 0.035
@export var balloon_height := 1.1
@export var balloon_string := 110.0
@export var balloon_tie: StringName = &"balloon_tie"
@export var balloon_color := Color("e8483a")
## The sky's birds (SkyFlock, W-07): flocks of little birds circling the band of air. Never food,
## never a threat: a worm coming near startles a flock (a tweet, the birds burst apart and flap
## up), and it settles back into its V a moment later. flock_speed is radians a second round the
## planet; flock_startle is how close (px) a worm's head comes before they scatter.
@export var flocks := 3
@export var flock_birds := 5
@export var flock_speed := 0.012
@export var flock_startle := 260.0
@export var flock_cue := "bird_tweet"
@export var flock_colors: Array[Color] = [Color("ffd23f"), Color("f08a3c"), Color("ff7ad9")]
