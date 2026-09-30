import Foundation

struct CarLinkService: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let symbol: String
}

enum AppConfig {
    // iPad Safari-like User-Agent for the Netflix experiment.
    static let desktopUserAgent = "Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

    static let services: [CarLinkService] = [
        CarLinkService(
            id: "youtube",
            name: "YouTube",
            url: URL(string: "https://www.youtube.com/")!,
            symbol: "play.rectangle.fill"
        ),
        CarLinkService(
            id: "netflix",
            name: "Netflix",
            url: URL(string: "https://www.netflix.com/")!,
            symbol: "play.tv.fill"
        ),
        CarLinkService(
            id: "apple-tv",
            name: "Apple TV",
            url: URL(string: "https://tv.apple.com/")!,
            symbol: "tv.fill"
        ),
        CarLinkService(
            id: "prime-video",
            name: "Prime Video",
            url: URL(string: "https://www.primevideo.com/")!,
            symbol: "play.tv"
        ),
        CarLinkService(
            id: "disney-plus",
            name: "Disney+",
            url: URL(string: "https://www.disneyplus.com/")!,
            symbol: "sparkles.tv.fill"
        ),
        CarLinkService(
            id: "google",
            name: "Google",
            url: URL(string: "https://www.google.com/")!,
            symbol: "magnifyingglass"
        )
    ]

    static let homeURL = services[0].url
    static let fallbackURL = URL(string: "https://www.google.com/")!
}
