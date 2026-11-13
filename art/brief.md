# Art brief (Stage A intake): Life of a Worm  (PILOT DRAFT, not yet reviewed)

project_id: life-of-a-worm
brief_version: v1-draft
written_by: Gary (producer), 2026-11-12
status: intake checked (AD, 2026-11-12; Brian's review of the pilot proposal still pending)

## 1. Premise and player experience
Old Reel tells his grandson Bobber, on a dock at dawn, the tall tale of the bait worm that got
away. You are that worm: eat what is smaller, flee what is bigger, grow through seven stages, dig a
burrow, eat the disk-shaped planet ring by ring, then drift through space eating planets. One or
two players, no losing. Long-form (hours), a game Kaden is most excited about.
Audience for the look: **an adult who loves beautifully made indie games, with his son as a
co-player** (Kaden, 2026-11-12).

## 2. Technical frame
- 2D, Godot 4.7, Linux TV box (GTX 1060 class) at 60 fps.
- Internal 480x270, integer scale, nearest-neighbour, whole-pixel camera zoom; 16 px tiles.
- Disk planet of tiles, gravity to the core.

## 3. Camera
- Side-on cutaway, rotating so the active worms' "down" is at the bottom; zooms to fit both worms;
  pulls back one notch per growth stage; stage 6 fixed planet shot; stage 7 space, no rotation.
- At stage 1 the worm head is about one tile (16 px) and the screen shows about 30x17 tiles.
- Framing reference: current grey-box frames on `origin/dev` (scripted run) and the round-3
  frames as rough reference only.

## 4. Mechanics that constrain the look
- Food vs threat must read at a glance by size and silhouette; edible tiles vs too-hard tiles.
- P1 green / P2 red as accents on the worms (not paint-bucket fills); edge arrows in those colours.
- Segmented worm: body length grows; traits show as visible parts the moment they are earned.
- Light matters underground (round one's one good idea: light is precious).
- Dock cutscenes (dawn/noon/dusk/night) with Old Reel and Bobber: quiet story scenes.
- Animation pilot: worm idle + crawl (side view, one facing, mirrored).

## 5. Wanted and not wanted
- Wanted: restrained palette with strong value structure and one or two meaningful accents;
  atmosphere and depth (parallax, haze, light falloff, negative space); real-feeling materials
  (wet soil, root fibre, mineral grain, chitin, moss); a worm with presence through silhouette,
  posture and segmented anatomy.
- Rejected, quoted:
  - Round 1 (Lantern Deep): "reads immature" (keep only its use of light).
  - Round 2 (Cosy, Deep, Sideshow Banner): "I don't really like any of these. It still feels to
    kid focused. I think we can dial up the design for these to be more sophisticated."
  - Round 3 (Naturalist, Cinematic Pixel, Specimen Plate; stock SDXL): never judged; withdrawn
    when the process changed. Rough reference only.
- Prohibited: mascot worm (grin, googly or big lidded eye, blush), candy/neon brights, toy-round
  everything, flat centred compositions, gore, text in gameplay.
- Reference feel (never copy): high-end modern pixel art with dramatic light; hand-painted
  atmospheric 2D platformers; natural-history plates and engravings.

## 6. Scope
- Characters: 2 player worms (hero, bespoke, not Jarlings), Old Reel and Bobber (Jarlings,
  3D masters exist or are planned), the Mole (Jarling resident), ring creatures (NPC/background).
- Environments: dock + pond surface, dirt ring, aquifer, rock, core, sky, space.
- Props: surface town props (generic), food items per ring, secrets.
- Pipeline guess: pixel (A: PixelLab + Aseprite) for the worms and ring creatures; Jarlings keep
  their 3D masters and get pixel forms drawn over low-res renders (house rule); a painted pick at
  Gate 1 would move the worms to B (rendered 2D) or hand-painted.

## 7. House rules that apply
- `art-director/house-rules/open-jar-kids.md` (readability, P1/P2, no text, no gore, privacy),
  with Worm's look exemption from the Jarling kid look.

## Exit check (AD, 2026-11-12)
Frames: `art/concepts/round1/greybox-stage1.png` (`--demo`, stage 1, 20 s in) and
`art/concepts/round1/greybox-stage5.png` (scratch scene, stage 5 on the surface). Both 1920x1080
from `scripts/tools/shots.sh`, grey-box placeholder art.

- [x] **What the player sees, from what distance, what must stay readable:**
  - **Correction to section 2:** there is no 480x270 buffer. The viewport is 1920x1080
    (`canvas_items` stretch, nearest filter) and `PolarCamera` zooms in whole steps
    (`data/stages.tres` zoom_index 6,5,4,4,3,3,3 = 3x, 2x, 1x, 1x, 0.5x, 0.5x, 0.5x).
    One 16 px tile is 48 / 32 / 16 / 16 / 8 screen px. The *effective* art canvas is 640x360 at
    stage 1, 960x540 at stage 2, 1920x1080 at stages 3-4, and art is **minified** (half its pixels
    dropped) from stage 5 on.
  - **Stage 1 (couch distance, ~3 m to a TV):** about 40 x 22 tiles on screen. The worm's head is
    ~55 px on screen (~18 art px), the whole stage-1 worm ~4 tiles; it sits at **screen centre**,
    not the lower third (the camera centres on the worm; "down" is at the bottom). The frame is
    ~85% solid dirt with dug pockets; foods (grubs, seeds, pebbles) are 15-30 px on screen,
    the beetle threat ~80 px, the HUD glyph panel bottom right, P1 marker top left.
  - **Stage 5:** about 240 x 135 tiles. The worm is a ~110 x 10 px sliver on the curved horizon at
    screen centre; houses, trees and fences are 20-40 px; the sky fills the top half and the
    bitten disk the bottom. At this scale the worm reads only by its **solid green fill**: a
    green *accent* (collar, rim) alone would vanish.
  - Must stay readable at 1x on the TV: food vs threat (size + silhouette first, the face
    reaction second); edible vs too-hard tiles (value and texture, not just hue, because the
    camera rotates and rings change hue); air/tunnel vs solid (currently only a darker flat
    brown: the weakest read in the stage-1 frame; grey-box food and threats are both warm orange-brown, so today they differ by size alone); P1 green / P2 red (slot colour on the worm and
    edge arrows, distinct from every ring); head direction (head shape and eye, taper of the
    body, the open mouth near food). Everything must also hold at 0.5x for stages 5-6.
- [x] **Open questions for the producer (only ones that change the look):**
  1. **Faces.** GAME.md's art section asks for "exaggerated faces", food that "goes wide-eyed"
     and threats that "go smug", one big eye on P1; the brief bans mascot eyes on the worm.
     Proposal: the worm gets a small eye and no grin; food/threat reactions are kept but drawn
     as posture and a small eye shape change, not cartoon faces. Does Kaden agree?
  2. **Slot colour as fill or accent.** At stage 5-6 (0.5x) an accent-only worm is unreadable.
     Options: (a) accent at stages 1-4, the body takes a slot tint from stage 5; (b) keep accents
     and add a slot-coloured glow/outline at far zoom (recommended); (c) full slot fill always.
  3. **Stage features.** The bow/cap (3), monocle (5) and crown of stars (7) are mascot-adjacent.
     Keep them (drawn naturalistically), or swap for anatomy (horn plates, a lamp organ, a halo of
     orbiting moons)? Recommendation: swap; they decide the worm's silhouette from stage 3.
  4. **0.5x minification.** Pixel art drawn for 1x loses half its pixels at stages 5-6.
     Options: a separate far-zoom tile set (recommended for a pixel direction), or raise the
     camera floor to 1x and accept a smaller view of the planet. Affects which direction wins.
  5. **Camera placement.** The worm is centred, not in the lower third as the pack template
     assumes. Prompts still compose it low for a stronger picture; confirm a "look-ahead" offset
     is not planned, or the proofs will be recentred.
  6. **Kaden drawing the worms himself** (GAME.md) favours a pixel direction (B or C);
     is that still on?
