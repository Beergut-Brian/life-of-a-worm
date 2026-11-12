## The centipede's numbers (data/creatures/centipede.tres): a wavy chaser that gives up fast.
## Who it chases is size alone (CreatureSense: a worm smaller than size_stage is ambled toward);
## these only shape how: the wave, how long it keeps at it, how far it follows.
class_name CentipedeData
extends CreatureData

## px: how far the body swings either side of its line toward the worm.
@export var wave_amplitude := 10.0
## Swings per second.
@export var wave_rate := 0.9
## Seconds of chasing before it gives up (then turns away, visibly).
@export var chase_time := 3.0
## px: a worm this far from its head has left its reach, and it gives up at once.
@export var give_up_distance := 200.0
## Seconds it sulks after giving up before it will chase anyone again.
@export var rest_time := 3.0
## Sneaker colour (placeholder: one on every foot) and its stripe.
@export var sneaker := Color(0.96, 0.96, 0.94)
@export var sneaker_stripe := Color(0.9, 0.3, 0.25)
## Body segments drawn behind the head (legs and sneakers on each).
@export var segments := 5
