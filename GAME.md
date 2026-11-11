# Life of a Worm

# Producer notes (Gary, 2026-11-10; these supersede the plan text below)

The plan below is Kaden's brief of 2026-11-09, revised 2026-11-10, kept as he wrote it. Where it disagrees with these notes or with Open Jar's standing rules, these notes win. "Hermes" in the plan means Gary, the producer.

## Where Worm stands
- **Gate.** The Hill has reached first playable (v0.1.0 on `main`, 2026-11-10). The second half of the gate, The Hill's `tileworld`, `split_screen`, cutscene player and PictoBubble moved into `openjar-addons` and tagged, is being built by lane `addons-extract-hill-1` (started 2026-11-10 23:07, target addons `v0.2.0`). The Hill's own copy of the tile world already has a `disk_shape.gd` and a shape/gravity abstraction, so Worm's polar world is an extension, not a rewrite.
- **Repo.** `Beergut-Brian/life-of-a-worm` is created only when Kaden says go. Everything in this folder is ready for that moment.
- **Priority.** Spaceballs, Junk Yard Zap and the launcher go first (launch-ready). The Hill and Worm only fill slots those don't need (Kaden, 2026-11-10 22:41).

## Standing rules mapped onto this plan
- **Template pieces.** Ready-up start screen, main menu, pause menu with the big back-to-launcher icon, drop-in, and solo playtest mode (`--solo`, or hold Select + Start for 2 s; session-only) all come from `openjar-template`. The bait-tin dock is the start screen's backdrop and the save select; the template lobby runs on top of it. Menus are for Kaden: real type, text labels and controller glyphs are fine there. Gameplay stays text-free.
- **No forced movement (supersedes "the far worm is gently pulled toward the other by a wormhole tunnel").** Kaden's rule is never to auto-steer or move a player for them. The shared camera zooms out to fit both worms up to a cap; beyond the cap the far worm gets an edge arrow in its colour, and holding B warps it to its partner (the plan's own 2026-11-10 addition). The "wormhole" survives only as the look of that warp.
- **Select (supersedes "Select: Restart (double press)").** A persistent 25-hour planet has nothing to restart, and an accidental restart would be a disaster. Select does nothing alone; Select + Start held for 2 s is solo mode, as in every game. A stuck worm warps home with a held B.
- **Buttons.** Stick, A and B are the whole game for the kid; X carry, held-B warp and Y tackle box are the depth layer. There is no "stick-only" requirement anywhere (Kaden, 2026-11-10). Each game with more than a few actions shows an on-screen hint panel with glyphs that changes with context (next to food you could carry: X; in the burrow: Y), plus a blinking glyph over the worm when an interaction is ready.
- **Show the cause.** Every stage-up, trait, getting eaten, the breakthrough and the planet chomp is shown on screen with a camera beat, and the big ones are the dock cutscenes the plan already describes. A trait that changes play shows its part on the worm the moment it is earned.
- **Upgrades are felt.** Every trait changes something visible and audible on the worm (the plan already requires this). No hidden-number traits.
- **Progress is earned.** Rings are gated by stage and apex creature, the plan's own structure. Stage 1 starts slow.
- **Characters are 3D-first (Kaden, 2026-11-10).** Bobber is a new Jarling on the standard body (a kid build) with a 3D master, then a pixel form drawn over low-res renders and cleaned at size. Old Reel and the Mole already exist in `openjar-characters`; their pixel forms for Worm derive from their masters. The two worms are not Jarlings: they are Worm's player avatars, designed as a bespoke Jarling-style 3D creature master (the way the Dragon was) and then a hand-cleaned 16 px pixel set. Kaden may hand-draw the worm heroes himself (the plan); if he does, his pixel art is the source of truth and the 3D master follows it.
- **Character chooser.** In Worm you play a worm, so the template chooser is hidden; the green/red slot follows the launcher's profile pick (the plan). The two worms are library entries with `playable: false`, because a playable library character must use the standard humanoid body.
- **Stage features are the worm's, not gear.** The bow or cap at stage 3, the monocle at 5 and the crown of stars at 7 are parts of each stage's sprite set, not equipment items, so the gear rule doesn't apply.
- **Old Reel's role.** His library bible (written from Kaden's character sheet) calls him the worm's nemesis who appears at the water's edge. The brief decided the bible bends to the dock scenes, so in Worm he is the narrator of the tall tale, and the "afraid of catching the worm" joke becomes "he never did catch it, and he's glad". Revised bible draft: `characters/old_reel-worm-revision.md`.
- **Jarling cameos.** The brief allows only Old Reel, Bobber and the Mole at launch. Bloom's character sheet named Worm as her home game, so she becomes Worm's first cameo update (one of the empty spots the surface and secrets keep), and her bible's home game stays Worm with "first appears" moved to that update. (Gary's pick; Kaden can veto.)
- **No personal info or real places.** The dock, the pond, the shed and the small town are invented and generic (the plan already says so).
- **Launcher jar.** `store/jar.glb`: a tiny text-free 3D diorama, a dock on a bitten little planet with a worm curling out of it, made in the store-art lane.
- **Music and voices.** Music via ElevenLabs (a paid service; one track first with its real cost, then the rest). Old Reel's voice is his library voice, whichever take Kaden picks on Docket D85. Bobber's voice follows `references/voices.md` after his bible is approved.
- **Physics tests stage their objects** so outcomes never hinge on a chaotic pile (falling debris, cows rolling to the core).
- **Plan status.** The repo gets `PLAN-STATUS.md` with one row per brief line before the first lane, and every lane updates its rows.

## Stale lines in the plan
- `data/BALANCE.md: 20 to 30 minute full run; one stage every 3 to 4 minutes` is superseded by the 2026-11-10 targets (2 to 4 hours a stage, 15 to 25 hours to the chomp, a segment every 2 minutes, something new every 15).
- "Getting eaten ... about a minute of eating" and "one segment shorter" agree; the kid check "never a stage" stands.
- "Split director: available" stays an experiment only; the default is one shared rotating camera, decided by playtest.
- The "Open questions for Kaden" list is current except that Bobber's bible is now drafted (`characters/bobber-bible.md`).

## Kaden's answers, 2026-11-10 (these supersede the open questions below)
- D86: create the repo now and run the two tile-free risk prototypes (traits on a segmented worm; stage-6 chomp + jar + cut to space) in slots the priority games leave free. The polar-chunk prototype waits for `openjar-addons` v0.2.0.
- D87: palette by options lane: three different looks, one lit and Terraria-like; Kaden picks or edits.
- D88: Gary proposes three name pairs for the green and red worms; Kaden picks.
- D89: Bobber's bible and Old Reel's dock-scene revision approved as drafted (`openjar-characters`).
- 2026-11-11: Worm names (D90, Kaden): green = Gulp, red = Burp.

## Decisions made without Kaden
- 2026-11-10: Wormhole pull dropped (no forced movement); edge arrow + held-B warp instead.
- 2026-11-10: Select restart dropped; Select + Start = solo, as everywhere.
- 2026-11-10: The worms are bespoke Worm avatars (library entries, not playable elsewhere), 3D creature master then 16 px pixel set, unless Kaden draws them.
- 2026-11-10: Bloom becomes Worm's first cameo update rather than a launch character.
- 2026-11-10: Build order inside the gate: addons extraction now (Systems, Opus); the Worm risk prototypes that don't need the tile world (trait resolver on a segmented worm; the stage-6 chomp + jar snapshot + cross-fade) can run as soon as the repo exists; the polar-chunk prototype waits for addons `v0.2.0`.
- 2026-11-11 (proto R-b): A jar is per install at `user://jars/<planet_id>.json`, `planet_id = <profile>_<seed>`. Entering a jar plays it as profile `jar_<id>` with `stage6_disabled`; leaving writes what you did back into the jar, so a jar is a planet you keep playing, not a frozen photo.
- 2026-11-11 (proto R-b): If the jar can't be written, the chomp doesn't happen (nothing built is ever lost).
- 2026-11-11 (proto R-b): Confirm is a 2.0 s hold of A with a filling ring; letting go drains the ring at twice the fill speed and plays a soft boop. Either player's A counts.
- 2026-11-11 (proto R-b): The chomp is 6 s of 14 bites that grow bigger, ~12 s from confirm to space in all (1.1 s jar beat, 6.4 s chomp, 3.6 s gulp-silence-burp, 1.25 s cross-fade). Tunable constants in `scripts/chomp/planet_chomp.gd`.
- 2026-11-11 (proto R-b): In space, bumping a bigger planet knocks the worm back (a physical bounce, not steering) and the planet wakes up for a second. The demo's autopilot exists only under `--demo-chomp`.
- 2026-11-11 (proto R-b): Bigger-eats-smaller lives in `scripts/space/stage_rule.gd` (`StageRule.relation`) until the worm lane's stage logic exists; the disk's `World.is_edible_by` should call the same rule.
- 2026-11-11 (proto R-a): Polar chunks are 32-tile ring bands cut into sectors about 32 tiles of arc long, 5x5 live around each worm. 16-tile chunks need twice as many to cover a screen; 48-tile chunks double the cost of every load (numbers in the R-a report).
- 2026-11-11 (proto R-a): Regrowth runs on the planet's own saved clock, not the wall clock: nothing regrows while the game is closed, and only chunks near a worm regrow (a far tunnel catches up the moment a worm comes back).
- 2026-11-11 (proto R-a): Castings stay under a tile that grows back, so a tunnel eaten twice comes back fast twice and gardens can spread along old tunnels. Regrowth never fills a cell within 3 tiles of a worm.
- 2026-11-11 (proto R-a): Starting regrow times in planet seconds (plain / in castings): surface 120 / 30, topsoil 180 / 45, dirt 240 / 60, deep rock 600 / 150, core 900 / 225. Tiles removed by anything but a worm regrow at the plain rate. Content lane tunes `data/rings/rings.tres`.
- 2026-11-11 (proto R-a): A seed dropped in castings sprouts at once, then fills one cell every 4 planet seconds, spreading only through castings, up to 10 tiles from the seed; garden food that gets eaten grows back as garden.
- 2026-11-11 (proto R-a): The planet shot steps the zoom down to 1/16 centred on the core and swaps the live tiles for a 1-px-per-2-tiles picture of the whole planet with every bite drawn in; that picture is also the stage-6 chomp's `planet_texture`.
- 2026-11-11 (proto R-c, traits): A trait is earned when, at one moment, the worm has at least N segments of each flavour its `TraitData.requires` names. A hybrid is simply a trait that names two flavours; there is no other hybrid rule, so the base traits of a hybrid are earned on the way to it (Stone head and Glow before Drill head).
- 2026-11-11 (proto R-c): A segment's flavour is whichever flavour gave the most growth since the previous segment; the partner's 0.25 share is flavourless, so co-op never paints the other worm's diet or hands it traits.
- 2026-11-11 (proto R-c): New segments join at the tail. Getting eaten removes the newest (tail) segment; stage and earned traits never drop, even if segments fall below the stage threshold.
- 2026-11-11 (proto R-c): Stacking rule: `value = (base + sum of adds) * product of muls` over active traits, sorted by id (order never matters). Two parts in one slot: the higher `part_priority` shows (Drill head beats Stone head), but both traits' modifiers still stack.
- 2026-11-11 (proto R-c): With every slot full, a newly earned trait waits on the trait wall (with its reveal ring and sting); when a stage adds a slot, the newest waiting trait equips itself. The wall never auto-unequips anything.
- 2026-11-11 (proto R-c): Stage thresholds, slots per stage, growth per segment, partner share and base stats live in `data/traits/worm_rules.tres` for the prototype (stages 2..7 at 6/10/15/20/24/40 segments, 2 growth per segment); they move into `data/stages.tres` when the Content lane makes it.
- 2026-11-11 (proto R-c): Placeholder trait wall opens on Y (left/right picks, A equips/unequips, B or Y closes); in the real game it hangs in the burrow. X and Y are new player actions `carry` and `tackle`.
- 2026-11-11 (proto R-c): "Bite rock a stage early" is a stat per flavour, `bite_bonus/<flavour>`; slow ground is `drag/<kind>`. New traits that change what can be eaten or where you are slowed need no worm code.
- 2026-11-11 (grey-box): The worm names show wherever the game names a worm: lobby podiums and plates, "GULP PAUSED", the tin log, debug logs. Gameplay stays text-free (the HUD is glyphs and pictures).
- 2026-11-11 (grey-box): An apex creature is food once the worm's body has grown to its size (segments for the next stage), and the stage-up waits for that apex bite. So the dirt beetle is a threat at stage 1, turns pale and wide-eyed when you are long enough, and eating it is the stage-up.
- 2026-11-11 (grey-box): The apex notices a smaller worm within 260 px (the rumble plays once), winds up for 1.0 s before every lunge, and dozes for 6 s after eating; the worm pops out of its back end one segment shorter and dizzy.
- 2026-11-11 (grey-box): A hollow is a spot where 75% of the cells within 2 tiles are air; hold still there for 2 s and the worm falls asleep: that is home. Sleeping in a hollow elsewhere moves home (trophies come along, they are data). Nothing within 5 tiles of home ever regrows.
- 2026-11-11 (grey-box): Carried home, a seed is planted in the nearest castings by the bed (a garden); anything else becomes a trophy in a notch dug in the burrow floor. Pets later.
- 2026-11-11 (grey-box): Held-B warp goes home; if the partner is more than 420 px away and not smaller, it goes to the partner instead; with no home and no far partner it is a bonk. Y in the burrow opens the trait wall; Y elsewhere is the tackle box (a placeholder beep for now).
- 2026-11-11 (grey-box): Tunnelling costs 35% speed, and each dirt tile is 0.05 growth in its ring's flavour (about 40 tiles a segment); the tunnel is about 1.5 tiles wide at stage 1. The worm's body grows 18% per stage. Camera cap: 3x at stage 1, 2x at stage 2, 1x at stages 3 and 4, 0.5x after.
- 2026-11-11 (grey-box): Saves are three bait tins per launcher profile (`user://saves/<profile>_tin1..3.json`). The dock comes after ready-up: pick a tin, an empty one is a new planet. `--demo` plays in a throwaway "demo" tin and never touches a real one.
- 2026-11-11 (grey-box): A worm that drops in hatches at once (no waiting for a round); one that leaves stays in the tin and comes back with its own body. Select alone does nothing; in solo, Select hands the pad to the other worm.
- 2026-11-11 (grey-box): Until the Audio lane delivers files, every cue plays a synthesized placeholder beep. Cues beyond the Audio table: `carry`, `drop`, `sleep`, `warp`, `warp_charge`, `segment_pop`, `hatch`, `egg_crack`, `bonk`, `boop`, `beetle_windup`, `beetle_lunge`, `home_trophy`, `home_seed`, `tackle_box`, `solo_focus`, `trait_*`, `wall_open`, `wall_close`, `trait_swap`.
- 2026-11-11 (grey-box): Grey-box planet: radius 300 tiles, the worm starts in a small pocket in the dirt ring, with a seeded trail of grubs past the apex's lair and pebbles and seeds near the start. The lobby backdrop is a placeholder dock still, with no round card.

---

# Life of a Worm — Game Design & Build Plan

Nov 9, 2026 · @Kaden Miller

## Pitch

Old Reel sits on a dock with his grandson and tells the story of the one that got away: a bait worm that slipped off his hook, back when worms were small, and started to eat. You are that worm. Everything smaller than you is food and everything bigger is a threat, until you outgrow it. Eat, grow, mutate, dig a burrow, tend the soil you leave behind, and keep going until the dirt runs out: the trees, the houses, the hills, the whole planet, and then you are a worm the size of a world, drifting through space eating planets.

**This is the capstone of the library so far, and the bar is "incredible".** Ordinary play stays as simple as the first plan: steer and eat. Around that sits a long-form game with Stardew Valley and Terraria-lite depth: a persistent planet, a burrow that is yours, a diet that changes what your worm becomes, a living food chain, secrets in every ring, and a story told in cutscenes. Kaden's son can play it and grow into it; Kaden can play it alone for weeks.

2D pixel art on a disk-shaped planet you can eat tile by tile. One or two players. No losing: getting eaten is a hiccup, never an end. Revised 2026-11-10 from a 20 to 30 minute growth run into a long-form game; the sections below are the current plan.

Repo: `Beergut-Brian/life-of-a-worm` (from `openjar-template`). Build order: game 4, after The Hill, and it starts only once The Hill's tile engine, cutscene tool, split director and PictoBubble are extracted into `openjar-addons`. It inherits those rather than rebuilding them, which is what frees its budget for depth and polish.

**Kaden's original notes, kept verbatim as the north star**

- I know this is kind of like Smash Party, but: a 2D game where you start as a small worm in the ground.
- You need to eat stuff around you to get bigger while avoiding bugs that are bigger than you and can eat you.
- Eventually you can get big enough as a worm to eat the whole world around you.
- Picturing a pretty massive world, and it can all be eaten.
- Spherical world to match our planet, and at the end you get so big that you are just floating around space eating planets.
- Art style like Super Mega Worm.
- Palette: Kaden specifies this one up front rather than picking from Hermes's three.

**Kaden's notes of 2026-11-10, also verbatim**

- Kind of the capstone project so far. We should really work to make this game incredible.
- Complex, creative and fun. Stardew Valley / Terraria-lite levels. Ordinary gameplay needs to be simple. My son should be able to play it and grow. I would love for this to be one I play solo too. A beautiful, fun game that scratches the itch.
- Creative use of cutscenes will help. We started a cutscene generator with The Hill.
- We have a Jarling, Old Reel, an old fisherman. Opening sequence: Old Reel talking to his grandson on a dock about the good old days when worms were small, when they were used as bait. Before they started to grow. Then a storyline about what happened to the worms: they started mutating, growing.

## Story: Old Reel's tall tale

The whole game is a fisherman's story, told from a dock, and it grows the way fish stories do. That frame does three jobs: it gives every cutscene a home, it makes "a worm ate the planet" funny instead of apocalyptic, and it lets a 5-year-old follow the plot by voice and pictures alone.

**Opening (about 60 seconds, skippable, proposed).** Dawn on the dock. Old Reel and his grandson are fishing with something silly on the hook, a sandwich. The grandson asks why they do not use worms. Reel chuckles: worms, in his day, were small enough to fit on a hook. He holds two fingers an inch apart. Flashback in a warmer palette: young-ish Reel, a bait tin, one worm wriggling off the hook, plop, into the dirt by the pond. "That one got away. And then it got hungry." The camera follows the worm underground. You have the stick.

**Structure.** One short dock scene (15 to 30 seconds) at each growth stage. Each time, Reel's hands are spread wider ("it was THIS big"), the grandson is less convinced ("nuh-uh"), and something in the background quietly confirms the story: a tremor in the water, a missing tree, a bite out of the hill.

| Beat | When | Dock scene | In play it marks |
| --- | --- | --- | --- |
| The one that got away | start | The opening above | Stage 1, Grub |
| It got hungry | stage 2 | Reel: it ate everything smaller than itself. Grandson: so do I | Diet and the first trait |
| It started to change | stage 3 | Reel: it was not just bigger. It was different. A sketch of a worm with a stone head | Mutations open up; the burrow |
| It came up | stage 4 | Reel's own shed vanishes into the ground behind him mid-sentence, in the flashback | Breakthrough to the surface |
| Nobody fished that year | stage 5 | The town watches a hill get eaten. Reel is the only one delighted | Hills, sky, the core |
| The big one | stage 6 | Hands as wide as they go. "And then it ate... everything." Grandson: "Then where are WE sitting?" Reel: "...It's a long story." | The planet chomp |
| Still out there | ending | Night. Grandson asleep on Reel's shoulder. A bite is missing from the moon. A long shape drifts past the stars. Reel tips his hat | Space, the sun, credits |

**What happened to the worms (decided 2026-11-10).** Reel gives a different explanation every time he is asked: a comet, his wife's chili, a funny-coloured rock he dug the bait up next to. It is a running gag, and the truth is in the background for anyone who looks: the bait tin sits on a chunk of softly pulsing Strangestone, the same unbreakable stone at the bottom of The Hill, and there is a seam of it at this planet's core. The worms that ate near it began to mutate. That makes mutation the story and the central mechanic at once, and it ties the library's lore together without a word of exposition.

**Rules for cutscenes**

- Voiced, not written. Old Reel narrates in his library voice (Chatterbox); the grandson has a handful of lines. Subtitles exist for Kaden and are off by default. Gameplay itself stays text-free.
- Short, skippable with any button, and rewatchable from the tackle box (see Depth systems).
- Built with the cutscene tool started for The Hill, moved into `openjar-addons` first. Scenes are data: a timeline of shots, sprite poses, PictoBubbles and voice clips, so the Content lane can author new ones.
- In-engine pixel art with a handful of hand-finished key frames per scene. The dock at dawn, noon, dusk and night is one background painted four times.
- Old Reel is an existing Jarling. The grandson is a new one, named Bobber; his bible is drafted for Kaden's approval.

## Players and co-op

One or two worms on the same disk, green and red. The game is complete solo: nothing needs a second player, and a second worm can drop in or out of any save at any time. In co-op they share one camera and one world, so what one eats is gone for both, and a big worm can eat the dirt walls a small worm is stuck behind.

**Saves are bait tins.** The title screen is Old Reel's dock with three bait tins on the rail; each tin is a planet. One can be the family planet and one Kaden's solo planet, and neither affects the other. The launcher's two-face profile picker still decides who is green.

|  | Gulp (green, Player 1) | Burp (red, Player 2) |
| --- | --- | --- |
| Worm | Green segments with a lighter belly stripe; big single eye with a lid for expressions | Red segments, darker stripe; two small eyes, always a little cross-eyed |
| Name | Gulp (Kaden, D90) | Burp (Kaden, D90) |

**Co-op rules that keep both players happy**

- **Growth is shared-ish.** Each worm has its own size, but every bite either worm takes adds a little to both (full amount to the eater, a quarter to the partner). The smaller worm always catches up; nobody is left tiny while the other eats the planet.
- **Can't eat each other.** Worms pass through each other with a boop sound and a heart particle.
- **Shared camera that never loses anyone.** Zoom fits both worms; if they drift too far apart, the far worm is gently pulled toward the other by a "wormhole" tunnel. No split screen in this game; the disk world and rotating camera make splitting disorienting.
- **Drop-in.** The second worm hatches from an egg next to the first at the first worm's current size minus one stage.
- **Getting eaten** by a bigger bug: the worm pops out of the bug's other end dizzy (stars, wobble) and one segment shorter, about a minute of eating, next to the partner or the nearest tunnel. Funny, not scary. A stage is never lost; stages are now hours of play.

## Core loop

Moment to moment the loop is what it always was: eat, grow, unlock bigger food. What changed on 2026-11-10 is the time scale and what surrounds it. The seven stages are now chapters of roughly 2 to 4 hours each for an adult playing with intent (15 to 25 hours to the planet chomp, then an open-ended space endgame), while a 5-year-old makes visible progress in any ten minutes. The planet persists and saves constantly.

| Loop | Length | What you do | What pulls you on |
| --- | --- | --- | --- |
| Bite | seconds | Steer, eat, dodge | The chomp, a new segment popping on |
| Outing | 20 to 40 minutes | Leave the burrow with a purpose: a flavour you need, a secret you spotted, a garden to tend, a trophy to bring home | A new trait, a filled tackle-box page, a nicer burrow |
| Chapter | 2 to 4 hours | Outgrow the ring: eat its apex creature, find its secret, stage up | The dock cutscene, a new ring, new foods, the camera pulling back |
| Planet | 15 to 25 hours | All seven stages | Eating the world, then space, then another tin |

1. **Tunnel and eat.** Steer the worm through dirt. Anything smaller than you is food: dirt itself (slow growth), seeds, roots, grubs, pebbles, then beetles, then everything else. Eating is automatic on contact; the mouth opens as food approaches so the player sees it coming.
2. **Eat it or keep it.** Hold X, the gentle bite, and the worm carries the thing in its mouth instead of swallowing. Carry it home to the burrow and it becomes a trophy, a seed for a garden, or a pet. This is the one decision in the game, and it is optional: a 5-year-old eats everything and the game is fine.
3. **Avoid, then outgrow.** Bugs bigger than you chase lazily. Dodge by tunnelling (they are slower in dirt). Outgrow one and it becomes food, with a "now I eat YOU" sting.
4. **Grow by segments.** Every few bites adds a visible segment. Segments are the progress bar, and they are on the worm, not the HUD.
5. **Stage up.** Enough segments, plus having eaten the ring's apex creature, and the worm swells, the screen shakes, the dock cutscene plays, the camera pulls back and a new ring becomes edible. This is the big reward and gets the biggest sound and visual in the game.
6. **Eat the surface.** Past stage 4 the worm bursts through the crust: trees, fences, cars, houses, hills. The disk visibly shrinks.
7. **Eat the planet.** Stage 6 is a deliberate point of no return, shown as a picture and confirmed by holding the button: one long chomp and the planet is gone. Before it happens the planet is preserved as a **planet in a jar** on Old Reel's shelf, a snapshot you can re-enter and keep playing forever, so nothing built is ever lost.
8. **Space.** Stage 7 and the endgame: themed planets drift by; eat the small ones, dodge the big ones, pick up rare traits, and the sun is the last meal. Then Old Reel offers another tin: a new planet, keeping one trait you choose as an heirloom.

**No fail state.** Getting eaten costs one segment and spits you out dizzy. Nothing built can be destroyed by anything except you. The only irreversible act in the game is the planet chomp, and the jar makes even that safe.

## Two depths: simple for him, deep for Kaden

Same rule as The Hill, pushed further because this is the capstone: **his layer is actions, Kaden's layer is consequences.** Steering and eating are the whole game for a 5-year-old and always work. Everything in the Depth systems section below is something he does by accident and Kaden does on purpose, and it shows up on the worm and in the world, never as numbers, text or menus.

|  | His layer | Kaden's layer |
| --- | --- | --- |
| Eating | Everything is yummy | Diet is a build: which flavours you fill decides which traits you get |
| The worm | It got a cool rock head | A stone head opens the rock ring a stage early; pair it with glow to find geodes |
| The soil | Stuff grows back where I went | Castings make gardens; route your tunnels and you are farming |
| The burrow | My room with my stuff | Trophies give small standing bonuses; pets do jobs; layout matters a little |
| Creatures | Big ones chase me, small ones run | Populations rise and fall with what you eat; thin the beetles and grubs boom |
| Secrets | I found a cave | Every ring has a hidden place with a unique food and a tackle-box page |

Guardrails: nothing in Kaden's layer is ever required to reach the planet chomp; no system punishes; and every system must pass the kid test, meaning that stumbled into by accident it still reads as a fun thing that happened.

## Growth stages

Seven stages, each unlocking a new class of food, a new ring of the world, and a visible feature on the worm. Stages 1 to 5 happen inside one disk scene; stage 6 is the scripted planet chomp that hands off to the space scene for stage 7.

&#91;embedded content: growth stages · 7 stages, grub to star eater\]

Each stage is now a chapter of 2 to 4 hours rather than 3 to 4 minutes, ends with a dock cutscene, and needs two things: enough segments, and having eaten that ring's apex creature. Thresholds, zoom levels and feature sprites are data in `data/stages.tres` so pacing is tuned from playtests without code changes.

## Depth systems

Six systems carry the Stardew and Terraria-lite depth. Each is one simple idea; the depth is in how they combine. All of them are data-driven, all show on the worm or in the world rather than in menus, and none is required to finish.

**1. Diet and traits: you are what you eat.** This is the mutation the story is about. Every food has a flavour. Eating tints the worm's newest segments that flavour's colour, so a diet is visible as stripes. Fill enough segments of one flavour and the worm grows a trait, visibly.

| Flavour | Found in | Trait | What it does |
| --- | --- | --- | --- |
| Root | dirt, topsoil | Green thumb | Castings regrow food twice as fast; gardens yield more |
| Bug | every ring | Wriggle | Faster, with a longer burst |
| Stone | rock ring, pebbles | Stone head | Bite rock a stage early; boulders stop bonking you |
| Crystal | geodes, the core | Glow | Lights dark rings; hidden seams and secrets shimmer |
| Junk | buried cars, the surface | Magnet | Small food drifts to your mouth; later, drag big objects |
| Water | aquifers, the pond | Slick | Swim fast; flooded tunnels stop slowing you |
| Cloud | the sky | Float | Glide between hills and across gaps |
| Star | space planets | one rare trait per planet type | Endgame collecting |

- Two filled flavours combine into a hybrid: Stone and Crystal make a Drill head, Bug and Water make a Skater, Root and Junk grow a Garden cart that carries three things at once. About 8 base traits and 10 hybrids at launch, as `TraitData`.
- Trait slots grow with stage, from 1 at stage 2 to 5 at stage 6. Earned traits are never lost. Sleep in the burrow to choose which are active, from a wall of pictures. For a player who never opens that wall, the newest trait equips itself.

**2. Castings and gardens.** Where a worm has eaten, it leaves dark, rich soil, which is what worms do. Food regrows in castings faster and bigger. Carry a seed home, or anywhere, drop it in castings, and a patch of that flavour grows and keeps growing. That is farming, with no farm screen: Kaden routes tunnels and plants a Crystal patch next to the burrow; his son notices that stuff grows back where he went. The whole world also regrows slowly on its own, so a ring is never exhausted until you have outgrown it and decide to devour it.

**3. The burrow.** Hollow out a chamber anywhere and sleep in it: that is home. Things carried home become trophies on shelves the worm digs itself, seeds become gardens, and small creatures become pets with jobs (a ladybird that fetches seeds, a glow-worm lamp, an ant crew that tends one garden). Trophy families give small standing bonuses, so decorating is also a build. The burrow grows with the worm: by stage 5 it is a cavern with a buried house for furniture. Hold Wiggle to warp home. The burrow rides along into the jar at the planet chomp.

**4. Living rings.** Each ring has a small food chain with plain rules: plants regrow, grubs eat roots, beetles eat grubs, birds eat beetles. Eat one link hard and the others shift. Each ring has one apex creature that must be outgrown and eaten to stage up; it is the chapter's set piece, telegraphed and funny, never a fight.

**5. Secrets.** One hidden place per ring, each with a unique food, a tackle-box page, and sometimes the only source of a hybrid: an ant city in the dirt, Old Reel's sunken rowboat and lost tackle in the aquifer, a fossil hall in the rock, a geode cathedral at the core, a balloon stuck in the sky. **Jarlings are never food.** Library characters met underground (the Mole keeps a swap shop of found things in the dirt ring: trophies for seeds) are neighbours, drawn with a soft outline that means friend.

**6. Old Reel's tackle box.** The collection book, and the only menu in the game: sketched pages for every food eaten, creature met, trait earned, secret found, and every cutscene to rewatch, in Reel's handwriting-style doodles with no words. Each completed page pins a fishing lure to the lid. Completion is the long tail that keeps a solo player going after the planet is eaten.

**Space endgame.** After the chomp, planets are small themed disks (ice, jungle, junk, candy, clockwork), each a 20 to 40 minute meal with its own foods, one Star trait and one page. They come in a different order every time. The sun is the last meal of a run; then a new tin, with one heirloom trait carried over.

## The world

The planet is a **disk**, not a sphere: a big circle of tiles with gravity pointing at its centre. "Down" is always toward the core, so a worm on the far side is upside down relative to one on the near side, the camera rotates to keep the active worms' "down" at the bottom of the screen, and the whole disk can be eaten one tile at a time. This gives the spherical-planet feel in 2D without any 3D.

**Rings from the core outward**

| Ring | Tiles | Food | Threats | Edible from stage |
| --- | --- | --- | --- | --- |
| Core | glowing rock, crystals, and an unbreakable seam of Strangestone at the very centre | crystals (big growth) | lava blobs (bounce you, no damage) | 5 |
| Deep rock | stone, ore | ore nuggets, fossils | rock beetles | 4 |
| Dirt | dirt, clay, roots | seeds, roots, grubs, pebbles | beetles, centipedes, moles | 1 to 3 |
| Topsoil | grass, mushrooms, burrows | mushrooms, ants, worms' lunch (sandwich crumbs) | birds (peck from above), the gardener's boot | 2 to 3 |
| Surface | trees, fences, houses, cars, cows, hills, the water tower | all of it, by size | the lawnmower (loud, slow, funny) | 4 to 5 |
| Sky | clouds, birds, planes, balloons | all of it | nothing | 5 to 6 |
| Space | moons, planets, comets, the sun | all of it, by size | big planets (bump you) | 7 |

- For a long-form game the disk grows to about 1,000 tiles across at 16 px, roughly 785,000 tiles (final size set by the prototype), so it is streamed in **polar chunks** (ring x angular sector) around the active worms.
- Every tile is destructible. Eaten tiles become air; air lets gravity pull loose things (pebbles, a cow) toward the core, which is its own source of comedy.
- Surface props (houses, trees, cows) are multi-tile objects that break into edible chunks when a big enough worm bites them.
- The disk's radius shrinks as it is eaten; the camera's "planet shot" at stage 6 shows a lumpy, bitten planet.
- Surface props are generic small-town jokes: a water tower, a diner, a basketball court, Old Reel's dock and shed by the pond. No real places (decided 2026-11-09). Content lane data, not code.

## Bugs and threats

One rule: **bigger eats smaller.** Every creature has a size stage. If it is below yours, it is food and runs away slowly. If it is above yours, it is a threat and ambles toward you. Equal size ignores you. The player never needs to learn a bestiary; they only need to look at whether the thing is bigger than them, and the game makes that obvious.

| Creature | Stage | Behaviour | Un-scary because |
| --- | --- | --- | --- |
| Grub | 1 | wiggles in place | it is adorable |
| Ant | 1 | marches in lines | cartoon march, tiny hats |
| Beetle | 2 | trundles toward smaller worms, slow in dirt | round, shiny, blinks a lot |
| Centipede | 3 | wavy chase, gives up fast | wears sneakers on every foot |
| Mole | 3 | a Jarling, so never food and never a threat: pops out of walls, surprised, and keeps the swap shop | squints, apologises (bark), goes back in |
| Bird | 3 | pecks from the surface when you are near the top | pecks with a boing, flies off offended |
| Gardener's boot | 4 | stomps near the surface every so often | just a boot; the gardener is never seen |
| Lawnmower | 5 | drives along the surface, very loud | eats grass only; bumps you, does not eat you |
| Big planet | 7 | drifts; bumps smaller worms off course | has a sleepy face |

- Threats telegraph: a shadow or a rumble a full second before a bigger bug arrives, so a 5-year-old has time to tunnel away.
- Being eaten: a comic gulp, the worm appears out the other side one segment shorter with stars around its head, next to its partner. Half a second of invulnerability sparkle. No sound of pain, ever.
- Every creature except a Jarling becomes food eventually. The moment a former threat becomes edible gets a special sting and a close-up of the worm grinning.
- Nothing hunts you in space except the fun of dodging big planets.

## Camera and controls

One shared camera that rotates so "down" is toward the planet's core, zooms to fit both worms, and pulls back a notch each growth stage. The player only ever steers.

| Input | Does |
| --- | --- |
| Left stick | Steer the worm's head. The body follows (snake style). Holding toward dirt tunnels through it |
| A (Action) | Burst: a short speed boost with a dust trail. Mashing it is fine and funny; it recharges fast |
| B (Jump) | Wiggle: the worm does a little dance and chirps. Pure toy, makes nearby food hop toward you a bit |
| Start | Pause |
| Select | Restart (double press) |

- The camera rotation rate is capped so the screen never spins fast; between two worms on opposite sides of the disk it picks the average "down" and zooms out until both fit.
- At stage 6 the camera cuts to a fixed planet shot for the final chomp, then eases into space where gravity is off and the camera stops rotating.
- Eating is automatic on contact. There is no bite button.

**Added 2026-11-10.** The stick, A and B are still the whole game for a 5-year-old. Three more inputs exist for the depth layer and do nothing harmful if pressed by accident: hold **X** for the gentle bite (carry instead of swallow; release to drop), hold **B** (Wiggle) for two seconds to warp home to the burrow, and **Y** opens Old Reel's tackle box. In co-op the smaller worm's warp goes to its partner instead when the partner is far away, which replaces most uses of the wormhole tether.

## Art direction

Chunky 2D pixel art in the spirit of Super Mega Worm, raised to a "beautiful" bar because this is the capstone: thick outlines, a few big readable colours per thing, exaggerated faces, meaty chomp frames, and on top of that real lighting, depth and atmosphere. Kaden specifies the palette for this game up front rather than picking from proposals.

- **Light.** 2D lights and normal-mapped tiles: the worm's glow trait actually lights tunnels, crystals cast colour, daylight shafts fall through holes you ate in the crust.
- **Depth.** Three parallax layers behind the dirt in every ring; the sky and space get more.
- **Time and weather up top.** A slow day and night cycle and rain that soaks down into the topsoil and makes castings sprout. Cosmetic first, a light garden bonus second.
- **The worm shows its history.** Diet stripes, trait parts, stage features and trophies carried in the mouth are all visible, so two worms never look alike.
- **The dock.** One hand-finished background painted at dawn, noon, dusk and night, with Old Reel and the grandson as the most carefully animated sprites in the game. Title screen, save select and every cutscene live here.

* **Technique:** 16 px tiles for the world, worm segments at 16 px per stage-1 segment scaling up by sprite swap at each stage (not by stretching), surface props as multi-tile sprites, 4 to 6 frame animations. Rendered at a fixed pixel scale with nearest-neighbour filtering; the camera zoom happens in whole pixel multiples so pixels stay crisp.
* **Reference feel:** Super Mega Worm (the worm, the chomp, the mayhem), Terraria (dirt and tiles), Katamari (the joy of scale). Vibe only; no copying.
* **Palette:** Kaden's call. Constraint: each ring of the disk needs its own dominant hue so depth reads instantly (dirt brown, rock grey-blue, core orange, topsoil green, sky blue, space navy), and the two worms' green and red must stay distinct against every ring.
* **The worm:** one big eye (P1) or two little ones (P2), a mouth that opens wide as food approaches, segments that squash when boosting. Each stage adds a visible feature: stage 3 gets a tiny bow or cap, stage 5 gets a monocle, stage 7 gets a crown of stars. Kaden names them; they are library characters.
* **Food reactions:** everything edible has a face that goes wide-eyed when a bigger worm approaches. Threats have a face that goes smug.
* **Juice:** chomp particles in the food's colour, screen shake scaled to bite size, a stage-up flash that whites out the screen for two frames, debris that falls to the core.
* **Store art:** grid is the worm bursting through the surface with a cow in its mouth; hero is the worm in space mid-bite on a planet.
* Pixel art is Kaden's own skill: heroes (the two worms) may be hand-drawn by him; everything else from the Art lane's prompt pack, cleaned in Aseprite.

## Audio

The chomp is the game. Soundbox for SFX, Chatterbox for the worms' chirps and the bugs' barks, ElevenLabs for the music.

| Cue | Plays when | Feel |
| --- | --- | --- |
| `chomp_1..5` | eating, variant by the food's size relative to you | crunch, munch, CRUNCH, gulp, planet-swallowing boom |
| `tunnel` | moving through dirt, looped and pitched by speed | soft scrunch |
| `burst` | boost | zip |
| `wiggle` | dance | chirp and tiny maracas |
| `stage_up` | growth stage reached | rising swell, bell, the worm's happy chirp |
| `threat_near` | a bigger bug within a screen | low rumble, one second of warning |
| `eaten` | gulped by a bug | cartoon gulp, pop, dizzy stars jingle |
| `now_i_eat_you` | first bite of a former threat | triumphant sting |
| `breakthrough` | crust broken at stage 4 | crumbling, birds scatter |
| `planet_gone` | stage 6 final chomp | a huge gulp, then silence, then a tiny burp |
| `space_drift` | stage 7 ambience | sparse synth |

- Music: one theme arranged in seven layers, one added per stage; it goes from a ukulele plink in the dirt to a full brass band on the surface to a slow cosmic pad in space.
- Barks: the worms chirp, never speak words. Bugs have one bark each (the mole's apology, the bird's offended squawk).

**Added 2026-11-10.** Old Reel narrates every cutscene in his library voice (Chatterbox, per the library decision); the grandson has a few lines. Each ring also gets its own ambience bed (dripping aquifer, humming crystals, wind above ground), and each trait adds a small signature sound to the worm, so a build can be heard as well as seen. The dock has its own quiet theme: one guitar, water, gulls.

## Technical plan

Godot 4.7.2 from `openjar-template`, 2D. After The Hill this game is no longer the library's riskiest engineering, because most of its hard parts arrive as tested addons. Its own new risks are three: the polar version of the chunk world with regrowth, the stage-6 hand-off with the jar snapshot, and trait stacking on a segmented worm. Those three are prototyped before anything else.

**Inherited from The Hill via `openjar-addons` (do not rebuild)**

| Addon | What Worm takes | What Worm changes |
| --- | --- | --- |
| `tileworld` | Chunk manager, edit-only save store, falling bodies that wake when undercut, water fill, props that break into chunks | Chunk key becomes ring and sector instead of x and y; gravity points at the core; edits gain a timestamp so tiles can regrow |
| Cutscene tool | Timeline of shots, poses, PictoBubbles and voice clips as data | New scenes only; the dock set |
| `PictoBubble` | Wordless speech and prompts | The Mole's swap shop, the planet-chomp confirmation, trait wall |
| Split director | Available | Not used by default: one shared rotating camera. Try it with per-view rotation in the prototype and decide by playtest |
| Template systems already built | Lobby, pause, drop-in, solo playtest mode, layered music (one layer per stage) | Seven layers, one per ring |

**New in this game**

- Regrowth: a low-frequency pass over live chunks restores eaten food tiles whose edit is older than the ring's regrow time, faster in castings; castings are a second tile layer written wherever a worm eats.
- Traits: `TraitData` resources (flavour requirements, modifiers, a part sprite per stage, a sound). The worm holds flavour counts per segment and a list of earned and active traits; modifiers stack through one `WormStats` resolver so no trait is a special case.
- Burrow: a flagged chamber region with shelf slots the worm digs, a sleep spot, pet slots; trophies and pets are `Node2D`s saved by id.
- Living rings: per-ring population counters with simple birth and predation rates, spawning into live chunks; no simulation outside live chunks beyond the counters.
- Tackle box: a page per `FoodData`, `CreatureData`, `TraitData`, secret and cutscene, unlocked by signals.
- Jar snapshot: before the chomp the save is copied to `jars/<planet>.json`; entering a jar loads that copy as an ordinary planet with stage 6 disabled.

**The disk world**

- World coordinates are plain Cartesian with the core at the origin. Gravity for any body is `-position.normalized() * g`. Worms do not use gravity while tunnelling (they cling to dirt); loose debris and surface props do.
- Tiles live in one logical grid, but only chunks near the active worms are instantiated as `TileMapLayer` nodes. A chunk is a ring band x angular sector (e.g. 32 tiles radial x 32 tiles angular); the chunk manager keeps a 5x5 neighbourhood per worm live and serialises the rest to a dictionary of edited tiles (only edits are stored; the base disk is procedurally generated from a seed, so the save stays small).
- Eating a tile: set it to air in the live chunk, record the edit, spawn a chomp particle, add growth. Multi-tile props are separate `Node2D`s with a size stage; a bite from a big enough worm splits them into edible chunk sprites.
- The camera is a `Camera2D` whose rotation tracks the average of the active worms' `-position.angle()`; zoom steps in whole pixel multiples.

**Scale stages**

- Stages 1 to 5 live in one disk scene. Growth changes the worm's segment sprite set and collision size, and pulls the camera back. Tile size never changes.
- Stage 6 (eat the planet) is a scripted sequence: the remaining disk is rendered to a texture, the worm scene is swapped for a "giant worm" sprite, one long chomp eats the texture with a shader mask, and the scene cross-fades to space.
- Stage 7 (space) is a separate scene: no tiles, no gravity, planets as `RigidBody2D` with size stages and sleepy faces, the same bigger-eats-smaller rule. Reusing the stage logic, not the world.

**Scenes**

| Scene | Lane | Notes |
| --- | --- | --- |
| `scenes/levels/disk.tscn` | Gameplay | Chunk manager, camera, gravity, rings data, prop spawner |
| `scenes/levels/space.tscn` | Gameplay | Stage 7 world |
| `scenes/levels/planet_chomp.tscn` | Gameplay | Stage 6 scripted hand-off |
| `scenes/players/worm.tscn` | Systems | Head `CharacterBody2D`, segment chain, mouth, size stage, eat area, boost, wiggle |
| `scenes/creatures/*.tscn` | Gameplay (behaviour), Art (sprites) | One scene per creature, driven by `CreatureData` |
| `scenes/props/*.tscn` | Art | Multi-tile surface props with break-apart chunks |
| `scenes/ui/hud.tscn` | Systems | Size stage as a growing worm icon; no numbers |

**Data (Content lane)**

- `data/rings.tres`: ring order, radii, tile set, dominant hue, edible-from stage.
- `data/creatures/*.tres` as `CreatureData`: stage, behaviour enum, sprite, bark, telegraph.
- `data/props/*.tres`: surface props with stage, tile footprint, break-apart pieces.
- `data/stages.tres`: growth thresholds, camera zoom per stage, feature sprite per stage, music layer.
- `data/BALANCE.md`: 20 to 30 minute full run; one stage every 3 to 4 minutes; shared-growth ratio 0.25.

Added 2026-11-10: `data/foods/*.tres` (flavour, growth, size stage, regrow time, sprite, sounds), `data/traits/*.tres`, `data/secrets/*.tres`, `data/pets/*.tres`, `data/trophies/*.tres` with their family bonus, `data/planets/*.tres` for the space endgame, `data/cutscenes/*.tres`, and per-ring population rules inside `data/rings.tres`. `data/BALANCE.md` now targets 2 to 4 hours per stage, 15 to 25 hours to the chomp, a segment every 2 minutes and something new every 15.

**Game-specific contracts (add to `docs/contracts.md`)**

```gdscript
signal ate(player: int, what: StringName, growth: float)
signal stage_changed(player: int, from: int, to: int)
signal eaten_by(player: int, creature: StringName)
signal breakthrough(player: int)          # crust broken
signal planet_eaten()
func World.is_edible_by(stage: int, thing) -> bool
func World.eat_tile(cell: Vector2i, player: int) -> void
```

```gdscript
# added 2026-11-10
signal segment_added(player: int, flavour: StringName)
signal trait_earned(player: int, trait_id: StringName)
signal traits_changed(player: int, active: Array[StringName])
signal carried(player: int, what: StringName)
signal brought_home(player: int, what: StringName, kind: StringName)   # trophy | seed | pet
signal garden_planted(cell: Vector2i, flavour: StringName)
signal secret_found(id: StringName)
signal page_completed(id: StringName)
signal cutscene_finished(id: StringName)
signal planet_jarred(planet_id: StringName)
func Worm.stats(player: int) -> WormStats
func World.regrow_time(cell: Vector2i) -> float
```

**Save, per bait tin:** the planet seed, tile edits with timestamps, the castings layer, each worm's stage, segments, flavour counts, earned and active traits, the burrow (location, trophies, pets, gardens), ring populations, secrets, tackle-box pages, cutscenes seen, jars. Autosave every 30 seconds and on sleep, pause and quit.

**Performance notes:** 25 live chunks of 1,024 tiles each is \~25k tiles per worm; `TileMapLayer` handles that easily on the 1060. Creature count capped at 40 live. If chunk streaming stutters, move the chunk serialiser to C#; that is the one expected hot path.

**Lanes active:** Systems, Gameplay, Art, Content, Audio, Reviewer. All six.

## Build phases

| Phase | Lanes | Output | Tag |
| --- | --- | --- | --- |
| Gate | none | The Hill has reached first playable and its tile world, cutscene tool, PictoBubble and split director are tagged in `openjar-addons`. Worm does not start before this |  |
| 0. Design sprint | Hermes + Kaden | This doc becomes `GAME.md`. Kaden supplies the palette, names the worms and the grandson, and approves the story beats and what Reel says happened to the worms. Old Reel's library bible is updated to fit the dock scenes (decided 2026-11-10) |  |
| 1. Risk prototypes | Systems, solo | (a) polar chunks with regrowth and castings at 60 fps on a 1,000-tile disk; (b) the stage-6 chomp, jar snapshot and cross-fade to space; (c) a segmented worm with five stacked traits and no special cases | `v0.0.1-dev.N` |
| 2. Grey-box | Systems, solo | One worm, the dirt ring, eat and carry, segments, one trait, a burrow you can sleep in, every action beeps | `v0.0.2-dev.N` |
| 3. Vertical slice | all lanes | Stages 1 and 2 at final quality: the opening cutscene, the dirt and topsoil rings with their food chain, three traits, castings and one garden, the burrow with trophies and a pet, the ant-city secret, the tackle box, the Mole's swap shop. **Kaden plays it alone for an evening and with his son for an afternoon.** This is the gate that answers "is this the game?" | `v0.1.0` |
| 4. Ring by ring | all lanes | One ring per milestone, each shipped to `dev` as a playable chapter with its cutscene: rock, core, surface, sky | `v0.2` to `v0.5` |
| 5. Chomp and space | all lanes | Stage 6, the jar, the space endgame with five planet types, the ending cutscene, new tin with an heirloom | `v0.6` |
| 6. Beauty pass | Art, Audio, Reviewer | Lighting, parallax, weather, ambience beds, the dock, store art; performance on the 1060 | `v0.9` |
| 7. Release | Hermes | On the TV main tile | `v1.0.0` |

**First playable is the vertical slice**, not a thin run through all seven stages. The old plan proved the whole arc with boxes; this one proves that two hours of the real game are worth playing, then repeats that quality ring by ring. If a premium-model budget is available for this game, spend it the way The Hill did: on the trait resolver and polar chunk design, the story script and cutscene direction, and the art direction for light and the dock.

## Kid-design checks specific to this game

On top of the template checklist in `docs/kid-design.md`.

- [ ] Bigger-than-me is always visually obvious at a glance (size on screen, not a number or colour code).
- [ ] Every threat telegraphs for at least one second before it can reach the worm.
- [ ] Being eaten costs one segment, never a stage.
- [ ] Camera rotation is capped; no fast spins.
- [ ] The smaller worm catches up within a minute via shared growth.
- [ ] Ordinary eating adds a segment at least every 2 minutes, and something new (a food, a trait, a secret, a page) turns up at least every 15.
- [ ] Autosaves continuously; quitting at any moment loses nothing.
- [ ] Nothing in the dirt is dark or creepy; the deep rings are colourful, not black.
- [ ] Eating a house, a cow or a car is clearly cartoon mayhem: things squeak and pop, nobody is inside.

## Out of scope and open questions

**Out of scope for v1**

- A true 3D sphere. The disk gives the planet feel at a fraction of the cost.
- Placing blocks or buildings from a menu. The burrow and gardens are dug and grown. Also out: combat, hunger or survival meters, crafting screens, written quests or dialogue, a calendar.
- Versus, scores, or leaderboards.
- Procedural planets beyond one seed per run. One hand-tuned disk layout with seeded variation is enough.
- Multiple space systems. Space ends at the sun.

**Open questions for Kaden**

- [ ] The palette (you said you would specify this one).
- [ ] Names and personalities for the two worms. Names answered 2026-11-11 (D90): Gulp (green) and Burp (red); personalities still open.
- [ ] Approve Bobber's bible once Hermes drafts it.

**Decided 2026-11-10**

- What happened to the worms: Reel gives a different silly reason each time; Strangestone in the background is the real one and is never said out loud.
- Old Reel's bible is adjusted to fit the dock scenes, not the other way round.
- Planet in a jar: yes.
- Length: 2 to 4 hours a stage, 15 to 25 hours to the chomp.
- The Mole's swap shop is in, as the first Jarling cameo.
- Nothing is indestructible except the Strangestone seam at the core. Everything else can be eaten.

* The grandson is named Bobber. He is a new Jarling; Hermes drafts his bible for approval.
* No Jarlings besides Old Reel, Bobber and the Mole at launch. Cameos may come in later updates, so secrets and the surface keep a few empty spots for them.
