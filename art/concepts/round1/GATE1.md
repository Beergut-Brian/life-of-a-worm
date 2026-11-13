# Life of a Worm: Gate 1 (visual identity), round 1 (AD, 2026-11-12)

Inputs: Kaden's five picks (`OWNER-PICKS.md`), the grey-box stage-1 and stage-5 frames, the brief's
exit check. Outputs: `compare.png` (3 columns: A, B, B+A mix) and `proofs/` (per direction: the
640x360 stage-1 canvas, the same at 3x, a 0.5x minify, the worm sheet, the palette strip, and
`palettes.json`). Made by `art/tools/gate1_proofs.py` and `art/tools/gate1_compare.py`. **No pixel is
drawn in code:** the soil, light, palettes and worms all come from Kaden's images. The scripts only
crop, tile, downscale, quantise, multiply by a light map taken from P5 and composite. Two inputs are
not the owner's: the tunnel layout, cut from the grey-box frame's dug pockets, and the slot collar
colour (P1 `#3cc24a` / P2 `#e4393c`, shaded by the sprite's own values).

## 1. Curation: what Kaden's selection tells us
None of the five shows text, a mouth or grin on the worm, or a real place, so none is rejected under
the pack rule.

| Image | Verdict | What it tells us |
| --- | --- | --- |
| A P1-1 cutaway | **keep** (composition, materials) | He wants the "glass-sided wormery" cross-section: grass line and sky band on top, strata, root mass at one side, the worm small in a tunnel. The technique came back as **inked line work with muted washes**, not the soft painting A described, which matters at 0.5x (see 3). His world, not his worm: P1's worm is a banded thread, too thin to play. |
| A P2-1 close worm | **keep for anatomy only** | Translucent ringed body, pale saddle, tapered head, wet glisten. Reject the technique (photographic macro with bokeh, which can't be built as tiles). Reject the eye size: the pack asked for a tiny eye spot and got a big glossy one. It is not a face (no mouth), so the image stays, but the eye is not adopted. |
| B P5-1 close worm | **keep for technique and light** | Low-key chiaroscuro, dithered hand-placed clusters, a warm pool on the floor, the worm as the brightest warm form, the open cavity near-black. Reject its anatomy: legs and feelers make it a grub or millipede, and the pill-round segments lean toward the banned "toy-round". It has no eye or mouth. |
| B P6-1 dock dusk | **keep** | Pixel dusk, lantern, silhouettes without faces, a generic pond. The palette came back **teal / blue-grey + amber**, not the charcoal/umber/ochre B was written with. |
| B P6-2 dock dusk | **keep, strongest of the round** | The same scene with a better lantern pool, amber reeds and layered mist. He sent P6 twice: the clearest signal of the round, for B's light model and the dock look. |

What he did **not** send: nothing from C (Relief Print), which is dropped. Not P3 (the painted dock): the
dock is pixel. Not P4 (B's own cutaway): B's underground evidence is a single close-up, which is why the
mix borrows A's cutaway.

## 2. The three candidates at the real camera
Stage 1 = 3x zoom: the art canvas is 640x360, one 16 px tile is 48 screen px, and the grey-box worm is
33x18 art px at screen centre. Every proof uses that canvas, the grey-box tunnels and the worm at that
size (the proposals are 41x17, 36x17 and 38x17 art px).

| | A Wet Earth | B Low Light | B+A mix |
| --- | --- | --- | --- |
| Source | P1 world, P2 worm, A's 24-colour palette | P5 tiled as a tile set, P5 light, P5 worm, B's 18 colours | P1 composition and strata, P2 worm anatomy; B's palette, P5 light pool, P6 dusk sky, P5 worm ramp + outline |
| Strengths | Most "sophisticated" still: the inked strata and roots, the sky band, a real naturalist feel. The pale worm reads by value. | The most game-like: P5's clusters are already tile-scale; drama from light; the chunky pink worm has the strongest presence at couch distance; tunnels read as black voids. | Keeps both things Kaden picked: the cutaway he chose and the dusk light he sent twice. Big value masses (the dusk sky band, the warm pool, the dark depths); the worm is the brightest warm form, with a clean outline. The dock scenes (P6) and the underground share one palette. |
| Risks | Ink lines are image-scale: they don't tile, and a destructible tile world cuts them. Lower strata are dark on dark, so tunnels read weakly there. Cool mint/grey light disagrees with the dock picks (P6 is pixel dusk). The worm is low in warmth and presence. | Only one underground image as evidence; the proof's tile grid shows because P5 is a close-up. About 85% of the screen is near-black, too dark for a daytime living-room TV. Outside the pool, solid vs tunnel is lost. The worm reads as a grub (legs, pills). | P1's ink contours must be redrawn as pixel clusters in production (B technique). The lower strata go blue-black, so food there needs light. The worm ramp's light pink `#d6756a` is ΔE 11.8 from P2 red (flag), so a red collar on a pink worm is weak. |
| How close the game gets, stage 1 at 3x | ~65%: quantised ink holds at 3x, but tiling and digging break the line work | ~85% of the look, on thin evidence | ~80% |
| Stage 5 at 0.5x (minify proof) | ~40%: lines break into noise, the mint sky survives | ~60%: the dark field turns to mush, only the light and the worm survive | ~70%: the sky band, the pool and the dark depths survive |
| Pipeline | rendered 2D or inked-pixel hybrid, costly | pixel (PixelLab + Aseprite), Light2D in the build | pixel (PixelLab + Aseprite), Light2D in the build |

Readability (all three): food vs threat is **not proven**. No owner image shows food or threats at
gameplay scale (P5's seeds and pebbles are the only food), so it is the first image-API request after
Gate 1. All three proposal worms are slimmer than the grey-box blob: median body thickness is 6 / 6 / 8
art px against its 9 (15 at the head). So the stage-1 body needs to be about 9-10 art px (just over
half a tile) to keep its presence. That puts the right proportion between P2's annelid and P5's grub.

ΔE00 to the slot colours (full strips in `proofs/*-palette.png`): A's nearest colours are 22.9 to P1 and
20.6 to P2 (all ok). B and the mix have no fails, but three flags against P2 red in B (`#d6756a` 11.8,
`#a9334f` 16.6, `#93674f` 19.7) and two in the mix (`#d6756a`, `#93674f`). P1 green is ≥ 32 everywhere.
Style-bible fix if B or the mix wins: move the worm's light flesh toward P2's peach (ΔE ≥ 20) and put a
1 px dark separator either side of the collar.

## 3. My six exit-check questions: what the picks settle
1. **Faces.** Partly settled. Nothing he picked has a mouth, grin or blush; P2's big eye came back
   anyway and he kept the image. At gameplay scale an eye is 1-2 art px whatever the concept does. Still
   for Kaden, because GAME.md asks for a "big single eye with a lid" on P1: confirm a small eye and
   reactions shown by posture (recommended).
2. **Slot colour as fill or accent.** Not settled. The proofs show a 2-column collar reads at stage 1
   (green strongly, red weakly on a pink worm). Recommendation unchanged: (b) accent + slot glow at far
   zoom, plus the flesh shift above.
3. **Stage features (bow, monocle, crown).** Not settled by the picks; belongs to the G1 main-character
   sub-decision, not this gate.
4. **0.5x minification.** The minify proofs support a far-zoom tile set for any direction. The mix
   needs it least.
5. **Camera placement.** Not settled: his picks frame the worm mid-low, the game centres it. The proofs
   use the real centred camera and still compose.
6. **Kaden drawing the worms.** Leaning yes: three of his five picks are pixel, and both dock picks are
   pixel. A pixel direction keeps that open.

## 4. Recommendation
**Approve the B+A mix.** It is the only candidate that keeps both things Kaden chose: A's cutaway world
and anatomy, and B's dusk light, which he sent twice. It holds best at 0.5x, it shares one palette with
the dock scenes, and it is a pixel pipeline the build already supports (Light2D, normal maps) and he
can draw into. B alone is the fallback: cheapest, but its underground evidence is one close-up and it
is too dark. A alone is the most "sophisticated" still, but its ink line work fights a destructible tile
world.

## 5. Gate 1 question for the producer to post (text for Kaden)
> **Life of a Worm: pick the look (Gate 1).** From your Midjourney picks I made three test screens at
> the game's real stage-1 camera, with the worm at its real size (sheet attached: `compare.png`).
> - **A, Wet Earth:** your P1 cutaway and P2 worm as they are: inked soil, cool grey daylight.
> - **B, Low Light:** your P5 and P6 look as it is: pixel, mostly dark, warm light pools, chunky pink worm.
> - **B+A mix (recommended):** B's pixel technique, dusk palette and light, painted over your P1 cutaway,
>   with P2's slender worm body.
>
> Reply with one: **approve A / approve B / approve B+A mix / revise one (say which and what to change) / reject all.**
> What a pick approves: the art style and technique, the palette (and its teal + amber dusk for the
> dock), the light model (dark world, light is precious), the camera scale as shown (stage 1 at 3x,
> worm about one tile tall), and how the worm reads (small eye, no mouth/grin, your green or red as a
> collar band and glow). It does not approve the final worm design: that is a separate pick right after.

Log the answer in `art/approvals.md` as A-001 (quoted). Silence is `no decision` and the gate stays
closed.
