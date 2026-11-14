# Art approvals log: <game title>

Append-only. One entry per gate decision or recorded sub-decision. Never infer approval from
silence: a gate question that expires without an answer is logged as `no decision` and the gate
stays closed.

| id | date (CST) | gate | revision | options presented | owner decision (quoted) | via | conditions | blocked work released |
|---|---|---|---|---|---|---|---|---|
| A-001 | 2026-11-12 21:13 | G1 visual identity | round 1 | B+A mix / A Wet Earth / B Low Light / revise or reject / hold | "B+A mix" (Docket D99 option a, 21:13:44; same pick on duplicate D100 option c, 21:13:56) | Docket D99 (D100 duplicate) | Style-bible fixes from GATE1.md: worm light flesh moved to ΔE ≥ 20 from P2 red, 1 px dark separators beside the collar; worm body 9-10 art px at stage 1 | style bible v1.0, master package (main-character sub-decision A-002 next) |
| A-002 | 2026-11-13 21:29 | G1-sub main character | worm-master | C1 Annelid / C2 Lamplit / C3 Plated / revise / hold | "C2 Lamplit" (Docket D106 option a, 21:29) | Docket D106 | faint C1 rings on the lit top in the master; P2 keeps the second eye pixel; stage features as natural parts (producer call, Kaden may veto) | master concept (Midjourney P2 + optional P4), then image-API views |
| A-003 | | G2 first playable sample | | approve / rework | | | | ticketed production |
| A-004 | | G3 milestone / exception | | | | | | |

Gates: G1 visual identity (mandatory), G2 first playable visual sample in engine (mandatory),
G3 milestone or exception (conditional: identity change, major camera/style change, quality gap
past retry limits, material new spend or schedule change). Routine assets inside the approved style
bible are approved by the producer/AD and logged in `qa/reports/`, not here.
