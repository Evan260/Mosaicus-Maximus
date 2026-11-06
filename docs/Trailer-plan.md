# Mosaicus Maximus trailer

The Steam trailer is 77 seconds long. It tells one story: you inherit your uncle's mosaic workshop, make your first floor for a bride-to-be, and grow until your floors are the pride of the town, floors good enough to outlast Rome itself. It is made the same way as the Farmus Maximus trailer: every shot is the game playing itself in movie mode, and an edit scene cuts the shots together on the beat of the game's own music.

## The story

1. **The place and the time.** A black card: "The Bay of Naples, AD 72."
2. **The inheritance.** The empty workshop at dawn, the lamps out and the dog asleep in its basket. A card: "Your uncle has left you his mosaic workshop."
3. **The first client.** The job board, and Livia, who is getting married in the spring and wants two doves, for love, facing each other. The price is agreed with the coins and a handshake.
4. **The first floor.** A dove dragged onto her bedroom at the design table, made smaller and paired with a mirror image that faces it, and a flower set between them, the stars filling up. Then the floor laid one stone at a time, as the player lays it: white picked in the tray and swept over the dove where it glows, then red over the flower, before the sponge wipes in the grout and the cloth brings up the shine.
5. **The reward.** The floor in her painted bedroom, five stars, her verdict ("Mother cried. Then she asked who made it.") and the coins.
6. **The rise.** A card: "Word gets around." Bigger floors pour in tile by tile: a sea floor, a villa's dining room, a room with an apse.
7. **The town's past.** A card: "Under the old houses, floors lie forgotten." The trowel scrapes the dirt from a buried floor and its gaps are mended.
8. **Home.** The dog is petted and wags, and the workshop glows at night with its lamps lit.
9. **The promise.** A card: "Lay a floor that lasts two thousand years." The end card shows a finished floor shining, with the logo and "Wishlist now on Steam".

The last line points at what the players may know: the floors of the Bay of Naples, buried by Vesuvius in AD 79, are still there today.

## Cut list

One beat is 0.857 seconds of "Solitary Expedition" from the game's soundtrack, and every cut lands on a beat.

| # | Shot or card | Beats |
|---|---|---|
| 1 | Card: The Bay of Naples, AD 72. | 4 |
| 2 | `dawn`: the workshop at dawn, fading in | 5 |
| 3 | Card: Your uncle has left you his mosaic workshop. | 4 |
| 4 | `client`: the pointer opens the job board and picks Livia | 4 |
| 5 | `client`, later: Livia's wishes, the coins slid, the handshake | 5 |
| 6 | `design`: a dove dragged onto the plan and paired, a flower between, the stars | 10 |
| 7 | `floor`: white picked in the tray and swept over a dove where it glows, then red over the flower, close up | 8 |
| 8 | `floor`, later: grout and polish, the shimmer | 5 |
| 9 | `floor`, at its end: the floor in her bedroom, five stars and coins | 6 |
| 10 | Card: Word gets around. | 3 |
| 11 | `sea`, `villa`, `apse`: three big floors poured in fast | 3 each |
| 12 | Card: Under the old houses, floors lie forgotten. | 3 |
| 13 | `dig`: the trowel uncovers a buried floor, then the gaps are mended | 6 |
| 14 | `dog`: the dog is petted | 3 |
| 15 | `night`: the workshop at night | 4 |
| 16 | Card: Lay a floor that lasts two thousand years. | 4 |
| 17 | `endcard`: a finished floor, the logo and the wishlist scroll | 7 |

## How it is made

- `python tools/trailer/make_trailer.py` records every shot that is not recorded yet, then renders the trailer. `shots NAME...` records shots again, and `render` renders from the recorded shots, or from a given second into a preview.
- `game/tools/trailer/shots.gd` scripts the shots. The game starts it with `--trailer-shot=NAME`. It sets up a fresh workshop that is never saved, opens the screens, and moves a drawn pointer that clicks and drags with made-up input; the real mouse is shut out.
- `game/tools/trailer/edit.gd` is the edit: the cut list, the cards, the end card and the music. Each shot's own sounds play under the music.
- The shots are recorded at 1920 by 1080 and 30 frames a second, with the interface at four screen pixels to the game pixel, into `marketing/recordings/content/trailer_shots/`, which git ignores.
- The finished trailer, `steam_trailer.avi` and an `.mp4` copy, goes to `marketing/recordings/videos/steam_trailer/`, beside its `title.txt`, `description.txt` and `thumbnail.png`, a frame of the end card.
- The logo is drawn by `tools/trailer/make_logo.py` in Cinzel gold, like the Farmus Maximus logo.

## The shorts

`short_one_stone_at_a_time` is a 23-second vertical cut for YouTube Shorts, Reels and TikTok, made with `make_trailer.py --cut=one_stone`. Its shots are the trailer's floor, dig and end card recorded again in a tall 1080 by 1920 frame, where the shots frame themselves closer. It plays without cards, with a caption over each shot:

1. "POV: you lay Roman mosaics for a living": white is picked in the tray and swept over a dove, close up.
2. "one stone at a time": the view turns to the flower, red is picked and swept in.
3. "until the whole floor is down": the rest of the floor pours in.
4. "then grout and polish": the sponge, the cloth and the shine.
5. "and dig up floors lost for centuries": the trowel uncovers the old CAVE CANEM floor.
6. The end card with the logo and the wishlist scroll.

It goes to `marketing/recordings/videos/short_one_stone_at_a_time/`, with its `.mp4` copy, `title.txt`, `description.txt` and `thumbnail.png`.

Six more shorts share the same tall frame and end card. Each is made with `make_trailer.py --cut=NAME` and goes to its own `short_NAME` folder:

| Cut | Folder | What it shows |
|---|---|---|
| `pet_the_dog` | `short_pet_the_dog` | Each of the five breeds woken in its basket with a pat: "yes, you can pet the dog", then the mastiff, the sighthound, the little one and the fluffy one. |
| `guess_the_floor` | `short_guess_the_floor` | The trowel scrapes the dirt from around a buried picture first, so CAVE CANEM shows as a clue, and from the picture last: "guess what's under the dirt", then "a guard dog. of course." |
| `cozy_sounds` | `short_cozy_sounds` | No music, only the stones, the sponge and cloth, the trowel and the dog, under "turn your sound on". |
| `first_vs_last` | `short_first_vs_last` | A first floor of one black and white rosette, then a villa floor of peacocks and coloured marble. |
| `client_reviews` | `short_client_reviews` | Four clients' floors in their own rooms, each captioned with the client's verdict from the game. |
| `biggest_floor` | `short_biggest_floor` | The forum's floor of 17,847 stones poured in from one corner as the view pulls back. |

