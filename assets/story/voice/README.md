# Story voice lines

Gary voices each line from the speaker's saved library voice and drops it here as
`<line_id>.ogg` (mono, -16 LUFS, like the library barks). The cutscene player picks a file up as soon
as it exists; until then the line plays its fallback (`scripts/story/story_voice.gd`). The script and
directions are in `data/story/lines.json` (`text`, `delivery`) and `docs/story-script.md`.
Add each file to `assets/CREDITS.md` (voice tool, voice name, line id) when it lands.

| File | Speaker | Line | Delivery |
| --- | --- | --- | --- |
| `op_bobber_why.ogg` | bobber | Grandpa? Why's a sandwich on my hook? Why not worms? | curious, a bit put out, quick |
| `op_reel_worms.ogg` | old_reel | [chuckles] Worms? Heh. Back in my day, worms were little. | low, slow, creaky; chuckle first; trails off |
| `op_reel_this_big.ogg` | old_reel | THIS big. Fit right on a hook... | holds two fingers an inch apart; fond, quiet |
| `op_bobber_tiny.ogg` | bobber | That's teeny. | unimpressed, a little giggle |
| `op_reel_one_morning.ogg` | old_reel | Heh. Then one morning, right here by the pond... | slows down, story voice, drifting into memory |
| `op_reel_young_hum.ogg` | old_reel | [hums] Come on, little fella. Breakfast for the fish. | younger, brighter, humming while baiting the hook |
| `op_reel_two_of_em.ogg` | old_reel | Two of 'em, come to think of it. | remembers, amused; co-op only |
| `op_reel_names.ogg` | old_reel | One I called Gulp. The other one... [chuckles] Burp. | fond, slow; the chuckle lands right before Burp |
| `op_bobber_burp.ogg` | bobber | [giggles] BURP! | delighted kid giggle, then shouts it |
| `op_reel_got_away.ogg` | old_reel | Heh. That one got away... Well. Those two. | the old catchphrase, then a sheepish correction, quieter |
| `op_reel_hungry.ogg` | old_reel | And then... it got HUNGRY. | pause, then big on HUNGRY |
| `s2_reel_ate_everything.ogg` | old_reel | [chuckles] That worm ate everything smaller than itself. | proud, like bragging about a grandkid |
| `s2_bobber_so_do_i.ogg` | bobber | So do I! | delighted, fist pump, mouth full of sandwich |
| `s2_reel_my_boy.ogg` | old_reel | Heh heh. That's my boy. | warm chuckle |
| `s2_reel_this_big.ogg` | old_reel | Seeds. Roots. Bugs. Got THIS big. | counts on fingers, then hands a hand-width apart |
| `s2_bobber_eww.ogg` | bobber | Bugs? EWWW. | scrunched face, delighted disgust |
| `s3_reel_different.ogg` | old_reel | It wasn't just bigger, see. It was... different. | lowers voice, mysterious |
| `s3_bobber_rock_head.ogg` | bobber | A worm with a ROCK for a head? | squinting, half laughing |
| `s3_reel_comet.ogg` | old_reel | Heh. Must've been that comet. Whoosh! Right over the pond. | excuse 1: points at the sky, sure of himself |
| `s3_reel_this_big.ogg` | old_reel | Got THIS big, too. | hands shoulder-width apart |
| `s3_bobber_hmm.ogg` | bobber | Hmmmm. | long, suspicious squint |
| `s4_reel_came_up.ogg` | old_reel | Then one day it came UP. Right under my shed... | building; keeps talking while the shed sinks behind him |
| `s4_reel_chili.ogg` | old_reel | Heh. Your grandma's chili, I reckon. Fed it one spoonful. | excuse 2: certain, a bit guilty |
| `s4_reel_this_big.ogg` | old_reel | It was THIS big! | arms wide open |
| `s4_bobber_nuh_uh.ogg` | bobber | Nuh-uh. | flat, arms crossed: the catchphrase |
| `s4_reel_honest.ogg` | old_reel | Honest! Never saw that shed again. | wounded dignity, hand on heart, trails off |
| `s5_reel_nobody_fished.ogg` | old_reel | Nobody fished that year. Whole town watched the hill. | wistful, then lighting up |
| `s5_reel_ho_ho.ogg` | old_reel | Ho ho! Look at it GO! | the only delighted one; hops; laughing |
| `s5_reel_purple_rock.ogg` | old_reel | Dug the bait up by a funny purple rock, see. That's why. | excuse 3: confident, taps his nose |
| `s5_reel_this_big.ogg` | old_reel | THIS big. Bigger! | on tiptoe, arms as wide as a hug |
| `s5_bobber_nuh_uh.ogg` | bobber | Nuh-UH. | louder, arms crossed tighter |
| `s6_reel_biggest.ogg` | old_reel | [chuckles] It was THIS... big. | arms as wide as they go; strains |
| `s6_reel_socks.ogg` | old_reel | Ate my lucky socks first. Powerful socks, those. | excuse 4: dead serious |
| `s6_reel_everything.ogg` | old_reel | And then it ate... everything. | slow, hushed, dramatic pause |
| `s6_bobber_where.ogg` | bobber | Then where are WE sitting? | triumphant, gotcha |
| `s6_reel_long_story.ogg` | old_reel | ...It's a long story. | caught out, sheepish chuckle |
| `s7_reel_up.ogg` | old_reel | Too big for the ground, so... up it went. | points up, slow wonder |
| `s7_reel_lightning.ogg` | old_reel | Lightning hit it on the nose. Zap! That's why. | excuse 5: claps on Zap |
| `s7_bobber_cant_fly.ogg` | bobber | Worms can't fly, Grandpa. | patient, like explaining to a baby |
| `s7_reel_didnt_say_fly.ogg` | old_reel | Heh. Didn't say fly. Said UP. | smug little chuckle |
| `s7_bobber_squint.ogg` | bobber | Hmmmm... nuh-uh. | the squint: one eye closed, slow and sceptical |
| `end_reel_still_out_there.ogg` | old_reel | Heh. And it's still out there. Eating stars. | quiet, under the stars, fond |
| `end_reel_wish.ogg` | old_reel | Maybe it was my wish. I wished for the big one. | excuse 6: soft, almost to himself |
| `end_bobber_sleepy.ogg` | bobber | Nuh... uh... | fast asleep, mumbled |
| `end_reel_glad.ogg` | old_reel | Never did catch it. Glad I didn't. | whisper, smile in the voice, trails off |
