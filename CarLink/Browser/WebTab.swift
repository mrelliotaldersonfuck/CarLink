import Combine
import Foundation
import WebKit

/// One browser tab. It owns its own `WKWebView`, observes it through safe
/// block-based KVO (which auto-invalidates), and keeps its navigation delegate
/// alive so navigation keeps working regardless of SwiftUI view recreation.
@MainActor
final class WebTab: ObservableObject, Identifiable {
    let id = UUID()
    let webView: WKWebView

    @Published var title: String = "Nova aba"
    @Published var addressText: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var isDesktopMode = false
    @Published var isFullscreen = false

    private var observations: [NSKeyValueObservation] = []
    private let navigator: WebNavigator

    init(webView: WKWebView, onOpenNewTab: @escaping (URLRequest) -> Void) {
        self.webView = webView
        self.navigator = WebNavigator(onOpenNewTab: onOpenNewTab)
        self.navigator.tab = self
        webView.navigationDelegate = navigator
        webView.uiDelegate = navigator
        startObserving()
    }

    private func startObserving() {
        func hop(_ work: @escaping () -> Void) {
            DispatchQueue.main.async { MainActor.assumeIsolated(work) }
        }

        observations = [
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in
                hop { guard let self else { return }; self.progress = self.webView.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, _ in
                hop { guard let self else { return }; self.isLoading = self.webView.isLoading }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in
                hop { guard let self else { return }; self.canGoBack = self.webView.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in
                hop { guard let self else { return }; self.canGoForward = self.webView.canGoForward }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                hop {
                    guard let self else { return }
                    let value = self.webView.title ?? ""
                    self.title = value.isEmpty ? "CarLink" : value
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                hop {
                    guard let self, !self.isEditingSafe else { return }
                    if let url = self.webView.url { self.addressText = url.absoluteString }
                    self.recordVisit()
                }
            },
            webView.observe(\.fullscreenState, options: [.new]) { [weak self] _, _ in
                hop {
                    guard let self else { return }
                    let state = self.webView.fullscreenState
                    self.isFullscreen = (state == .enteringFullscreen || state == .inFullscreen)
                }
            }
        ]
    }

    /// The address field sets this while the user is typing so URL updates from
    /// the web view don't fight the keyboard.
    var isEditingSafe = false

    private func recordVisit() {
        guard let url = webView.url else { return }
        BrowserStore.shared.recordVisit(title: webView.title ?? "", url: url)
    }

    func load(_ url: URL) {
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }

    func applyUserAgent() {
        webView.customUserAgent = isDesktopMode ? AppConfig.desktopUserAgent : AppConfig.mobileUserAgent
    }
}

/// Navigation + UI delegate. Kept in its own object so it isn't torn down when
/// SwiftUI recreates the representable.
@MainActor
final class WebNavigator: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var tab: WebTab?
    private let onOpenNewTab: (URLRequest) -> Void

    init(onOpenNewTab: @escaping (URLRequest) -> Void) {
        self.onOpenNewTab = onOpenNewTab
    }

    // Single policy method with preferences: iOS calls this one when present,
    // so all navigation decisions (content mode + scheme blocking) live here.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let url = navigationAction.request.url, isExternalAppScheme(url) {
            decisionHandler(.cancel, preferences)
            return
        }
        preferences.preferredContentMode = (tab?.isDesktopMode ?? false) ? .desktop : .mobile
        decisionHandler(.allow, preferences)
    }

    // Open links that want a new window/tab inside CarLink.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url, isExternalAppScheme(url) {
                return nil
            }
            onOpenNewTab(navigationAction.request)
        }
        return nil
    }

    private func isExternalAppScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return !(scheme == "http" || scheme == "https" || scheme == "about" || scheme == "data")
    }
}
