# Deep rock lane report (feature/worm-deep-rock-1, 2026-11-12)

## Rows moved
- **W-03** partial -> **built**: the deep rock runs in play (rock beetles live, ore nuggets live,
  fossils scattered and regrowing, nugget and fossil have their own looks).
- **W-02** stays **partial** (notes updated): the lava blob now has a body and bounces, but
  `live_max` is still 0 so it never appears in play. That is the one thing left (see follow-ups).

## What was built
1. **Rock beetle body.** `scenes/creatures/rock_beetle.tscn` (the shared `Creature`, drawn with the
   beetle placeholder in the data's grey shell and gold spot). `deep_rock_life.tres` points
   `rock_beetle.live` at it with `live_scale 0.5`, `live_max 3`. **These two numbers are mine:** the
   data said `live_max 0` (no body), so there was no number to reuse; I took the dirt beetle's shape
   (a few bodies near the worm, start 6 -> 3 live). Tune them freely; the counter chain is unchanged
   and `test_thinning_rock_beetles_lets_ore_nuggets_build_up` stays green. Eating a live beetle thins
   the counter (tested). Also in `creature.gd`: a TRUNDLE creature that goes straight into its wind-up
   (worm already inside strike range) now turns to face the worm first; before, it could wind up
   and lunge facing away (seen in the first frames).
2. **Deep rock life in `RingsDirector.LIVES`** (that line only). 5 fossils are scattered in the deep
   rock and grow back where they were (`regrow_time` 600); ore nuggets come live from their counter.
   Side effect, same as when the core joined: fossils go into the static list before the picnic
   crumbs, sky and apples, so in an **old tin** those later slots shift (they start uneaten; the
   slot-id check already guards this) and their scattered positions move once.
3. **Nugget and fossil looks**, `RingFood.Look.NUGGET` / `FOSSIL`, drawn in code in
   `scripts/rings/ring_pickup.gd`. **These are placeholders** (no new art; held until Kaden picks the
   Worm art direction). Nugget: a lumpy gold 8-point rock with a pale facet and a twinkling glint.
   Fossil: a cream disc with a ribbed rim and a curled spiral shell. Both keep the usual face.
4. **Lava blob body and bounce (W-02).** `CreatureData.Behaviour.BOUNCE` (appended, index 6),
   `CreatureData.bounce` (px), `scenes/creatures/lava_blob.tscn` (code-drawn wobbling lava drop with
   rising bubbles and a glow). For a smaller worm (stage <= 5):
   - the telegraph: within 48 px it swells 12% and plays `lava_blob_swell`;
   - contact (head within radius + 14 px): it squashes flat toward the worm, a white burst at the
     contact point, `boing`, and the worm's head is pushed straight away 80 px over 0.45 s. The worm
     keeps its stick the whole time (the push is added to the head; heading untouched). 0.8 s
     cooldown per worm so holding against it is a slow boing-boing, not a buzz;
   - a worm bonking it also gets the existing smug squint and its bark `lava_blob_blorp` (worm code,
     unchanged).
   A stage-6 worm is never bounced; it eats the blob (tested). `core_life.tres` now points
   `lava_blob.live` at the scene, **`live_max` stays 0**, so lava blobs still never spawn.

## Tests
- New `tests/test_deep_rock.gd` (11 cases, runs in its own `SuiteSandbox` profile).
- `tests/test_rings_content.gd`: three "no scene yet" assertions now expect the scenes; the lava blob
  is BOUNCE with `bounce > 0`.
- Full suite after `rm -rf .godot; godot --headless --path . --import`: see
  `handoff/test-output.txt` (465 test cases, 0 errors, 0 failures on three runs; the third overlapped
  the second and two other lanes' gdUnit runs).

## Frames
`handoff/shots/deep-rock/` (scratch scene `.scratch/deep_rock_shot/shot.tscn`, no planet, camera
zoom 4 so the shapes read; looked at all four):
- `t000.3s`: left, the rock beetle (grey shell, gold spot) beside a stage-3 worm, the nugget and the
  fossil below; right, a stage-5 worm driving into the lava blob.
- `t001.0s`: the beetle has turned to the worm and is swelling (wind-up); the worm has been
  bounced back off the blob, which squints smug.
- `t001.6s`: the beetle lunges and gulps the small worm; the blob is squashed flat with the white
  burst at the contact point as the worm comes back in.
- `t002.0s`: the beetle mid-gulp (the worm a bulge in it); the blob back to round.

## What I could not check
- **Not seen on a real planet.** The frames are a scratch scene without `PolarWorld` (no rotation,
  no rock). In play the knock moves the worm's head directly (the lawnmower does the same), so a
  bounce could push the head a few px into solid core rock; I could not see how the worm handles
  that there. Only matters once lava blobs spawn.
- Not seen on the TV or with a controller; frame rate on the software renderer means nothing.
- K-01 size check passes for both creatures (`test_kid_checks`), but the swell (+12%) and squash
  were not checked against a stage-5 head on screen in play.
- Saves: the brief asked for `.scratch/` save paths; `Save` (systems lane, not mine) only writes to
  `user://saves/<profile>.json`, so the suite uses the standard `SuiteSandbox` profile
  `gdunit_deep_rock` instead (never the family's tin). The frames write no save.

## Follow-ups (not mine)
- **Gary (design): spawn lava blobs?** One number: `data/rings/core_life.tres` `lava_blob`
  `live_scale` / `live_max` (the counter sits at 4-10; e.g. `live_scale 0.3`, `live_max 2` gives
  1-2 near a stage-5 worm in the core). Then check a real-planet frame for the head-into-rock push
  above, and mark W-02 built.
- Art lane: replace the NUGGET / FOSSIL / lava blob / rock beetle placeholders once the Worm art
  direction is picked.
