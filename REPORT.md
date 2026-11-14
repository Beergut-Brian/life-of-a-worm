# REPORT: worm-gap-close-37 (UI and HUD gap-close)

Branch `feature/worm-gap-close-37`, based on `origin/dev` at `6b18824` (merged `origin/dev` first:
already up to date). Not pushed: the producer ships.

## What changed

**One hint panel per player (C-24, moves P-13 on).** Dev had a single shared panel, bottom-right,
lit when *any* worm could carry or was in the burrow, with green pictures for both players. Now:

- `HintRules` (`scripts/ui/hint_rules.gd`) is a pure rule set: `rows_for(ctx)`, `hot_for(ctx)`,
  `visible_rows(ctx, awake)`, `glyph_for(ctx)`, `signature(ctx)`, `refusal_for(button, solo)`.
  No nodes, no state; the tests drive it directly.
- `PlayerHints` (`scripts/ui/player_hints.gd`) draws one player's panel: glyph + picture per row,
  edged in the player's colour, green bottom-left and red bottom-right (clear of the stage icons
  at the top). Lit rows pulse. It **folds to its lit rows after 8 s with no change** (a thin
  coloured tab when nothing is lit), so two panels never sit over the play area for long. A new
  context, Select or a refused press opens it again.
- Context is per worm now: `PlanetLevel.hint_context(w)` (carry ready / carrying, what held B warps
  to, partner lost, the bed's wall), then `HomeSlice` adds the swap shop and the tackle box's new
  page for each worm. `PlanetHud.set_player_context(player, ctx)` feeds the panel, and
  `keep_panels` drops a panel when its worm leaves.
- New context row: **held B back to your partner**. When the partner is far and one of the two is
  off screen, the B row shows the partner worm with a pull arrow and lights (the warp target
  follows `_on_warp_requested`: partner if you are not ahead, else home).

**Head glyph (C-25).** `ReadyGlyph.token` comes from `HintRules.glyph_for`: A swap, X carry,
Y wall, and new: B when the partner is lost. `ReadyGlyph.refuse(tok)` shows a refused press's
glyph there with a steady side-to-side shake for 0.6 s.

**Every press answers (C-26, K-15).** `PressAnswer` (`scripts/ui/press_answer.gd`, made by
PlanetHud, `_unhandled_input` only, so the pause menu, menus and cutscenes never reach it): in
play, Select alone (outside solo; not while Start is held, which is the solo hold), keyboard R,
LB / RB and the stick clicks now play `bonk`, pop the worm, shake that button's glyph over *that
player's* worm (Select glyph, stick glyph; shoulders have no glyph art, so only the panel shakes)
and open that player's panel, which shows the buttons that do work. A, B, X, Y, Start and the
d-pad are never refused; the guide button is left to the launcher.

Text-free: the new files have no text nodes or string drawing; a test greps their source for the
same calls `test_hud_has_no_numbers_or_words` bans. No image or audio files added (existing
`UiStyle.draw_glyph` glyphs, existing `bonk` cue, drawn placeholder pictures like the old panel's).

## Sync (first commit)

| Row | Was | Now | Proof |
| --- | --- | --- | --- |
| P-11 | partial | built | `test_lobby::test_lobby_menu_has_text_labels`; `test_hud_stage_icon::test_hud_has_no_numbers_or_words`, `::test_gameplay_screen_has_no_visible_text`; `test_hint_rules::test_hint_pieces_draw_no_text`. Menu half and gameplay half (K-10) are both built |
| P-13 | built | built, moved on | one panel per player (C-24); `tests/test_hint_rules.gd` |
| K-15 | built | built, moved on | Select alone, shoulders, stick clicks answered (C-26) |
| P-06 / K-13 / K-11 | built | unchanged | Checked against code: pause has Resume, Main menu, Settings, Back to Open Jar with the big door icon (`pause_menu.gd` asks, then `Game.quit()`); the lobby's Back to Open Jar bar does the same (`lobby.gd`); Continue / New world on the dock (K-11, `tests/test_fresh_start.gd`). Nothing to build |
| R-05 | partial | unchanged | Not a UI row: still waits on Reel's revised bible (Y-13) and worm personalities |
| R-07 | missing | unchanged | Not a UI row (ring chapters with their cutscenes); gameplay and story lanes |
| P-05 | partial | unchanged | Code side done; waits on the dock art (held for direction) |

The brief's "R-05 and R-07-style rows (every press answers; show the buttons that matter)" read as
the feel rules, which are K-15 (every press answers) and P-12 / P-13 (show the buttons); those are
the rows moved above.

## Moved row IDs

- **P-11** partial → built (sync)
- **P-13** built, proof moved on
- **K-15** built, note moved on
- **C-24**, **C-25**, **C-26** new rows (source S9, this brief), built

Totals: 267 rows: 202 built, 32 partial, 21 missing, 5 superseded, 4 dropped, 3 later.

## Skipped

- No unmerged `origin/feature/worm-*` or `origin/fix/*` branches besides the held art branches
  (`art-rings-1`, `art-worms-1`), so no file was off-limits from origin.
- `feature/worm-gap-close-36` (local, parallel, gameplay): touches `scripts/burrow/burrow_wall.gd`,
  PLAN-STATUS D-13 / K-14; none of those touched here.
- **Overlap with local, unpushed branches (producer, please read):**
  - `feature/worm-gap-close-4` commit `adbc7ab` built a per-player `HintPanel`
    (`scripts/planet/hint_panel.gd`) and rewrote `planet_hud.gd`, `planet_level.gd`,
    `home_slice.gd` and the P-13 row. It never reached origin. This branch supersedes that commit
    (same idea, plus pure `HintRules`, folding, the partner-lost row and refusals); merging both
    would conflict in those three files. Drop `adbc7ab` if gap-close-4 is ever shipped. Its other
    commits (P-08, P-17 tests) do not overlap.
  - `feature/worm-gap-close-6` (local) moves P-11 to built with the same conclusion; trivial
    conflict on that row only.
- Space (stage 7) has no PlanetHud, so no hint panel or refusal answers there yet:
  `scripts/space/` belongs to the space lane and `space_stage.tscn` gets its HUD there.
- Shoulder buttons have no glyph in `UiStyle.GLYPHS`; a shoulder press shakes the panel only.
  An `lb`/`rb` glyph is an art-lane ask.
- `docs/ui.md` is the template's menu doc; not edited.

## Tests

- New: `tests/test_hint_rules.gd`, 10 cases (6 pure rule cases, 4 live in a real planet).
- Touched callers kept green: `test_hud_stage_icon.gd` (5), `test_swap_shop.gd` (5;
  `HomeSlice.token_for` now delegates to `HintRules.glyph_for`).
- Full suite on a clean import (`.godot/` removed, `--import`, then GdUnitCmdTool `-a tests`):
  **875 test cases, 0 errors, 0 failures, 0 orphans**, exit 0, no ObjectDB leak line.

## Frames

Taken with `scripts/tools/shots.sh res://.scratch/hints_shot.tscn 0.9,1.15,2.4,3.6` (staging scene
in `.scratch/`, not committed), looked at, kept in `handoff/frames/`:

- `handoff/frames/h01_hint_panels_per_player.png`: green panel bottom-left with X carry lit and X
  blinking over green's head; red's panel bottom-right, plain.
- `handoff/frames/h03_select_refused_red.png`: red pressed Select alone: the Select glyph shakes over
  red's worm (red's panel shakes, not in a still), green keeps its X.
- `handoff/frames/h01_panels_folded.png`: after the quiet time: green folds to its one lit X row,
  red to a thin red tab. Play area clear.
- `handoff/frames/h02_partner_lost_b_row.png`: red off the far side (edge arrow at the bottom): both
  panels open again with the held-B "back to partner" row lit.

Look check: full panels are 150 x ~300 px in the bottom corners (same footprint as dev's single
panel, now one per side); folding keeps them small in normal play. Nothing covers the worms or
the stage icons.
