# Art direction

## House style (every Open Jar game)

The rendering technique changes per game; these rules do not.

- Chunky silhouettes readable from 10 feet. Every character identifiable by outline alone.
- Big faces, big eyes, exaggerated expressions. Emotion is the feedback channel.
- Saturated, high-contrast palette: 5 to 7 hues per game drawn from a master palette
  (Hermes proposes three, Kaden picks, unless Kaden specified one up front).
- Player 1 is green (`#3cc24a`), Player 2 is red (`#e4393c`), in every game, carried by the
  character's costume accents, not by a separate skin.
- Thick outlines or strong rim light so things pop off the background.
- Squash-and-stretch on everything that moves. Juice over fidelity.
- Zero on-screen text in gameplay. Icons, colour, sound and animation carry meaning.
- Humour is physical: wobbling, bonking, flying hats, exaggerated reactions.
- Nothing scary. Goofy enemies, pops and boings, no blood.

## Characters

Recurring characters come from `openjar-characters` (submodule at `addons/openjar/characters/`).
Each has a bible, a look sheet, a voice pack and prompt packs. Universal characters can be used
anywhere; Jeff and Chuck are the P1 / P2 defaults, not locked: players pick any roster character, and
the slot colour (not the character) says who is who.
New characters are proposed in the design sprint and approved by Kaden before any art is made.

## This game

The pick (Docket D92, defaulted 2026-11-12 07:00 to the recommendation): **"B Lantern Deep as the
base look, plus A's faces and C's grade on the dock."** Kaden earlier: a grown-up, adventurous look,
not one "catered to kids".

- Technique: 2D pixel art, 16 px tiles, nearest filter, whole-pixel camera zoom, lit with Godot 2D
  lights. Dense 4-shade textured tiles with ore flecks, roots, crystals and glowing mushrooms, a
  normal map per atlas (`assets/sprites/tiles/`, baked by `art/tools/lantern_tiles.py`), drawn through
  the addon's `TileArt` hook (`scripts/lighting/lantern_tile_art.gd`: solid tiles by open mask x 4
  variants, back walls per ring). Light: one `Lantern` node per level (`scripts/lighting/lantern.gd`):
  a coloured CanvasModulate ambient by ring (warm dirt, cool rock, orange core; dim, never dark,
  floor 0.6), a capped pool of 16 PointLight2Ds handed to the worms first, then the core, daylight
  shafts through eaten crust, crystals, the Strangestone and glowing mushrooms. Solid ground
  darkens away from open air in the tile shader (`shaders/lantern_tiles.gdshader`), read on the GPU
  from the planet overview texture. No 2D shadows.
- Faces (from A): huge white eyes, 1 px ink, loud mouths on worms, foods and creatures. P1 one big
  lidded eye, P2 two small cross-eyed eyes; foods go wide-eyed with an "o" mouth and a sweat drop,
  threats look smug (half lids, smirk). Never on machines or vehicles (boot, lawnmower).
  Sprite sets: `assets/sprites/worm/lantern/` (same names and sizes as `assets/proto/worm/`),
  `assets/sprites/foods/<id>_calm|wide.png`, `assets/sprites/creatures/<id>_calm|wide|smug.png`
  (`art/tools/lantern_faces.py`).
- Dock grade (from C): the dock and its cutscenes only, never underground: `DockGrade`
  (`scripts/lighting/dock_grade.gd`, `shaders/dock_grade.gdshader`): sun-faded colour mapped between
  sepia ink `#3a2418` and paper `#f8ecd0`, paper grain, soft vignette, as one screen pass.
- Palette (file in `art/`): `art/palette/lantern_deep.gpl` (and `.hex`), 66 colours: look B's ring
  ramps (deep, low, mid, high + two wall shades) for topsoil, dirt, rock, core, the grass crust, plus
  clay, ore, crystal, mushroom, stem, flower, Strangestone, castings, root, sprout, egg, pebble, ink.
  Every tile pixel is snapped to it. Sky `#2d5f96 > #c7e4f2`, space `#05071a > #24306a`.
  ΔE2000 of both worms against every ring colour: `art/direction/deltae_lantern.md` (worst 20.6).
- Reference feel: a lantern-lit dig. Moody, warm, deep, the worms carrying their own light; the
  dock a faded storybook plate. Vibe only, no copying.
- Characters used: the two worms (Gulp P1 `#3cc24a`, Burp P2 `#e4393c`, tinted in code), Old Reel and
  Bobber on the dock (library pixel forms), the slice's foods and creatures.
- Tile or model scale: 16 px tiles; worm head 20 px, segment 16 px at stage 1; stage-1 food under
  20 px; a stage-2 threat at least 1.25x the head (K-01).
- Outline weight / rim light: characters 1 px ink `#140c12`; terrain has no outline, only a dark
  1 px rim and a lit 2 px lip where a tile meets air. Each worm's light is warm white pulled 30%
  toward its slot colour, so the rim of light round Gulp is greenish and round Burp reddish.

## Asset pipeline

- 2D sprites and textures: ComfyUI on the Proxmox GPU server with this game's prompt pack in
  `art/prompts/`. Clean and palette-snap before anything enters `assets/`.
- Pixel art: generated roughs cleaned in Aseprite; hero characters hand-drawn or heavily cleaned.
- 3D: image-to-mesh for props, cleaned in Blender; hero characters modelled or heavily cleaned.
  Export `.glb` with flat materials.
- Placeholders ship first: coloured boxes with the final size and pivot, named exactly as the
  final asset will be, so Gameplay never waits on Art.
- Every asset gets a line in `assets/CREDITS.md`. Generated art must not depict or imitate
  recognisable characters, brands or artists.

## Life of a Worm (Gary, 2026-11-10)
- Technique: 2D pixel art, 16 px tiles, nearest-neighbour, whole-pixel camera zoom (GAME.md, Art direction). Not the smooth 3D Jarling look; Jarlings appear as pixel forms drawn over low-res renders of their 3D masters.
- Palette: Kaden chose an options lane (Docket D87, 2026-11-10): three genuinely different looks, one of them a lit, Terraria-like style (dense textured tiles, light falloff, parallax), each as real frames of the disk world with every ring's dominant hue (dirt brown, rock grey-blue, core orange, topsoil green, sky blue, space navy) and both worms (P1 `#3cc24a`, P2 `#e4393c`) readable on every ring. He picks or edits. No final art before his pick.
- The kid-friendly option must not read as "catered to kids"; at least one option is grown-up and adventurous.
