import Foundation

/// Wikipedia lookups: title search for the add sheet, page summary for year/blurb/art.
enum Wiki {
    static let agent = "Collection/1.0 (personal macOS app)"

    struct Hit: Identifiable, Hashable {
        var id: String { key }
        let key: String            // article key, e.g. "Persona_4"
        let title: String
        let description: String    // "2008 video game", "1997 studio album by Radiohead"
        let thumb: URL?

        /// Article title without a disambiguator: "Doom (2016 video game)" -> "Doom"
        var cleanTitle: String { title.replacingOccurrences(of: " \\([^)]*\\)$", with: "", options: .regularExpression) }
        var year: Int? { Self.year(in: description) }
        /// "... album by Radiohead" -> "Radiohead"
        var artist: String? {
            guard let r = description.range(of: " by ") else { return nil }
            return String(description[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        static func year(in s: String) -> Int? {
            guard let r = s.range(of: "\\b(19|20)\\d{2}\\b", options: .regularExpression) else { return nil }
            return Int(s[r])
        }
    }

    static func search(_ query: String, suffix: String) async -> [Hit] {
        let q = (query + " " + suffix).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://en.wikipedia.org/w/rest.php/v1/search/page?q=\(q)&limit=8") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(agent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pages = json["pages"] as? [[String: Any]] else { return [] }
        return pages.compactMap { p in
            guard let key = p["key"] as? String, let title = p["title"] as? String else { return nil }
            var thumb: URL? = nil
            if let t = (p["thumbnail"] as? [String: Any])?["url"] as? String {
                thumb = URL(string: "https:" + t.replacingOccurrences(of: "/60px-", with: "/240px-"))
            }
            return Hit(key: key, title: title, description: p["description"] as? String ?? "", thumb: thumb)
        }
    }

    struct Summary { var description: String?; var extract: String?; var year: Int? }

    static func summary(_ key: String) async -> Summary? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?&#")
        let path = key.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(agent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let desc = json["description"] as? String
        let extract = json["extract"] as? String
        return Summary(description: desc, extract: extract, year: desc.flatMap(Hit.year) ?? extract.flatMap(Hit.year))
    }
}
