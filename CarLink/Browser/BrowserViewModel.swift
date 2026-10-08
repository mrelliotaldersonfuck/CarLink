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
    @Published var isDesktopMode = true

    // Netflix keeps a lot of important state inside the web process: cookies,
    // session storage, SPA state and FairPlay/EME playback state. Keep one
    // app-wide WKWebView instead of letting SwiftUI create a fresh player
    // environment when the BrowserView is recreated.
    private static let sharedProcessPool = WKProcessPool()
    private static let sharedWebView: WKWebView = makePersistentWebView()

    let webView: WKWebView

    init(initialURL: URL = AppConfig.homeURL) {
        self.webView = Self.sharedWebView
        self.webView.customUserAgent = AppConfig.desktopUserAgent
        self.webView.allowsBackForwardNavigationGestures = true
        self.isDesktopMode = true

        if webView.url == nil {
            webView.load(URLRequest(url: initialURL))
        } else if shouldLoadInitialURL(initialURL) {
            load(initialURL)
        } else {
            updateState()
        }
    }

    private static func makePersistentWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = sharedProcessPool
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = .desktop
        configuration.defaultWebpagePreferences = preferences

        // Keep the desktop browser identity coherent and expose WebKit
        // media APIs through the entry points Netflix checks. This preserves
        // native WebKit playback while bridging ManagedMediaSource to
        // MediaSource only when classic MediaSource is absent.
        let browserCompatibilityScript = WKUserScript(
            source: #"""
            (() => {
                try {
                    const isDesktopIdentity =
                        typeof navigator.userAgent === "string" &&
                        navigator.userAgent.includes("Macintosh");

                    if (isDesktopIdentity) {
                        try {
                            Object.defineProperty(Navigator.prototype, "platform", {
                                configurable: true,
                                get: () => "MacIntel"
                            });
                        } catch (_) {
                            try {
                                Object.defineProperty(navigator, "platform", {
                                    configurable: true,
                                    get: () => "MacIntel"
                                });
                            } catch (_) {}
                        }

                        try {
                            Object.defineProperty(Navigator.prototype, "maxTouchPoints", {
                                configurable: true,
                                get: () => 5
                            });
                        } catch (_) {
                            try {
                                Object.defineProperty(navigator, "maxTouchPoints", {
                                    configurable: true,
                                    get: () => 5
                                });
                            } catch (_) {}
                        }
                    }

                    // In iPadOS desktop mode Safari identifies as a Mac, but
                    // page scripts see a tablet-sized viewport/screen rather
                    // than the narrow iPhone viewport. Netflix reached /watch
                    // on iPhone but still reported 402x637 and stopped before
                    // creating a media element. Present a stable tablet-size
                    // environment before Netflix player code runs.
                    const tabletMetrics = {
                        width: 1024,
                        height: 768,
                        availWidth: 1024,
                        availHeight: 744,
                        innerWidth: 1024,
                        innerHeight: 768,
                        outerWidth: 1024,
                        outerHeight: 768,
                        devicePixelRatio: 2
                    };

                    const defineGetter = (target, name, getter) => {
                        try {
                            Object.defineProperty(target, name, {
                                configurable: true,
                                get: getter
                            });
                        } catch (_) {
                            try {
                                Object.defineProperty(Object.getPrototypeOf(target), name, {
                                    configurable: true,
                                    get: getter
                                });
                            } catch (_) {}
                        }
                    };

                    try {
                        defineGetter(window, "innerWidth", () => tabletMetrics.innerWidth);
                        defineGetter(window, "innerHeight", () => tabletMetrics.innerHeight);
                        defineGetter(window, "outerWidth", () => tabletMetrics.outerWidth);
                        defineGetter(window, "outerHeight", () => tabletMetrics.outerHeight);
                        defineGetter(window, "devicePixelRatio", () => tabletMetrics.devicePixelRatio);
                    } catch (_) {}

                    try {
                        defineGetter(screen, "width", () => tabletMetrics.width);
                        defineGetter(screen, "height", () => tabletMetrics.height);
                        defineGetter(screen, "availWidth", () => tabletMetrics.availWidth);
                        defineGetter(screen, "availHeight", () => tabletMetrics.availHeight);
                    } catch (_) {}

                    try {
                        const originalMatchMedia = window.matchMedia ? window.matchMedia.bind(window) : null;
                        window.matchMedia = (query) => {
                            const q = String(query || "").toLowerCase();
                            if (q.includes("max-width") && q.match(/max-width\s*:\s*(?:4|5|6|7|8|9)\d{2}px/)) {
                                return { matches: false, media: query, onchange: null, addListener(){}, removeListener(){}, addEventListener(){}, removeEventListener(){}, dispatchEvent(){ return false; } };
                            }
                            if (q.includes("min-width") && q.match(/min-width\s*:\s*(?:7|8|9)\d{2}px/)) {
                                return { matches: true, media: query, onchange: null, addListener(){}, removeListener(){}, addEventListener(){}, removeEventListener(){}, dispatchEvent(){ return false; } };
                            }
                            if (q.includes("pointer") || q.includes("hover")) {
                                return { matches: q.includes("pointer: coarse") || q.includes("hover: none"), media: query, onchange: null, addListener(){}, removeListener(){}, addEventListener(){}, removeEventListener(){}, dispatchEvent(){ return false; } };
                            }
                            return originalMatchMedia ? originalMatchMedia(query) : { matches: false, media: query, onchange: null, addListener(){}, removeListener(){}, addEventListener(){}, removeEventListener(){}, dispatchEvent(){ return false; } };
                        };
                    } catch (_) {}

                    try {
                        const installViewportMeta = () => {
                            try {
                                const head = document.head || document.getElementsByTagName("head")[0];
                                if (!head) return false;
                                let meta = document.querySelector('meta[name="viewport"]');
                                if (!meta) {
                                    meta = document.createElement("meta");
                                    meta.name = "viewport";
                                    head.appendChild(meta);
                                }
                                meta.content = "width=1024, initial-scale=1.0, viewport-fit=cover";
                                return true;
                            } catch (_) { return false; }
                        };
                        if (!installViewportMeta()) {
                            const viewportObserver = new MutationObserver(() => {
                                if (installViewportMeta()) viewportObserver.disconnect();
                            });
                            viewportObserver.observe(document.documentElement || document, { childList: true, subtree: true });
                        }
                    } catch (_) {}

                    // Safari/WebKit on recent Apple platforms may expose
                    // ManagedMediaSource while hiding classic MediaSource.
                    // With a desktop Safari identity, Netflix can still probe
                    // window.MediaSource before it builds the player. Keep the
                    // native implementation when it exists, but provide the
                    // WebKit-managed implementation as the compatibility entry
                    // point when MediaSource is absent.
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

                    // Netflix can stop before creating the media element when
                    // it believes the tab is backgrounded. In this app the
                    // persistent WKWebView can be evaluated while a SwiftUI
                    // overlay/diagnostics view is on top, and earlier tests
                    // showed document.hidden=true / hasFocus=false on the watch
                    // page. Present the page as foregrounded to page scripts.
                    const installForegroundProperty = (target, name, getter) => {
                        try {
                            Object.defineProperty(target, name, {
                                configurable: true,
                                get: getter
                            });
                        } catch (_) {}
                    };

                    installForegroundProperty(Document.prototype, "hidden", () => false);
                    installForegroundProperty(Document.prototype, "visibilityState", () => "visible");

                    try {
                        Document.prototype.hasFocus = function() { return true; };
                    } catch (_) {
                        try { document.hasFocus = () => true; } catch (_) {}
                    }

                    // Ensure dynamically-created media elements use inline
                    // playback on iPhone WebKit. This does not create video
                    // elements, but prevents a later player step from being
                    // blocked by iPhone fullscreen-only defaults.
                    const prepareMediaElement = (node) => {
                        try {
                            if (!node || !node.tagName) return;
                            const tag = String(node.tagName).toLowerCase();
                            if (tag !== "video" && tag !== "audio") return;
                            node.setAttribute("playsinline", "");
                            node.setAttribute("webkit-playsinline", "");
                            if (tag === "video") node.playsInline = true;
                        } catch (_) {}
                    };

                    try {
                        const observer = new MutationObserver((mutations) => {
                            for (const mutation of mutations) {
                                for (const node of mutation.addedNodes || []) {
                                    prepareMediaElement(node);
                                    try {
                                        node.querySelectorAll?.("video,audio").forEach(prepareMediaElement);
                                    } catch (_) {}
                                }
                            }
                        });
                        observer.observe(document.documentElement || document, {
                            childList: true,
                            subtree: true
                        });
                        document.querySelectorAll?.("video,audio").forEach(prepareMediaElement);
                    } catch (_) {}

                    try {
                        window.addEventListener("blur", () => {
                            try { window.dispatchEvent(new Event("focus")); } catch (_) {}
                        }, true);
                    } catch (_) {}
                } catch (_) {}
            })();
            """#,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(browserCompatibilityScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = AppConfig.desktopUserAgent
        webView.allowsBackForwardNavigationGestures = true

        return webView
    }

    private func shouldLoadInitialURL(_ initialURL: URL) -> Bool {
        guard let current = webView.url else { return true }
        guard let currentHost = current.host?.lowercased(),
              let initialHost = initialURL.host?.lowercased() else {
            return current.absoluteString != initialURL.absoluteString
        }

        // If the user is already somewhere inside the same service, do not
        // reload and risk destroying Netflix player state.
        return currentHost != initialHost
    }

    func toggleDesktopMode() {
        isDesktopMode.toggle()
        webView.customUserAgent = isDesktopMode
            ? AppConfig.desktopUserAgent
            : AppConfig.mobileUserAgent

        // Reload the current page so the site sees the new browser identity
        // from the next navigation.
        if let url = webView.url {
            webView.load(URLRequest(url: url))
        } else {
            webView.reload()
        }
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
