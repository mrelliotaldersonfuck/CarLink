import AVFoundation
import Combine
import Foundation
import MediaPlayer

extension Notification.Name {
    static let carLinkPlaybackChanged = Notification.Name("CarLinkPlaybackChanged")
}

struct CarLinkMedia: Equatable {
    let url: URL
    let title: String
}

final class MediaPlaybackCoordinator: ObservableObject {
    static let shared = MediaPlaybackCoordinator()

    let player = AVPlayer()

    @Published private(set) var currentMedia: CarLinkMedia?
    @Published private(set) var isPlaying = false
    @Published private(set) var statusText = "Nenhum vídeo preparado"

    private var timeObserver: Any?

    private init() {
        configureAudioSession()
        configurePlayer()
        configureRemoteCommands()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("CarLink AVAudioSession error: \(error)")
        }
    }

    private func configurePlayer() {
        player.allowsExternalPlayback = true
        player.automaticallyWaitsToMinimizeStalling = true

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] _ in
            self?.publishNowPlayingInfo()
        }
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true

        commands.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commands.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.isPlaying ? self.pause() : self.play()
            return .success
        }
    }

    func loadAndPlay(url: URL, title: String? = nil) {
        let mediaTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (mediaTitle?.isEmpty == false ? mediaTitle! : url.lastPathComponent)

        currentMedia = CarLinkMedia(url: url, title: resolvedTitle.isEmpty ? "Vídeo" : resolvedTitle)
        statusText = "Preparando para reprodução"

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        play()
        notifyCarPlay()
    }

    func play() {
        guard player.currentItem != nil else { return }
        player.play()
        isPlaying = true
        statusText = "Reproduzindo"
        publishNowPlayingInfo()
        notifyCarPlay()
    }

    func pause() {
        player.pause()
        isPlaying = false
        statusText = "Pausado"
        publishNowPlayingInfo()
        notifyCarPlay()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentMedia = nil
        isPlaying = false
        statusText = "Nenhum vídeo preparado"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        notifyCarPlay()
    }

    private func publishNowPlayingInfo() {
        guard let media = currentMedia else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: media.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0),
            MPNowPlayingInfoPropertyPlaybackRate: player.rate
        ]

        if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func notifyCarPlay() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .carLinkPlaybackChanged, object: nil)
        }
    }
}
