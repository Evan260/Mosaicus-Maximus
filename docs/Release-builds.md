# Mosaicus Maximus: Release builds

GitHub builds the game in the cloud: it runs the tests, exports Windows, macOS and Linux for the full game and the demo, signs and notarizes the Mac apps, and for a version tag publishes a GitHub release with every build attached. The workflow is `.github/workflows/release.yml`; the scripts it runs are in `.github/scripts/`.

GitHub Actions is free for public repositories, Mac runners included, so the repository has to be public before the first run.

## Starting a build

There are two ways.

**A version tag** builds everything and publishes a release. First set the new version everywhere it lives (`config/version` in `game/project.godot`, which the Windows exe and the Mac app take their versions from; see CLAUDE.md), commit, then in the project folder:

```
git tag v1.0.0
git push origin v1.0.0
```

The tag must be `v` followed by `config/version`, or the tests job stops with "Version mismatch". A tag with a hyphen, such as `v1.1.0-beta1`, is published as a pre-release.

**Run workflow** builds everything without a release, to try a build. On GitHub, open the repository's **Actions** tab, choose **Release builds** on the left, press **Run workflow**, pick the branch (normally `main`) and press the green **Run workflow** button. These builds are labelled `dev-` and the commit, such as `Mosaicus-Maximus-dev-1a2b3c4-windows.zip`.

## What the workflow does

| Job | Runs on | What it does |
|---|---|---|
| Tests | Ubuntu | Imports the project and runs `--run-tests`; fails unless it prints `ALL TESTS PASSED` |
| Export (six at once) | Ubuntu | Exports Windows, macOS and Linux for the full game and the demo with `tools/export.py`, with `Credits and licences.txt` and, for the full Windows game, the everything-unlocked launcher |
| Sign macOS (twice) | Mac | Signs the app and its libraries with the Developer ID certificate, notarizes it with Apple, staples the ticket and checks it with Gatekeeper |
| GitHub release | Ubuntu | Only for a tag: creates the release and attaches every build |
| Steam upload | Ubuntu | Switched off until set up (below) |

Godot 4.7.2 and its export templates are downloaded from Godot's GitHub releases on the first run and kept in the Actions cache afterwards, so later runs skip that download. The Windows export uses the trimmed engine `tools/engine/slim.windows.template_release.x86_64.exe`, kept in Git LFS, so the release exe is the same small one built on this computer. It is built in Farmus Maximus by `tools/engine/build_template.py`; after a rebuild, copy the new exe here and commit it (`Steam-publishing.md`).

## Where the builds appear

**Every run:** open the run on the Actions tab and scroll to **Artifacts** at the bottom. Each download is a zip holding one build:

- `release-full-windows`, `release-demo-windows`: the game folder zipped
- `release-full-linux`, `release-demo-linux`: a `.tar.gz`, which keeps the Linux executable permissions that a plain zip from GitHub would lose
- `release-full-macos`, `release-demo-macos`: the signed and notarized app with the credits, zipped on the Mac, or `-macos-unsigned.zip` when the Apple secrets are not set
- `macos-export-full-macos`, `macos-export-demo-macos`: Godot's unsigned export, only used by the signing job

**A tag:** the repository's **Releases** page gets a release named after the tag with these files:

- `Mosaicus-Maximus-v1.0.0-windows.zip`
- `Mosaicus-Maximus-v1.0.0-macos.zip`
- `Mosaicus-Maximus-v1.0.0-linux.tar.gz`
- `Mosaicus-Maximus-Demo-v1.0.0-windows.zip`, `Mosaicus-Maximus-Demo-v1.0.0-macos.zip`, `Mosaicus-Maximus-Demo-v1.0.0-linux.tar.gz`

The demo's Mac app is named `Mosaicus Maximus.app`, since Godot names the app after the project.

## The secrets

The Mac signing needs six secrets. They have the same names in all three game repositories, so making them once covers Farmus Maximus, Fishus Maximus and Mosaicus Maximus. Until they exist, the Mac build is published unsigned and the run shows a notice saying so; if only some are set, the signing job fails and names the missing ones.

| Secret | What it holds |
|---|---|
| `MACOS_CERTIFICATE_P12` | The Developer ID Application certificate with its private key, as a base64 .p12 |
| `MACOS_CERTIFICATE_PASSWORD` | The password chosen when exporting that .p12 |
| `APPLE_API_KEY_P8` | The App Store Connect API key, the .p8 file in base64 |
| `APPLE_API_KEY_ID` | That key's Key ID |
| `APPLE_API_ISSUER_ID` | The Issuer ID shown above the keys |
| `APPLE_TEAM_ID` | The Apple Developer team ID, ten letters and digits |
| `STEAM_USERNAME` | Later, for the Steam upload: the Steam account that uploads builds |
| `STEAM_CONFIG_VDF` | Later, for the Steam upload: steamcmd's saved login in base64 |

### 1. Export the Developer ID certificate as a .p12

On the Mac:

1. Open **Keychain Access** (Applications, Utilities). Choose the **login** keychain on the left and the **My Certificates** tab at the top.
2. Find **Developer ID Application: (your name) (TEAMID)**. Press the arrow beside it: a private key must be listed under it. Without the key, the certificate cannot sign, so it has to be exported from the Mac that made the certificate request.
   - If there is no Developer ID Application certificate yet, the Account Holder makes one: in Keychain Access choose Keychain Access, Certificate Assistant, **Request a Certificate From a Certificate Authority**, enter your email, choose **Saved to disk**, then at developer.apple.com go to Certificates, IDs & Profiles, Certificates, press +, choose **Developer ID Application**, upload the request and download the certificate. Double-click the downloaded `.cer` to add it to the login keychain beside its key.
3. Right-click the certificate (the certificate line, not the key) and choose **Export "Developer ID Application: ..."**.
4. Choose the format **Personal Information Exchange (.p12)**, name it `developer_id.p12`, save it to the Desktop and press Save.
5. Type a strong password for the file and note it: this is `MACOS_CERTIFICATE_PASSWORD`. macOS then asks for the Mac's login password to allow the export.
6. Open **Terminal** and copy the file as base64:

   ```
   base64 -i ~/Desktop/developer_id.p12 | pbcopy
   ```

   The clipboard now holds `MACOS_CERTIFICATE_P12`. Paste it into GitHub straight away (step 3 below).
7. The team ID is the ten characters in brackets at the end of the certificate's name, also shown at developer.apple.com under Account, Membership details. That is `APPLE_TEAM_ID`.
8. Delete `developer_id.p12` from the Desktop once the secrets are saved, or keep it only in a password manager.

The certificate made in WSL with `tools/steam/apple_setup.sh` works too: its .p12 is `~/mosaicus-steam/apple/developer_id.p12` and its password is in `p12_password` beside it.

### 2. Create the App Store Connect API key

1. Sign in at appstoreconnect.apple.com and open **Users and Access**.
2. Choose the **Integrations** tab, then **App Store Connect API** on the left, then **Team Keys**. The first time, the Account Holder presses **Request Access** and accepts the terms.
3. Press **+** (Generate API Key). Name it `GitHub notarization` and choose the **Developer** access. Press Generate.
4. Copy the **Issuer ID** shown above the list: that is `APPLE_API_ISSUER_ID`.
5. Copy the new key's **Key ID** from the list: that is `APPLE_API_KEY_ID`.
6. Press **Download** beside the key. Apple only allows this once, so keep the file `AuthKey_KEYID.p8` safe until the secret is saved.
7. Copy the file as base64. On the Mac:

   ```
   base64 -i ~/Downloads/AuthKey_KEYID.p8 | pbcopy
   ```

   or in PowerShell on Windows:

   ```
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_KEYID.p8")) | Set-Clipboard
   ```

   The clipboard now holds `APPLE_API_KEY_P8`.

One key serves all three games. The key stays valid until it is revoked on that page.

### 3. Add the secrets on GitHub

1. Open the repository on GitHub, then **Settings**, **Secrets and variables**, **Actions**.
2. On the **Secrets** tab, press **New repository secret**.
3. Type the name exactly as in the table above, paste the value, and press **Add secret**.
4. Repeat for all six Apple secrets, then do the same in the other two game repositories.

The GitHub command line does the same from PowerShell; it asks for each value, so nothing lands in the shell history:

```
gh secret set APPLE_TEAM_ID --repo Evan260/Mosaicus-Maximus
```

GitHub never shows a secret again once saved, and the workflow keeps them out of its logs. To replace one, add it again with the same name.

## The Steam upload

The Steam job is written but switched off. It uploads the builds from the same run with steamcmd, leaving the everything-unlocked launcher out of the Windows depot (it stays in the GitHub release), and makes them live on the `testing` branch, never the default branch, which is still set live by hand in Steamworks (`Steam-publishing.md`). The Mac depot needs the signed Mac build, so the Apple secrets come first. To switch it on:

1. Fill in `tools/steam/steam.json` (the account, and the App ID and depots of `playtest`, `game` and `demo`; `Steam-publishing.md`, step 8) and commit it.
2. Log steamcmd in once in WSL, as in `Steam-publishing.md` step 9, with the account that uploads builds. That saves the login in `~/Steam/config/config.vdf` inside WSL.
3. Copy that saved login as base64 from PowerShell:

   ```
   wsl bash -c "base64 -w0 ~/Steam/config/config.vdf" | Set-Clipboard
   ```

   Add it as the secret `STEAM_CONFIG_VDF`, and the account name as `STEAM_USERNAME`.
4. On the same Settings page, choose the **Variables** tab and add the repository variable `STEAM_UPLOAD` with the value `true`.
5. A tag then uploads to the Playtest. To upload tags to another app, add the variable `STEAM_TARGET` with `game` or `demo`. **Run workflow** has a menu to pick the app for that run.

If Steam ends the saved login, the job fails asking for a new `STEAM_CONFIG_VDF`; log in again in WSL and repeat step 3. To switch uploads off, set `STEAM_UPLOAD` to `false`.
