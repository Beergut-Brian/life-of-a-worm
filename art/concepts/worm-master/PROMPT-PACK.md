# Midjourney prompt pack: Life of a Worm, worm master concept (2026-11-12)

Run by hand by Kaden (or someone he names) on midjourney.com. No bots, no scraping, no unofficial
API, no browser automation. Expected time is about 5 minutes and uses about 8 fast images.
**This is the last Midjourney step for this game.** Every later view of the worm (turnaround, poses,
stage sizes, traits) goes through the image API from the master he picks, without him.

**Why a pack is needed.** None of the round-1 picks can be the master. P2-1 has the right anatomy
but it is a photographic macro with a big glossy eye, which A-001 rules out. P5-1 has the right
technique and light but it is a grub (legs, feelers, pill segments). The master has to be one image
of the worm alone that carries both.

**Send with A-002, run after it.** Kaden runs only the prompt(s) for the candidate he picks in
A-002 (C1 → P1, C2 → P2, C3 → P3). P4 is optional and goes with any pick. If he picks "revise", hold
this pack until the revised candidate exists.

## How to run it (same every round; these 3 lines go with the pack)
1. midjourney.com > Create: paste each numbered prompt as-is (you can queue several at once).
2. Download every image you like, at least one per prompt; don't rename (names start with the prompt's tag).
3. Send them back in one go as **files** (Telegram paperclip > File, not photo), or drop the folder into send-to-hub.

Optional: one line of reaction. Skipping a prompt is fine. Don't edit the prompts: say what you'd
change instead.

## Pose and framing (style bible §8)
Side view facing right, a gentle S-curve, the head end slightly raised, resting on a lit soil floor.
Neutral near-black background, one warm light from above. The worm alone: no props, no other
creatures, no text.

## Prompts
**P1 (C1 Annelid)** `wormmaster p1 pixel art earthworm, side view facing right, gentle S curve, head end slightly raised, slender tapered body with fine ring segments, pale peach flesh with a cool pale saddle band a third of the way back, faint translucent darker gut line, one tiny dark eye dot, no mouth, single soft warm light from above, dark wet soil floor in a small lit pool, near black background, hand placed pixel clusters, limited muted palette, sophisticated indie game sprite art, low key lighting --ar 3:2 --style raw --no text, letters, watermark, legs, antennae, grin, smile, mouth, big eyes, cartoon face, neon`

**P2 (C2 Lamplit)** `wormmaster p2 pixel art earthworm, side view facing right, gentle S curve, head end slightly raised, smooth tapered body with faint fine ring lines on the lit top, warm peach and amber flesh as the brightest thing in the scene, bright highlight along the top edge, deep plum shadow underneath, subtle pale saddle band, one tiny dark eye dot, no mouth, chiaroscuro, single warm lantern light from above left, dithered pool of light on dark soil, near black background, hand placed pixel clusters, limited palette, moody atmospheric indie game art --ar 3:2 --style raw --no text, letters, watermark, legs, antennae, grin, smile, mouth, big eyes, cartoon face, neon`

**P3 (C3 Plated)** `wormmaster p3 pixel art earthworm, side view facing right, gentle S curve, blunt head end slightly raised, sturdy body of flattened rectangular segments separated by thin dark lines, muted peach flesh with mauve shadows, pale saddle band, one tiny dark eye dot, no mouth, single soft warm light from above, dark wet soil floor in a small lit pool, near black background, hand placed pixel clusters, limited muted palette, natural history plate feeling, indie game sprite art --ar 3:2 --style raw --no text, letters, watermark, legs, antennae, grin, smile, mouth, big eyes, cartoon face, round beads, neon`

**P4 (optional, any pick: the worm in its world)** `wormmaster p4 cross section of soil like a glass sided wormery, a single earthworm in a narrow tunnel at the center, side view facing right, pale peach flesh, tiny dark eye dot, no mouth, the worm is the brightest warm form, warm light pool around it, dark strata above and below, roots hanging from the top right, dusk teal sky band at the very top beyond a grass line, hand placed pixel clusters, ordered dither, muted palette of umber, teal and amber, sophisticated indie game art --ar 16:9 --style raw --no text, letters, watermark, legs, antennae, grin, smile, mouth, big eyes, cartoon face, neon`

## After import (producer + AD)
- Files go to `art/concepts/worm-master/mj/P<n>-<k>.png`, with one line per file in
  `art/provenance/generation-jobs.jsonl` (tool midjourney, owner-operated, prompt id, date, sha256).
- The AD scores the returns against the A-002 pick and the identity lock (anatomy, no face, flesh in
  the bible's range or remappable to it), then proposes the master for the producer to confirm with
  Kaden (logged under A-002). Then come the image-API requests: side view clean-up at 1x, stage
  1/3/5 sizes, idle + crawl reference, with 1 image first per new kind.
- Licence note: per `art/provenance/licenses.md` (owner's Midjourney plan; images are public unless
  Stealth).

Provenance of this file: written by the AD lane (Claude, Opus 5.5), 2026-11-12, from style bible
v1.0 §8 and A-001. No generation run.
