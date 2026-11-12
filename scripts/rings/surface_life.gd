## The surface ring (GAME.md Rings, W-06): a RingLife for the grass on top of the planet and the
## small town on it. Its tiles are the last ring in rings.tres (grass, flowers); this file adds the
## counters (apples, the lawnmower: counted only, no body yet), the apples scattered on the grass,
## and the stages that bite its props. The props themselves are data/props/*.tres (PropData), stood
## on the surface by WorldDestruct; `props` lists the ones that belong to this ring.
class_name SurfaceLife
extends RingLife

## Smallest and biggest worm stage the surface's props are sized for: every prop here has
## size_stage + 1 in [edible_from, edible_to] (fences, trees, cows from 4; houses, cars from 5).
@export var edible_from := 4
@export var edible_to := 5
## Planet seconds before an eaten apple is back where it was; every scattered surface food has it.
@export var regrow_time := 120.0
## Where the scattered foods sit: just on top of the grass, as fractions of the planet radius.
@export var scatter_inner := 1.003
@export var scatter_outer := 1.008
## How far round from the start the scattered foods go, radians either side.
@export var scatter_spread := 0.4
## The surface's props (each also a data/props/<id>.tres with a scenes/props/<id>.tscn).
@export var props: Array[PropData] = []
