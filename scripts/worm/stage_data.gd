## One growth stage (a row of data/stages.tres). Pacing, size and look per stage live here and
## nowhere else: the worm, the camera and the stage-up beat read them by stage number.
class_name StageData
extends Resource

@export var stage := 1
## Kaden's stage name where known (only "Grub" is in the files; the rest are in the plan's embed).
@export var name_hint := ""
## Segments the body needs to reach this stage (stage 1 = 0).
@export var segments := 0
## The apex creature of the ring below must have been eaten too (GAME.md "Stage up").
@export var needs_apex := true
## PolarCamera.ZOOMS index cap at this stage: the camera never zooms in past it.
@export var zoom_index := 6
## Body scale against stage 1 (sprites, spacing, the tunnel the mouth eats).
@export var size := 1.0
## Head collision radius in pixels. Tiles stay 16 px at every stage (S-15).
@export var collision_radius := 6.0
## Largest food size class edible without a trait bonus (FoodData.size_stage).
@export var edible_size := 1
## The ring whose tiles open at this stage (a RingDef id; the beat points it out). &"" = none.
@export var opens_ring: StringName
## The visible feature this stage adds to the worm (WormLook.feature_texture(stage) draws it).
@export var feature_id: StringName
## Active trait slots (D-12: 1 at stage 2 to 5 at stage 6).
@export var slots := 0
## Played in the one disk scene (stages 1 to 5); 6 is the scripted chomp, 7 the space scene.
@export var in_disk := true
## From this stage the worm bites through this ring: the crust (S-08). Below it the ring is not
## food (the worm bonks off it); its eaten tiles never grow back, so the disk shrinks. &"" = none.
@export var crust_ring: StringName
