import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        model.webView.navigationDelegate = context.coordinator
        model.webView.uiDelegate = context.coordinator
        return model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Navigation is initiated by BrowserViewModel methods.
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let model: BrowserViewModel

        init(model: BrowserViewModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            Task { @MainActor in model.updateState() }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
            Task { @MainActor in model.updateState() }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                model.updateState()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            Task { @MainActor in model.updateState() }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
            Task { @MainActor in model.updateState() }
        }

        // Keep Netflix app deep-links inside CarLink. Normal HTTPS navigation
        // is left untouched; only the known Netflix app schemes are blocked.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url, isNetflixAppScheme(url) {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private func isNetflixAppScheme(_ url: URL) -> Bool {
            guard let scheme = url.scheme?.lowercased() else { return false }
            return scheme == "nflx" || scheme == "nflxvideo"
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                if let url = navigationAction.request.url, isNetflixAppScheme(url) {
                    return nil
                }
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
