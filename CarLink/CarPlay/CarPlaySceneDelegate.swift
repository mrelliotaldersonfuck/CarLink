import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private weak var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var storeObserver: NSObjectProtocol?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.sessionConfiguration = CPSessionConfiguration(delegate: self)
        interfaceController.setRootTemplate(makeRootTemplate(), animated: false, completion: nil)

        storeObserver = NotificationCenter.default.addObserver(
            forName: BrowserStore.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshRootIfNeeded() }
        }
    }

    /// Satisfies the CPSessionConfigurationDelegate requirements. The protocol
    /// is @MainActor, so these run on the main actor with the rest of the UI.
    func sessionConfiguration(
        _ sessionConfiguration: CPSessionConfiguration,
        limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface
    ) {}

    func sessionConfiguration(
        _ sessionConfiguration: CPSessionConfiguration,
        contentStyleChanged contentStyle: CPContentStyle
    ) {
        // Rebuild so the icons match the car's new light/dark style.
        refreshRootIfNeeded()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
        storeObserver = nil
        if self.interfaceController === interfaceController {
            self.interfaceController = nil
            sessionConfiguration = nil
        }
    }

    // MARK: - Trait helpers

    private var carTraits: UITraitCollection {
        interfaceController?.carTraitCollection ?? UITraitCollection(userInterfaceStyle: .dark)
    }

    private var carScale: CGFloat {
        interfaceController?.carTraitCollection.displayScale ?? 2
    }

    private var supportsVideo: Bool {
        guard let sessionConfiguration else { return false }
        if #available(iOS 26.4, *) {
            return sessionConfiguration.supportsVideoPlayback
        }
        return false
    }

    // MARK: - Root grid

    private func refreshRootIfNeeded() {
        guard let interfaceController else { return }
        interfaceController.setRootTemplate(makeRootTemplate(), animated: false, completion: nil)
    }

    private func makeRootTemplate() -> CPGridTemplate {
        // Keep the five most useful services, then Recentes, Favoritos and
        // (when the car supports it) Vídeos — eight buttons max per the SDK.
        let featured = Array(AppConfig.services.prefix(5))
        var buttons = featured.map { service in
            gridButton(title: service.name, symbol: service.symbol, tint: service.tint) { [weak self] in
                self?.showServiceRecents(service)
            }
        }

        buttons.append(gridButton(title: "Recentes", symbol: "clock.fill", tint: 0x4C8DFF) { [weak self] in
            self?.pushPages(title: "Recentes", pages: BrowserStore.shared.recents)
        })
        buttons.append(gridButton(title: "Favoritos", symbol: "star.fill", tint: 0xFFB300) { [weak self] in
            self?.pushPages(title: "Favoritos", pages: BrowserStore.shared.favorites)
        })
        buttons.append(gridButton(title: "Vídeos", symbol: "play.rectangle.on.rectangle.fill", tint: 0x8E8E93) { [weak self] in
            self?.showVideos()
        })

        return CPGridTemplate(title: "CarLink", gridButtons: Array(buttons.prefix(8)))
    }

    private func gridButton(title: String, symbol: String, tint: UInt32, handler: @escaping () -> Void) -> CPGridButton {
        let image = CarPlayAssets.gridImage(symbol: symbol, tint: tint, traits: carTraits, scale: carScale)
        return CPGridButton(titleVariants: [title], image: image) { _ in handler() }
    }

    // MARK: - Lists

    private func showServiceRecents(_ service: CarLinkService) {
        let pages = BrowserStore.shared.recents(forHost: service.url.host ?? service.name)
        pushPages(title: service.name, pages: pages, emptyHint: "Abra \(service.name) no navegador do iPhone. O que você visitar aparece aqui para retomar no carro.")
    }

    private func pushPages(title: String, pages: [WebPage], emptyHint: String? = nil) {
        let items = pages.map { page -> CPListItem in
            let item = CPListItem(
                text: page.title,
                detailText: page.host,
                image: CarPlayAssets.listImage(symbol: "globe", tint: 0x4C8DFF, traits: carTraits, scale: carScale)
            )
            item.handler = { [weak self] _, completion in
                self?.presentNotice(title: "Pronto no CarLink",
                                    message: "“\(page.title)” está aberta no navegador do iPhone. Por segurança, páginas da web não são exibidas na tela do carro — continue no telefone quando estiver parado.")
                completion()
            }
            return item
        }

        let list = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        list.emptyViewTitleVariants = ["Nada por aqui ainda"]
        if let emptyHint {
            list.emptyViewSubtitleVariants = [emptyHint]
        }
        interfaceController?.pushTemplate(list, animated: true, completion: nil)
    }

    // MARK: - Video (official iOS 27 path)

    private func showVideos() {
        guard #available(iOS 27.0, *), supportsVideo else {
            presentNotice(title: "Vídeo no carro",
                          message: supportsVideoNotice())
            return
        }

        let item = CPListItem(text: "Vídeo de teste (HLS)", detailText: "Reproduz no painel — apenas estacionado")
        item.playbackConfiguration = CPPlaybackConfiguration(
            preferredPresentation: .video,
            playbackAction: .play,
            elapsedTime: .zero,
            duration: .zero
        )
        item.handler = { _, completion in
            CarLinkVideoPlayback.shared.playSample()
            completion()
        }

        let list = CPListTemplate(title: "Vídeos", sections: [CPListSection(items: [item])])
        interfaceController?.pushTemplate(list, animated: true, completion: nil)
    }

    private func supportsVideoNotice() -> String {
        if #available(iOS 27.0, *) {
            return "Este veículo não informa suporte a vídeo no CarPlay. O teste de vídeo continua disponível no iPhone."
        }
        return "O vídeo no CarPlay requer iOS 27 ou posterior e um veículo compatível."
    }

    // MARK: - Alerts

    private func presentNotice(title: String, message: String) {
        let alert = CPAlertTemplate(
            titleVariants: [message, title],
            actions: [CPAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }]
        )
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}
