# REPORT: worm-gap-close-38 (branch `feature/worm-gap-close-38`)

Gap-close lane, third fill. World content only: code logic and data, no image or audio files.

## Moved rows

| Row | From | To | Proof |
| --- | --- | --- | --- |
| X-01 | partial | **built** | `tests/test_sweet_tooth.gd` (6 cases); frames `handoff/frames/x01_sweet_tooth_pink_stripes.png`, `x01_sweet_tooth_crop3x.png` |
| K-08 | partial | partial (moved on) | `tests/test_pillbug_stands_out.gd` (4 cases); frames `handoff/frames/k08_pillbug_raspberry.png`, `k08_pillbug_raspberry_crop3x.png` |
| D-11 | built | built (note) | an 11th hybrid, `data/traits/sweet_tooth.tres` |
| A-13 | partial | partial (sync note only) | art still held for direction |

Totals: 264 rows, 199 built (was 198), 32 partial (was 33), 21 missing, 5 superseded, 4 dropped, 3 later.

## What changed

1. **Sync (first commit, `worm: sync content rows ...`).** I rechecked the content rows on dev that no
   sibling is building. Only X-01 and K-08 had open content clauses: A-13 is art (held) and S-18 is
   space (off-limits). Every other food, creature, hazard, book, swap shop, secret and castings row
   was already built. Sync notes are on X-01, K-08 and A-13.
2. **X-01, "sometimes the only source of a hybrid" (Gary's pick, in GAME.md's decisions).** I added
   a seventh flavour, `sweet`, with its own pink stripe in `data/traits/worm_rules.tres`. Exactly one
   food in the world carries it: the jam drops in Old Reel's buried picnic basket
   (`data/foods/jam_drop.tres`, root before this change). Sweet + bug makes a new 11th hybrid,
   **Sweet tooth** (`data/traits/sweet_tooth.tres`): top speed x1.15, burst recharge x0.6, a
   code-drawn round sweet on its back, and Wriggle's sting. Only a worm that found the basket can
   grow it. It shows up on the trait wall and in the book automatically, because both read
   `data/traits/`. I changed no existing recipe, food count or tuning number, so D105 is untouched.
   The jam still regrows (300 s), so both worms can earn it.
3. **K-08, the deep-rock apex pill bug.** Its shell was slate blue `#4a6890`, the rock's own hue
   (hue gap 0.02), so it hid in the ground. It is raspberry now: `#b2386e` as a threat and pale
   pink `#ffd6ea` once it is food (`ApexBeetle.shell_color`). Its book page
   `data/apexes/apex_pillbug.tres` matches (colour and accent). In the real frame it reads bright
   pink on the navy rock. K-08 stays partial only for ground luminance, which is the Lantern
   textures (Art, held).

## Frames (real renders, looked at)

- `handoff/frames/x01_sweet_tooth_pink_stripes.png` and `x01_sweet_tooth_crop3x.png`: a live
  `planet.tscn` worm that ate 3 honeydew and 4 jam drops. It wears pink and orange stripes. The run
  logged `earned [wriggle, sweet_tooth]` and segments `... bug x4, sweet x6`. Next to it is the pill
  bug in its pale "food" look, because 20 segments make this worm size stage 5.
- `handoff/frames/k08_pillbug_raspberry.png` and `k08_pillbug_raspberry_crop3x.png`: an unfed
  stage-3 worm next to the pill bug. The pill bug is a threat here and shows a bright raspberry
  shell on the navy rock.
- Driver: `.scratch/gc38_shot.tscn` (env `GC38_STAGE`, `GC38_FEED=0`), run with
  `scripts/tools/shots.sh res://.scratch/gc38_shot.tscn 4 <out>`.

## Tests

- New: `tests/test_sweet_tooth.gd` (6) and `tests/test_pillbug_stands_out.gd` (4).
- Passed alone after the change: test_hybrids, test_data_files_complete, test_traits_stripes,
  test_secrets_3, test_traits_visible, test_float_slick, test_deep_apexes, test_book_creatures,
  test_art_lantern.
- Full suite on a clean import (`.godot` removed): see "Full suite" below.

## Skipped

- `feature/worm-gap-close-36` (local, 2 commits, plus uncommitted work): it changes `burrow_wall.gd`,
  `tin_fresh.gd`, `pause_cover.gd`, `scenes/main.tscn` and `docs/kid-check.md`, and builds N2 / D-13
  (wall lets go) and C-08 / K-11 (pause cover). I did not touch any of these.
- `feature/worm-gap-close-37` (worktree only, uncommitted): it changes `home_slice.gd`,
  `planet_hud.gd`, `planet_level.gd` and `ready_glyph.gd` (UI, HUD, hints). I did not touch any of these.
- `origin/feature/art-rings-1` and `origin/feature/art-worms-1`: art, held, ignored as instructed.
- Stale local branches that touch nearby files (`feature/worm-gap-close-2` secret_spot.gd,
  `feature/worm-gap-close-6` secret_data.gd, `feature/worm-star-traits-1` worm_rules.tres, all dated
  2026-11-12 and already superseded or on dev): I kept off `secret_spot.gd` and `secret_data.gd`
  anyway. That is why the find bubble does not show the hybrid. The pink stripes are the cause shown.
  `worm_rules.tres` only gains one list entry and one colour.
- Still blocked: A-13 (art), S-18 (space, off-limits), K-08 item (1) (Lantern textures, Art).

## Full suite

`rm -rf .godot`, `godot --headless --path . --import`, then
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests`:
**875 test cases, 0 errors, 0 failures, 0 flaky, 0 orphans**, exit 0.
