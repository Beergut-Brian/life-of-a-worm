## A visible thing that drifts by in space (D105 content, stage 7; data in data/rings/space_sights.tres,
## played by SpaceSights, a child of scenes/levels/space_stage.tscn). A few small bodies of its own
## food come in from the edge of the view in a shape the kid can read: a loose drifting clump
## (SWARM), a fast line streaking past (STREAK), a ring round the worms (RING) or a single file
## (TRAIL). They are ordinary SpaceDrift smalls (kind &"sight"): bigger eats smaller, a body bigger
## than the worm bumps it back like a big planet. Nothing steers a worm; nothing is saved.
class_name SpaceSight
extends Resource

enum Shape { SWARM, STREAK, RING, TRAIL }

@export var id: StringName
## What each body is (size_stage, colour, radius; flavour is only read by the disk).
@export var food: FoodData
@export var count := 4
@export var shape := Shape.SWARM
## Space seconds the worms spend in space before the first one, then between later ones.
@export var first_after := 60.0
@export var every := 240.0
## Only after this many themed planets have been eaten (0 = from the first minute in space).
@export var after_planets := 0
## px/s it drifts at (STREAK: its streaking speed). RING: the ring's radius in px.
@export var speed := 40.0
@export var distance := 520.0
## Existing cue (Audio.play) when it arrives.
@export var cue := "space_drift"
