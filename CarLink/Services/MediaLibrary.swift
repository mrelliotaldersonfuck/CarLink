import Foundation
import Combine
import CarLinkCore

@MainActor
final class MediaLibrary: ObservableObject {
    @Published private(set) var entries: [MediaEntry] = []
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?
    let directory: URL
    private let catalogueURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("CarLink/Media", isDirectory: true)
        catalogueURL = support.appendingPathComponent("CarLink/library.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: catalogueURL.path) {
                entries = try JSONDecoder().decode([MediaEntry].self, from: Data(contentsOf: catalogueURL))
            }
        } catch {
            errorMessage = "Não foi possível abrir a biblioteca salva. Os arquivos existentes foram preservados."
        }
    }

    func resolvedURL(for entry: MediaEntry) throws -> URL {
        if entry.source == .remote { return try URLPolicy.mediaURL(entry.location) }
        // Persist only filenames: sandbox container paths can change after installation.
        guard entry.location == (entry.location as NSString).lastPathComponent,
              !entry.location.isEmpty, entry.location != ".", entry.location != ".." else {
            throw MediaInputError.invalidURL
        }
        let url = directory.appendingPathComponent(entry.location)
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    @discardableResult
    func addRemote(_ input: String, title: String = "", live: Bool = false) throws -> MediaEntry {
        let url = try URLPolicy.mediaURL(input)
        guard !URLPolicy.isWebPage(url) else {
            throw LibraryError.webPage
        }
        if let existing = entries.first(where: { $0.source == .remote && $0.location == url.absoluteString }) {
            return existing
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = MediaEntry(title: cleanTitle.isEmpty ? (url.lastPathComponent.isEmpty ? "Vídeo" : url.lastPathComponent) : cleanTitle,
                              location: url.absoluteString, isLive: live)
        entries.insert(item, at: 0)
        save()
        return item
    }

    @discardableResult
    func addDemo() -> MediaEntry? {
        do {
            return try addRemote("https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
                                 title: "Teste HLS · Apple")
        } catch { errorMessage = error.localizedDescription; return nil }
    }

    func importRemotePlaylist(_ input: String) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let url = try URLPolicy.mediaURL(input)
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw LibraryError.download
            }
            if response.expectedContentLength > Int64(M3UParser.maximumBytes) { throw MediaInputError.tooLarge }
            var data = Data()
            for try await byte in bytes {
                guard data.count < M3UParser.maximumBytes else { throw MediaInputError.tooLarge }
                data.append(byte)
            }
            // Use the final response URL so redirected playlists resolve relative URLs correctly.
            try await importPlaylistData(data, sourceURL: response.url ?? url)
        } catch { errorMessage = safeMessage(error) }
    }

    func importFiles(_ urls: [URL]) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                if ["m3u", "m3u8"].contains(url.pathExtension.lowercased()) {
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? 0) <= M3UParser.maximumBytes else { throw MediaInputError.tooLarge }
                    let data = try Data(contentsOf: url)
                    // Only absolute network URLs are accepted in local playlist files.
                    try await importPlaylistData(data, sourceURL: url)
                } else {
                    let name = UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
                    let destination = directory.appendingPathComponent(name)
                    try await Task.detached(priority: .userInitiated) {
                        try FileManager.default.copyItem(at: url, to: destination)
                    }.value
                    entries.insert(MediaEntry(title: url.deletingPathExtension().lastPathComponent,
                                              location: name, source: .local), at: 0)
                    save()
                }
            } catch { errorMessage = safeMessage(error) }
        }
    }

    private func importPlaylistData(_ data: Data, sourceURL: URL) async throws {
        guard let text = String(data: data, encoding: .utf8) else { throw MediaInputError.unreadable }
        let result = try await Task.detached(priority: .userInitiated) {
            try M3UParser.parse(text, sourceURL: sourceURL)
        }.value
        switch result {
        case .hls(let url):
            try addRemote(url.absoluteString, title: sourceURL.deletingPathExtension().lastPathComponent)
        case .channels(let channels):
            var known = Set(entries.filter { $0.source == .remote }.map(\.location))
            let additions = channels.filter { known.insert($0.url.absoluteString).inserted }.map {
                MediaEntry(title: $0.title, location: $0.url.absoluteString, group: $0.group, isLive: true)
            }
            entries.append(contentsOf: additions)
            save()
        }
    }

    func toggleFavorite(_ entry: MediaEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].favorite.toggle()
        save()
    }

    func remove(_ entry: MediaEntry) {
        if entry.source == .local, let url = try? resolvedURL(for: entry) { try? FileManager.default.removeItem(at: url) }
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func save() {
        do { try JSONEncoder().encode(entries).write(to: catalogueURL, options: .atomic) }
        catch { errorMessage = "Não foi possível salvar as alterações da biblioteca." }
    }

    private func safeMessage(_ error: Error) -> String {
        if error is MediaInputError || error is LibraryError { return error.localizedDescription }
        return "Não foi possível importar a mídia. Verifique o endereço, a conexão e o acesso ao arquivo."
    }
}

enum LibraryError: LocalizedError {
    case webPage, download
    var errorDescription: String? {
        switch self {
        case .webPage: return "Esse endereço é uma página. Abra-o na aba Web. O player recebe URLs diretas de mídia."
        case .download: return "O servidor não disponibilizou a lista. Confira o endereço e suas credenciais."
        }
    }
}
