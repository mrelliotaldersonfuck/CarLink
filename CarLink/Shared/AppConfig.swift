import Foundation

struct CarLinkService: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let symbol: String
    let tint: UInt32
}

enum AppConfig {
    // Mobile identity is the default: it gives responsive layouts that fit the
    // phone and the car screen, and lets sites like YouTube use their own web
    // player (with a quality menu) instead of the iOS native player. Desktop
    // identity is available per-tab through the browser's desktop toggle.
    static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    static let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    static let services: [CarLinkService] = [
        CarLinkService(id: "youtube", name: "YouTube", url: URL(string: "https://m.youtube.com/")!, symbol: "play.rectangle.fill", tint: 0xFF3B30),
        CarLinkService(id: "netflix", name: "Netflix", url: URL(string: "https://www.netflix.com/")!, symbol: "play.tv.fill", tint: 0xE50914),
        CarLinkService(id: "prime-video", name: "Prime Video", url: URL(string: "https://www.primevideo.com/")!, symbol: "play.tv", tint: 0x00A8E1),
        CarLinkService(id: "disney-plus", name: "Disney+", url: URL(string: "https://www.disneyplus.com/")!, symbol: "sparkles.tv.fill", tint: 0x113CCF),
        CarLinkService(id: "apple-tv", name: "Apple TV", url: URL(string: "https://tv.apple.com/")!, symbol: "tv.fill", tint: 0x5A5A5F),
        CarLinkService(id: "google", name: "Google", url: URL(string: "https://www.google.com/")!, symbol: "magnifyingglass", tint: 0x4285F4)
    ]

    static let homeURL = URL(string: "https://www.google.com/")!
    static let fallbackURL = URL(string: "https://www.google.com/")!

    static func service(forHost host: String?) -> CarLinkService? {
        guard let host = host?.lowercased() else { return nil }
        return services.first { service in
            guard let serviceHost = service.url.host?.lowercased() else { return false }
            let base = serviceHost.replacingOccurrences(of: "www.", with: "").replacingOccurrences(of: "m.", with: "")
            return host.contains(base)
        }
    }
}

/// Turns whatever the user types in the address bar into a URL: a full URL, a
/// bare domain, or a Google search for anything else.
enum URLBuilder {
    static func resolve(_ raw: String) -> URL {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return AppConfig.homeURL }

        if let url = URL(string: text), let scheme = url.scheme, scheme == "http" || scheme == "https" {
            return url
        }

        if looksLikeDomain(text), let url = URL(string: "https://\(text)") {
            return url
        }

        return searchURL(for: text)
    }

    static func searchURL(for query: String) -> URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url ?? AppConfig.fallbackURL
    }

    private static func looksLikeDomain(_ text: String) -> Bool {
        if text.contains(" ") { return false }
        guard text.contains(".") else { return false }
        // Reject things that are clearly a sentence ending in a period.
        let host = text.split(separator: "/").first.map(String.init) ?? text
        return host.contains(".") && !host.hasSuffix(".")
    }
}
