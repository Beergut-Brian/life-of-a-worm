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

- Technique: 2D pixel art, 16 px tiles, nearest-neighbour, lit with Godot 2D lights (look B, D92).
- Palette (file in `art/`): `art/tools/worm_looks.py` option "b" plus the tuned ring palettes in
  `scripts/look/gen/make_world.py` (see "Life of a Worm: final look" below).
- Reference feel: Super Mega Worm (chomp, faces), Terraria (dense lit tiles). Vibe only.
- Characters used: Gulp and Burp (bespoke worms), Old Reel, Bobber, the Mole.
- Tile or model scale: 16 px tiles, 1 texel per world pixel, camera zoom in whole steps (3, 2, 1).
- Outline weight / rim light: 1 px ink `#140c12` on characters and edibles; 1 px ink plus a lit lip
  on every cut edge of the ground.

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

## Life of a Worm: final look (Docket D92, Kaden, applied 2026-11-12)

**Kaden picked option b: B "Lantern Deep" (lit, Terraria-like, textured tiles, light from the worms,
crystals and the core) with A's faces and ink outlines on characters and edible things, and C's
storybook grade for the dock and the flashbacks.** Sample frame: `art/direction/b_lantern_deep/xs.png`.

What that means lane by lane:

| Part | Rule | Where it lives |
| --- | --- | --- |
| Ground | Dense 4-shade clumpy tiles with pebbles, roots, flecks; each material a seamless 128 px texture + normal map sampled in world space (no 16 px repeat); 1 px ink on every cut edge, a lit lip under it, rounded convex corners; solid ground darkens 7% a step away from open air; grass blades only on the side facing away from the core | `assets/sprites/world/`, `scripts/look/ring_tile_art.gd`, `assets/shaders/ring_tiles.gdshader` |
| Tunnels | Eaten cells show the castings floor (a translucent dark wash with crumbs) over the soil parallax, never a flat back wall | `assets/sprites/world/castings.png` |
| Light | Ambient darkness per ring from `data/rings/looks.tres` (CanvasModulate following the camera's depth); a lantern on every worm head; glowing food casts its colour (crystal cyan, honeydew amber, mushroom violet, droplet blue; nearest 12); daylight shafts through holes eaten in the grass crust (nearest 8) | `scripts/look/look_director.gd` |
| Depth | Three soil parallax layers behind every ring (far dark, roots and stones, deep silhouettes), coloured per ring, sliding around the disk; a sky above the topsoil with far and near hills, clouds and stars | `assets/shaders/soil_parallax.gdshader`, `assets/shaders/sky.gdshader` |
| Time and weather | A 600 planet-second day (dawn, day, dusk, night) tints the topsoil and sky, a quarter of it reaches the dirt top; rain greys the sky and soaks the soil darker from the top down, drying in a minute | `data/rings/looks.tres`, LookDirector |
| Food and creatures | A-style faces with 1 px ink: calm, blink, wide-eyed (something can eat it or carries it), smug (a threat near a smaller worm); drawn at the data radius, lit from the top left | `assets/sprites/food/`, `assets/sprites/creatures/`, `scripts/look/face_sprite.gd` |
| Juice | `Juice.chomp/shake/stage_flash/debris` (`scripts/fx/juice.gd`): crumbs in the food's colour, shake by bite size, 2 white frames, debris falling to the core | everyone calls these |
| Dock and flashbacks | C's storybook grade (sun-faded palette, sepia ink, dither, paper grain) | story / dock lanes |

Palette rules that keep the worms readable (tested in `tests/test_look_contrast.gd`): every colour that
covers 5% or more of a dirt or topsoil material is at least ΔE2000 20 from both P1 `#3cc24a` and
P2 `#e4393c`, every colour over 1% at least 15. The grass was moved toward olive and the clay toward
ochre to get there (B's own grass `#9fbf63` is only 12 from P1).

Regenerate the art: `python3 scripts/look/gen/make_world.py && python3 scripts/look/gen/make_sprites.py`
(Pillow only, deterministic). Frames: `scripts/tools/shots.sh "" 5 <dir> --demo --look=<preset>` with
`dirt`, `topsoil_day`, `topsoil_dusk`, `tunnel_both`, `shaft`, `chomp`, `rain`, `stress`.
