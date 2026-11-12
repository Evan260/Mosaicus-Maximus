# Mosaicus Maximus: Publishing to Steam

How builds get onto Steam and to players. Once the steps below are done, every update is one command, and everyone with the game on Steam receives it automatically the next time their Steam client updates. Prices here are in CAD.

## What is already set up

- `tools/export.py` builds the game for Windows, macOS and Linux, each with `Credits and licences.txt` beside it. `tools/steam/publish.py` uses it to export each platform that has a depot, then hands over to WSL (the Linux that runs inside Windows), which lays out the builds, signs and notarizes the Mac app, and uploads everything.
- The upload runs in WSL because a Mac app copied through Windows loses its file permissions and will not open, and the Linux game needs its "executable" permission too. `tools/steam/wsl_build.sh` does that half.
- `tools/steam/wsl_setup.sh` installs Valve's Linux steamcmd and rcodesign (the tool that signs and notarizes a Mac app without a Mac) into `~/mosaicus-steam` inside WSL. WSL with Ubuntu is already installed on this computer.
- `tools/steam/apple_setup.sh` makes or imports the Apple credentials; `tools/steam/macos_entitlements.plist` gives the Mac app the two permissions the Steam overlay needs. The macOS export preset asks for the same two.
- `tools/steam/steam.json` holds the Steam account name and the app and depot numbers. Every number is 0 until the steps below give you the real ones; a depot left at 0 is skipped.
- GodotSteam 4.24 (the GDExtension, with Steamworks SDK 1.65) is in `game/addons/godotsteam/`, for 64-bit Windows, macOS and Linux. Each export puts its libraries beside the game (inside the app's `Contents/Frameworks` on a Mac). `game/scripts/autoload/awards.gd` starts Steam with `steamInitEx` and sends achievements only when Steam answers; without the Steam client the game plays as normal and keeps achievements in the save.

## Testing Steam before the game has an App ID

Valve's test app, Spacewar, has the App ID 480 and works with any Steam account. To check that GodotSteam starts:

1. Start the Steam client and log in.
2. Put a file named `steam_appid.txt` holding just `480` beside the game's exe (`builds/windows/`), or in `game/` when running from the editor.
3. Start the game. Steam shows it as playing Spacewar, and the overlay opens with Shift+Tab.

`steam_appid.txt` is ignored by git and left out of every export, so it never ships. Once the game has its own App ID, put that number in the file instead; Spacewar has none of the game's achievements, so unlocks only show with the real App ID. A copy started by Steam itself never needs the file.

## One-time setup on this computer

Open PowerShell in the project folder and run:

```
wsl -u root -- bash tools/steam/wsl_setup.sh
```

It installs steamcmd and rcodesign inside WSL and prints the rcodesign version when it is done.

The Windows build uses a trimmed Godot engine, `tools/engine/slim.windows.template_release.x86_64.exe`, kept in Git LFS so a fresh clone and the GitHub release builds (`Release-builds.md`) use it. It is built in Farmus Maximus with `python tools/engine/build_template.py` and copied here from Farmus Maximus's `tools/engine/bin/farmus.windows.template_release.x86_64.exe`; build and copy it again after every Godot update, and commit it.

## One-time setup on Steamworks

These steps need you, because they involve your Steam account, payment and tax details.

1. **Join Steamworks.** Sign up at partner.steamgames.com, pay the Steam Direct fee (US\$100 per game, about \$140, paid back once the game earns US\$1,000), and fill in the tax and bank forms. Valve checks these, which can take from a few days to a couple of weeks.
2. **Create the app.** Steamworks gives the game an **App ID**, for example 3456780. Under App Admin, SteamPipe, Depots, it also creates a **depot**, usually numbered one higher, for example 3456781. Set that depot's operating system to Windows, then add two more depots, one set to macOS and one to Linux + SteamOS.
3. **Tell Steam how to start the game.** Under Installation, General, add three launch options:
   - executable `Mosaicus Maximus.exe`, operating system Windows
   - executable `Mosaicus Maximus.app`, operating system macOS
   - executable `Mosaicus Maximus.x86_64`, operating system Linux + SteamOS
4. **Say the Mac app is notarized.** Under Installation, General (or the store page's Platforms section), tick **App Bundles Are Notarized**. Steam has required notarized Mac games since 2019; the publish script notarizes every Mac build.
5. **Add a test branch.** Under SteamPipe, Builds, create a branch named `testing`. No password is needed.
6. **Publish the settings.** Steamworks changes only apply after you press Publish on the Publish tab.
7. **Create the Playtest.** On the game's Steamworks page, open Playtest and create one. This makes a separate app, "Mosaicus Maximus Playtest", with its own App ID. Repeat steps 2 to 6 for it, adding Mac and Linux depots only if Mac and Linux testers are wanted.
8. **Fill in the numbers.** Put the account name and the numbers into `tools/steam/steam.json`:
   - `account`: the Steam account that uploads builds. Valve recommends a separate Steam account that has only the permission to upload builds, so your own account is never used by a script.
   - `targets.playtest`: the Playtest's App ID and its depots (`windows`, and `macos` and `linux` if it has them).
   - `targets.game`: the main game's App ID and its three depots.
9. **Log in to steamcmd once.** In PowerShell, run:

   ```
   wsl ~/mosaicus-steam/steamcmd/steamcmd.sh +login YOUR_ACCOUNT +quit
   ```

   Type the password, then the Steam Guard code from the email or the Steam phone app. steamcmd remembers the login, so the publish script never needs the password.

The achievements, Steam Cloud paths and store page are in `Steam-setup.md`.

## One-time setup with Apple

The publish script signs the Mac app with a **Developer ID Application** certificate and notarizes it with an App Store Connect key, both kept in `~/mosaicus-steam/apple` inside WSL. Each command runs in PowerShell from the project folder.

**If the Developer ID already lives in your Mac's keychain** (as it does now), bring it over instead of making a new one:

1. On the Mac, open Keychain Access, find "Developer ID Application: ..." under My Certificates, right-click it, choose Export, save it as a `.p12` file with a password, and copy it to Downloads on this computer.
2. Import it, typing the password when asked:

   ```
   wsl bash tools/steam/apple_setup.sh import-p12 "C:\Users\evand\Downloads\Certificates.p12"
   ```

   Then delete the `.p12` from Downloads.

**Otherwise, make a new one here.** Only the Apple Developer account's **Account Holder** can make the certificate in step 2.

1. **Make a certificate request.** This creates a private key that never leaves WSL, and puts the request in Downloads:

   ```
   wsl bash tools/steam/apple_setup.sh csr "C:\Users\evand\Downloads"
   ```

2. **Get the certificate.** At developer.apple.com, go to Certificates, IDs & Profiles, Certificates, press +, choose **Developer ID Application**, upload `developer_id.csr` from Downloads, and download the certificate it gives you (`developerID_application.cer`).
3. **Turn it into the signing file:**

   ```
   wsl bash tools/steam/apple_setup.sh p12 "C:\Users\evand\Downloads\developerID_application.cer"
   ```

**Either way, add the notarization key:**

1. At appstoreconnect.apple.com, go to Users and Access, Integrations, App Store Connect API, Team Keys, and generate a key with the **Developer** role. Note the **Issuer ID** at the top of the page and the key's **Key ID**, and download the `.p8` file (Apple only lets you download it once).
2. Store it:

   ```
   wsl bash tools/steam/apple_setup.sh api-key ISSUER_ID KEY_ID "C:\Users\evand\Downloads\AuthKey_KEYID.p8"
   ```

   Then delete the `.p8`, `.csr` and `.cer` files from Downloads; WSL keeps what it needs in `~/mosaicus-steam/apple`.

The Developer ID certificate lasts five years; the Apple Developer membership it needs is renewed every year.

For a build to test on the Mac without Steam, `python tools/export.py macos --mac-share` puts Godot's unsigned `.zip` in `C:\Users\evand\MacShare\Mosaicus Maximus`, to be signed, notarized and stapled on the Mac itself.

## Giving a tester access

1. In Steamworks, open the Playtest app and request Steam keys (a handful is plenty).
2. Send one key to the tester. They redeem it in Steam under Games, Activate a Product on Steam, and the Playtest appears in their library.
3. They right-click it, choose Properties, Betas, and pick `testing`. They only do this once; from then on Steam keeps them on the newest test build.

Later, the Playtest can also be opened to sign-ups from the store page, with you deciding how many people get in.

## Sending an update

Ask Claude to "push an update to the playtest", or run:

```
python tools/steam/publish.py playtest --note "Faster floor setting"
```

The script builds the game for every platform with a depot, signs and notarizes the Mac app (Apple's check usually takes a few minutes), uploads it and makes it live on the `testing` branch. The Windows depot leaves out `Mosaicus Maximus - everything unlocked.bat`, the launcher that opens a workshop with everything unlocked, since it is for checking builds and never for players; `tools/export.py` and the GitHub release still put it beside the game. Testers get it the next time Steam updates, usually within minutes when Steam is open. The note and the git commit appear next to the build in Steamworks, under SteamPipe, Builds.

`--dry-run` builds every platform, signs the Mac app if the Apple credentials exist, and lays everything out in `~/mosaicus-steam` inside WSL without notarizing or uploading, to check that everything is in order. It needs neither steamcmd nor any Steam numbers; with every number still 0 it builds all three platforms.

## The default branch and release

Steam only lets a script make a build live on a branch such as `testing`. For the default branch, the one every buyer gets, go to SteamPipe, Builds in Steamworks and set the build live there yourself. This is Valve's safeguard against a script releasing a broken build to everyone. When the game launches, the same command uploads with `game` instead of `playtest`, and you set each release live on the default branch by hand.

Before each release, raise `config/version` in `game/project.godot`; the Windows exe's version and the Mac app's version are both taken from it.
