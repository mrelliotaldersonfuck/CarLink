import Foundation

public struct PlaylistChannel: Equatable, Sendable {
    public let title: String
    public let url: URL
    public let group: String
}

public enum PlaylistResult: Equatable, Sendable {
    case hls(URL)
    case channels([PlaylistChannel])
}

public enum M3UParser {
    public static let maximumBytes = 5 * 1024 * 1024
    public static let maximumChannels = 5_000

    public static func parse(_ text: String, sourceURL: URL) throws -> PlaylistResult {
        guard text.utf8.count <= maximumBytes else { throw MediaInputError.tooLarge }
        let lines = text.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // HLS manifests are a single media item, not an IPTV channel catalogue.
        if lines.contains(where: { $0.hasPrefix("#EXT-X-") }) {
            return .hls(try URLPolicy.mediaURL(sourceURL.absoluteString))
        }
        var channels: [PlaylistChannel] = []
        var title = ""
        var group = ""
        var seen = Set<String>()
        for line in lines where !line.isEmpty {
            if line.hasPrefix("#EXTINF:") {
                title = titleAfterAttributes(line)
                group = attribute("group-title", in: line) ?? ""
            } else if line.hasPrefix("#EXTGRP:") {
                group = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if !line.hasPrefix("#") {
                defer { title = ""; group = "" }
                guard let url = try? URLPolicy.mediaURL(line, relativeTo: sourceURL),
                      seen.insert(url.absoluteString).inserted else { continue }
                guard channels.count < maximumChannels else { throw MediaInputError.tooLarge }
                let fallback = url.deletingPathExtension().lastPathComponent
                channels.append(PlaylistChannel(title: title.isEmpty ? (fallback.isEmpty ? "Canal" : fallback) : title,
                                                url: url, group: group))
            }
        }
        guard !channels.isEmpty else { throw MediaInputError.emptyPlaylist }
        return .channels(channels)
    }

    private static func titleAfterAttributes(_ line: String) -> String {
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            if line[index] == "," && !quoted {
                return String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func attribute(_ name: String, in line: String) -> String? {
        guard let range = line.range(of: name + "=\"") else { return nil }
        let remainder = line[range.upperBound...]
        guard let end = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[..<end])
    }
}
