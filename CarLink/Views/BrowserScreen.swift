import SwiftUI
import WebKit
import Combine
import CarLinkCore

@MainActor
final class WebBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published private(set) var currentURL = "https://m.youtube.com"
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var loading = false
    @Published var errorMessage: String?
    private var observations: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        // Standard persistent WebKit storage; no script injection or media interception.
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.loading = view.isLoading }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.currentURL = view.url?.absoluteString ?? "" }
            }
        ]
        open(currentURL)
    }

    func open(_ text: String) {
        let normalized = text.contains("://") ? text : "https://" + text
        guard let url = try? URLPolicy.mediaURL(normalized) else {
            errorMessage = "Digite um endereço de site válido."
            return
        }
        webView.load(URLRequest(url: url))
    }

    func clearWebsiteData() async {
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        open("https://m.youtube.com")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(["http", "https", "about", "blob"].contains(scheme) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url,
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { errorMessage = "Não foi possível abrir o site. Verifique a conexão." }
    }
}

private struct BrowserCanvas: UIViewRepresentable {
    let browser: WebBrowser
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

struct BrowserScreen: View {
    @StateObject private var browser = WebBrowser()
    @State private var address = "https://m.youtube.com"
    @State private var showClearConfirmation = false
    @FocusState private var editingAddress: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "globe").foregroundStyle(.mint)
                    TextField("Endereço do site", text: $address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($editingAddress).submitLabel(.go)
                        .onSubmit { editingAddress = false; browser.open(address) }
                    Button {
                        if browser.loading {
                            browser.webView.stopLoading()
                        } else {
                            browser.webView.reload()
                        }
                    } label: {
                        Image(systemName: browser.loading ? "xmark" : "arrow.clockwise").frame(width: 30, height: 36)
                    }.accessibilityLabel(browser.loading ? "Parar carregamento" : "Recarregar")
                }.padding(.horizontal, 14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal).padding(.bottom, 10)
                Text("Navegação no iPhone. Use a saída oferecida pelo site quando disponível.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
                BrowserCanvas(browser: browser)
                HStack(spacing: 28) {
                    Button { browser.webView.goBack() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(!browser.canGoBack).accessibilityLabel("Voltar")
                    Button { browser.webView.goForward() } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(!browser.canGoForward).accessibilityLabel("Avançar")
                    Spacer()
                    if let url = URL(string: browser.currentURL) {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                            .accessibilityLabel("Compartilhar página")
                    }
                }.padding(.horizontal).background(.thinMaterial)
            }
            .navigationTitle("Web").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("YouTube", systemImage: "play.rectangle") { browser.open("https://m.youtube.com") }
                        Button("Limpar dados dos sites", systemImage: "trash") { showClearConfirmation = true }
                    } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Opções do navegador")
                }
            }
            .onChange(of: browser.currentURL) { _, url in if !editingAddress { address = url } }
            .confirmationDialog("Limpar cookies e encerrar sessões dos sites?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Limpar dados", role: .destructive) { Task { await browser.clearWebsiteData() } }
            }
            .alert("Navegador", isPresented: Binding(get: { browser.errorMessage != nil }, set: { if !$0 { browser.errorMessage = nil } })) {
                Button("OK") { browser.errorMessage = nil }
            } message: { Text(browser.errorMessage ?? "") }
        }
    }
}
