import CarPlay
import AVFoundation
import Combine
import CarLinkCore

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private var controller: CPInterfaceController?
    private var configuration: CPSessionConfiguration?
    private var libraryTemplate: CPListTemplate?
    private var favoritesTemplate: CPListTemplate?
    private var playableRows: [(MediaEntry, CPListItem)] = []
    private var subscriptions = Set<AnyCancellable>()
    private let model = AppModel.shared

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        controller = interfaceController
        configuration = CPSessionConfiguration(delegate: self)
        model.diagnostics.carConnected = true
        if #available(iOS 26.4, *) {
            model.diagnostics.videoSupported = configuration?.supportsVideoPlayback
        } else {
            model.diagnostics.videoSupported = nil
        }
        model.diagnostics.record("Cena CarPlay conectada; vídeo anunciado: \(model.diagnostics.videoSupported.map(String.init) ?? "API indisponível")")

        let library = CPListTemplate(title: "Biblioteca", sections: [])
        library.tabTitle = "Biblioteca"
        library.tabImage = UIImage(systemName: "play.rectangle.on.rectangle")
        library.emptyViewTitleVariants = ["Sua biblioteca está vazia"]
        library.emptyViewSubtitleVariants = ["Adicione vídeos ou uma lista no iPhone."]
        let favorites = CPListTemplate(title: "Favoritos", sections: [])
        favorites.tabTitle = "Favoritos"
        favorites.tabImage = UIImage(systemName: "star")
        favorites.emptyViewTitleVariants = ["Nenhum favorito"]
        favorites.emptyViewSubtitleVariants = ["Marque uma mídia com a estrela no iPhone."]
        libraryTemplate = library
        favoritesTemplate = favorites
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.tabTitle = "Reproduzindo"
        nowPlaying.tabImage = UIImage(systemName: "waveform")
        if #available(iOS 27.0, *) { nowPlaying.allowsMiniPlayer = true }
        // Keep Now Playing on the navigation stack, not inside the tab bar.
        // Only list templates are used as tabs for consistent audio/video support.
        for template in [library, favorites] {
            template.trailingNavigationBarButtons = [CPBarButton(title: "Reproduzindo") { [weak self] _ in
                guard let self, self.controller?.topTemplate !== CPNowPlayingTemplate.shared else { return }
                self.controller?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }]
        }
        let root = CPTabBarTemplate(templates: [library, favorites])
        updateLibrary()
        interfaceController.setRootTemplate(root, animated: false) { [weak self] success, error in
            Task { @MainActor in
                self?.model.diagnostics.record(success ? "Interface CarPlay pronta" : "Falha ao apresentar templates CarPlay")
            }
        }

        model.library.$entries.dropFirst().debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateLibrary() }.store(in: &subscriptions)
        model.playback.$revision.sink { [weak self] _ in self?.refreshPlayback() }.store(in: &subscriptions)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        subscriptions.removeAll()
        controller = nil
        configuration = nil
        libraryTemplate = nil
        favoritesTemplate = nil
        playableRows = []
        model.diagnostics.carConnected = false
        model.diagnostics.videoSupported = nil
        model.diagnostics.record("Cena CarPlay desconectada")
        model.playback.pause()
    }

    private func updateLibrary() {
        playableRows.removeAll()
        // Respect the head unit's own item limit; the full library stays on iPhone.
        let limit = Int(CPListTemplate.maximumItemCount)
        let entries = Array(model.library.entries.prefix(limit))
        libraryTemplate?.updateSections([CPListSection(items: entries.map(makeRow))])
        let favorites = Array(model.library.entries.filter(\.favorite).prefix(limit))
        favoritesTemplate?.updateSections([CPListSection(items: favorites.map(makeRow))])
        refreshPlayback()
    }

    private func makeRow(_ entry: MediaEntry) -> CPListItem {
        let detail = entry.group.isEmpty ? (entry.isLive ? "Ao vivo" : "Vídeo") : entry.group
        let row = CPListItem(text: entry.title, detailText: detail,
                             image: UIImage(systemName: entry.isLive ? "dot.radiowaves.left.and.right" : "play.rectangle"))
        row.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            if self.model.playback.current?.id == entry.id {
                self.model.playback.toggle()
            } else {
                self.model.playback.play(entry, presentOnPhone: true)
            }
            completion()
            // The system presents native video when supported. Do not replace
            // the template stack here: doing so can dismiss the system player.
            if self.model.diagnostics.videoSupported != true {
                self.controller?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
        }
        playableRows.append((entry, row))
        return row
    }

    private func refreshPlayback() {
        guard #available(iOS 26.4, *) else { return }
        for (entry, row) in playableRows {
            let selected = model.playback.current?.id == entry.id
            let active = selected && (model.playback.isPlaying || model.playback.isBuffering)
            row.playbackConfiguration = CPPlaybackConfiguration(
                // This describes the content, not the receiver's capability.
                // The system chooses video or its audio-only fallback.
                preferredPresentation: .video,
                playbackAction: active ? .pause : .play,
                elapsedTime: CMTime(seconds: selected ? model.playback.elapsed : 0, preferredTimescale: 600),
                duration: CMTime(seconds: selected ? model.playback.duration : 0, preferredTimescale: 600)
            )
        }
    }

    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {
        model.diagnostics.record("Limites da interface CarPlay atualizados")
    }
    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration, contentStyleChanged contentStyle: CPContentStyle) {
        model.diagnostics.record("Estilo da interface CarPlay atualizado")
    }
}
