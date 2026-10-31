import AVFoundation
import MediaPlayer
import Combine
import CarLinkCore

@MainActor
final class PlaybackController: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var current: MediaEntry?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var revision = 0
    @Published var errorMessage: String?
    @Published var showPlayer = false
    private let library: MediaLibrary
    private let diagnostics: Diagnostics
    private let localServer = LocalMediaServer()
    private var preparation: Task<Void, Never>?
    private var statusObserver: NSKeyValueObservation?
    private var externalObserver: NSKeyValueObservation?
    private var itemObserver: NSKeyValueObservation?
    private var sizeObserver: NSKeyValueObservation?
    private var timer: Any?
    private var notifications: [NSObjectProtocol] = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var interruptedWhilePlaying = false
    private var reportedProgress = false

    init(library: MediaLibrary, diagnostics: Diagnostics) {
        self.library = library
        self.diagnostics = diagnostics
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        statusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = player.timeControlStatus == .playing
                self.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                let state: String
                switch player.timeControlStatus {
                case .playing: state = "Reproduzindo"
                case .waitingToPlayAtSpecifiedRate: state = "Aguardando dados"
                case .paused: state = "Pausado"
                @unknown default: state = "Estado desconhecido"
                }
                if self.diagnostics.nativePlaybackState != state {
                    self.diagnostics.nativePlaybackState = state
                    self.diagnostics.record("AVPlayer: \(state)")
                }
                self.updateNowPlaying()
                self.revision += 1
            }
        }
        externalObserver = player.observe(\.isExternalPlaybackActive, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.diagnostics.updateRoute(self.player)
                self.diagnostics.record("Saída externa: \(self.player.isExternalPlaybackActive ? "ativa" : "inativa")")
            }
        }
        timer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? max(0, time.seconds) : 0
                self.diagnostics.nativeElapsed = self.elapsed
                if self.current != nil, self.elapsed >= 2, !self.reportedProgress {
                    self.reportedProgress = true
                    self.diagnostics.record("AVPlayer avançou 2s; saída externa=\(self.player.isExternalPlaybackActive). Confirmação da imagem é separada.")
                }
                let seconds = self.player.currentItem?.duration.seconds ?? 0
                self.duration = seconds.isFinite ? max(0, seconds) : 0
                self.diagnostics.updateRoute(self.player)
                self.updateNowPlaying()
                self.revision += 1
            }
        }
        observeNotifications()
    }

    func play(_ entry: MediaEntry, presentOnPhone: Bool = true) {
        CarWindowExperiment.shared.stop()
        if remoteTargets.isEmpty { installRemoteCommands() }
        preparation?.cancel()
        localServer.stop()
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObserver = nil
        sizeObserver = nil
        reportedProgress = false
        current = entry
        elapsed = 0
        duration = 0
        errorMessage = nil
        diagnostics.nativeMediaState = "Preparando"
        diagnostics.nativeVideoSize = "Ainda não informado"
        diagnostics.nativeElapsed = 0
        diagnostics.visualObservation = "Não informado"
        if presentOnPhone { showPlayer = true }
        revision += 1
        preparation = Task { [weak self] in
            guard let self else { return }
            do {
                let source = try self.library.resolvedURL(for: entry)
                let playbackURL: URL
                if entry.source == .local {
                    playbackURL = try await self.localServer.start(file: source)
                    self.diagnostics.record("Arquivo local servido por loopback; saída CarPlay depende do proxy do iOS")
                } else {
                    playbackURL = source
                    self.diagnostics.record("Preparando mídia de \(URLPolicy.displayOrigin(source))")
                }
                try Task.checkCancellation()
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
                try session.setActive(true)
                let item = AVPlayerItem(url: playbackURL)
                self.player.replaceCurrentItem(with: item)
                self.itemObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self, self.player.currentItem === item else { return }
                        switch item.status {
                        case .readyToPlay:
                            self.diagnostics.nativeMediaState = "Pronta para reproduzir"
                            self.diagnostics.record("Mídia AVPlayer pronta para reproduzir")
                        case .failed:
                            let error = item.error as NSError?
                            self.diagnostics.nativeMediaState = "Falhou"
                            self.errorMessage = "Não foi possível reproduzir. Verifique o formato, o acesso à mídia e a conexão."
                            self.diagnostics.record("Falha no player: \(error?.domain ?? "AVPlayer") / \(error?.code ?? 0)")
                        case .unknown: self.diagnostics.nativeMediaState = "Carregando"
                        @unknown default: self.diagnostics.nativeMediaState = "Estado desconhecido"
                        }
                    }
                }
                self.sizeObserver = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self, self.player.currentItem === item else { return }
                        let size = item.presentationSize
                        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
                        let dimensions = "\(Int(size.width))×\(Int(size.height))"
                        if self.diagnostics.nativeVideoSize != dimensions {
                            self.diagnostics.nativeVideoSize = dimensions
                            self.diagnostics.record("Mídia contém vídeo: \(dimensions); isso não confirma apresentação na central")
                            self.updateNowPlaying()
                        }
                    }
                }
                self.player.play()
                self.updateNowPlaying()
            } catch is CancellationError {
                // A newer selection owns the player now.
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = "Não foi possível preparar essa mídia. Verifique o arquivo ou endereço."
                self.diagnostics.nativeMediaState = "Falhou ao preparar"
                let code = error as NSError
                self.diagnostics.record("Falha ao preparar mídia: \(code.domain) / \(code.code)")
            }
        }
    }

    func toggle() { isPlaying || isBuffering ? pause() : resume() }
    func pause() { player.pause() }
    func resume() {
        guard current != nil, player.currentItem != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }
    func stop() {
        preparation?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
        localServer.stop()
        itemObserver = nil
        sizeObserver = nil
        reportedProgress = false
        current = nil
        elapsed = 0
        duration = 0
        isPlaying = false
        isBuffering = false
        diagnostics.nativeMediaState = "Sem mídia"
        diagnostics.nativePlaybackState = "Parado"
        diagnostics.nativeVideoSize = "Ainda não informado"
        diagnostics.nativeElapsed = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        for (command, target) in remoteTargets { command.removeTarget(target) }
        remoteTargets.removeAll()
        revision += 1
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func seek(to seconds: Double) {
        guard duration > 0, seconds.isFinite else { return }
        player.seek(to: CMTime(seconds: min(max(0, seconds), duration), preferredTimescale: 600))
    }
    func skip(_ seconds: Double) { seek(to: elapsed + seconds) }
    func next() { step(1) }
    func previous() { elapsed > 3 ? seek(to: 0) : step(-1) }

    private func step(_ offset: Int) {
        guard !library.entries.isEmpty else { return }
        let index = library.entries.firstIndex(where: { $0.id == current?.id }) ?? 0
        let nextIndex = (index + offset + library.entries.count) % library.entries.count
        play(library.entries[nextIndex], presentOnPhone: showPlayer)
    }

    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.group.isEmpty ? "CarLink" : current.group,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: current.isLive
        ]
        if (player.currentItem?.presentationSize.width ?? 0) > 0 {
            info[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.video.rawValue)
        }
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = duration > 0
    }

    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        bind(center.playCommand) { $0.resume() }
        bind(center.pauseCommand) { $0.pause() }
        bind(center.togglePlayPauseCommand) { $0.toggle() }
        bind(center.nextTrackCommand) { $0.next() }
        bind(center.previousTrackCommand) { $0.previous() }
        bind(center.stopCommand) { $0.stop() }
        let seekTarget = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
        remoteTargets.append((center.changePlaybackPositionCommand, seekTarget))
    }

    private func bind(_ command: MPRemoteCommand, action: @escaping @MainActor (PlaybackController) -> Void) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] _ in
            Task { @MainActor in if let self { action(self) } }
            return .success
        }
        remoteTargets.append((command, target))
    }

    private func observeNotifications() {
        let center = NotificationCenter.default
        notifications.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                guard let self else { return }
                if type == .began {
                    self.interruptedWhilePlaying = self.isPlaying || self.isBuffering
                    self.pause()
                } else if type == .ended {
                    if self.interruptedWhilePlaying && options.contains(.shouldResume) { self.resume() }
                    self.interruptedWhilePlaying = false
                }
            }
        })
        notifications.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            Task { @MainActor in
                guard let self else { return }
                if reason == .oldDeviceUnavailable { self.pause() }
                self.diagnostics.updateRoute(self.player)
            }
        })
        notifications.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, self.player.currentItem === item else { return }
                self.pause()
                self.diagnostics.record("Mídia AVPlayer chegou ao fim")
            }
        })
        notifications.append(center.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: nil, queue: .main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, self.player.currentItem === item, let event = item.errorLog()?.events.last else { return }
                // Do not export error comments or URIs; providers can put credentials there.
                self.diagnostics.record("Erro de entrega AVPlayer: \(event.errorDomain) / \(event.errorStatusCode)")
            }
        })
    }
}
