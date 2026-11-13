# Balance: growth stages (Life of a Worm)

Data: `data/stages.tres` (a `StageTable` of seven `StageData` rows), read through
`WormRules.default_rules()` (`data/traits/worm_rules.tres`). Proof: `tests/test_balance_stages.gd`,
seeded simulated runs over that table, the real body model (`WormGrowth` + `WormStats`), the real
foods (`data/foods/*.tres`) and the worm's code constants (`Worm.TILE_GROWTH`, `Worm.BITE_RADIUS`,
`Worm.DIG_SPEED`). The test holds no copy of the numbers: it rebuilds the table below from the data
and fails if this file no longer matches (`test_the_sheet_in_balance_md_matches_the_data`).

The suite prints (seed 7; rerun it to refresh these lines after any tuning):

```
balance kid: s2 9 min (+9), s3 16 min (+7), s4 25 min (+9), s5 34 min (+9), s6 41 min (+7) | segment every 15 s | longest wait for progress 39 s
balance adult: s2 6 min (+6), s3 8 min (+2), s4 12 min (+4), s5 17 min (+5), s6 21 min (+4) | segment every 9 s | longest wait for progress 21 s
balance chapters: adult shortest stage 0.03 h (Kaden 2 h+), to the chomp 0.35 h (Kaden 15 h+)
```

## Targets

| Target | Source | Where it is checked | Today |
| --- | --- | --- | --- |
| A 5-year-old sees progress in any ten minutes | Kaden, 2026-11-10; kid check | `test_a_kid_sees_progress_in_any_ten_minutes`: longest wait for a segment or stage <= 600 s, seeds 1 to 3 | met (39 s) |
| Ordinary eating adds a segment at least every 2 minutes | GAME.md 2026-11-10 | same test: mean segment interval <= 120 s, kid profile | met (15 s) |
| Every stage is reached, in order, none a blink | GAME.md "Core loop" | `test_every_stage_is_reached_in_order`: each stage >= 1 min apart for an adult | met |
| The smaller worm catches up within a minute via shared growth (K-05) | GAME.md kid checks | `tests/test_kid_checks.gd::test_k05_the_smaller_worm_catches_up_within_a_minute_through_shared_growth`: a drop-in hatchling (partner's stage minus one, 4 segments behind at stage 3) reaches the partner's segment count within 60 s, both at the kid profile | met (level at 60 s: big +4, small +8 segments; `catch_up_boost` 3.0) |
| 2 to 4 h a stage, 15 to 25 h to the chomp | GAME.md 2026-11-10 | `test_chapter_lengths_against_kaden_are_reported` prints it, does not assert it | **not met: see "Gary's pick needed"** |

## Profiles (in the test file; keep them in sync with this table)

| Profile | Tunnelling new ground | Foods met | Apex found after it is food | Eaten |
| --- | --- | --- | --- | --- |
| kid | 35% of seconds | 0.6 a minute | ~8 min (0.5x to 1.5x) | every ~9 min (one segment) |
| adult with intent | 60% of seconds | 1.5 a minute | ~4 min | never |

Tunnelling swallows `speed * dig_speed * 2 * BITE_RADIUS * size / 16^2` tiles a second (stage 1:
80 * 0.65 * 24 / 256 = 4.9), each worth `tile_growth` (base `Worm.TILE_GROWTH`, traits can change
it). Foods are drawn at random from `data/foods`; only those at or under the stage's `edible_size`
count. A stage also needs that ring's apex eaten, so the times above include the apex hunt.

## The numbers

Rebuilt by the test from `data/stages.tres` and `WormRules` (columns: stage, segments to reach,
body size, head collision radius px, zoom cap `PolarCamera.ZOOMS` index, edible size class, trait
slots, ring it opens, feature, where it is played):

| Stage | Segments | Size | Collision r | Zoom | Edible | Slots | Opens | Feature | Played |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 1.00 | 6.0 | 6 | 1 | 0 | dirt | - | disk |
| 2 | 6 | 1.18 | 7.0 | 5 | 2 | 1 | topsoil | feelers | disk |
| 3 | 10 | 1.36 | 8.0 | 4 | 3 | 2 | - | cheek_puffs | disk |
| 4 | 15 | 1.54 | 9.0 | 4 | 4 | 3 | deep_rock | back_ridge | disk |
| 5 | 20 | 1.72 | 10.0 | 3 | 5 | 4 | core + surface (crust) | tail_tuft | disk |
| 6 | 24 | 1.90 | 11.0 | 3 | 6 | 5 | - | planet_jaw | scripted |
| 7 | 40 | 2.08 | 12.0 | 3 | 7 | 5 | - | star_shine | scripted |

| Constant | Value | Where |
| --- | --- | --- |
| tile growth per tile | 0.05 | `Worm.TILE_GROWTH` (base when no trait sets `tile_growth`) |
| growth per segment | 2.0 | `data/traits/worm_rules.tres` |
| partner share | 0.25 | `data/traits/worm_rules.tres` (`partner_share`: every bite also grows the other worm by this share of the plain bite, no flavour) |
| catch-up boost | 3.0 | `data/traits/worm_rules.tres` (`catch_up_boost`: while a worm has fewer segments than its partner, its own bites grow it this many times as much; K-05) |

The crust (stage 5, `crust_ring = surface`): the surface is food only from stage 5 and its eaten
tiles never grow back (`StageTable.apply_crust`), so the disk shrinks; the first bite through is the
breakthrough (`scripts/gameplay/crust_burst.gd`).

## Gary's pick needed

**The sheet and Kaden's chapter lengths disagree by about 40x.** On dev's `data/stages.tres` an
adult with intent reaches the stage-6 chomp in about **21 minutes** and a kid in about **41
minutes**; the shortest stage is about 2 minutes. Kaden's targets (GAME.md 2026-11-10) are **2 to 4
hours a stage and 15 to 25 hours to the chomp**. Dev's numbers fit the superseded "20 to 30 minute
full run" line (GAME.md line 32 says it is superseded). Nothing was retuned here.

The kid rule (a segment at least every 2 minutes) is met with a lot of room (one every 15 s), so the
long chapters cannot come from slower segments alone without making the worm very long: at a
segment every 2 minutes, 2 to 4 hours is 60 to 120 segments a stage, 450+ by stage 6, far longer
than a body that reads on screen. Options:

1. **Port stages-1's tuning onto dev's table**: thresholds 40 / 90 / 150 / 210 / 300 / 360 and
   tile growth about 0.004 (falling to 0.003 by stage 5). stages-1's own run of it measured about
   4 h (adult) and 9.5 h (kid) to stage 6, still short of 15 h, with a kid segment every ~93 s. It
   needs a per-stage `tile_growth` on `StageData` (dev has one global constant) and a re-run here.
2. **Keep dev's fast growth and get the hours from content**: apex hunts, ring secrets, the surface,
   stage-own foods and creatures. Nothing to tune now; the chapter length becomes a content target.
3. **Longer worms with a wider camera** or **segments that merge at a stage-up** (changes trait
   counting, which reads segment flavours).

Recommendation: 2 for now, with 1 as the playtest lever once more ring content exists; either way a
playtest should set the number, not this sheet.

## The demo tin

`--demo` runs on the same table (dev has no demo pace scale); its scripted stage-up is
`scripts/planet/greybox_demo.gd`'s.
