import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct CollectionApp: App {
    @StateObject private var collection = Collection(kind: .current)

    var body: some Scene {
        WindowGroup(Kind.current.appName) {
            ContentView()
                .environmentObject(collection)
        }
        .defaultSize(width: 1240, height: 800)
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Import Collection…") { importCollection() }.keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Export Collection…") { exportCollection() }.keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }

    /// Merge a JSON export from the iPhone app (or another Mac) into this collection.
    private func importCollection() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.message = "Choose a collection export (JSON)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let n = try collection.merge(from: url)
            let alert = NSAlert(); alert.messageText = "Imported"
            alert.informativeText = "\(n) new \(Kind.current.noun)\(n == 1 ? "" : "s") added; existing entries updated."
            alert.runModal()
        } catch {
            let alert = NSAlert(); alert.alertStyle = .warning
            alert.messageText = "Couldn't import"; alert.informativeText = "That file isn't a \(Kind.current.appName) export."
            alert.runModal()
        }
    }

    private func exportCollection() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = Kind.current.appName.lowercased().replacingOccurrences(of: " ", with: "-") + ".json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? collection.export(to: url)
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case title = "Title", added = "Recently added", year = "Year", category = "Category", artist = "Artist"
    var label: String { self == .artist ? Kind.current.artistNoun : rawValue }
    var id: String { rawValue }

    static var available: [SortOrder] { Kind.current.hasArtist ? allCases : allCases.filter { $0 != .artist } }

    func compare(_ a: Item, _ b: Item) -> Bool {
        switch self {
        case .title: return a.sortKey < b.sortKey
        case .added: return a.addedAt > b.addedAt
        case .year:
            if (a.year ?? 0) != (b.year ?? 0) { return (a.year ?? 0) < (b.year ?? 0) }
            return a.sortKey < b.sortKey
        case .category:
            if a.category != b.category { return Kind.rank(a.category) < Kind.rank(b.category) }
            return a.sortKey < b.sortKey
        case .artist:
            if a.artist != b.artist { return a.artist.localizedCaseInsensitiveCompare(b.artist) == .orderedAscending }
            return (a.year ?? 0) < (b.year ?? 0)
        }
    }
}

extension Kind {
    /// Preset order first, then anything the user typed, alphabetically.
    static func rank(_ category: String) -> (Int, String) {
        (current.categories.firstIndex(of: category) ?? current.categories.count, category.lowercased())
    }
}

enum Layout: String { case list, grid }

// MARK: - Main view

struct ContentView: View {
    @EnvironmentObject private var collection: Collection
    private let kind = Kind.current
    @State private var category: String? = "all"
    @State private var query = ""
    @State private var sort: SortOrder = .title
    @AppStorage("layout") private var layout: Layout = .grid
    @State private var selection: Item.ID?
    @State private var showAdd = false

    private var categories: [(String, Int)] {
        var counts: [String: Int] = [:]
        for i in collection.items { counts[i.category, default: 0] += 1 }
        return counts.keys.sorted { Kind.rank($0) < Kind.rank($1) }.map { ($0, counts[$0]!) }
    }

    private var visible: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return collection.items
            .filter { (category == nil || category == "all" || $0.category == category) && $0.matches(q) }
            .sorted(by: sort.compare)
    }

    private var selected: Item? { selection.flatMap { id in collection.items.first { $0.id == id } } }

    var body: some View {
        NavigationSplitView {
            List(selection: $category) {
                Section("Collection") {
                    Label("Everything", systemImage: "square.grid.3x3").badge(collection.items.count).tag("all")
                }
                Section(kind.categoryNoun + "s") {
                    ForEach(categories, id: \.0) { name, count in
                        Label(name, systemImage: kind.symbol).badge(count).tag(name)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } content: {
            Group {
                if collection.items.isEmpty {
                    ContentUnavailableView {
                        Label("No \(kind.noun)s yet", systemImage: "plus.circle")
                    } description: {
                        Text("Add your first \(kind.noun) — it'll look up the art and year for you.")
                    } actions: {
                        Button("Add a \(kind.noun)") { showAdd = true }
                    }
                } else if visible.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if layout == .grid {
                    GridView(items: visible, selection: $selection, onRemove: remove)
                } else {
                    ListView(items: visible, selection: $selection, onRemove: remove)
                }
            }
            .navigationTitle(category == nil || category == "all" ? "Everything" : category!)
            .navigationSubtitle("\(visible.count) \(kind.noun)\(visible.count == 1 ? "" : "s")")
            .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            .searchable(text: $query, placement: .toolbar, prompt: "Search your collection")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Label("Add \(kind.noun)", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command)
                        .help("Add a \(kind.noun) (⌘N)")
                }
                ToolbarItemGroup {
                    Picker("Layout", selection: $layout) {
                        Image(systemName: "square.grid.2x2").tag(Layout.grid)
                        Image(systemName: "list.bullet").tag(Layout.list)
                    }
                    .pickerStyle(.segmented)
                    Menu {
                        Picker("Sort by", selection: $sort) {
                            ForEach(SortOrder.available) { Text($0.label).tag($0) }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                }
            }
        } detail: {
            if let item = selected {
                ItemDetail(item: item, onRemove: { remove(item.id) })
                    .id(item.id)
            } else {
                ContentUnavailableView("Pick a \(kind.noun)", systemImage: kind.symbol,
                                       description: Text("Details and notes show here."))
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSheet { item in
                collection.add(item)
                selection = item.id
                if let key = item.wikiTitle { Task { await enrich(item.id, key: key) } }
            }
        }
    }

    private func remove(_ id: Item.ID) {
        if selection == id { selection = nil }
        collection.remove(id)
    }

    /// Fill in the year and blurb from the article summary after adding.
    private func enrich(_ id: Item.ID, key: String) async {
        guard let s = await Wiki.summary(key), var item = collection.items.first(where: { $0.id == id }) else { return }
        if item.year == nil { item.year = s.year }
        if item.blurb == nil, let e = s.extract { item.blurb = String(e.prefix(400)) }
        collection.update(item)
    }
}

// MARK: - List & grid

struct ListView: View {
    let items: [Item]
    @Binding var selection: Item.ID?
    let onRemove: (Item.ID) -> Void

    var body: some View {
        List(items, selection: $selection) { i in
            HStack(spacing: 12) {
                ArtView(title: i.wikiTitle, artURL: i.artURL).frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(i.title).fontWeight(.medium).lineLimit(1)
                    Text(subtitle(i)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(i.year.map(String.init) ?? "").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    if !i.condition.isEmpty { Tag(text: i.condition) }
                }
            }
            .padding(.vertical, 3)
            .tag(i.id)
            .contextMenu { Button("Remove from collection", role: .destructive) { onRemove(i.id) } }
        }
    }

    private func subtitle(_ i: Item) -> String {
        i.artist.isEmpty ? i.category : "\(i.artist) · \(i.category)"
    }
}

struct GridView: View {
    let items: [Item]
    @Binding var selection: Item.ID?
    let onRemove: (Item.ID) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)], spacing: 16) {
                ForEach(items) { i in
                    VStack(alignment: .leading, spacing: 6) {
                        ArtView(title: i.wikiTitle, artURL: i.artURL).aspectRatio(1, contentMode: .fit)
                        Text(i.title).font(.callout).fontWeight(.medium).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        Text(i.artist.isEmpty ? i.category : i.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(8)
                    .background(selection == i.id ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selection == i.id ? Color.accentColor : .clear, lineWidth: 1.5))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { selection = i.id }
                    .contextMenu { Button("Remove from collection", role: .destructive) { onRemove(i.id) } }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Detail (editable)

struct ItemDetail: View {
    @EnvironmentObject private var collection: Collection
    @State private var draft: Item
    let onRemove: () -> Void
    private let kind = Kind.current

    init(item: Item, onRemove: @escaping () -> Void) {
        _draft = State(initialValue: item)
        self.onRemove = onRemove
    }

    private var yearText: Binding<String> {
        Binding(get: { draft.year.map(String.init) ?? "" }, set: { draft.year = Int($0.filter(\.isNumber)) })
    }
    private var categoryChoices: [String] {
        kind.categories.contains(draft.category) ? kind.categories : kind.categories + [draft.category]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ArtView(title: draft.wikiTitle, artURL: draft.artURL, large: true).frame(maxWidth: .infinity).frame(height: 280)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: $draft.title).font(.title).fontWeight(.bold).textFieldStyle(.plain)
                    if kind.hasArtist {
                        TextField(kind.artistNoun, text: $draft.artist).font(.title3).foregroundStyle(.secondary).textFieldStyle(.plain)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        Text(kind.categoryNoun).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Picker("", selection: $draft.category) { ForEach(categoryChoices, id: \.self) { Text($0) } }
                            .labelsHidden().frame(maxWidth: 220)
                    }
                    GridRow {
                        Text("Year").foregroundStyle(.secondary)
                        TextField("Year", text: yearText).frame(width: 70)
                    }
                    GridRow {
                        Text("Condition").foregroundStyle(.secondary)
                        Picker("", selection: $draft.condition) {
                            ForEach(kind.conditions, id: \.self) { Text($0.isEmpty ? "—" : $0) }
                        }
                        .labelsHidden().frame(maxWidth: 220)
                    }
                    GridRow {
                        Text("Added").foregroundStyle(.secondary)
                        Text(draft.addedAt, style: .date)
                    }
                }

                if let b = draft.blurb, !b.isEmpty {
                    Text(b).foregroundStyle(.secondary).font(.callout)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes").font(.headline)
                    TextEditor(text: $draft.notes)
                        .font(.body)
                        .frame(minHeight: 90)
                        .padding(6)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
                }

                HStack {
                    if let url = draft.wikipediaURL {
                        Link(destination: url) { Label("Open on Wikipedia", systemImage: "safari") }
                    }
                    Spacer()
                    Button("Remove from collection", role: .destructive, action: onRemove)
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: draft) { _, new in collection.update(new) }
    }
}

// MARK: - Add sheet

struct AddSheet: View {
    let onAdd: (Item) -> Void
    @Environment(\.dismiss) private var dismiss
    private let kind = Kind.current

    @State private var query = ""
    @State private var hits: [Wiki.Hit] = []
    @State private var pickedKey: String?
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var category: String
    @State private var otherCategory = ""
    @State private var artist = ""

    init(onAdd: @escaping (Item) -> Void) {
        self.onAdd = onAdd
        _category = State(initialValue: Kind.current.categories.first ?? "")
    }

    private var picked: Wiki.Hit? { hits.first { $0.key == pickedKey } }
    private var finalCategory: String {
        category == "Other" && !otherCategory.trimmingCharacters(in: .whitespaces).isEmpty ? otherCategory.trimmingCharacters(in: .whitespaces) : category
    }
    private var canAdd: Bool { picked != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a \(kind.noun)").font(.title2).fontWeight(.bold)

            TextField("Search Wikipedia for \(kind.searchHint)", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .onSubmit { if picked == nil, let first = hits.first { pickedKey = first.key; fill(first) } else if canAdd { add() } }
                .onChange(of: query) { _, q in search(q) }

            ZStack {
                List(hits, selection: $pickedKey) { h in
                    HStack(spacing: 10) {
                        Thumb(url: h.thumb).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.title).fontWeight(.medium).lineLimit(1)
                            Text(h.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .tag(h.key)
                }
                .onChange(of: pickedKey) { _, k in if let h = hits.first(where: { $0.key == k }) { fill(h) } }
                if hits.isEmpty {
                    Text(searching ? "Searching…" : query.isEmpty ? "Type a title to look it up" : "No matches — you can still add it by name")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 230)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                if kind.hasArtist {
                    GridRow {
                        Text(kind.artistNoun).gridColumnAlignment(.trailing)
                        TextField(kind.artistNoun, text: $artist).textFieldStyle(.roundedBorder)
                    }
                }
                GridRow {
                    Text(kind.categoryNoun).gridColumnAlignment(.trailing)
                    HStack {
                        Picker("", selection: $category) { ForEach(kind.categories, id: \.self) { Text($0) } }.labelsHidden()
                        if category == "Other" {
                            TextField("Which?", text: $otherCategory).textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(picked == nil ? "Add without a match" : "Add") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private func fill(_ h: Wiki.Hit) {
        if kind.hasArtist, artist.isEmpty, let a = h.artist { artist = a }
    }

    private func search(_ q: String) {
        searchTask?.cancel()
        pickedKey = nil
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { hits = []; searching = false; return }
        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let found = await Wiki.search(trimmed, suffix: kind.searchSuffix)
            if Task.isCancelled { return }
            hits = found
            searching = false
        }
    }

    private func add() {
        let title = picked?.cleanTitle ?? query.trimmingCharacters(in: .whitespaces)
        let item = Item(title: title, artist: artist.trimmingCharacters(in: .whitespaces), category: finalCategory,
                        wikiTitle: picked?.key, year: picked?.year)
        onAdd(item)
        dismiss()
    }
}

/// Small search-result thumbnail, straight from the URL (not cached — these are tiny).
struct Thumb: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url) { phase in
            if let img = phase.image { img.resizable().scaledToFit() } else { Color.primary.opacity(0.06) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Bits

struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.18), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}

struct ArtView: View {
    let title: String?
    var artURL: String? = nil
    var large = false
    @State private var image: NSImage?
    private let kind = Kind.current

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06))
            if let image = image {
                Image(nsImage: image).resizable().scaledToFit().padding(large ? 0 : 1)
            } else {
                Image(systemName: kind.symbol)
                    .font(.system(size: large ? 40 : 16))
                    .foregroundStyle(.quaternary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: (artURL ?? "") + "|" + (title ?? "")) {
            image = nil
            if let s = artURL, let url = URL(string: s) { image = await ArtStore.shared.load(url: url); return }
            guard let title = title else { return }
            image = await ArtStore.shared.load(title, large: large)
        }
    }
}
