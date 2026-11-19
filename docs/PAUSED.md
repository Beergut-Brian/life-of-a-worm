# Life of a Worm: PAUSED (Kaden, 2026-11-19)

> "Life of a worm should just be paused for now. Make sure it's clear where we are on the roadmap." (Kaden, chat 2026-11-19 ~12:05)

**No lanes, art runs, voice or music jobs start on this game until Kaden un-pauses it.** Game dev is moving to another profile; this file is the hand-off point. Read it first, then `GAME.md` and `PLAN-STATUS.md`.

## Where it stands (2026-11-19, `origin/dev` @ 15a1af7)

- **Playable?** Only as dev builds. Last release is `v0.0.2-dev.1` (2026-11-12). About 130 merges have landed on `dev` since and were never tagged or booted. Nothing is on `main` (no stable build, so the TV hides it unless LB+RB is held).
- **PLAN-STATUS:** 276 rows: 221 built, 23 partial, 20 missing, 5 superseded, 4 dropped, 3 later. Nearly all systems and content exist in placeholder (code-drawn) art; almost every open row is art, audio/voice, performance on the GTX 1060, or the release phases.

## Roadmap (GAME.md phases, rows R-01..R-11)

| Phase | Row | Status | What that means |
|---|---|---|---|
| 1a Risk prototypes | R-01 polar chunks at 60 fps | partial | Built and tested; the GTX 1060 check of 25 live chunks (W-23) was never run on the box |
| 1b | R-02 chomp, jar, space | built | |
| 1c | R-03 segmented worm, stacked traits | built | |
| 0 Design sprint | R-05 | built | GAME.md, names, story beats, Reel's bible |
| 2 Grey-box | R-04 | built | Plus far beyond it: all 7 stages of content, 8 dock scenes / 45 lines, traits, burrow, gardens, ant city, jars shelf, space book |
| **3 Vertical slice `v0.1.0`** | R-06 | **missing ← we are here** | Stages 1-2 at final quality. Blocked on art (below), music and voices |
| 4 Ring chapters `v0.2`-`v0.5` | R-07 | missing | |
| 5 Stage 6, space, ending `v0.6` | R-08 | partial | Systems built, art and planets' final content not |
| 6 Beauty pass `v0.9` | R-09 | missing | |
| 7 Release `v1.0.0` | R-10 | missing | |

## Art (Art Director pilot, branch `art/ad-pilot-1`, `art/approvals.md`)

- **Gate 1, look:** approved, A-001 "B+A mix" (Docket D99/D100, 2026-11-12).
- **Player worm:** approved, A-002 "C2 Lamplit" (Docket D106, 2026-11-13).
- **Next step (open):** the worm master in Midjourney. The pack `PROMPT-PACK-master-C2-lamplit.md` (P2 + P4) went to Kaden on 2026-11-14; no images have come back. After that: image-API supporting views, then Gate 2 (an in-engine sample of the worm idle + crawl), then the Art lanes.
- **Stale, do not merge:** PR #15 (art-rings-1) and PR #17 (art-worms-1) are the pre-Art-Director "Look B" art. Held; close or rebuild them under the AD process. Library PR `openjar-characters` #20 (Bobber, proposed) is also held.

## Open decisions and loose ends

- **Pacing (D116 a, applied):** keep K-05 (catch-up within a minute) and meet the "something new every 15 min" rule inside the current stages, with no new segments. `worm-pacing-apply-4` (PR 108) only measured; the content work that meets the rule is **not built**. First lane on resume.
- **Brian's card `worm-leader-run` (WLR1, 10-lane cap):** waits on Kaden's yes and on Brian's scope file. Paused with the game.
- **Unreleased dev:** on resume, tag `dev` and boot it before any new lane, so the next session starts from a known build.

## Resume checklist (for whoever picks it up)

1. Kaden says un-pause (and which profile runs it).
2. Tag `dev` as the next dev build, boot the zip, look at the frames.
3. D116 content lane (15-min rule inside current stages).
4. Worm master images from Kaden → image-API views → Gate 2 sample → Art lanes for the vertical slice (R-06).
5. Music (one ElevenLabs track first, with its cost), Reel and Bobber voices.
6. 1060 bench (R-01 / W-23) on the TV box.
