# REPORT: worm-old-reel-tin-1 (S-12, the story after the sun)

Branch `feature/worm-old-reel-tin-1`, based on `origin/dev` c1fe0c6. Not pushed.

## What a player sees

1. **The sun is eaten.** The space lane's beat plays as before: gold flash, glow, and the "five planets = sun" bubble.
   The offer is saved at that moment, so quitting here loses nothing.
2. **5.5 s later: Old Reel's `new_tin` dock scene.** It is a normal Story scene (letterbox, input
   locked, any button skips, camera on Reel). Bobber asks "then what?" (worm, sun, ?). Reel holds up a new bait tin (tin, planet), then tells him "a
   worm that big keeps one little thing" (worm, star, tin), hands Bobber the tin, and Bobber says "Again!". There are four new
   voiced lines (`nt_*` in `data/story/lines.json`). Each one has a `bark:` fallback, the same as the story lane's lines. No voice files exist yet.
   Frames: `handoff/shots/old-reel-tin/01`, `02`.
3. **The heirloom pick.** The new tin sits open in the middle. Its band and the planet on it show
   the new planet's type. The traits this worm has earned float above it. The stick moves a ring in the player's colour (with a tick sound), and A drops the trait
   into the tin with the trait's own sting. The lid shuts (`box_close`) and the tin slides down onto a dock rail (`jar_clink`), with a
   ring and the trait over it. Only earned traits are offered, and there is no empty choice. With nothing earned, the empty tin still goes on the
   rail. Frames `03`..`05`.
4. **The dock.** The new tin is in the next free slot, shown as "New planet" (frame `06`, TIN 2).
5. **Opening the new tin.** It builds a new planet from its own seed. Every worm that spawns gets the heirloom
   earned and equipped. The worm's own trait reveal plays (sting, ring, part pops on), and a picture
   bubble over it shows bait tin = trait = happy face. At stage 1, where there are no slots, the heirloom stays on as an extra.
   From stage 2 the normal slot rules apply. The tackle box draws a small bait tin on the heirloom's
   sketch on the traits page. `new_tin` is on the cutscenes page so it can be rewatched.

The worms are never moved. While the scene or the pick is up their stick input is ignored (steer is set to 0), so they hold still.

## Rules decided here (Gary can veto)
- **One heirloom per tin, given to both worms.** The worm that ate the sun picks from its own earned
  traits, and every worm in the new tin gets the chosen trait. This avoids co-op jealousy.
- **The rail spot** is the first tin slot with no file at all. A tin is never overwritten. If all three are
  full, the offer stays saved in the old tin (`slot: ""`) and is placed the next time space loads with a free slot.
  If the pick was not made, the pick opens again then (without the scene).
- **The planet type** is the first planet of the new seed's `SpaceDrift.shuffled` order (the existing
  random-order rule). It is stored as `theme` in the new tin.
- Offers happen only in real tins (`tin1`..`tin3`), never in the demo or the profile's own file.

## Placeholder art (said plainly)
The bait tin, the rail, the trait discs and the lid are code-drawn shapes. They reuse the dock tin's grey,
the existing trait part textures, and `StarParts` for Star traits. The dock-scene "hold"/"item" tin is
the new `bait_tin` picture.

## Follow-ups for other lanes (off-limits here)
- **UI / planet lane (`scripts/planet/dock.gd`, `bait_tins.gd`):** the dock tin should show its heirloom
  (the trait picture on the tin) and its planet type. Right now it reads only "New planet". `BaitTins.summary`
  could return `heirloom` / `theme` from the file.
- **Planet lane (`scripts/planet/planet_level.gd`):** the new planet ignores `theme`. A themed tint or
  foods would make "a new planet" visible. Also, the heirloom hook lives in `scenes/main.gd`
  (`level.worm_spawned`), so a level opened another way (`--demo`, shots) does not give it.
- **Audio:** voice files for `nt_bobber_then_what`, `nt_reel_new_tin`, `nt_reel_keep_one`,
  `nt_bobber_again`.
- **Story lane:** the `ending` scene is still not played anywhere. It could be queued before `new_tin`.
- **Systems:** `Save.dir` was added (default `user://saves`, used only by tests to write under `.scratch/`).

## Tests
`tests/test_old_reel_tin.gd` (7 cases, all saves under `res://.scratch/old_reel_saves`). The
`test_story_data` scene count is now 9. Full-suite result: see `handoff/test-output.txt`.
