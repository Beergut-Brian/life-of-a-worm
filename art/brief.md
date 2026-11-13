# Art brief (Stage A intake): Life of a Worm  (PILOT DRAFT, not yet reviewed)

project_id: life-of-a-worm
brief_version: v1-draft
written_by: Gary (producer), 2026-11-12
status: draft (waits on Brian's review of the pilot proposal)

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

## Exit check (AD fills in)
- [ ] What the player sees, from what distance, what must stay readable:
- [ ] Open questions for the producer:
