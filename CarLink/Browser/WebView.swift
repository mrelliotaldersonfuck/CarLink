import SwiftUI
import WebKit

/// Thin wrapper that hosts a tab's persistent `WKWebView`. The navigation and
/// UI delegates live on the `WebTab`, so this view is purely presentational.
struct WebViewContainer: UIViewRepresentable {
    let tab: WebTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Navigation is driven by WebTab / BrowserViewModel.
    }
}
