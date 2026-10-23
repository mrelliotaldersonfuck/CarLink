import AVFoundation
import CarPlay
import Foundation
import UIKit

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private weak var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var playbackObserver: NSObjectProtocol?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.sessionConfiguration = CPSessionConfiguration(delegate: self)

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .carLinkPlaybackChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.installRootTemplate(animated: false)
        }

        installRootTemplate(animated: false)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
        }
        playbackObserver = nil
        self.interfaceController = nil
        self.sessionConfiguration = nil
    }

    private func installRootTemplate(animated: Bool) {
        guard let interfaceController else { return }

        let playback = MediaPlaybackCoordinator.shared
        let hasMedia = playback.currentMedia != nil

        let detail: String
        if #available(iOS 27.0, *) {
            if sessionConfiguration?.supportsVideoPlayback == true {
                detail = hasMedia
                    ? "Toque para reproduzir em vídeo quando o veículo permitir."
                    : "Prepare um vídeo no iPhone para ele aparecer aqui."
            } else {
                detail = hasMedia
                    ? "Este CarPlay não anuncia suporte a vídeo; reprodução pode ficar em áudio."
                    : "Prepare um vídeo no iPhone."
            }
        } else {
            detail = hasMedia
                ? "CarPlay Video requer iOS 27 ou posterior."
                : "Prepare um vídeo no iPhone."
        }

        let item = CPListItem(
            text: playback.currentMedia?.title ?? "Nenhum vídeo preparado",
            detailText: detail
        )

        if hasMedia {
            item.handler = { [weak self] _, completion in
                let playback = MediaPlaybackCoordinator.shared
                playback.play()

                if #available(iOS 27.0, *) {
                    self?.applyVideoPlaybackConfiguration(to: item)
                }
                completion()
            }

            if #available(iOS 27.0, *) {
                applyVideoPlaybackConfiguration(to: item)
            }
        }

        let section = CPListSection(items: [item])
        let template = CPListTemplate(title: "CarLink", sections: [section])
        interfaceController.setRootTemplate(template, animated: animated, completion: nil)
    }

    @available(iOS 27.0, *)
    private func applyVideoPlaybackConfiguration(to item: CPListItem) {
        let playback = MediaPlaybackCoordinator.shared
        let elapsed = playback.player.currentTime()
        let duration = normalizedDuration(playback.player.currentItem?.duration)
        let action: CPPlaybackConfiguration.Action = playback.isPlaying ? .pause : .play

        item.playbackConfiguration = CPPlaybackConfiguration(
            preferredPresentation: .video,
            playbackAction: action,
            elapsedTime: elapsed.isValid ? elapsed : .zero,
            duration: duration
        )
    }

    @available(iOS 27.0, *)
    private func normalizedDuration(_ value: CMTime?) -> CMTime {
        guard let value, value.isValid, !value.isIndefinite else { return .zero }
        let seconds = value.seconds
        guard seconds.isFinite, seconds > 0 else { return .zero }
        return value
    }

    func sessionConfiguration(
        _ sessionConfiguration: CPSessionConfiguration,
        contentStyleChanged contentStyle: CPContentStyle
    ) {}

    func sessionConfiguration(
        _ sessionConfiguration: CPSessionConfiguration,
        limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface
    ) {}
}
