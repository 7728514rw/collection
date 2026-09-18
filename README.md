# Collection apps

Two native macOS apps (SwiftUI, no Xcode project) built from the same sources:

- **Game Collection** — every game you own, by system
- **Music Collection** — CDs, vinyl, cassettes, by format and artist

Type a title in the add sheet (⌘N) and it searches Wikipedia as you type; pick the match and the
system/format, and it's added with cover art, the year and a short blurb. Anything Wikipedia
doesn't know can still be added by name. Each item has an editable condition and notes.

## Build

    ./build.sh                    # builds both into build/
    ./build.sh --install          # also copies to /Applications
    ./build.sh --install --launch # and opens them

Needs the Xcode Command Line Tools (`swiftc`), macOS 14+. `-D MUSIC` selects the music build
(`Sources/Kind.swift` holds the two configurations: name, presets, search hint, conditions).

## Where the data lives

- `~/Library/Application Support/Game Collection/collection.json`
- `~/Library/Application Support/Music Collection/collection.json`

Plain JSON, saved after every change — back these up or edit them by hand if you like.
Cover art is cached next to them in `art/`.
