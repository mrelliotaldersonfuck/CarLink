import Combine
import Foundation
import WebKit

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published private(set) var tabs: [WebTab] = []
    @Published var currentIndex: Int = 0

    // One shared process pool + the default persistent data store so logins,
    // cookies and playback state survive across tabs and app launches.
    private static let processPool = WKProcessPool()

    var current: WebTab? {
        tabs.indices.contains(currentIndex) ? tabs[currentIndex] : nil
    }

    init(initialURL: URL?) {
        addTab(url: initialURL)
    }

    // MARK: - Tabs

    @discardableResult
    func addTab(url: URL?) -> WebTab {
        let webView = Self.makeWebView()
        let tab = WebTab(webView: webView) { [weak self] request in
            self?.addTab(request: request)
        }
        tabs.append(tab)
        currentIndex = tabs.count - 1
        tab.applyUserAgent()
        if let url {
            tab.load(url)
        }
        return tab
    }

    private func addTab(request: URLRequest) {
        let tab = addTab(url: nil)
        tab.webView.load(request)
    }

    func select(_ tab: WebTab) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            currentIndex = index
        }
    }

    func closeTab(_ tab: WebTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.stop()
        tabs.remove(at: index)
        if tabs.isEmpty {
            addTab(url: AppConfig.homeURL)
        } else {
            currentIndex = min(index, tabs.count - 1)
        }
    }

    // MARK: - Actions on the current tab

    func submitAddress(_ text: String) {
        current?.load(URLBuilder.resolve(text))
    }

    func toggleDesktopMode() {
        guard let tab = current else { return }
        tab.isDesktopMode.toggle()
        tab.applyUserAgent()
        tab.reload()
    }

    func toggleFavoriteForCurrent() {
        guard let tab = current, let url = tab.webView.url else { return }
        BrowserStore.shared.toggleFavorite(title: tab.webView.title ?? tab.title, url: url)
        objectWillChange.send()
    }

    func currentIsFavorite() -> Bool {
        guard let url = current?.webView.url else { return false }
        return BrowserStore.shared.isFavorite(url)
    }

    // MARK: - Web view factory

    private static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        configuration.websiteDataStore = .default()

        // Let web pages drive their own media: inline playback and the site's
        // own fullscreen player (with its quality menu) instead of the iOS
        // native player, plus AirPlay and Picture-in-Picture.
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = true

        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        pagePreferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = pagePreferences

        configuration.userContentController.addUserScript(netflixCompatibilityScript())

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = AppConfig.mobileUserAgent
        webView.allowsBackForwardNavigationGestures = true
        // Render correctly when WebKit detaches the view for element fullscreen.
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return webView
    }

    /// Minimal, Netflix-only WebKit bridge: when classic `MediaSource` is
    /// missing but `ManagedMediaSource` exists, expose it so Netflix can build
    /// its player under the Safari identity. Scoped to netflix.com so it never
    /// touches general browsing.
    private static func netflixCompatibilityScript() -> WKUserScript {
        let source = #"""
        (() => {
            try {
                if (!/netflix\.com$/.test(location.hostname) &&
                    !location.hostname.endsWith(".netflix.com")) {
                    return;
                }
                if (typeof window.MediaSource === "undefined" &&
                    typeof window.ManagedMediaSource === "function") {
                    try {
                        Object.defineProperty(window, "MediaSource", {
                            configurable: true,
                            writable: false,
                            value: window.ManagedMediaSource
                        });
                    } catch (_) {
                        try { window.MediaSource = window.ManagedMediaSource; } catch (_) {}
                    }
                }
            } catch (_) {}
        })();
        """#
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}
