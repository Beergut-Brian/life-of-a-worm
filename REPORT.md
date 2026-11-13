# Audio hooks lane report (feature/worm-audio-hooks-1)

PLAN-STATUS IDs moved: **U-09, U-11, U-14** → built. No new audio, no ElevenLabs, no music (U-12 untouched).

## What changed

| ID | Where | What |
| --- | --- | --- |
| U-09 `breakthrough` | none (already wired) | `CrustBurst._burst()` (`scripts/gameplay/crust_burst.gd`) already called `Audio.play("breakthrough")`; PLAN-STATUS was out of date. I only added a test that the call resolves to the real `breakthrough.ogg` and fires once per worm per tin. |
| U-11 `space_drift` | `scripts/space/space_stage.gd` (+15 lines) | `drift_bed = Audio.loop_player("space_drift")` at `DRIFT_DB = -4.0`, `autoplay` on, added as a child in `_ready`; `_exit_tree` stops it. So it plays whenever the space stage is in the tree and stops when the stage leaves. |
| U-14 ring beds | new `scripts/audio/ring_ambience.gd`; one node added to `scenes/levels/planet.tscn` | `RingAmbience` finds the level's `world` and the lowest-numbered worm in the level, reads which ring the head is in (`RingDef.id`) and plays `amb_<id>` at `LEVEL_DB = -6.0` (constant at the top of the file). When the ring changes, the old bed fades out and the new one fades in over `FADE = 1.5` s, at the same time. Above `SkyLife.inner` (1.03 x planet radius) the id is `sky`. If an id has no `amb_<id>.ogg` it plays nothing: no placeholder beep, no warning. All beds fade out while the chomp shot or space is on screen (`level.chomp.busy()`). |

Contract: `docs/contracts.md` → `### Audio hooks (worm-audio-hooks-1)` (appended).

## Each cue: what the tests prove, what a human still has to hear

| Cue | Test proved (`tests/test_audio_hooks.gd`) | Still needs a listen on the TV |
| --- | --- | --- |
| `breakthrough` | The first crust bite at stage 5 adds 1 to `Audio.played["breakthrough"]`, and exactly one pool player holds `breakthrough.ogg` (the file, not the grey beep). Two more crust bites add nothing. Reloading the tin plays no second one (`test_stages_crust`). | Whether the crumble and birds land with the flash and debris, and whether it's loud enough over the bite cue (`burst`) that plays in the same frame. |
| `space_drift` | When the space stage enters the tree, `DriftBed` is playing `space_drift.ogg` with `loop = true` at `DRIFT_DB`. Still playing a frame later. `remove_child` stops it, adding the stage back starts it again. A planet level never has a player on `space_drift.ogg`. | Level against `warp` and the space cues (`DRIFT_DB` -4 dB on a -28 LUFS file); whether the 16 s loop seam can be heard; whether it should fade in after the warp instead of starting at full level. |
| `amb_dirt`, `amb_topsoil`, `amb_deep_rock`, `amb_core`, `amb_surface` | Every ring in `data/rings/rings.tres` has a bed file. A bed starts silent and fades up to exactly `LEVEL_DB` (below 0 dB). On a ring change, halfway through the fade both beds are playing, one going down and one going up. After the fade the old bed has stopped, and going back brings it back. On the real planet, a few frames after spawn the playing bed is the head's ring. `ring_id_at` returns dirt, topsoil and deep_rock for cells in those rings, and `sky` above the grass. When the worm is removed, the bed fades out and stops. | Whether -6 dB feels "under the music" (there is no music yet, U-12). Whether a 1.5 s crossfade is too slow or fast when a worm bobs along a ring border; if it flutters, add hysteresis. Whether the beds suit the rings. |
| unknown id / `sky` | `follow(&"no_such_ring")` and `follow(&"sky")` make no player, fade the old bed out, and play no placeholder beep (`Audio.played` stays empty). | Flying up into the sky goes quiet (the wind stops), since there is no `amb_sky`. Decide whether that's right (see follow-ups). |

## Choices made

- **Which worm in co-op:** the bed follows P1's head (or the lowest player present). Only one bed plays at a time, so two players in different rings don't mix two beds. Change `followed()` to follow the camera centre if Kaden prefers that.
- **Bus:** the beds and the drift are on the SFX bus, so the sound slider controls them, not the music slider.
- **Sky:** it follows the brief's rule, so it stays silent until an `amb_sky.ogg` exists. The other option is to alias the sky to `amb_surface` (wind).
- The node is in `scenes/levels/planet.tscn`, not `planet_level.gd` (`scripts/planet/` is off-limits). It finds `world` and `chomp` itself through `get_parent()`.

## Follow-ups for other lanes

- **Audio lane:** `assets/audio/CUES.md` still says `space_drift` has "no call site yet", and that the `amb_*` beds play when the camera is in a ring. Update both to `SpaceStage.drift_bed` and `RingAmbience` (it follows the head). Also an `amb_sky.ogg` if the sky should have its own bed.
- **Space lane:** the prototype `SpaceLevel` (`scripts/space/space.gd`, `scenes/levels/space.tscn`, used by `planet_chomp.gd`) does not play `space_drift`. If that path is still live, add the same three lines there.
- **Music (U-12):** when layered music lands, recheck `LEVEL_DB` and `DRIFT_DB` against it.

## Tests

See `handoff/test-output.txt`. The build box sometimes aborts at exit after "Exit code: 0" (known); read the Overall Summary line.
