import Combine
import Foundation

final class BrowserViewModel: ObservableObject {
    @Published var addressText = "https://www.youtube.com/"
    @Published var requestedURL = URL(string: "https://www.youtube.com/")!
    @Published var navigationID = UUID()

    @Published var currentURL: URL?
    @Published var pageTitle = "CarLink"
    @Published var detectedMediaURL: URL?
    @Published var detectedMediaTitle: String?
    @Published var message = "Abra um site e reproduza um vídeo."

    func navigate() {
        guard let url = normalizedURL(from: addressText) else {
            message = "Endereço inválido"
            return
        }
        requestedURL = url
        navigationID = UUID()
        detectedMediaURL = nil
        detectedMediaTitle = nil
        message = "Carregando…"
    }

    func useDetectedMedia() {
        guard let mediaURL = bestPlayableURL else {
            message = "A página não expôs um stream HTTP/HTTPS direto para o AVPlayer."
            return
        }

        let title = detectedMediaTitle ?? pageTitle
        MediaPlaybackCoordinator.shared.loadAndPlay(url: mediaURL, title: title)
        message = "Vídeo preparado. Use ‘Ver no carro’ para escolher a saída CarPlay/AirPlay."
    }

    var bestPlayableURL: URL? {
        if let detectedMediaURL {
            return detectedMediaURL
        }

        guard let currentURL else { return nil }
        let ext = currentURL.pathExtension.lowercased()
        let directExtensions = ["m3u8", "mp4", "mov", "m4v", "mp3", "aac"]
        return directExtensions.contains(ext) ? currentURL : nil
    }

    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}
