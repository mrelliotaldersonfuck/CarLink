import Foundation

public struct MediaEntry: Identifiable, Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable { case remote, local }
    public var id: UUID
    public var title: String
    /// Remote absolute URL, or an app-managed filename. Never a sandbox absolute path.
    public var location: String
    public var source: Source
    public var group: String
    public var favorite: Bool
    public var isLive: Bool
    public var addedAt: Date

    public init(id: UUID = UUID(), title: String, location: String, source: Source = .remote,
                group: String = "", favorite: Bool = false, isLive: Bool = false, addedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.location = location
        self.source = source
        self.group = group
        self.favorite = favorite
        self.isLive = isLive
        self.addedAt = addedAt
    }
}

public enum MediaInputError: LocalizedError {
    case invalidURL, emptyPlaylist, tooLarge, unreadable
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Informe uma URL completa de mídia começando com https:// ou http://."
        case .emptyPlaylist: return "A lista não contém canais com endereços HTTP ou HTTPS válidos."
        case .tooLarge: return "A lista excede o limite de 5 MB ou 5.000 canais."
        case .unreadable: return "Não foi possível ler a lista. Use um arquivo de texto M3U em UTF-8."
        }
    }
}

public enum URLPolicy {
    public static func mediaURL(_ input: String, relativeTo base: URL? = nil) throws -> URL {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.contains("\n"), !clean.contains("\r"),
              let url = URL(string: clean, relativeTo: base)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { throw MediaInputError.invalidURL }
        return url
    }

    /// Diagnostics must not leak IPTV passwords, path tokens or URL query parameters.
    public static func displayOrigin(_ url: URL) -> String {
        guard let scheme = url.scheme, let host = url.host else { return "Arquivo local" }
        return "\(scheme)://\(host)" + (url.port.map { ":\($0)" } ?? "")
    }

    public static func isWebPage(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        return ["youtube.com", "youtu.be", "netflix.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
