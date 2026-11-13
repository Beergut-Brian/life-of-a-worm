# Midjourney prompt pack: Life of a Worm round 1 (2026-11-12)

Run by hand by the owner (or someone he names) on midjourney.com. No bots, no scraping, no
unofficial API, no browser automation, ever: Midjourney's terms forbid automated access.
Expected time: about 14 minutes (9 prompts, about 1.5 minutes each). Uses about 36 fast images
(4 per prompt) of the plan's monthly allowance.

## How to run it (same every round; these 3 lines go with the pack)
1. midjourney.com > Create: paste each numbered prompt as-is (you can queue several at once).
2. Download every image you like, at least one per prompt; don't rename (names start with the prompt's tag).
3. Send them back in one go as **files** (Telegram paperclip > File, not photo), or drop the folder into send-to-hub.

Optional: one line of reaction ("P4 is the one", "none of C"). Not required: picks happen later on
Docket. Skipping a prompt is fine. Don't edit the prompts: say what you'd change instead, so the
next pack carries it.

Three directions (details in `DIRECTIONS.md`): per direction, (1) the game's real camera, (2) the
worm in its world at gameplay scale, (3) the dock where every story scene happens.

## Prompts
### Direction A: Wet Earth (painted naturalist)
**P1** `wormwet p1 side-on cutaway cross-section of deep wet soil seen like a glass-sided wormery, wide game screen composition, a small slender segmented earthworm crawling through a narrow tunnel in the lower third of the frame, layered dark loam with mineral grain and small stones, pale fibrous root hairs threading through the earth, hazy air pockets, soft grey overcast daylight filtering down from the grass line at the very top and fading into darkness with depth, faint cold teal glow from fungal threads, hand-painted 2D environment, visible brush texture, three layers of depth with atmospheric haze, desaturated earth browns and slate grey, quiet and tactile, lots of negative space --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, user interface, cartoon, smiling face, big eyes`

**P2** `wormwet p2 close side view inside an earth tunnel, a slender segmented earthworm about one sixth of the frame wide moving left to right, glistening wet translucent skin with fine ring bands, a paler smooth saddle band near the front, tapered head with a tiny dark eye spot and closed mouth, crumbling clods of loam and pale roots around it, soft top light and gentle rim of reflected light along its back, tiny seeds and a root tip ahead of it, dark soil background with haze, naturalist painting, muted pink umber, deep brown and slate --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, cartoon, grin, smiling mouth, googly eyes, blush, teeth`

**P3** `wormwet p3 wide side-on view of an old weathered wooden fishing dock on a still pond at dawn, an old fisherman and a small boy sitting at the end with fishing rods, seen small in the frame, a bait tin beside them, reeds and low mist on the water, pale warm sun low behind thin cloud, soft reflections, hand-painted 2D cutscene background, muted greys, wet wood browns and one pale gold, generic countryside, calm and tender --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, buildings with signs, cartoon`

### Direction B: Low Light (cinematic pixel chiaroscuro)
**P4** `wormlow p4 pixel art side-on underground cross-section, wide 2D game screen, a small segmented worm crawling through a narrow tunnel in the lower third, most of the frame in deep warm shadow, densely hand-placed pixel clusters of packed soil, angular stone chips and mineral grain, a single hard shaft of amber light falling through a hole in the crust above and catching the faceted edges of rocks with a rim light, a few dim ochre crystals in a far pocket, restrained palette of charcoal, umber and ochre with one warm amber key, crisp pixels, no outlines in the terrain, dramatic and quiet --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, user interface, blur, smooth gradient, cartoon, big eyes`

**P5** `wormlow p5 pixel art close side view of a segmented worm in a dark earth tunnel, the worm about one sixth of the frame wide heading right, warm pink umber body with each segment as a step of value, a thin bright rim light along its back from a light source above, tapered head with a tiny dark eye and closed mouth, crumbled stone facets and a few seeds ahead of it, deep charcoal shadows, 4 to 5 shade ramps, crisp hand-placed pixels, 2D game sprite in its environment --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, blur, smooth gradient, cartoon, grin, googly eyes, blush, teeth`

**P6** `wormlow p6 pixel art wide side-on scene of an old wooden fishing dock on a pond at dusk, an old fisherman and a small boy sitting at the end with rods, small in the frame, a lantern beside them making a warm pool of light, dark silhouetted reeds and trees in layered parallax, long amber reflections on still water, deep blue-grey shadows, restrained palette, crisp pixels, 2D game cutscene background, generic countryside --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, blur, buildings with signs, cartoon`

### Direction C: Relief Print (Hail Mary)
**P7** `wormprint p7 hand-pulled linocut relief print of a side-on cross-section of the earth, wide composition, many layers of soil and stone carved as bold rhythmic gouge strokes that follow curved strata like rings of a great disk, a small segmented worm tunnelling through the lower third leaving a clean paper-white tunnel behind it, roots and pebbles as simple carved shapes, indigo-black ink and moss green ink on warm bone paper with a rust red overprint in a few places, slight registration offset, visible paper grain, flat inks with no gradients, graphic and elegant --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, labels, numbers, frame border, cartoon, gradient`

**P8** `wormprint p8 linocut relief print close side view of a segmented worm inside a carved earth tunnel, the worm one sixth of the frame wide heading right, a single confident carved silhouette with carved segment rings and a tiny cut eye, surrounded by bold gouge-cut soil texture and two seeds, indigo-black ink on warm bone paper with a single ochre overprint on the worm, slight registration offset, paper grain, flat inks, no gradients --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, labels, frame border, cartoon, grin, googly eyes, blush`

**P9** `wormprint p9 linocut relief print, wide side-on view of an old wooden fishing dock on a pond at sunrise, an old fisherman and a small boy sitting at the end with rods, small in the frame, a big low sun carved as concentric rings, water carved as long horizontal gouge strokes, reeds as sharp cut shapes, indigo-black ink and rust overprint on warm bone paper, flat inks, paper grain, quiet and graphic --ar 16:9 --style raw --v 7 --no text, letters, watermark, signature, logo, labels, frame border, buildings with signs`

## After import (producer + AD)
- Files go to `art/concepts/round1/<direction>/P<n>-<k>.png` (`a-wet-earth/`, `b-low-light/`,
  `c-relief-print/`); one line per file in `art/provenance/generation-jobs.jsonl` (tool midjourney,
  owner-operated, prompt id, date, file sha256).
- Licence note in `art/provenance/licenses.md`: owner owns Midjourney assets under its ToS (check
  the plan and the company-revenue clause); images are public on Midjourney unless Stealth.
- AD then makes, per direction: a true-res proof at the real stage-1 canvas (640x360, shown 3x) and
  at 1x, the worm at gameplay size next to the grey-box worm, a palette strip with ΔE to P1/P2,
  a compare sheet, and `GATE1.md`. Reject any image with text, a face on the worm or a real place.
