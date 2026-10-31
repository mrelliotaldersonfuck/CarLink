import UIKit
import AVFoundation
import Combine

private final class ProbeVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@MainActor
final class CarWindowProbeController: UIViewController {
    private let heading = UILabel()
    private let status = UILabel()
    private let content = UIView()
    private let videoView = ProbeVideoView()
    private let player = AVPlayer()
    private var youtube: YouTubePlayerModel?
    private var preparation: Task<Void, Never>?
    private var itemObservation: NSKeyValueObservation?
    private var layerObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var mediaToken = UUID()
    private var lastGeometry = ""
    private var lastProgressBucket = -1
    private var diagnostics: Diagnostics { AppModel.shared.diagnostics }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        heading.text = "CARLINK • JANELA 45"
        heading.font = .boldSystemFont(ofSize: 17)
        heading.textColor = .systemMint
        heading.textAlignment = .center
        status.text = "Teste com veículo estacionado"
        status.font = .systemFont(ofSize: 12)
        status.textColor = .white
        status.textAlignment = .center
        status.numberOfLines = 2
        let controls = UIStackView(arrangedSubviews: [
            button("Tela") { [weak self] in self?.showMarker() },
            button("Vídeo") { CarWindowExperiment.shared.playMovie() },
            button("YouTube") { CarWindowExperiment.shared.showYouTube("M7lc1UVf-VE") },
            button("Parar") { CarWindowExperiment.shared.stop() }
        ])
        controls.axis = .horizontal
        controls.distribution = .fillEqually
        controls.spacing = 6
        let stack = UIStackView(arrangedSubviews: [heading, controls, content, status])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            controls.heightAnchor.constraint(equalToConstant: 44)
        ])
        player.allowsExternalPlayback = false // Render inside this window; do not hand off to the native route.
        videoView.playerLayer.player = player
        videoView.playerLayer.videoGravity = .resizeAspect
        showMarker()
    }

    private func button(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = .darkGray
        button.layer.cornerRadius = 8
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        diagnostics.record("Janela: viewDidAppear recebido; confirmação visual ainda necessária")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopMedia()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let dimensions = "\(Int(view.bounds.width))×\(Int(view.bounds.height)); conteúdo \(Int(content.bounds.width))×\(Int(content.bounds.height))"
        if dimensions != lastGeometry {
            lastGeometry = dimensions
            diagnostics.carWindowDetails = dimensions
            diagnostics.record("Janela: layout \(dimensions)")
        }
    }

    func showMarker() {
        loadViewIfNeeded()
        stopMedia()
        let marker = UILabel()
        marker.text = "JANELA CARLINK 45\n\nSe esta tela verde está na central,\na janela própria apareceu.\n\nConfirme o carro estacionado no iPhone."
        marker.numberOfLines = 0
        marker.textAlignment = .center
        marker.font = .boldSystemFont(ofSize: 18)
        marker.adjustsFontSizeToFitWidth = true
        marker.minimumScaleFactor = 0.6
        marker.textColor = .black
        marker.backgroundColor = .systemMint
        display(marker)
        diagnostics.carWindowMode = "Tela de identificação"
        status.text = "Tela verde preparada • confirme visualmente na central"
        diagnostics.record("Janela: tela verde preparada")
    }

    func playMovie() {
        loadViewIfNeeded()
        stopMedia()
        AppModel.shared.playback.stop()
        let token = mediaToken
        diagnostics.carWindowMode = "Vídeo local"
        diagnostics.carWindowVideoState = "Gerando vídeo H.264 no iPhone"
        status.text = "Gerando vídeo local…"
        preparation = Task { [weak self] in
            do {
                let url = try await ProbeMovieFactory.shared.movie()
                try Task.checkCancellation()
                guard let self, self.mediaToken == token else { return }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                self.display(self.videoView)
                let item = AVPlayerItem(url: url)
                self.player.replaceCurrentItem(with: item)
                self.installObservers(for: item, token: token)
                self.diagnostics.carWindowVideoState = "Vídeo gerado; preparando player"
                self.diagnostics.record("Janela: vídeo H.264 local gerado; player próprio, sem saída externa")
                self.player.play()
            } catch is CancellationError {
                // A newer command owns the surface.
            } catch {
                guard let self, self.mediaToken == token else { return }
                let code = error as NSError
                self.diagnostics.carWindowVideoState = "Falha \(code.domain)/\(code.code)"
                self.status.text = "Não foi possível preparar o teste local"
                self.diagnostics.record("Janela: falha no teste local \(code.domain)/\(code.code)")
            }
        }
    }

    func showYouTube(_ input: String) {
        loadViewIfNeeded()
        stopMedia()
        let youtube = YouTubePlayerModel(destination: .carWindow)
        self.youtube = youtube
        display(youtube.webView)
        diagnostics.carWindowMode = "YouTube na janela"
        status.text = "Toque em reproduzir dentro do vídeo na central"
        youtube.load(input)
        diagnostics.record("Janela: WebKit próprio anexado; reprodução depende do toque no player")
    }

    private func display(_ child: UIView) {
        for subview in content.subviews { subview.removeFromSuperview() }
        child.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            child.topAnchor.constraint(equalTo: content.topAnchor),
            child.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func installObservers(for item: AVPlayerItem, token: UUID) {
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.mediaToken == token else { return }
                switch item.status {
                case .readyToPlay:
                    self.diagnostics.carWindowVideoState = "Mídia pronta"
                    self.diagnostics.record("Janela: AVPlayerItem pronto")
                case .failed:
                    let code = item.error as NSError?
                    self.diagnostics.carWindowVideoState = "Falha no player"
                    self.diagnostics.record("Janela: erro do item \(code?.domain ?? "AVPlayer")/\(code?.code ?? 0)")
                default: break
                }
            }
        }
        layerObservation = videoView.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            Task { @MainActor in
                guard let self, self.mediaToken == token else { return }
                self.diagnostics.carWindowFrameReady = layer.isReadyForDisplay
                if layer.isReadyForDisplay {
                    self.diagnostics.record("Janela: AVPlayerLayer pronto para exibir; imagem na central não confirmada")
                }
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, self.mediaToken == token else { return }
                let seconds = time.seconds
                guard seconds.isFinite, seconds >= 0 else { return }
                self.diagnostics.carWindowElapsed = seconds
                self.status.text = "Vídeo local • \(Int(seconds)) s • confirme a barra branca em movimento"
                let bucket = Int(seconds) / 3
                if bucket != self.lastProgressBucket {
                    self.lastProgressBucket = bucket
                    self.diagnostics.record("Janela: vídeo local \(Int(seconds))s; layer pronto=\(self.videoView.playerLayer.isReadyForDisplay)")
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.mediaToken == token else { return }
                self.player.seek(to: .zero)
                self.player.play()
            }
        }
    }

    func stopMedia() {
        mediaToken = UUID()
        preparation?.cancel()
        preparation = nil
        itemObservation = nil
        layerObservation = nil
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        youtube?.stop()
        youtube = nil
        diagnostics.carWindowFrameReady = false
        diagnostics.carWindowElapsed = 0
        diagnostics.carWindowVideoState = "Parado"
        diagnostics.carWindowMode = "Parado"
        lastProgressBucket = -1
        status.text = "Teste parado"
    }
}
