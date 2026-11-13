MOSAICUS MAXIMUS: STEAM STORE PAGE FILES

Everything the Steam store page needs, ready to upload in Steamworks (partner.steamgames.com). Open the game's app,
then Edit Store Page. Steamworks shows the exact size it wants on each upload slot; if a size there differs from the
file name here, tell Claude and the picture will be remade.

The pictures are made by python tools/steam/make_store_art.py, which has the game lay each floor and render each
scene, so they always match the game. Run it again after the art changes. This folder is the only one it writes to:
the pieces it crops or combines are rendered into a temporary folder and removed when it finishes.


TEXT

short_description.txt       Description tab > Short description (280 of 300 characters)
about_this_game.txt         Description tab > About This Game (written in Steam's [h2] and [list] formatting)
tags.txt                    Basic Info > Tags and Genres
languages.txt               Basic Info > Supported Languages
system_requirements.txt     System Requirements tab
ai_content_disclosure.txt   Content Survey > AI-generated content


STORE GRAPHICS (Graphical Assets tab, Store Assets)

header_capsule_920x430.png     Header capsule: top of the store page and in most lists
small_capsule_462x174.png      Small capsule: search results and smaller lists
main_capsule_1232x706.png      Main capsule: the front page's featured carousel
vertical_capsule_748x896.png   Vertical capsule: seasonal sales and some store pages
page_background_1438x810.png   Page background: behind the store page (optional)


LIBRARY GRAPHICS (Graphical Assets tab, Library Assets)

library_capsule_600x900.png         Library capsule: the game's cover in players' libraries
library_header_920x430.png          Library header
library_hero_3840x1240.png          Library hero: the wide picture at the top of the game's library page (no logo, on purpose)
library_logo_1280_transparent.png   Library logo: laid over the hero by Steam; place it to the bottom left


ICONS (Basic Info and the Community section)

community_icon_184x184.jpg   Community icon
app_icon.ico                 Client icon (also usable as the game's own Windows icon)


SCREENSHOTS (Screenshots tab)

screenshots/01 to 12, all 1920x1080, moments of the trailer's recorded shots. Upload them in this order; the first
four show in the store page's sidebar and in search, so they lead with the workshop, the job board, a client's visit
and the design table.


ACHIEVEMENTS

The 64 by 64 achievement icons are in store/achievements; docs/Steam-setup.md has the table to enter.


TRAILER (Trailers tab)

The trailer is rendered to marketing/recordings/videos/steam_trailer/ (kept out of git because of its size) by
python tools/trailer/make_trailer.py, which keeps an .mp4 copy beside the .avi for uploading. Before uploading,
confirm with the composer of the harp music (Mythago Music) that the free LITE pack may be used in a trailer.


BUILDS

The game itself goes to Steam with python tools/steam/publish.py, which builds Windows, macOS and Linux and uploads
them. docs/Steam-publishing.md has the one-time Steamworks and Apple setup, the App ID and depot numbers to fill in,
and how to send an update.


DEVELOPER AND PUBLISHER (Basic Info)

Slow Villa Games, in both the Developer and the Publisher fields.


STILL TO DECIDE BEFORE SUBMITTING

- Release date: "Coming soon", or a season and year such as "Spring 2027".
- Price in CAD, which Steamworks asks for separately and which Valve reviews.
- Steam Cloud and achievements are set up as described in docs/Steam-setup.md.
- The builds are uploaded as described in docs/Steam-publishing.md.
