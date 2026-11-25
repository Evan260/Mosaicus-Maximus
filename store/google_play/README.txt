MOSAICUS MAXIMUS: GOOGLE PLAY STORE LISTING PICTURES

The pictures the Google Play store listing needs, ready to upload in Play Console (play.google.com/console). Open the
app, then Store presence > Main store listing > Graphics.

The pictures are made by python tools/phone/make_store_art.py, which has the game render each scene with its phone
interface (--phone) at the store's exact size, so they always match the game. Run it again after the art or the
interface changes, then look at every picture. Like the Steam screenshots, they carry no captions. Every picture draws
the painted scenes and the interface at a whole number of screen pixels to the game pixel (the scenes 4 times on the
phone and the 7-inch tablet and 6 times on the 10-inch tablet, the interface 4 and 5 times), lays the mosaic floors at
the screen's own resolution, as the game always does, and resizes nothing with smoothing.


APP ICON

icon_512.png   512x512, 32-bit PNG, every pixel opaque.
               The game's icon: a red flower on white marble inside a black band, laid tile by tile by the game's own
               floor renderer at 512 by 512, the same mosaic as the launcher icon without its rounded rim. It fills the
               whole square, because Google rounds the corners and adds the shadow itself.
               Meets: 512x512 32-bit PNG, at most 1024 KB (this one is 236 KB).


FEATURE GRAPHIC

feature_graphic_1024x500.png   1024x500, 24-bit PNG, no alpha.
               A sea floor laid by the game at exactly 1024 by 500: two dolphins leap at the sides of the logo, and
               under it an octopus swims between two fish and two scallop shells, inside a blue wave border. The logo
               is laid over it at twice its pixel size, as on the Steam capsules. No badges and no text but the logo.
               Meets: 1024x500, JPEG or 24-bit PNG without alpha.


PHONE SCREENSHOTS (phone_screenshots/, all 1920x1080 landscape, 24-bit PNG)

Upload them in this order; the first three show first on the listing.

01_the_workshop.png          The workshop on a sunny afternoon, with its plants, wine jars and lamps, the dog asleep in
                             its basket, and the phone's top bar (purse, chapter, day and End the day).
02_a_client_visits.png       Widow Cornelia comes in for an entrance hall floor: her story, her wishes, and the price
                             slider with Shake on it.
03_designing_her_floor.png   The design table: two doves facing each other across a flower on Livia's bedroom floor,
                             the flower picked with the phone's turn, mirror, bigger, smaller, Pair and remove buttons
                             over it, her five stars, all the stone in stock and Start laying ready.
04_laying_the_stones.png     Laying her floor: the right-hand dove laid in white, red stones landing round the
                             flower where they glow, the stone tray below and the zoom buttons at the side. The script
                             takes a burst of frames and keeps the one with most of the flower laid.
05_in_her_bedroom.png        Her finished floor in her bedroom, and her card: five stars and "Mother cried. Then she
                             asked who made it." The card covers the edge of the left dove, as on any 16:9 screen.
06_the_town.png              The town on the Bay of Naples: the forum, the harbour, the baths, the villas on the hill,
                             the temple of Venus and the rival workshop.
07_a_villa_dining_room.png   A finished floor visited from the town: peacocks round a Medusa in a villa's dining hall,
                             five stars.
08_festival_day.png          The job board on the day of the Vinalia, with a cook's notice that asks for wine and pays
                             more for the festival. The next row of notices shows its top edge under them, as the
                             board scrolls.

Meets: 2 to 8 phone screenshots, JPEG or 24-bit PNG without alpha, each side 320 to 3,840 px, 16:9. A game needs at
least three 16:9 landscape screenshots of at least 1920x1080 to be shown in Google Play's game recommendations; all
eight qualify.


TABLET SCREENSHOTS

tablet_7_inch_screenshots/    1920x1080 landscape (16:9), 24-bit PNG
tablet_10_inch_screenshots/   2560x1440 landscape (16:9), 24-bit PNG

Each folder holds the same four scenes, taken at that window size with the phone interface, so the layout is the one a
tablet of that shape gets:

01_the_workshop.png
02_designing_her_floor.png
03_a_villa_dining_room.png
04_the_town.png

On the 10-inch tablet the painted pictures are drawn 6 times, which crops a little off their top and bottom, as the
game does on that screen: the dog's basket and the front of the villa's floor reach past the bottom edge.

Meets: up to 8 screenshots for each tablet size, JPEG or 24-bit PNG without alpha, each side 320 to 3,840 px, the long
side at most 2.3 times the short one. They are 16:9, as Google's large-screen guidance asks for a game to be featured
on tablets.


NOT MADE HERE

- The listing's text (app name, short description and full description) is in listing.txt in this folder, and the
  answers for Play Console's App content forms (content rating, data safety, privacy policy and the rest) are in
  app_content_answers.txt beside it.
- A promo video, optional, given as a YouTube link.
- Chromebook and Android XR screenshots, optional.
