import SwiftUI
import WebKit

struct WebBrowserView: UIViewRepresentable {
    @ObservedObject var model: BrowserViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "carlinkMedia")
        configuration.userContentController = controller

        let detector = #"""
        (function() {
          function sendMedia() {
            try {
              const videos = Array.from(document.querySelectorAll('video'));
              const video = videos.find(v => v.currentSrc || v.src) || videos[0];
              if (!video) return;
              const src = video.currentSrc || video.src || '';
              if (!src) return;
              window.webkit.messageHandlers.carlinkMedia.postMessage({
                src: src,
                title: document.title || 'Vídeo'
              });
            } catch (_) {}
          }

          document.addEventListener('play', sendMedia, true);
          document.addEventListener('loadedmetadata', sendMedia, true);
          new MutationObserver(sendMedia).observe(document.documentElement, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['src']
          });
          setInterval(sendMedia, 2000);
          sendMedia();
        })();
        """#

        controller.addUserScript(
            WKUserScript(source: detector, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView
        context.coordinator.load(model.requestedURL, navigationID: model.navigationID)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastNavigationID != model.navigationID else { return }
        context.coordinator.load(model.requestedURL, navigationID: model.navigationID)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let model: BrowserViewModel
        weak var webView: WKWebView?
        var lastNavigationID: UUID?

        init(model: BrowserViewModel) {
            self.model = model
        }

        func load(_ url: URL, navigationID: UUID) {
            lastNavigationID = navigationID
            webView?.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.model.currentURL = webView.url
                self.model.addressText = webView.url?.absoluteString ?? self.model.addressText
                self.model.pageTitle = webView.title ?? "CarLink"
                self.model.message = "Página carregada"
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            DispatchQueue.main.async {
                self.model.message = "Falha ao carregar: \(error.localizedDescription)"
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "carlinkMedia",
                  let body = message.body as? [String: Any],
                  let src = body["src"] as? String,
                  let url = URL(string: src),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return
            }

            let title = body["title"] as? String
            DispatchQueue.main.async {
                self.model.detectedMediaURL = url
                self.model.detectedMediaTitle = title
                self.model.message = "Mídia detectada: \(url.lastPathComponent.isEmpty ? url.host ?? "stream" : url.lastPathComponent)"
            }
        }
    }
}
