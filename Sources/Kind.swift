import Foundation

/// What this build collects. `build.sh` compiles the same sources twice: with `-D MUSIC` for
/// Music Collection, without it for Game Collection.
struct Kind {
    let appName: String
    let noun: String            // "game" / "album"
    let categoryNoun: String    // "System" / "Format"
    let categories: [String]    // presets for the picker; anything else can be typed
    let searchSuffix: String    // appended to Wikipedia searches to steer results
    let hasArtist: Bool
    let conditions: [String]
    let seed: [Item]

    #if MUSIC
    static let current = Kind(
        appName: "Music Collection", noun: "album", categoryNoun: "Format",
        categories: ["CD", "Vinyl", "Cassette", "Digital", "Other"],
        searchSuffix: "album", hasArtist: true,
        conditions: ["", "Sealed", "Mint", "Very good", "Good", "Worn"],
        seed: [])
    #else
    static let current = Kind(
        appName: "Game Collection", noun: "game", categoryNoun: "System",
        categories: ["PlayStation", "PlayStation 2", "PlayStation 3", "PlayStation 4", "PlayStation 5", "PSP", "PS Vita",
                     "NES", "SNES", "Nintendo 64", "GameCube", "Wii", "Wii U", "Switch", "Switch 2",
                     "Game Boy", "Game Boy Color", "Game Boy Advance", "DS", "3DS",
                     "Xbox", "Xbox 360", "Xbox One", "Xbox Series X/S",
                     "Master System", "Mega Drive", "Saturn", "Dreamcast", "PC", "Other"],
        searchSuffix: "video game", hasArtist: false,
        conditions: ["", "Sealed", "Complete in box", "Boxed, no manual", "Loose"],
        seed: [Item(title: "Persona 4", artist: "", category: "PlayStation 2", wikiTitle: "Persona 4", year: 2008,
                    blurb: "Persona 4, released outside Japan as Shin Megami Tensei: Persona 4, is a 2008 role-playing video game by Atlus.")])
    #endif
}
