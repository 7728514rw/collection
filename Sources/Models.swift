import Foundation

struct Item: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var artist: String = ""         // artist (music) or director (movies)
    var category: String            // system or format
    var wikiTitle: String?          // Wikipedia article key for art and the blurb
    var year: Int?
    var blurb: String?
    var condition: String = ""
    var notes: String = ""
    var addedAt = Date()

    var sortKey: String { title.lowercased().replacingOccurrences(of: "^(the|a|an) ", with: "", options: .regularExpression) }

    var wikipediaURL: URL? {
        guard let w = wikiTitle else { return nil }
        let path = w.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? w
        return URL(string: "https://en.wikipedia.org/wiki/\(path)")
    }

    func matches(_ q: String) -> Bool {
        q.isEmpty || title.localizedCaseInsensitiveContains(q) || artist.localizedCaseInsensitiveContains(q)
            || category.localizedCaseInsensitiveContains(q) || notes.localizedCaseInsensitiveContains(q)
            || (year.map { String($0).hasPrefix(q) } ?? false)
    }
}

/// The collection itself: a JSON file in Application Support, saved after every change.
@MainActor
final class Collection: ObservableObject {
    @Published var items: [Item] { didSet { save() } }
    private let fileURL: URL

    init(kind: Kind) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(kind.appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("collection.json")
        if let data = try? Data(contentsOf: fileURL), let saved = try? Self.decoder.decode([Item].self, from: data) {
            items = saved
        } else {
            items = kind.seed
        }
    }

    func add(_ item: Item) { items.append(item) }
    func remove(_ id: Item.ID) { items.removeAll { $0.id == id } }
    func update(_ item: Item) { if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item } }

    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()

    private func save() {
        guard let data = try? Self.encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
