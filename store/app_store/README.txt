MOSAICUS MAXIMUS: APP STORE PICTURES

The pictures the App Store listing needs. Screenshots are uploaded in App Store Connect (appstoreconnect.apple.com):
Apps, the game, the version being prepared, then Previews and Screenshots, with one tab per display size.

The pictures are made by python tools/phone/make_store_art.py, which has the game render each scene with its phone
interface (--phone) at the store's exact size, so they always match the game. Run it again after the art or the
interface changes, then look at every picture. Like the Steam screenshots, they carry no captions. Every picture draws
the painted scenes and the interface at a whole number of screen pixels to the game pixel (the scenes 6 times and the
interface 4 times on the iPhone; on the iPad the interface 5 times and the bedroom 4 times, so its whole floor shows
beside Livia's card), lays the mosaic floors at the screen's own resolution, as the game always does, and resizes
nothing with smoothing.


APP ICON

icon_1024.png   1024x1024 PNG, no alpha channel, square corners.
                The game's icon: the red flower on white marble inside a black band, laid by the game at 1024 by 1024,
                the same mosaic as icon_512.png in store/google_play. Apple rounds the corners itself.
                Meets: the App Store icon, 1024x1024, no transparency and no alpha channel, no rounded corners.
                App Store Connect takes this icon from the build rather than from an upload, so it goes into the iOS
                export preset's Icons section (the 1024x1024 App Store icon) once the game has one.


IPHONE SCREENSHOTS (iphone_6.9_inch_screenshots/, all 2868x1320 landscape, PNG without alpha)

01_the_workshop.png          The workshop on a sunny afternoon, with its plants, wine jars and lamps, the dog asleep in
                             its basket, and the phone's top bar. The room is cropped a little at the top and bottom,
                             as the game shows it on a screen this wide, so the basket reaches past the bottom edge.
02_a_client_visits.png       Widow Cornelia comes in for an entrance hall floor: her story, her wishes, and the price
                             slider with Shake on it.
03_designing_her_floor.png   The design table: two doves facing each other across a flower on Livia's bedroom floor,
                             with the phone's buttons over the picked flower, her five stars and Start laying ready.
04_laying_the_stones.png     Laying her floor: the right-hand dove laid in white and red stones landing round the
                             flower, with the stone tray below.
05_in_her_bedroom.png        Her finished floor in her bedroom beside her card: five stars and "Mother cried. Then she
                             asked who made it." The top of the room is cropped so the whole floor shows above the
                             bottom edge.
06_the_town.png              The town on the Bay of Naples: the forum, the harbour, the baths, the villas on the hill
                             and the rival workshop.
07_a_villa_dining_room.png   A finished floor visited from the town: peacocks round a Medusa in a villa's dining hall,
                             five stars, the top of the room cropped as in the bedroom.
08_festival_day.png          The job board on the day of the Vinalia, four notices across, among them a cook's that
                             asks for wine and pays more for the festival.

Meets: the 6.9-inch iPhone display size, which takes 2868x1320 in landscape (or 2796x1290 or 2736x1260); 1 to 10
screenshots, PNG or JPEG without alpha. Apple scales these down for the smaller iPhones, so this one size covers them.


IPAD SCREENSHOTS (ipad_13_inch_screenshots/, all 2752x2064 landscape, PNG without alpha)

01_designing_her_floor.png   The design table laid out for the iPad's squarer screen, with the doves and the flower on
                             Livia's floor, her five stars and Start laying ready.
02_laying_the_stones.png     Laying her floor close up: the right-hand dove laid in white and red stones landing round
                             the flower.
03_in_her_bedroom.png        Her finished floor in her bedroom beside her five-star card.
04_a_client_visits.png       Widow Cornelia's visit, her wishes and the price slider.
05_an_old_floor_dug_up.png   A restoration: the trowel scraping the dirt off an old floor found under a house, its
                             guard dog with its red collar coming up out of the dirt.
06_festival_day.png          The job board on the day of the Vinalia, three notices across, the fourth running on under
                             the board's foot, as the board scrolls.

The workshop, the town and the visited villa are left out here: an iPad's squarer screen shows those painted scenes
small between dark bands above and below, and the workshop and the town with a thin light line along their top edge.

Meets: the 13-inch iPad display size, which takes 2752x2064 in landscape (or 2732x2048); required when the game runs
on iPad; 1 to 10 screenshots, PNG or JPEG without alpha. Apple scales these down for the smaller iPads.


NOT MADE HERE

- App previews, the optional videos of 15 to 30 seconds for each display size.
- The listing's text: name (30 characters), subtitle (30), promotional text (170), description (4,000) and keywords
  (100). store/google_play/listing.txt and store/steam_page/about_this_game.txt are a starting point.
- A support link and a privacy policy link, and the age rating questionnaire, which are forms in App Store Connect.
