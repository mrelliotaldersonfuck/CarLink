import Foundation

/// Recognize public video links without treating a web page as a media URL.
public enum YouTubeVideoID {
    public static func parse(_ input: String) -> String? {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= 4096, !clean.contains("\n"), !clean.contains("\r") else { return nil }
        if valid(clean) { return clean }
        let address = clean.contains("://") ? clean : "https://" + clean
        guard let parts = URLComponents(string: address),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443 || parts.port == 80,
              let host = parts.host?.lowercased() else { return nil }
        let path = parts.path.split(separator: "/").map(String.init)
        let candidate: String?
        if ["youtu.be", "www.youtu.be"].contains(host), path.count == 1 {
            candidate = path.first
        } else if ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "www.youtube-nocookie.com", "youtube-nocookie.com"].contains(host) {
            if path == ["watch"] {
                candidate = parts.queryItems?.first(where: { $0.name == "v" })?.value
            } else if path.count == 2, ["embed", "shorts", "live"].contains(path[0]) {
                candidate = path[1]
            } else { candidate = nil }
        } else { candidate = nil }
        guard let candidate, valid(candidate) else { return nil }
        return candidate
    }

    private static func valid(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return bytes.count == 11 && bytes.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
}
