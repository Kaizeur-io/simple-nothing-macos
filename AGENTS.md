# Notes for coding agents

This is a native macOS app (SwiftUI, Swift Package Manager, no third-party dependency) that controls Nothing and CMF headphones over Bluetooth. Code comments, commit messages and UI strings are in French; keep it that way.

## Installing it for someone

Asked to "install this": run one command from the repository root.

```sh
tools/install.sh
```

It downloads the device pictures (about 20 MB, once), builds the app, copies it to `/Applications/Nothing X.app` and opens it. A first run takes about a minute and a half. Offline, or with `NOTHING_SANS_IMAGES=1`, the pictures are skipped and the app draws the devices itself. Requirements, both checked by the script with a clear message:

- macOS 14 or later.
- Apple's Command Line Tools. If they are missing, `xcode-select --install` opens a system dialog the person has to accept; the download takes several minutes, then rerun the script. Full Xcode is not needed.

Things only the person can do, so tell them:

1. Click **Allow** when macOS asks whether "Nothing X" may use Bluetooth. Until then the app shows "No device".
2. Pair the headphones with the Mac in System Settings › Bluetooth, if not done already. The app only talks to devices that are already paired and connected.

Nothing else is needed. The `originaux/` folder mentioned in the README holds Nothing's own pictures and fonts, kept out of git; the install script fills in the pictures, and the app falls back to its own dot-matrix artwork and system fonts for whatever is missing.

To check an install without a device, run `tools/app.sh --demo --snapshot out.png`: it writes a screenshot of the window with made-up data and exits.

## Working on the code

- `swift test` runs the protocol tests (no Bluetooth needed).
- `tools/app.sh` builds and runs from the project folder; `--demo` uses made-up data. Launch options are listed at the top of `Sources/NothingX/NothingXApp.swift`.
- Only one process can hold the device's Bluetooth channel: quit the installed app before running another copy against a real device.
- UI text is written in French in the code and passed through `tr("…")`. Every new string needs its line in both `en.lproj` and `es.lproj` under `Sources/NothingX/Traductions/`.
- The app's name is only written in `tools/app-Info.plist` (and in the scripts' paths); the code reads it from there.
- The code is GPL-3.0. Protocol facts come from Ear (web) (AGPL-3.0) and BudsLink (GPL-3.0); do not paste code from AGPL projects.
- `docs/protocole.md` records what has been verified on a real device. Do not send write commands to someone's headphones without asking them; `tools/app.sh --verify report.txt` is the supported way to test writes and restores every value it changes.
- Nothing's images and fonts must never be committed: `originaux/` and `maquette/assets/` are git-ignored on purpose.
