import AppKit

/// Box art, lazily pulled from each game's Wikipedia article (page-summary API) and cached on disk.
@MainActor
final class ArtStore: ObservableObject {
    static let shared = ArtStore()

    struct ArtRef: Codable { var thumb: String?; var original: String? }

    private var images: [String: NSImage] = [:]
    private var inflight: [String: Task<NSImage?, Never>] = [:]
    private var index: [String: ArtRef] = [:]          // wikiTitle -> image URLs (empty ref = no art)
    private let dir: URL
    private let indexURL: URL
    private let limiter = Limiter(max: 4)

    init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Kind.current.appName + "/art", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        indexURL = dir.appendingPathComponent("index.json")
        if let data = try? Data(contentsOf: indexURL), let i = try? JSONDecoder().decode([String: ArtRef].self, from: data) {
            index = i
        }
    }

    func load(_ title: String, large: Bool) async -> NSImage? {
        let key = (large ? "L|" : "S|") + title
        if let img = images[key] { return img }
        if let t = inflight[key] { return await t.value }
        let task = Task<NSImage?, Never> {
            let ref = await self.ref(for: title)
            let urlString = large ? (ref.original ?? ref.thumb) : ref.thumb
            guard let s = urlString, let url = URL(string: s) else { return nil }
            let img = await Self.fetchImage(url, cacheDir: dir, limiter: limiter)
            if let img = img { images[key] = img }
            return img
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }

    private func ref(for title: String) async -> ArtRef {
        if let r = index[title] { return r }
        let r = await Self.fetchRef(title: title, limiter: limiter)
        index[title] = r
        if let data = try? JSONEncoder().encode(index) { try? data.write(to: indexURL, options: .atomic) }
        return r
    }

    nonisolated private static let agent = Wiki.agent

    nonisolated private static func fetchRef(title: String, limiter: Limiter) async -> ArtRef {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?&#")
        let path = title.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: allowed) ?? title
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(path)") else { return ArtRef() }
        var req = URLRequest(url: url)
        req.setValue(agent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        await limiter.acquire()
        defer { Task { await limiter.release() } }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ArtRef() }
        let thumb = (json["thumbnail"] as? [String: Any])?["source"] as? String
        let original = (json["originalimage"] as? [String: Any])?["source"] as? String
        return ArtRef(thumb: thumb, original: original)
    }

    nonisolated private static func fetchImage(_ url: URL, cacheDir: URL, limiter: Limiter) async -> NSImage? {
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        let file = cacheDir.appendingPathComponent(fnv(url.absoluteString) + "." + ext)
        if let img = NSImage(contentsOf: file) { return img }
        var req = URLRequest(url: url)
        req.setValue(agent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 30
        await limiter.acquire()
        defer { Task { await limiter.release() } }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let img = NSImage(data: data) else { return nil }
        try? data.write(to: file, options: .atomic)
        return img
    }

    nonisolated private static func fnv(_ s: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return String(h, radix: 16)
    }
}

/// Caps how many Wikipedia requests run at once.
actor Limiter {
    private let max: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(max: Int) { self.max = max }
    func acquire() async {
        if active < max { active += 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        if !waiters.isEmpty { waiters.removeFirst().resume() } else { active -= 1 }
    }
}
