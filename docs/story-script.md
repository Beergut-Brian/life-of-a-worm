# Old Reel's tall tale: the dock scenes

The whole story of Life of a Worm, as a screenplay for Kaden. Eight short scenes on one dock, told
by Old Reel to his grandson Bobber. Nobody reads anything: the lines are voiced, and a picture
bubble over the speaker shows what he's talking about. Any button skips a scene.

Data: lines in `data/story/lines.json`, scenes in `data/cutscenes/<id>.json`, played by the Story
host (`scripts/story/story.gd`) on the dock set (`scenes/story/dock.tscn`). Preview any scene with
`godot --path . res://scenes/story/story_preview.tscn -- --story=<id>`.

**Running jokes.** Reel's hands get wider every scene ("it was THIS big"). Bobber gets less
convinced every scene ("nuh-uh"). Reel gives a different silly reason for the worms changing every
time it comes up (a comet, Grandma's chili, a funny purple rock, his lucky socks, lightning, a
wish). The truth sits in plain sight and is never said: the bait tin rests on a softly glowing
Strangestone at the end of the bank. Something in the background quietly proves him right in every
scene.

**Times.** Measured with the placeholder voices (word-count timing). Real voice takes for Reel,
slow with a chuckle first, will add roughly a fifth.

| Scene | When it plays | Light | Background clue | Length now | Target |
| --- | --- | --- | --- | --- | --- |
| `opening` The one that got away | new tin (stage 1) | dawn, warm flashback | Gulp and Burp plop into the dirt; the camera follows them down | ~50 s | ~60 s |
| `stage_2` It got hungry | stage 2 | morning | a ripple on the pond (something long and dark under it) | ~18 s | 15 to 30 s |
| `stage_3` It started to change | stage 3 | noon | the tree on the far shore is pulled into the ground | ~19 s | 15 to 30 s |
| `stage_4` It came up | stage 4 | noon, warm flashback | Reel's shed sinks behind him mid-sentence (and stays sunk) | ~17 s | 15 to 30 s |
| `stage_5` Nobody fished that year | stage 5 | dusk, warm flashback | a bite out of the hill (stays bitten) | ~19 s | 15 to 30 s |
| `stage_6` The big one | stage 6 (before the chomp) | dusk | the hill is gone and the horizon bends | ~16 s | 15 to 30 s |
| `stage_7` Up it went | stage 7 (space) | night | a bright star winks out | ~18 s | 15 to 30 s |
| `ending` Still out there | after the sun | night | a bite out of the moon; a long shape drifts past the stars | ~23 s | 15 to 30 s |

Clues stay once they've happened: from stage 3 on the tree is gone, from stage 4 the shed is sunk,
and so on. Every clue happens on camera (worm-story-2): the camera eases onto it, holds while it
happens with its sound, then comes back to the dock. Nobody on the dock remarks on it; Bobber
only glances. `tests/test_story_dock_2.gd::test_the_camera_is_on_every_background_clue_when_it_happens`
keeps it that way.

---

## 1. The one that got away (`opening`, ~60 s)

*Dawn. The dock over a still pond, Reel's little shed on the bank, a hill and a tree on the far
shore. A bait tin sits on a dark stone that glows faintly. OLD REEL stands with his rod. BOBBER
sits at the end of the dock, feet dangling. There is a sandwich on his hook.*

*Wide shot, gulls, water. The camera drifts in to the two of them.*

**BOBBER** *(bubble: sandwich, question mark)*: Grandpa? Why's a sandwich on my hook? Why not worms?

**REEL** *(turns to him; bubble: worm, happy face)*: [chuckles] Worms? Heh. Back in my day, worms were little.

*Reel holds two fingers an inch apart.*

**REEL** *(bubble: a tiny worm between two fingers, a hook)*: THIS big. Fit right on a hook...

**BOBBER** *(squints; bubble: tiny worm, sheepish face)*: That's teeny.

*The camera drifts toward the bank.*

**REEL** *(bubble: the dock, sparkle)*: Heh. Then one morning, right here by the pond...

*Fade. FLASHBACK, warm golden light. YOUNG REEL walks from the shed to the bank, rod over his
shoulder. Two little worms wriggle on his hook: one green (GULP), one red (BURP).*

**YOUNG REEL** *(hums; bubble: hook, fish)*: [hums] Come on, little fella. Breakfast for the fish.

*The worms wriggle.*

**YOUNG REEL** *(bubble: a green worm and a red worm)*: Two of 'em, come to think of it.

**YOUNG REEL** *(bubble: both worms, happy face)*: One I called Gulp. The other one... [chuckles] Burp.

*Burp burps (bubble: burp rings).*

**BOBBER** *(off screen, giggling)*: [giggles] BURP!

*The worms wriggle harder, slip off the hook and plop into the dirt.*

**YOUNG REEL** *(bubble: both worms, sheepish face)*: Heh. That one got away... Well. Those two.

*The camera follows Gulp and Burp down into the ground, tunnels opening behind them.*

**REEL** *(voice over Gulp; bubble: open mouth, big worm)*: And then... it got HUNGRY.

*The worms hop. Fade to black. Hand-off: the game camera picks up the worms underground. You
have the stick.*

## 2. It got hungry (`stage_2`, 15 to 20 s)

*Morning, bright. Back on the dock.*

**REEL** *(bubble: worm, open mouth)*: [chuckles] That worm ate everything smaller than itself.

**BOBBER** *(bubble: sandwich, happy face; he bounces)*: So do I!

**REEL** *(bubble: heart)*: Heh heh. That's my boy.

*Reel's hands go a bit wider.*

**REEL** *(bubble: open mouth, big worm)*: Seeds. Roots. Bugs. Got THIS big.

*The camera eases out over the pond: something long and dark slides under the water, rings spread
and bubbles pop ("bloop"). Bobber glances that way. Back to the dock.*

**BOBBER** *(squints; bubble: worm, sheepish face)*: Bugs? EWWW.

*The camera drifts toward the ripples.*

## 3. It started to change (`stage_3`, 15 to 20 s)

*Noon.*

**REEL** *(bubble: worm, question mark)*: It wasn't just bigger, see. It was... different.

*Reel holds up a picture: a worm with a stone for a head.*

**BOBBER** *(bubble: stone-head worm, exclamation)*: A worm with a ROCK for a head?

*Hands wider.*

**REEL** *(bubble: comet, sparkle)*: Heh. Must've been that comet. Whoosh! Right over the pond.

**REEL** *(bubble: big worm)*: Got THIS big, too.

*The camera eases over to the far shore: the tree sinks into the ground with a crunch and a little
shake. Back to the dock.*

**BOBBER** *(squints; bubble: question mark)*: Hmmmm.

## 4. It came up (`stage_4`, 18 to 25 s)

*Noon. Fade to FLASHBACK, warm light: young Reel on the bank, his shed behind him.*

**YOUNG REEL** *(bubble: sinking shed, worm going up)*: Then one day it came UP. Right under my shed...

*Mid-sentence the ground rumbles and the shed sinks into the earth behind him, roof last. He
doesn't turn round.*

**YOUNG REEL** *(bubble: chili pot, sheepish face)*: Heh. Your grandma's chili, I reckon. Fed it one spoonful.

*Back to the dock. Only the tip of the shed's roof sticks out of the grass now.*

**REEL** *(hands wider still; bubble: big worm, exclamation)*: It was THIS big!

**BOBBER** *(arms crossed; bubble: a red cross)*: Nuh-uh.

**REEL** *(bubble: sunk shed, heart)*: Honest! Never saw that shed again.

## 5. Nobody fished that year (`stage_5`, 18 to 25 s)

*Dusk.*

**REEL** *(bubble: fish, red cross)*: Nobody fished that year. Whole town watched the hill.

*FLASHBACK, warm light: a row of little townsfolk on the far shore stare at the hill. A huge bite
comes out of it, with a rumble and a chomp. Young Reel, alone, hops for joy.*

**YOUNG REEL** *(bubble: huge worm, happy face)*: Ho ho! Look at it GO!

*Back to the dock at dusk.*

**REEL** *(bubble: purple rock, sparkle)*: Dug the bait up by a funny purple rock, see. That's why.

**REEL** *(hands very wide; bubble: huge worm, exclamation)*: THIS big. Bigger!

**BOBBER** *(arms crossed; bubble: red cross, sheepish face)*: Nuh-UH.

*The camera pulls back: the hill across the pond has a bite out of it.*

## 6. The big one (`stage_6`, 15 to 22 s)

*Dusk, deeper. The hill already has its bite.*

**REEL** *(bubble: sock, huge worm)*: Ate my lucky socks first. Powerful socks, those.

*Reel spreads his hands as wide as they go, wider than the screen; the camera pulls back to keep up.*

**REEL** *(bubble: huge worm, exclamation)*: [chuckles] It was THIS... big.

*Behind them the hill sinks away to nothing and the horizon bends round, like the edge of a ball.*

**REEL** *(bubble: a planet with a bite out of it)*: And then it ate... everything.

*The camera holds wide on the bent horizon; Bobber turns to look at it. Then it comes back in.*

**BOBBER** *(squints; bubble: dock, question mark)*: Then where are WE sitting?

**REEL** *(bubble: sheepish face)*: ...It's a long story.

## 7. Up it went (`stage_7`, 15 to 22 s)

*Night, stars.*

**REEL** *(points up; bubble: worm going up, star)*: Too big for the ground, so... up it went.

*The camera tilts toward the sky.*

**REEL** *(bubble: lightning, huge worm)*: Lightning hit it on the nose. Zap! That's why.

**BOBBER** *(bubble: worm, red cross)*: Worms can't fly, Grandpa.

**REEL** *(bubble: worm going up)*: Heh. Didn't say fly. Said UP.

*The camera tilts up to the bright star: it winks out with a tiny "tink". Back to the dock.*

**BOBBER** *(squints; bubble: question mark)*: Hmmmm... nuh-uh.

## 8. Still out there (`ending`, 20 to 30 s)

*Night. Bobber has shuffled up to Reel and fallen asleep against him. A bite is missing from the
moon.*

**REEL** *(bubble: huge worm, star)*: Heh. And it's still out there. Eating stars.

**BOBBER** *(asleep; bubble: zzz)*: Nuh... uh...

**REEL** *(bubble: wishing star)*: Maybe it was my wish. I wished for the big one.

*The camera rises to the moon. A long, segmented shape with one sleepy yellow eye drifts slowly
past the stars.*

*Back down to the dock.*

**REEL** *(bubble: heart, happy face)*: Never did catch it. Glad I didn't.

*Reel tips his hat. Twinkle. Fade out. Credits.*

---

## Voice

Gary voices each line to `assets/story/voice/<line_id>.ogg` from the speaker's saved library voice
(Old Reel: Chatterbox library voice; Bobber: his library voice once made). `delivery` in
`lines.json` is the direction; `[tags]` are ElevenLabs v3-style. Until a file exists the line plays
its fallback: the speaker's library bark (`bark:<cue>`) if it is vendored, else a short placeholder
babble in the speaker's pitch. Subtitles are off by default: the Save setting `subtitles`
(`Story.subtitles`) shows each line's `text`, minus its `[tags]`, under the bubbles. No menu toggles
it yet; preview with `story_preview.tscn -- --subtitles`.
