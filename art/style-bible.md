# Style bible: Life of a Worm

project_id: life-of-a-worm
style_bible_version: v1.0
approved_direction: B+A mix (Gate 1, `art/approvals.md` A-001, Kaden 2026-11-12 21:13, Docket D99 a / D100 c)
status: approved identity (A-001); worm design pending A-002
written_by: AD lane, 2026-11-12, from `art/concepts/round1/GATE1.md` and Kaden's five picks

The look in one line: **B's pixel clusters and dusk light painted over A's glass-sided cutaway.**
A dark, wet, cross-section world where light is precious, built from hand-placed pixel clusters, with
the worm as the brightest warm thing in it. It is meant for an adult who loves beautifully made indie
games, playing with his son (brief §1).

Evidence (approved references, §10): `art/concepts/round1/compare.png` (right column),
`proofs/mix-*.png`, and the owner images P1-1, P2-1, P5-1, P6-1 and P6-2.

---

## 1. Pillars
1. **Light is precious.** The world is dark by default. Every light source is a decision: the worm's
   own glow, a glow-worm, a lantern, the sky at a tunnel mouth, the core's heat. In practice, about
   60% of a stage-1 frame sits in the bottom three value steps, and lit pools carry the composition.
2. **A cutaway you could hold.** The world reads like a glass-sided wormery or a natural-history
   section: horizontal strata, a sky band at the top when the surface is near, roots hanging in from
   one side. In practice, rings are bands with their own texture and value, not just hue shifts.
3. **Hand-placed, not filtered.** Pixel clusters of 2-6 px, ordered dither only where a gradient is
   needed, no noise fills, no blur, no smooth gradients in play. In practice, every tile and sprite is
   finished by hand in Aseprite at 1x, even when a generator started it.
4. **The worm is the warmest thing on screen.** Its flesh is the brightest warm value in any
   underground frame. The slot colour is its only saturated accent. In practice, no terrain or food
   uses the top two flesh steps.
5. **Grown-up restraint, kid-proof reads.** A muted palette, then food vs threat, edible vs too-hard,
   and P1 vs P2 that read in half a second from the couch. In practice, every read is carried by
   value and silhouette first and hue last (the camera rotates and the rings change hue).

## 2. Anti-patterns (banned)
- **Mascot faces.** No grin, mouth line, blush, googly eye or big lidded eye on the worm. No "cute"
  pupils with glints the size of the eye. Rejected example: P2-1's big glossy eye (kept for anatomy
  only), the grey-box worm (`proofs/*-worm-sheet.png`, first tile), and round 1's Lantern Deep
  ("reads immature").
- **Toy-round shapes.** No pill segments, ball heads, bubbly outlines or symmetrical blobs.
  Rejected example: P5-1's pill segments and legs (a grub, not our worm).
- **Candy and neon.** No saturated pinks, purples, cyans or lime outside the slot colours. Saturation
  ceiling: HSV S ≤ 0.65 for everything except the slot colours, the amber light core and VFX flashes.
- **Text, numbers or letters in play.** None on props, signs, food or HUD. Menus may use type.
- **Flat, centred, evenly lit frames.** No fullbright tiles. If a screenshot has no darkest-step
  region and no lit pool, it is off-model.
- **Inked outlines on terrain.** A's ink line work does not survive tiling and digging. Terrain
  edges are value changes and clusters, never a continuous 1 px contour.
- **Gore and fright.** Nothing is shown hurt. Being eaten is a comic gulp and a puff.
- **Real places, brands, recognisable characters or artists' styles.** The dock, pond and town are
  generic and invented (house rules).
- **Red as danger.** Red belongs to P2. Danger reads by silhouette, motion (wind-up) and cold value,
  never by a red tint.

## 3. Colour
Master palette: `art/palette/worm-v1.json` (also `.gpl` for Aseprite, `.hex`, and the swatch sheet
`worm-v1-swatches.png`). It is generated and checked by `art/tools/palette_v1.py`, which prints a FAIL
for any colour under ΔE00 20 from either slot colour. **All 70 colours pass.** The hexes are sampled
from Kaden's P1, P5 and P6 and the Gate-1 mix palette. The only exceptions are the worm flesh shift
(A-001 condition) and the in-between ramp steps.

| Group / ramp | Hex, dark → light | Use |
|---|---|---|
| shared / void | `#020000` `#010d17` `#19100b` `#1e090d` | open tunnel, deep shadow, actor outline (`#1e090d`) |
| **worm / flesh** | `#1e090d` `#3c0a1a` `#7d4650` `#c4917c` `#e8b08c` `#f0c8a4` | the player worms only (top two steps are reserved) |
| worm / saddle | `#c09b95` | clitellum band (cool pale, from P2-1) |
| dusk / sky + water | `#060d17` `#0a2a34` `#1f4d55` `#286168` `#528077` `#8fb0a2` | sky band, pond, dock, surface air |
| dusk / silhouette | `#04111c` `#19272c` `#25312e` | dock, figures, trees, houses against the sky |
| light / amber | `#5a3214` `#a8601e` `#e68c33` `#f2b45e` `#fbe0a8` | lanterns, glow-worms, lit pools, sun, stars, UI focus |
| ring / grass crust | `#25312e` `#46695e` `#65725a` `#8c9466` | 3-4 tile surface crust, reeds |
| ring / topsoil | `#1c120e` `#3f261d` `#5e3d31` `#7d5640` `#a47c60` | warm, loose, root-shot |
| ring / roots | `#4d453c` `#655041` `#817964` `#a89a7c` | root fibre and mass (from P1) |
| ring / dirt | `#160e0c` `#2e2119` `#4a3a2c` `#5c4531` `#7a6450` | packed, cooler umber |
| ring / aquifer | `#04111c` `#173f4e` `#27596c` `#40656c` `#577a77` | wet seams, underground water |
| ring / rock | `#0e1214` `#222a2c` `#2c3a39` `#3e5452` `#50746d` `#7d958c` | blue-grey, mineral grain |
| ring / core | `#1a0d06` `#3d2008` `#7a4212` `#c0782a` `#f2b45e` | heat as amber, self-lit |
| ring / castings | `#0f0a08` `#2a1c16` `#3f2d24` `#8a7a6a` | rich dark crumb + pale grit fleck |
| life / garden leaf | `#2f4a3a` `#46695e` `#6a8458` `#b4b090` | sprouts, gardens (kept ≥ 20 from P1 green) |
| life / chitin | `#0b0d10` `#1b2226` `#33424a` `#6b7f86` `#c9d4d0` | threats' shells; the bone top step = "edible now" |
| space | `#010309` `#010d17` `#0a1a2a` `#1b2f45` `#fbe0a8` | space, star points |
| **slot (reserved)** | P1 `#3cc24a`, P2 `#e4393c` | only the players: collar, glow, edge arrows, rings |

**Value structure.** Underground: ~60% of the frame in the bottom three steps of the ring ramp, ~30%
in the mid steps, ≤ 10% in the top steps, and that 10% lives only in lit pools, food and the worms.
The surface at dusk inverts it: the sky band is the mid-light mass and the land is the silhouette.
Contrast rule: an actor (worm, food, creature) is ≥ 2 value steps away from the tile behind it, or it
gets the 1 px `#1e090d` outline (all actors have it anyway; see §5).

**Accent meanings.** Green and red = the player slot, nothing else. Amber = light, warmth and "good"
(food glint, the lantern, the sun, the UI focus). Bone `#c9d4d0` = "this threat is now food". Garden
leaf = growth you caused. No colour means "danger" (see §2).

**Dock and surface:** dusk teal + amber, straight from P6-2. Dawn, noon, dusk and night are one
background with four light passes: dawn lifts the teal toward `#8fb0a2` with an amber horizon line,
noon is the brightest the game gets (still no fullbright), dusk is P6-2, and night is `#060d17` with
amber windows and star points. The flashback in the opening uses the amber ramp as a warm grade over
the same palette (no new hues).

## 4. Shape language and silhouette
| Category | Primary shapes | Rule |
|---|---|---|
| Player worms | long tapered tube, flattened segments | the head end is blunt and slightly raised, the tail end tapers to 1-2 px; never a pill chain |
| Food | soft, organic, closed shapes: seeds, grubs, roots, droplets | rounded but irregular (one flat side, a stalk, a dent), smaller than the worm's head at its stage, warm or lit, with a 1 px amber glint |
| Threats | angular, jointed, overhanging: beetles, ant mandibles, beaks, boots | at least one point or hook in the silhouette; cold chitin values; bigger than the worm's head; a wind-up pose before any move |
| Too-hard tiles | blocky, faceted, with hard edges | a bevel on top-light (lit edge + dark edge), no crumbs |
| Edible tiles | crumbly clusters | broken edges, loose crumbs at the boundary, a soft top edge |
| Props (surface) | silhouettes first, flat-ish shapes | read as a shape at 0.5x with no interior detail |
| Residents (Mole) | the Jarling master's silhouette, pixel-drawn | keeps its library proportions, darker and wetter for this world (house rule: pixel forms drawn over low-res renders) |

**Silhouette test.** Fill the sprite with `#020000` on `#286168` at 1x. Someone who hasn't seen it
must name food vs threat vs worm. A threat's silhouette has a point; food's doesn't.

## 5. Rendering
- **Technique: B, pixel clusters.** Clusters of 2-6 px with readable form shading, 3-5 shades per
  material, and hand-placed ordered (Bayer 2x2 or checker) dither only on gradients wider than 4 px.
  No anti-aliasing to the background. Inner AA of one in-between step is allowed on curves of actors.
- **Outlines.** Actors (worms, food, creatures, carried things) get a 1 px outline in `#1e090d`,
  selective: the outline lightens one step on the lit side when the actor is in a lit pool.
  Terrain gets **no** outline; ring and tunnel edges are value steps plus crumb clusters.
- **Tunnels (air) vs solid.** This was the weakest read in the grey box. A dug tunnel is the ring's
  darkest step, or `#020000` when no light reaches it. The cut edge gets a 1-tile **lip**: one row of
  the ring's lightest-but-one step on the top face (lit from the worm) and the darkest step on the
  underside. Solid is never darker than open tunnel.
- **Light model.** Light2D with normal maps on terrain tiles and actors. The ambient underground is
  dark (CanvasModulate near `#2a2a33` at stage 1, darker deeper). Light sources, in order of strength:
  the worm's own soft glow (radius ~3 tiles at stage 1, slot-tinted at the rim, warm at the core), food
  glints, glow-worms and lanterns (amber), the sky through a tunnel mouth (dusk teal), and core heat
  (amber, self-lit). Falloff is stepped (3-4 bands) in the light texture, not smooth, so the
  quantised clusters stay quantised. The top light comes from the planet's outside (camera "up") and is
  read through the lip rule, not from a world direction (the camera rotates).
- **Time of day (surface and dock only):** four light passes over one background (§3).
- **Materials.**
  - Wet soil: dark crumb clusters with 1 px pale specks (wet glints) at ~1 per 32 px².
  - Root fibre: 1 px strands in the roots ramp, branching down, drawn by hand, never generated as noise.
  - Mineral grain (rock): faceted 3-5 px plates with a lit and a dark edge.
  - Chitin: 3-step cold ramp plus one hard specular pixel (bone).
  - Moss/garden: soft leaf clusters with a lit top.
  - Water (aquifer, pond): 2-step horizontal bands with 1 px shimmer lines that move.
  - Worm skin: see §8. Translucent read = the deep step `#3c0a1a` showing as a gut line through the
    shadow step.

## 6. Camera and scale
The real camera, from the brief's exit check and `data/stages.tres`. The viewport is 1920x1080,
nearest filter, and whole-step zoom. The camera centres on the worm(s) and rotates so "down" is
toward the core.

| Stage | Zoom | 16 px tile on screen | Art canvas | Worm body thickness (art px) | On screen |
|---|---|---|---|---|---|
| 1 | 3x | 48 px | 640x360 | 9-10 (size 1.0) | ~29 px thick, head ≈ one tile |
| 2 | 2x | 32 px | 960x540 | ~11-12 (1.18) | ~23 px |
| 3 | 1x | 16 px | 1920x1080 | ~13 (1.36) | ~13 px |
| 4 | 1x | 16 px | 1920x1080 | ~15 (1.54) | ~15 px |
| 5-6 | 0.5x | 8 px | minified | ~16-17 (1.72-1.9) | ~8 px, and the slot glow carries it |
| planet shot | 1/16 | 1 px = 2 tiles | | picture of the planet | worm = slot glow dot |
| 7 space | 0.5x, no rotation | | | | worm = slot glow + flesh streak |

- **Authoring scale:** everything is drawn at 1x art px on the 16 px grid. Sprites for a stage are
  drawn for that stage's size, not scaled up from stage 1 (redraw at 1, 3 and 5; 2 and 4 may be
  nearest-scaled if they pass at 1x review).
- **Far-zoom tile set (0.5x).** At 0.5x nearest minification drops every other pixel, so a separate
  far set swaps in at zoom ≤ 0.5x. It uses the same ramps, but every cluster is 2x2-aligned and at
  least 2x2 (so it survives the drop). There is no dither, and only 3 steps per ring, and the lip rule
  is kept as 2 px. Far-zoom actors (houses, trees, fences, the worm) follow the same rule.
- **Planet shot (1/16):** each ring is its mid step, bites are `#020000`, and the sky ring is a dusk
  teal gradient in 3 bands.
- **Minimum readable size at 1x on the TV:** food ≥ 6x6 art px at stages 1-2, ≥ 8 screen px at any
  zoom. The worm's eye is 1 art px (2x2 from stage 5). The slot collar is ≥ 2 art px wide.
- **Scale table at stage 1 (art px):** worm 38-44 long x 9-10 thick; seed 5x4; pebble 6x5; grub 9x6;
  root tip 3x10; ladybird 7x6; beetle (threat) 24x16; Mole ~2.5 tiles tall; tunnel 1.5 tiles (24 px).

## 7. Environments
Layers, back to front: (1) **back wall**: the ring's texture at -2 value steps, slight parallax 0.9,
which shows only through dug tunnels. (2) **Play tiles**: the destructible ring tiles. (3) **Actors.**
(4) **Foreground**: roots and crumbs hanging into tunnels at the edge of the frame, parallax 1.05,
used sparingly, never over the worm.

**Tiling and repetition.** Each ring has 16 base tiles plus 8 edge/lip tiles plus 4 rare tiles
(a fossil, a buried shell, a crystal pocket: landmarks with no text). Ring boundaries are 2-tile
dithered bands. A ring is repeated by hand-placed rare tiles every 12-20 tiles, so the eye has a
landmark.

**How each part of the game reads in this look:**
- **Rings.** Grass crust (the sky band shows above it: P1's composition), then topsoil (warm, roots),
  dirt (umber, packed), aquifer seams (teal, glinting), rock (blue-grey plates), and core (black with
  amber cracks, self-lit). Deeper means cooler and darker until the core, which turns warm again,
  because it is the light at the end.
- **Castings and gardens.** Castings are the darkest, richest crumb (`castings` ramp) with pale grit
  flecks: a trail of the worm's history, darker than the ring around it. Regrowth over castings comes
  in at the ring colour with a garden-leaf fleck. Gardens are soft leaf clusters growing through
  castings, lit by their own small amber pip on fruiting food, so a garden is a little lit island in
  the dark.
- **The burrow home.** The one room where light is warm and steady: a glow-worm/amber pool over the
  bed. Dug shelves get the lip rule. Trophies sit in the light. The trait wall is a dug face with
  parts hung like specimens on a natural-history plate (A's naturalist feel), with no labels.
- **The Mole's swap shop.** A low nook lit by one amber lantern, his shelf of swapped things as
  silhouettes in the pool, and the Mole at its edge. It is the most "furnished" place underground and
  still dark at the corners.
- **Surface (stage 4+).** Dusk teal sky band, silhouette trees, fences and houses in the silhouette
  ramp with amber windows, the grass crust in the grass ramp. Generic and invented (no real place).
  At 0.5x these are pure silhouettes plus amber dots.
- **Dock cutscenes.** P6-2 is the target: pixel dusk, lantern pool, reeds, layered mist, figures as
  silhouettes with rim light. Old Reel and Bobber are pixel forms drawn over their 3D masters (house
  rule), with faces simplified to a few pixels, in this palette.
- **Space.** `space` ramp with sparse amber star points (no starfield noise). Planets are discs
  drawn in a ring ramp each (one theme per planet) with a lit limb and a dark limb. The sun is the
  amber ramp, the only fullbright object in the game, and the payoff of "light is precious".

## 8. Characters
**The player worm** (the design is A-002, `art/concepts/worm-master/`; these rules hold whichever
candidate wins):
- **Anatomy:** a segmented annelid from P2-1, not a grub (no legs, feelers or pill segments). Body
  9-10 art px thick at stage 1, length ~4x the head at stage 1, growing by added segments (not by
  stretching). The head is blunt and slightly raised, the tail tapers, and there is a pale saddle
  (clitellum) about a third of the way back.
- **Flesh:** the `worm/flesh` ramp only. The A-001 shift: the old `#d6756a` light (ΔE 11.8 from P2)
  becomes `#c4917c` / `#e8b08c`, and the old `#a9334f` shadow (16.6) becomes `#7d4650`. Every flesh step
  is ≥ 20 from P2 red.
- **Eye:** one dark pixel (2x2 from stage 5) with an optional 1 px glint beside it, never inside it.
  No mouth line. When eating, the head end opens as a 1-2 px dark notch for 2-3 frames, then closes.
- **Reactions by posture**, not face: rearing up (curious), flattening (cower), coiling (sleep),
  a quick ripple (happy, eating), and the eye pixel's glint going out for one frame (a blink).
- **Slot colour = collar + glow.** A collar band 2 art px wide (3 from body ≥ 12), on or at the
  saddle, with a **1 px `#1e090d` separator column either side** (A-001 condition). It is shaded with
  2-3 steps of the slot colour following the body's light. The glow is a Light2D in the slot colour
  at the rim of the worm's own light, plus a 1-2 px outer glow sprite at 0.5x and in space, so the
  worm reads by slot colour when the collar is too small to see.
- **P1 vs P2:** the same body and flesh. The slot colour is the main read. GAME.md's personality note
  (P1 one eye, P2 "two small eyes, a little cross-eyed") is kept as a pixel detail: in side view, P2
  shows its far eye as one extra pixel above-behind the near one. It is offered in A-002.
- **Traits and stage features** are parts of the worm drawn in the worm's materials (stone plate,
  leaf sprout, blades, cart). They sit at fixed anchor points (crown, back, under, tail), use ring
  ramps, and must pass the 1x silhouette test. Stage features (bow/cap 3, monocle 5, crown of stars 7)
  are an open question in A-002.

**Creatures.** These use the creature rules in §4. Eyes are 1 px (bone or amber), and reactions are
posture. The "wide-eyed when edible" read from GAME.md is drawn as **turning pale** (the bone step
lights the shell) plus the eye pixel growing to 2 px, not a cartoon face. "Smug" threats are a
raised, puffed posture.

**Residents and Jarlings** (Old Reel, Bobber, the Mole, later Bloom): 3D master → low-res render →
pixel form hand-cleaned at size in this palette (house rules). Their identity comes from the master.
Their light and colour come from this bible.

## 9. UI and VFX
- **In-game HUD:** glyph panel and controller glyphs in a dark panel `#060d17` at 85% with a 1 px
  `#286168` rim, with amber focus. Glyphs are shapes, never words. Edge arrows and player markers
  use the slot colours.
- **Menus and the lobby** (for the adult): real type is allowed (brief / CLAUDE.md), set on the dock
  backdrop in the dusk palette.
- **VFX:** chunky pixel puffs (2x2 clusters) in the ring's light steps for digging, an amber sparkle
  (3-5 frames) for food eaten, a slot-colour ring for traits and stage-ups, and a white-amber flash
  (`#fbe0a8`, 2 frames) only for the planet chomp, the sun and stage-ups. VFX may exceed the
  saturation ceiling for ≤ 4 frames. A threat's wind-up is a 2-frame squash plus a bone highlight,
  never red.
- Every action shows a visual (CLAUDE.md rule 7). The visual is in this palette.

## 10. Approved references / rejected references
| ref_id | file | what it shows | approved/rejected | why |
|---|---|---|---|---|
| R1-P1 | `art/concepts/round1/a-wet-earth/P1-1.png` | cutaway, grass line, sky band, strata, root mass | approved (composition, materials) | the world's layout; its ink technique is rejected |
| R1-P2 | `art/concepts/round1/a-wet-earth/P2-1.png` | translucent ringed worm, saddle, taper | approved (anatomy only) | the worm's body; photo technique and big eye rejected |
| R1-P5 | `art/concepts/round1/b-low-light/P5-1.png` | low-key pixel, warm pool, dithered clusters | approved (technique, light, worm ramp) | how it is drawn and lit; grub anatomy rejected |
| R1-P6a | `art/concepts/round1/b-low-light/P6-1.png` | pixel dusk dock | approved | the dock look, palette |
| R1-P6b | `art/concepts/round1/b-low-light/P6-2.png` | dusk dock, lantern pool, mist | approved (target for dock scenes) | the strongest pick of round 1 |
| G1-MIX | `art/concepts/round1/proofs/mix-stage1-640x360.png`, `compare.png` | the approved mix at the real camera | approved (A-001) | the identity at true resolution |
| G1-A | `proofs/a-*` | A Wet Earth | rejected for identity | ink line work fights the tile world |
| G1-B | `proofs/b-*` | B Low Light | rejected for identity | too dark for a daytime TV; grub worm |
| R0 | `art/direction/*` (Arcade Chomp, Lantern Deep, Tall Tale) | earlier rounds | rejected | "reads immature", "too kid focused" (brief §5) |
| GB | `art/concepts/round1/greybox-stage1.png` | the grey-box mascot worm | rejected look (layout reference only) | mascot face, paint-bucket green |

## 11. Consistency rules for new content
- **A new location:** pick its ring ramp(s) from §3. Name its light source and where the lit pool
  falls. Give it one rare-tile landmark. Run the stage-1 screen at 1x and 3x and the 0.5x minify, and
  check there are no colours outside `worm-v1.json` (a new ramp is a minor version bump with the ΔE
  check run).
- **A new creature or food:** decide food or threat first, then follow §4's shape rules, the scale
  table in §6, the silhouette test, and the ΔE check (`palette_v1.py` ramps, or
  `art/tools/deltae_check.py` on the sprite).
- **A new trait part:** worm materials or a ring ramp, at a fixed anchor, readable at 1x, and it
  must never cover the collar or the eye.
- **A new variant of the worm:** the identity lock in the master package (after A-002). A change to
  its proportions, flesh ramp, eye or collar is a Gate 3 exception.
- **Generated art (image API, PixelLab):** the generated image is a starting point and is always
  repainted at 1x into this palette. It must keep provenance and must never imitate a named artist.

## Changelog
| version | date | change | approval |
|---|---|---|---|
| v1.0 | 2026-11-12 | First bible from the Gate-1 B+A mix: palette v1 (70 colours, all ≥ 20 ΔE00 from both slots), worm flesh shift and collar separators, camera table, far-zoom set, environment reads | A-001 (identity); worm design pending A-002 |
