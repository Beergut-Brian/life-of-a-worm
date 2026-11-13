# Life of a Worm: Stage B round 1 directions (AD, 2026-11-12)

Audience: an adult who loves beautifully made indie games, with his son as a co-player.
All three are shown from the real camera: side-on cutaway, "down" toward the core, worm small in
the lower third, wide 16:9. None has a mascot worm (no grin, no googly or big lidded eye, no blush),
candy brights, toy-round shapes or text in gameplay. P1 green `#3cc24a` / P2 red `#e4393c` are
slot accents (a collar band, a rim glint, the edge arrow), never fills, and no anchor below sits
near either hue.

**Real framing (from the grey-box, see `art/brief.md` exit check):** the viewport is 1920x1080 with
16 px tiles and whole-step zoom, not a 480x270 buffer. Stage 1 runs at 3x (one art pixel = 3 screen
px, an effective 640x360 canvas, about 40x22 tiles), stage 2 at 2x (960x540), stages 3-4 at 1x
(1920x1080, art pixels at native size) and stage 5 at 0.5x (art is minified). "480x270" below
means the brief's target proof size; the real canvas is finer, which helps B and C.

## What happened to the draft's three ideas
- **A Painted Naturalist: kept, sharpened.** It is the strongest answer to "more sophisticated";
  sharpened to a fixed light model (overcast daylight from above that dies with depth) and real
  wet materials, so it is not just "brown and soft".
- **B Cinematic Pixel: kept, sharpened.** It is the cheapest road to a shippable game and the one
  Kaden can hand-draw into; sharpened away from round 1's Lantern Deep (chunky tiles, light pools)
  toward low-key chiaroscuro: most of the screen is near-black, light is the drawing.
- **C Specimen Plate: replaced by Relief Print.** Sepia cross-hatched engraving repeats round 1's
  rejected Tall Tale and the hatching turns to grey mush at game scale; a carved relief print gives
  the same "made by hand, old story" feeling with flat inks that survive 1x and pixel scaling.

## A. Wet Earth (grounded): painted naturalist
**Pitch.** The soil as a naturalist would paint it from a glass-sided wormery: dark wet loam with
mineral grain, pale root hairs threading through, air pockets with haze, and the world above
reaching down only as soft grey daylight that fades ring by ring. The worm is a real annelid, made
beautiful: glistening, translucent at the edges, banded, with a pale saddle (the clitellum) where a
slot-coloured collar can sit. Quiet, tactile, a little awe; scale does the comedy, not faces.
- **Technique:** hand-painted 2D (soft and lost edges, visible brush texture, layered glazes),
  three parallax depth layers with atmospheric haze.
- **Camera scale:** gameplay framing, foreground root and grain layer slightly out of focus to sell
  the "tiny worm, huge world" macro feeling.
- **Light model:** diffuse overcast top light filtered through the crust, falling off with depth;
  local soft bioluminescence (fungal threads, crystals) as the only other sources.
- **Shape language:** organic, fibrous, irregular; long tapering curves (roots, the worm), crumbly
  clods; no hard outlines, silhouettes made by value.
- **Palette intent:** cool desaturated earth, high value range, one cold accent for living light.
  `#2b231f` deep loam, `#5a4636` wet soil, `#4c5560` slate stone, `#cfc6b0` root bone,
  `#8d9aa3` haze, `#5fa9b8` living-light teal.
- **How the worm reads:** pale pink-umber body against dark soil (value contrast), a lighter
  saddle band, head lit from above; head direction by taper and a tiny dark eye spot.
- **How close the game gets at 480x270 / 1x:** medium. Soft painting does not survive nearest
  filtering at 3x and minifies to mud at 0.5x; the game needs a "painted-pixel" translation
  (painted tiles authored at 1x with a clean value plan, soft light from Light2D, haze as
  parallax layers). Expect 60-70% of the concept.
- **Pipeline:** B (rendered 2D: painted/rendered sprites, normal maps, Light2D). Bigger asset
  cost; worms as a rendered segment rig, not a 16 px sprite set.

## B. Low Light (grounded): cinematic pixel chiaroscuro
**Pitch.** A dense, hand-placed pixel world where most of the screen is dark and light is earned:
a single hard key from a hole you ate, the warm glow of a crystal, the worm's own trait-light. Soil
is drawn as packed mineral grain and stone facets that catch a rim of light at their edges. It
looks like the best modern pixel games (dramatic, restrained, every pixel placed), and keeps round
1's one good idea, light is precious, without its chunky toy tiles.
- **Technique:** pixel art, hand-placed clusters, 4-5 shade ramps per material, no outlines inside
  the terrain, selective dark outline only on actors.
- **Camera scale:** gameplay framing, worm small in the lower third, crisp pixel grid.
- **Light model:** low-key chiaroscuro; one hard directional key plus rim light; deep shadow is
  the default; darkness lifts by ring as the world opens up.
- **Shape language:** angular and faceted (stone chips, crystal facets, broken clods), small
  sharp clusters against big dark masses.
- **Palette intent:** near-black warm darks, ochre midtones, one warm key colour.
  `#141214` charcoal, `#3a2a22` umber, `#8a6a3c` ochre, `#6b6a70` mineral grey,
  `#e8a04a` amber key, `#c28470` worm flesh.
- **How the worm reads:** brightest warm form in the frame, rim-lit edge on the dark side,
  segment bands as value steps; slot colour as a 1-2 px collar band and rim glint.
- **How close the game gets at 480x270 / 1x:** high at stages 1-4 (art is authored at 1x and
  scaled 3x/2x/1x exactly); stage 5's 0.5x needs a reduced tile set or the camera floor raised.
  Expect 85-90%. Light2D + normal maps already exist in the build.
- **Pipeline:** A (pixel: PixelLab + Aseprite), 16 px tiles, worms as a hand-cleaned pixel set.

## C. Relief Print (Hail Mary): carved woodblock/linocut
**Pitch.** Old Reel's tall tale as a hand-pulled relief print: two or three flat inks on a warm
bone paper, every soil layer cut as bold rhythmic gouge strokes that follow the strata, the worm a
single confident carved shape. Light is not simulated; it is the paper showing through the cuts,
so a tunnel you eat literally becomes "white" space. Graphic, adult, very ownable, and it ties
the underground to the dock scenes without storybook sweetness.
- **Technique:** flat ink layers with registration offsets, carved gouge marks, paper grain;
  no gradients.
- **Camera scale:** slightly wider than A and B, more strata visible (pitched at stage 2's framing),
  worm smaller in frame so the carved pattern carries the composition.
- **Light model:** none simulated; notan (ink vs paper) with one overprinted accent ink for
  heat and life.
- **Shape language:** bold curved gouge strokes, concentric rhythms following the disk's rings,
  big simple silhouettes, deliberate hand-cut wobble.
- **Palette intent:** limited inks. `#1b2238` indigo-black ink, `#e9e0cc` bone paper,
  `#a5502e` rust overprint, `#5f6b4e` moss ink, `#c9a85a` ochre overprint.
- **How the worm reads:** a paper-white or ink silhouette with carved segment rings, against the
  pattern by figure-ground; slot colour as the one extra overprint on the worm.
- **How close the game gets at 480x270 / 1x:** high for still frames (flat inks pixelate cleanly),
  hard for a fully destructible world: gouge patterns must be tile-able and re-cut as tiles are
  eaten, and food vs threat must not hide in the pattern. Expect 70-80%, with risk in motion.
- **Pipeline:** A (pixel: flat-ink tiles in Aseprite, small palette), worms as a 2-3 ink pixel set.

## Filter test (each pair must differ in >= 3 of 5)
| Pair | Technique | Camera scale | Light model | Shape language | Palette | Differs in |
| --- | --- | --- | --- | --- | --- | --- |
| A vs B | painted vs pixel | same | diffuse top light vs hard key + rim | organic fibrous vs faceted | cool earth + teal vs warm darks + amber | 4 |
| A vs C | painted vs carved flat ink | close macro vs wider strata | diffuse vs none (notan) | fibrous vs gouge rhythm | cool earth vs 3 inks on paper | 5 |
| B vs C | pixel shading vs flat ink | close vs wider | chiaroscuro vs none | faceted vs curved gouge | warm darks vs indigo/rust/bone | 5 |

## Scores (AD, before images; 1-5)
| | Originality | Coherence | Readability | Feasibility | Reuse | Total |
| --- | --- | --- | --- | --- | --- | --- |
| A Wet Earth | 3 | 4 | 3 | 2 | 3 | 15 |
| B Low Light | 3 | 4 | 4 | 5 | 5 | 21 |
| C Relief Print | 5 | 4 | 3 | 3 | 4 | 19 |

**Recommendation: B Low Light**, with C as the one to watch. B is the only direction the shipped
game can match closely at every stage, it reuses the build's Light2D and normal maps, and it
leaves room for Kaden to draw the worms himself. If C's images land, it is the more distinctive
identity and still a pixel pipeline.
