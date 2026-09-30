import Combine
import Foundation
import WebKit

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var addressText: String = AppConfig.homeURL.absoluteString
    @Published var currentURL: URL?
    @Published var pageTitle: String = "CarLink"
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0

    let webView: WKWebView

    init(initialURL: URL = AppConfig.homeURL) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true

        // Attempt to bridge the newer ManagedMediaSource implementation to
        // the traditional MediaSource name when a site only checks for the
        // latter. This does not add DRM support; it simply lets the page use
        // the MSE implementation that WebKit already exposes.
        let mediaSourceBridge = WKUserScript(
            source: #"""
            (() => {
                try {
                    const managed = window.ManagedMediaSource;
                    const current = window.MediaSource;
                    if (typeof current === "undefined" && typeof managed === "function") {
                        try {
                            Object.defineProperty(window, "MediaSource", {
                                value: managed,
                                configurable: true,
                                writable: true
                            });
                        } catch (_) {
                            try { window.MediaSource = managed; } catch (_) {}
                        }
                    }
                } catch (_) {}
            })();
            """#,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(mediaSourceBridge)

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // CarLink uses an iPad Safari-like identity for this Netflix experiment.
        // This only changes the browser identity; it does not add DRM or
        // other capabilities that WebKit does not provide.
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.customUserAgent = AppConfig.desktopUserAgent
        self.webView.allowsBackForwardNavigationGestures = true

        webView.load(URLRequest(url: initialURL))
    }

    func navigate() {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let candidate: URL?
        if let url = URL(string: trimmed), url.scheme != nil {
            candidate = url
        } else if let url = URL(string: "https://\(trimmed)") {
            candidate = url
        } else {
            candidate = nil
        }

        guard let url = candidate else {
            addressText = AppConfig.fallbackURL.absoluteString
            webView.load(URLRequest(url: AppConfig.fallbackURL))
            return
        }

        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func stop() {
        webView.stopLoading()
    }

    func load(_ url: URL) {
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func updateState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url
        pageTitle = webView.title?.isEmpty == false ? webView.title! : "CarLink"
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        if let url = webView.url {
            addressText = url.absoluteString
        }
    }
}
