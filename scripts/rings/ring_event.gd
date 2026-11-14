## A visible event of a ring (D105 content, data in RingLife.events): something that happens to a
## worm in that ring now and then and shows its cause on screen. A few foods pop out of the ground
## beside it (BURST, with a puff where it cracked), drop down from above it (FALL, seen falling), or
## spring up in a ring round it (RING). Played by RingEvents (a RingsDirector child).
class_name RingEvent
extends Resource

enum Shape { BURST, FALL, RING }

@export var id: StringName
## The ring it happens in (a worm's head must be in that ring's band).
@export var ring: StringName
## The smallest worm stage it happens to (the stage that opens the ring).
@export var stage_from := 1
## Planet seconds a worm spends in the ring before the first one, then between later ones.
@export var first_after := 120.0
@export var every := 300.0
## Only while it rains (G-06's shower).
@export var after_rain := false
@export var food: RingFood
@export var count := 3
@export var shape := Shape.BURST
## px from the worm's head to where it happens (BURST, FALL: beside it; RING: the ring's radius).
@export var distance := 72.0
## Existing cue (Audio.play) and RingsDirector puff kind (&"confetti", &"plant", &"leaf", &"yum").
@export var cue := "world_sprout"
@export var fx: StringName = &"confetti"
