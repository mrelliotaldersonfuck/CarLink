import SwiftUI
import UIKit
import WebKit
import Combine
import AVFoundation
import CarLinkCore

@MainActor
private final class YouTubeBridge: NSObject, WKScriptMessageHandler {
    weak var receiver: YouTubePlayerModel?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        receiver?.receive(message)
    }
}

@MainActor
final class YouTubePlayerModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    enum Destination: Equatable { case phone, carWindow }
    private let destination: Destination
    let webView: WKWebView
    @Published private(set) var state = "Cole um link para começar"
    @Published private(set) var hasVideo = false
    @Published var errorMessage: String?
    private var sessionToken = ""
    private var lastEvent = ""
    private var nativeSubscription: AnyCancellable?

    init(destination: Destination = .phone) {
        self.destination = destination
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        let bridge = YouTubeBridge()
        configuration.userContentController.add(bridge, name: "youtube")
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        bridge.receiver = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        nativeSubscription = AppModel.shared.playback.$current.dropFirst().sink { [weak self] entry in
            if entry != nil { self?.pause() }
        }
    }

    func load(_ input: String) {
        guard let id = YouTubeVideoID.parse(input) else {
            errorMessage = "Cole um link de vídeo do YouTube, Shorts, transmissão ao vivo ou o ID de 11 caracteres."
            return
        }
        let model = AppModel.shared
        if destination == .phone { CarWindowExperiment.shared.stop() }
        model.playback.stop()
        model.diagnostics.visualObservation = "Não informado"
        errorMessage = nil
        sessionToken = UUID().uuidString
        lastEvent = ""
        // Google requires Referer identification for embedded app players.
        // loadHTMLString(baseURL:) sets our real bundle ID as the app origin.
        let origin = "https://" + (Bundle.main.bundleIdentifier ?? "com.carlink.CarLink").lowercased()
        let values: [String: Any] = ["videoID": id, "origin": origin, "token": sessionToken,
                                    "fullscreen": destination == .carWindow ? 0 : 1]
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8), let baseURL = URL(string: origin) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            let code = error as NSError
            model.diagnostics.record("Sessão de áudio YouTube: \(code.domain) / \(code.code)")
        }
        hasVideo = true
        setState("Carregando player incorporado")
        webView.loadHTMLString(Self.html(configurationJSON: json), baseURL: baseURL)
    }

    func pause() {
        guard hasVideo else { return }
        webView.evaluateJavaScript("if (window.carlinkPlayer && window.carlinkPlayer.pauseVideo) { window.carlinkPlayer.pauseVideo(); }") { _, _ in }
    }

    func stop() {
        guard hasVideo else { return }
        sessionToken = UUID().uuidString
        hasVideo = false
        webView.stopLoading()
        webView.loadHTMLString("<!doctype html><html><body style='background:black'></body></html>", baseURL: nil)
        setState("Player encerrado")
        if AppModel.shared.playback.current == nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func setState(_ value: String) {
        state = value
        if destination == .carWindow {
            AppModel.shared.diagnostics.carWindowYouTubeState = value
        } else {
            AppModel.shared.diagnostics.youtubeState = value
        }
        if lastEvent != value {
            lastEvent = value
            let label = destination == .carWindow ? "YouTube na janela" : "YouTube no iPhone"
            AppModel.shared.diagnostics.record("\(label): \(value)")
        }
    }

    fileprivate func receive(_ message: WKScriptMessage) {
        // Only accept the wrapper's documented events. No DOM/media extraction.
        guard message.webView === webView, message.frameInfo.isMainFrame,
              let payload = message.body as? [String: Any], payload["token"] as? String == sessionToken,
              let kind = payload["kind"] as? String else { return }
        if kind == "ready" { setState("Pronto · toque em reproduzir no vídeo") }
        else if kind == "state", let value = payload["value"] as? Int {
            let states = [-1: "Aguardando reprodução", 0: "Vídeo encerrado", 1: "Reproduzindo no player · saída não confirmada", 2: "Pausado", 3: "Carregando vídeo", 5: "Vídeo preparado"]
            if let label = states[value] { setState(label) }
        } else if kind == "error", let code = payload["value"] as? Int {
            let detail: String
            switch code {
            case 2: detail = "Link ou ID inválido"
            case 5: detail = "Falha no player HTML5"
            case 100: detail = "Vídeo privado, removido ou indisponível"
            case 101, 150: detail = "O autor não permite reprodução incorporada"
            case 153: detail = "YouTube recusou a identificação do aplicativo"
            default: detail = "O player não conseguiu abrir este vídeo"
            }
            setState("Erro \(code)")
            errorMessage = "\(detail). Código YouTube: \(code)."
        } else if kind == "apiError" {
            setState("Falha ao carregar API YouTube")
            errorMessage = "Não foi possível carregar o player. Verifique a conexão."
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(["http", "https", "about", "blob"].contains(scheme) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Open explicitly tapped external links in the system browser, keeping
        // this web view's script bridge confined to its original wrapper.
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url,
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
    private func report(_ error: Error) {
        let code = error as NSError
        guard hasVideo, code.code != NSURLErrorCancelled else { return }
        setState("Falha WebKit \(code.code)")
        AppModel.shared.diagnostics.record("YouTube WebKit: \(code.domain) / \(code.code)")
        errorMessage = "Não foi possível carregar o vídeo. Verifique a conexão."
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        setState("Processo WebKit encerrado")
        errorMessage = "O player foi encerrado pelo sistema. Carregue o vídeo novamente."
    }

    private static func html(configurationJSON: String) -> String {
        """
        <!doctype html><html lang="pt-BR"><head>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;width:100%;height:100%;background:black}#player{width:100%;height:100%;min-width:200px;min-height:200px;border:0}</style>
        </head><body><div id="player"></div><script>
        const config = \(configurationJSON);
        function report(kind,value) {
          window.webkit.messageHandlers.youtube.postMessage({token:config.token,kind:kind,value:value});
        }
        function onYouTubeIframeAPIReady() {
          window.carlinkPlayer = new YT.Player('player', {
            width:'100%',height:'100%',videoId:config.videoID,
            playerVars:{playsinline:1,autoplay:0,controls:1,fs:config.fullscreen,origin:config.origin},
            events:{onReady:()=>report('ready',0),onStateChange:e=>report('state',e.data),onError:e=>report('error',e.data)}
          });
        }
        const script=document.createElement('script');
        script.src='https://www.youtube.com/iframe_api';
        script.onerror=()=>report('apiError',0);
        document.head.appendChild(script);
        </script></body></html>
        """
    }
}

private struct YouTubeCanvas: UIViewRepresentable {
    let model: YouTubePlayerModel
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

struct YouTubeScreen: View {
    @StateObject private var model = YouTubePlayerModel()
    @EnvironmentObject private var diagnostics: Diagnostics
    @State private var input = ""
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("YouTube").font(.largeTitle.bold())
                    Text("Abra um vídeo no player incorporado e teste a saída disponível com o carro estacionado.")
                        .foregroundStyle(.secondary)
                    TextField("Cole o link do vídeo", text: $input)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder).focused($editing).submitLabel(.go)
                        .onSubmit { load() }
                    HStack {
                        Button("Carregar vídeo") { load() }.buttonStyle(.borderedProminent)
                            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Exemplo") { input = "https://www.youtube.com/watch?v=M7lc1UVf-VE"; load() }
                    }
                    // Keep a >=200x200 viewport, including on small iPhones.
                    YouTubeCanvas(model: model).frame(height: 260).background(.black)
                    Text(model.state).font(.subheadline).textSelection(.enabled)
                    HStack {
                        Label("Escolher saída", systemImage: "airplayvideo")
                        Spacer()
                        RoutePicker().frame(width: 44, height: 44)
                        Button("Encerrar") { model.stop() }.disabled(!model.hasVideo)
                    }
                    Text("Use os controles do vídeo para reproduzir e abrir a tela cheia. O seletor mostra as rotas disponíveis; a imagem na central precisa ser confirmada no teste.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Registrar estado para o teste") { diagnostics.recordSnapshot() }
                    Text("O player vem do YouTube. Sua conexão é usada para carregar o vídeo e os recursos do serviço.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { model.pause() }
            .alert("YouTube", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        }
    }

    private func load() { editing = false; model.load(input) }
}
