# REPORT: worm-gap-close-40 (branch `feature/worm-gap-close-40`)

Gap-close lane, fifth fill. World content only: code logic and data, no image or audio files.
Not pushed. Two new rows built, both green in the full suite on a clean import.

## Moved rows

| Row | From | To | Proof |
| --- | --- | --- | --- |
| T-05 (new) | not in the plan | **built** | `tests/test_book_things.gd` (7 cases); frames `handoff/frames/gc40-t05-book-things.png`, `gc40-t05-tackle-box-things.png` |
| W-35 (new) | not in the plan | **built** | `tests/test_loose_rocks.gd` (4 cases); frames `handoff/frames/gc40-w35-boulder-rests-falls-lands.png`, `gc40-w35-boulder-falling-full.png` |
| T-01 | built | built (note) | points at T-05 |
| W-10 | built | built (note) | points at W-35 |
| P-21 | partial | partial (sync note) | same blocker as Y-13: Reel's revised bible is on the unmerged `openjar-characters` branch `feature/jarling-bobber` |

Counted from the status column on this branch: 269 rows: 205 built, 31 partial, 21 missing,
5 superseded, 4 dropped, 3 later (dev itself counts 267 rows, 203 built; its Totals line saying 264
is stale). **I did not edit the Totals line in PLAN-STATUS.md**: gap-close-39 rewrites that line, and
editing it here would conflict. After both merge it should read 271 rows, 207 built, 31 partial.

## What changed

1. **Sync (first commit `0ee1b54`).** I rechecked every food, creature, hazard, book, swap shop,
   secret and castings row on dev. All are already built. No partial or missing row was left that
   this lane could move: what is open is art, voice, pacing, hardware runs or unmerged branches.
   So both builds below come from an audit of what the plan asks for against what the game does,
   and each is a new row (the way gap-close-39 added B-09 and X-10).
2. **T-05, the surface things have a page (Gary's pick, in GAME.md's decisions).** Eating a house or
   a cow left no mark in the book: the book listed foods, creatures, traits, secrets, cutscenes and
   planets, and the 11 things in `data/props/` are none of those. Now `things` is the seventh tab
   of the pause-menu book and the sixth tab (and lure peg) of the Y tackle box. Each sketch is the
   thing as it stands on the planet (its tile footprint and marks, drawn by the new
   `scripts/ui/prop_sketch.gd`), grey outline until found. It is found when a worm breaks one:
   the page sound plays once per kind and the Y hint glows. A bonk, or a bite that leaves it
   standing, finds nothing. The page is saved with the log in the tin. A tin whose things were
   broken before this page existed gets them on load, silently, from its saved `destruct` state.
   The full page pins a lure. The tackle box's tabs and lure pegs now share their space, so six fit.
3. **W-35, rocks of every size fall (Gary's pick, in GAME.md's decisions).** The plan says loose
   things fall toward the core, but only pebbles and apples did; a boulder hung in mid-air when a
   worm ate the dirt under it. Now the boulder, ore nugget, fossil and big boulder are loose too
   (`WorldDestruct.loose_foods`). Each rests where it lies and drops down the tunnel eaten under it,
   landing once with the existing thud, squash and dust. A big one landing within 420 px of a worm
   also nudges the camera (it honours the screen-shake setting). It never hurts and never blocks.
   Nothing moves when a planet is first built; a test checks every scattered rock on the full-size
   planet.

`docs/contracts.md` has the new page, the prop group and the longer loose list.

## Frames (real renders, looked at)

- `handoff/frames/gc40-t05-book-things.png`: the pause book on the things tab, 7 of 11 found. Found
  ones are the planet pictures; unfound ones are grey outlines; the tab row shows 7 green slots.
- `handoff/frames/gc40-t05-tackle-box-things.png`: the Y tackle box on the things page. Six tabs
  and six pegs fit the tin and the lid.
- `handoff/frames/gc40-w35-boulder-rests-falls-lands.png`: three crops from `planet.tscn`: the
  boulder resting on a plug of dirt, falling after the plug is eaten, and landed on the floor
  beside the worm.

One thing I saw in the frames and left alone: the cow's sketch is a dark brown block with spots. It
matches the cow on the planet (its placeholder tile row is dark), so it is an art question.

## Skipped

| Row or idea | Why | Owner |
| --- | --- | --- |
| B-09 every find has a trophy family | being built | `feature/worm-gap-close-39` |
| X-10 the Mole's seeds match the swap | being built | `feature/worm-gap-close-39` |
| B-05, X-07, S-18, A-04, A-13, K-08 notes | gap-close-39 edits these rows; I left them alone | `feature/worm-gap-close-39` |
| Gardens for water, junk and cloud flavours (G-03 has only root, stone, bug, crystal) | needs new garden tile rows in the Lantern atlas (art), and a new seed food would change gap-close-39's `SwapShop.seed_for` results | Art, then a content lane |
| Surface food chain links (L-01) | `data/rings/surface_life.tres` is changed on unmerged local `feature/worm-gap-close-6` | that branch |
| S-10 jar shelf, S-12 dock rail | unmerged local `feature/worm-jar-2` | that branch |
| S-01, S-18 meal, S-19, W-24 | pacing (D105, off-limits here) | Gary |
| W-09, W-23, R-01 | disk size call and GTX 1060 runs | Gary, hardware |
| A-*, U-*, P-18 to P-25, Y-01, Y-09, Y-10 | art, sound, voice, roster | Art Director, Audio |
| Y-13, Y-14, P-21 | Reel's and Bobber's bibles on unmerged `openjar-characters` `feature/jarling-bobber` | characters lane |

Files gap-close-39 changes that I did not touch: `scripts/swap_shop/swap_shop.gd`,
`data/trophies/*.tres`, `tests/test_sweet_tooth.gd`. We both edit `GAME.md` and `PLAN-STATUS.md`
(different lines); `git merge-tree` of the two branches is clean apart from this `REPORT.md`, which
both lanes rewrite (keep either). I did not run the suite on the two branches merged together.

## Tests

- Full suite, clean import (`rm -rf .godot`, `--import`), run twice: **905 test cases, 0 errors,
  0 failures** both times (dev had 894; 11 new).
- New: `tests/test_book_things.gd` (7), `tests/test_loose_rocks.gd` (4).

## Commits

- `0ee1b54` plan: sync content rows for gap-close-40 (none left to move)
- `f22994e` content: things page in the book; rocks of every size fall
- this report
