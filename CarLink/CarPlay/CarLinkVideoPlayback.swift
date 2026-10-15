import AVFoundation
import MediaPlayer

/// Isolated media test for authorized CarPlay Video use. The sample stream is
/// published by Apple for HLS development. This does not embed a website or
/// bypass DRM; third-party streaming services require their own integration.
@MainActor
final class CarLinkVideoPlayback {
    static let shared = CarLinkVideoPlayback()

    let player = AVPlayer()
    private let sampleURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!

    private init() {
        player.allowsExternalPlayback = true
        setupRemoteCommands()
    }

    func playSample() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("CarLink: audio session setup failed: \(error.localizedDescription)")
        }

        player.replaceCurrentItem(with: AVPlayerItem(url: sampleURL))
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Vídeo de teste CarLink",
            MPMediaItemPropertyArtist: "Apple HLS Sample",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        player.play()
    }

    func resume() {
        player.play()
        updatePlaybackRate(1.0)
    }

    func pause() {
        player.pause()
        updatePlaybackRate(0.0)
    }

    private func updatePlaybackRate(_ rate: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        remote.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
    }
}
