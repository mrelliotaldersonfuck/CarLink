import Foundation

/// A page the user visited or saved. Codable so it survives relaunches and can
/// be read by both the iPhone UI and the CarPlay scene (same process).
struct WebPage: Identifiable, Hashable, Codable {
    let title: String
    let urlString: String
    var lastVisited: Date

    var id: String { urlString }
    var url: URL? { URL(string: urlString) }
    var host: String { url?.host?.replacingOccurrences(of: "www.", with: "") ?? urlString }

    init(title: String, url: URL, lastVisited: Date = Date()) {
        self.title = title.isEmpty ? (url.host ?? url.absoluteString) : title
        self.urlString = url.absoluteString
        self.lastVisited = lastVisited
    }
}

/// Shared store for favorites and recent pages. The CarPlay scene reads the
/// same data so the car can resume what you were watching on the phone.
@MainActor
final class BrowserStore: ObservableObject {
    static let shared = BrowserStore()

    @Published private(set) var favorites: [WebPage] = []
    @Published private(set) var recents: [WebPage] = []

    /// Posted whenever the data changes, so the CarPlay templates can refresh.
    static let didChange = Notification.Name("BrowserStoreDidChange")

    private let defaults = UserDefaults.standard
    private let favoritesKey = "carlink.favorites"
    private let recentsKey = "carlink.recents"
    private let recentsLimit = 40

    private init() {
        favorites = load(favoritesKey)
        recents = load(recentsKey)
    }

    func recordVisit(title: String, url: URL) {
        guard let scheme = url.scheme, scheme == "http" || scheme == "https" else { return }
        let page = WebPage(title: title, url: url)
        recents.removeAll { $0.urlString == page.urlString }
        recents.insert(page, at: 0)
        if recents.count > recentsLimit {
            recents = Array(recents.prefix(recentsLimit))
        }
        persist(recents, key: recentsKey)
    }

    func isFavorite(_ url: URL) -> Bool {
        favorites.contains { $0.urlString == url.absoluteString }
    }

    func toggleFavorite(title: String, url: URL) {
        if isFavorite(url) {
            favorites.removeAll { $0.urlString == url.absoluteString }
        } else {
            favorites.insert(WebPage(title: title, url: url), at: 0)
        }
        persist(favorites, key: favoritesKey)
    }

    func removeFavorite(_ page: WebPage) {
        favorites.removeAll { $0.urlString == page.urlString }
        persist(favorites, key: favoritesKey)
    }

    func clearRecents() {
        recents = []
        persist(recents, key: recentsKey)
    }

    func recents(forHost host: String, limit: Int = 12) -> [WebPage] {
        let needle = host.replacingOccurrences(of: "www.", with: "").replacingOccurrences(of: "m.", with: "")
        return recents.filter { $0.host.contains(needle) }.prefix(limit).map { $0 }
    }

    // MARK: - Persistence

    private func load(_ key: String) -> [WebPage] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WebPage].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist(_ pages: [WebPage], key: String) {
        if let data = try? JSONEncoder().encode(pages) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: BrowserStore.didChange, object: nil)
    }
}
