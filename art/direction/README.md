# Life of a Worm: look options, round 1 (for Kaden's pick, Docket D87)

Three looks that differ in **how things are rendered**, not just in colour. All three use the same
world slice, the same 16 px tile grid at a whole-pixel scale (x2 for the slice and planet, x5 for the
dock) with nearest filtering, the same P1 green `#3cc24a` (one big eye) and P2 red `#e4393c` (two small
cross-eyed eyes). Start with `compare.png`.

| | Look | In one line |
| --- | --- | --- |
| **A** | Arcade Chomp | Flat poster colour, 2 px ink on every cut edge and ring border, huge faces, no lighting: loud and graphic, closest to the "Super Mega Worm" note. |
| **B** | Lantern Deep | The lit, Terraria-like look: dense 4-shade textured tiles with ore flecks and roots, normal maps, a dim ambient underground, light pools from the worms, crystals, glowing mushrooms and the core, a daylight shaft through the eaten hole, solid ground darkening away from open air. The grown-up, adventurous one. |
| **C** | Tall Tale | Old Reel's story as a printed storybook plate: sun-faded palette, sepia ink line, engraved strata in the ground, ordered dither for every gradient, paper grain and vignette. My own pick for the third slot: it ties the underground to the dock where every cutscene lives, instead of a third "pixel game" look. |

## What is in each folder (`a_arcade_chomp/`, `b_lantern_deep/`, `c_tall_tale/`)
- `xs.png` **Godot render**: ring cross-section, sky to a glimpse of the core. P1 chomping a wide-eyed grub with chomp particles (CPUParticles2D) in the dirt, P2 heading for a wide-eyed ore nugget in the rock, a smug beetle one size up in its pocket, a wide-eyed mushroom in a topsoil burrow, crystals (one with a face) in a core cave, an eaten hole through the crust. B adds nine PointLight2Ds on normal-mapped sprites under a CanvasModulate.
- `planet.png` **Godot render**: the whole bitten disk small on screen, both worms (stage 6) chewing on it, a bitten moon. B lights it with a sun and a core glow.
- `dock.png` **Godot render**: the dock at dawn with Old Reel and a kid, the sandwich on the hook, the three bait tins (save slots) on the rail, the Strangestone pulsing under the first tin, the lantern.
- `swatch.png` **Pillow card**: every ring's 4 tile shades + 2 back-wall shades with hex, sky and space ramps, grass, outline, light colours, UI accent, both worms on each ring's dominant hue with ΔE.
- `compare.png` (this folder) **Pillow sheet** of the Godot frames: the three cross-sections 2x2 plus a planet + dock strip, labelled A/B/C.

Everything in the frames is placeholder art made for this comparison. The **worms, foods, beetle, props
and the kid are placeholders** I drew procedurally (the kid follows Bobber's drafted bible colours:
yellow rain hat, teal/cream stripes, denim shorts). **Old Reel is the library's existing pixel form from
The Hill** (`openjar-characters` `old_reel/refs/pixel/old_reel_pixel.png`, copied to `art/preview/ref/`),
not a Worm-specific pixel form; in C his outline is recoloured to the sepia ink. Worms are shown at
1.5x the stage-1 size (about stage 3) so faces read on a TV at this zoom.

## How the frames are made
`art/tools/make_frames.py` bakes each look's layers and sprites (tiles drawn per pixel from the
palette in `art/tools/worm_looks.py`, plus normal maps for B) into `art/preview/<a|b|c>/`. The scene
`art/preview/preview.tscn` composes them in Godot 4.7.2 (CanvasLayers at a whole-number scale, nearest
filter) and adds the lights, CanvasModulate, particles and the paper multiply overlay;
`art/tools/render_all.sh` takes the frames with `scripts/tools/shots.sh` (Forward+, software GPU).
`art/tools/make_sheets.py` builds the swatch cards and compare sheet. Re-run all four after a palette edit.
Parallax is shown as layers (sky with far hills, the tunnel back wall, terrain, sprites); in a still frame it doesn't move.

## ΔE2000: both worms against every ring (`art/tools/deltae_check.py`)
Palette check, every ring's dominant hue and worst case over all six of its colours (tile + back
wall). Under 10 would lose the worm, 10 to 20 is flagged. Five shades that started under 20 were fixed
(A topsoil highlight, B core low, C topsoil highlight, core low and core deep); nothing is flagged now.

| Option | Ring | dominant | P1 vs dom | P1 worst | P2 vs dom | P2 worst | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A | sky | `#62bdff` | 51.7 | 41.8 | 55.0 | 46.3 | ok |
| A | topsoil | `#1a7a63` | 28.2 | 24.5 | 60.3 | 52.3 | ok |
| A | dirt | `#a8622c` | 50.9 | 43.5 | 20.2 | 20.2 | ok |
| A | rock | `#4f62a8` | 56.8 | 50.7 | 41.0 | 41.0 | ok |
| A | core | `#ffbe2e` | 38.1 | 28.3 | 44.3 | 21.1 | ok |
| A | space | `#1e2356` | 68.8 | 66.0 | 46.4 | 44.1 | ok |
| B | sky | `#78afd8` | 45.7 | 37.7 | 50.3 | 45.2 | ok |
| B | topsoil | `#3d5e36` | 35.3 | 22.1 | 54.5 | 48.2 | ok |
| B | dirt | `#6c452c` | 54.9 | 45.1 | 26.2 | 23.0 | ok |
| B | rock | `#435069` | 54.0 | 44.8 | 39.8 | 37.7 | ok |
| B | core | `#e0782a` | 54.0 | 39.2 | 21.5 | 21.5 | ok |
| B | space | `#141c48` | 69.5 | 67.2 | 47.7 | 45.4 | ok |
| C | sky | `#bcd8d6` | 28.6 | 28.6 | 48.4 | 44.3 | ok |
| C | topsoil | `#768838` | 20.1 | 20.1 | 51.8 | 41.7 | ok |
| C | dirt | `#a2693c` | 47.0 | 39.1 | 21.1 | 21.1 | ok |
| C | rock | `#76829c` | 42.5 | 37.8 | 36.1 | 36.1 | ok |
| C | core | `#eb9a3e` | 44.8 | 32.1 | 31.2 | 22.9 | ok |
| C | space | `#343b68` | 63.2 | 56.4 | 42.6 | 39.9 | ok |

Worst case per option: A 20.2, B 21.5, C 20.1

Measured in the rendered Godot frames (after lighting, modulate and dither; `art/tools/frame_check.py`),
worm body against the tunnel wall behind it and the ground next to it:

| Option | Worm | body (frame) | against | colour | ΔE00 |
| --- | --- | --- | --- | --- | --- |
| A | P1 in dirt | `#3cc24a` | tunnel wall | `#4e2a17` | 62.8 |
| A | P1 in dirt | `#3cc24a` | dirt | `#a8622c` | 50.9 |
| A | P2 in rock | `#e4393c` | tunnel wall | `#272b4d` | 44.1 |
| A | P2 in rock | `#e4393c` | rock | `#4d5fa4` | 41.0 |
| B | P1 in dirt | `#41e859` | tunnel wall | `#493925` | 63.3 |
| B | P1 in dirt | `#41e859` | dirt | `#3d281d` | 74.0 |
| B | P2 in rock | `#fa3e45` | tunnel wall | `#434257` | 41.2 |
| B | P2 in rock | `#fa3e45` | rock | `#272b41` | 47.0 |
| C | P1 in dirt | `#3bb140` | tunnel wall | `#543726` | 52.0 |
| C | P1 in dirt | `#3bb140` | dirt | `#915c33` | 46.2 |
| C | P2 in rock | `#ce3432` | tunnel wall | `#3a3c43` | 34.5 |
| C | P2 in rock | `#ce3432` | rock | `#545b6d` | 33.9 |

Tightest pairs: P2 red against dirt (A 20.2, C 21.1) and against B's core (21.5). Both worms also
carry a dark outline and white eyes in every look, so neither depends on hue alone.

## Cost to build, and what the GTX 1060 needs

| | Tiles | Lights | Normal maps | GTX 1060 at 1080p 60 fps |
| --- | --- | --- | --- | --- |
| **A** | 4 rings x 1 atlas (2 shades + speck variants) + 4 back walls. Ink edges and ring borders from one edge shader on the tile layer (no 47-tile autotile needed). Cheapest. | none | none | trivial: unlit sprites and one edge shader |
| **B** | 4 rings x atlas of 4-shade tiles, 3 to 4 variants each, bevelled edges, ore/root decals; 4 back walls. Most art per tile; our generator already makes plausible ones. | PointLight2D per worm (glow trait), per crystal cluster, glowing mushrooms, the core, a sun band and one textured shaft light per eaten hole; plus a per-chunk "distance to air" darkness texture rebuilt when tiles are eaten (CPU flood fill per chunk, one small image upload). | yes, one per tile atlas and per sprite set (generated from height, as here) | fine if lights stay bounded: target under about 24 visible lights with limited range, no 2D shadows (or only on 1 or 2), darkness as a texture not as lights. Profile early in the polar-chunk prototype. |
| **C** | 4 rings x 3-shade dithered atlases; the engraved strata are better as a world-space shader by ring and depth than as baked tiles (cheap and seamless across chunks); ink edge shader as A. | none in play (optional warm vignette) | none | trivial: one fullscreen multiply for paper grain |

## Recommendation: **B, with two things borrowed**
B is the only option that meets the "beautiful: real lighting, depth, atmosphere" bar the brief sets,
and the plan's own art direction (normal-mapped tiles, the glow trait lighting tunnels, crystals casting
colour, daylight through eaten holes) is B's feature list, so B costs nothing extra in design. It is the
grown-up, adventurous one without losing the worms: they measured 41 to 74 ΔE00 against their
surroundings in the lit frame, because they carry their own light.
1. **Keep A's faces and outlines on characters** (already the case in B's frame): ink outline, big white eyes, so the cast stays loud and funny while the world is moody.
2. **Use C's storybook grade for the dock and the flashbacks.** The story already asks for "a flashback in a warmer palette"; C's dither, sepia ink and paper are that, as a post-process over the same assets, so the dock cutscenes feel like Old Reel telling it.
3. **Watch the kid check in B:** "nothing in the dirt is dark or creepy". The ambient here (`#9088a8`) is the floor; I'd not go darker, and the Lighting work should give every ring a coloured ambient (warm in dirt, cool in rock, orange near the core) rather than grey.

If Kaden wants the cheapest path to a playable look, A is about a third of B's art cost and has no
performance risk; C is between the two.

## What the pick changes downstream
- **B:** tile work is 4-shade atlases + normal maps + back walls per ring; a Lighting lane (lights on worm, crystals, core, eaten holes; per-chunk darkness texture); the 1060 profile becomes a gate in the polar-chunk prototype.
- **A or C:** tile work is flatter atlases + an edge-ink shader (C adds a strata shader and the paper overlay); no lighting lane, and the glow trait becomes a sprite effect instead of a light.
