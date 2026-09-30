import Combine
import Foundation
import UIKit
import WebKit

@MainActor
final class DiagnosticsModel: ObservableObject {
    @Published var logs = ""

    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
    }

    func runDiagnostics() {
        logs = "Executando diagnóstico...\n"

        let js = #"""
        (() => {
            const out = {};
            out.date = new Date().toISOString();

            out.url = location.href;
            out.title = document.title;
            out.readyState = document.readyState;
            out.userAgent = navigator.userAgent;

            out.mediaSource = typeof window.MediaSource !== "undefined";
            out.mediaSourceTypeSupported = out.mediaSource &&
                typeof MediaSource.isTypeSupported === "function";

            out.managedMediaSource = typeof window.ManagedMediaSource !== "undefined";
            out.managedMediaSourceTypeSupported =
                out.managedMediaSource &&
                typeof ManagedMediaSource.isTypeSupported === "function";

            out.mediaCapabilities = !!navigator.mediaCapabilities;

            out.eme = typeof navigator.requestMediaKeySystemAccess === "function";

            out.mediaDevices = !!navigator.mediaDevices;

            out.remotePlayback = "remote" in HTMLMediaElement.prototype;

            out.videoCount = document.querySelectorAll("video").length;
            out.audioCount = document.querySelectorAll("audio").length;

            const video = document.createElement("video");

            const types = {
                "H264": 'video/mp4; codecs="avc1.42E01E"',
                "H264 High": 'video/mp4; codecs="avc1.640028"',
                "HEVC": 'video/mp4; codecs="hvc1.1.6.L93.B0"',
                "AAC": 'audio/mp4; codecs="mp4a.40.2"',
                "VP9": 'video/webm; codecs="vp09.00.10.08"',
                "Opus": 'audio/webm; codecs="opus"',
                "HLS": 'application/vnd.apple.mpegurl'
            };

            out.canPlay = {};
            for (const [name, type] of Object.entries(types)) {
                try {
                    out.canPlay[name] = video.canPlayType(type);
                } catch (e) {
                    out.canPlay[name] = "ERROR";
                }
            }

            out.mse = {};
            if (out.mediaSourceTypeSupported) {
                for (const [name, type] of Object.entries(types)) {
                    try {
                        out.mse[name] = MediaSource.isTypeSupported(type);
                    } catch (e) {
                        out.mse[name] = "ERROR";
                    }
                }
            }

            out.managedMse = {};
            if (out.managedMediaSourceTypeSupported) {
                for (const [name, type] of Object.entries(types)) {
                    try {
                        out.managedMse[name] = ManagedMediaSource.isTypeSupported(type);
                    } catch (e) {
                        out.managedMse[name] = "ERROR";
                    }
                }
            }

            out.emeTest = "not-tested";
            if (out.eme) {
                out.emeTest = "API-present";
            }

            out.videoDetails = Array.from(document.querySelectorAll("video")).map(v => ({
                readyState: v.readyState,
                networkState: v.networkState,
                paused: v.paused,
                ended: v.ended,
                autoplay: v.autoplay,
                muted: v.muted,
                currentTime: v.currentTime,
                duration: v.duration,
                src: v.currentSrc || v.src || "",
                errorCode: v.error ? v.error.code : null,
                errorMessage: v.error ? v.error.message : null
            }));

            return out;
        })();
        """#

        webView.evaluateJavaScript(js) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.logs += "\nERRO JavaScript:\n\(error.localizedDescription)\n"
                    return
                }

                guard let data = result as? [String: Any] else {
                    self.logs += "\nResultado inesperado do JavaScript.\n"
                    return
                }

                self.appendFormatted(data)
            }
        }
    }

    func copyLogs() {
        UIPasteboard.general.string = logs
    }

    func clearLogs() {
        logs = ""
    }

    private func appendFormatted(_ d: [String: Any]) {
        var s = "\n=== CarLink Diagnostics ===\n"
        s += "Data: \(d["date"] ?? "")\n"

        s += "\n=== Página ===\n"
        s += "URL: \(d["url"] ?? "")\n"
        s += "Título: \(d["title"] ?? "")\n"
        s += "ReadyState: \(d["readyState"] ?? "")\n"
        s += "User-Agent: \(d["userAgent"] ?? "")\n"

        s += "\n=== APIs de mídia ===\n"
        s += "MediaSource disponível: \(boolText(d["mediaSource"]))\n"
        s += "MediaSource.isTypeSupported: \(boolText(d["mediaSourceTypeSupported"]))\n"
        s += "ManagedMediaSource disponível: \(boolText(d["managedMediaSource"]))\n"
        s += "ManagedMediaSource.isTypeSupported: \(boolText(d["managedMediaSourceTypeSupported"]))\n"
        s += "MediaCapabilities: \(boolText(d["mediaCapabilities"]))\n"
        s += "EME: \(boolText(d["eme"]))\n"
        s += "navigator.mediaDevices: \(boolText(d["mediaDevices"]))\n"
        s += "Remote Playback: \(boolText(d["remotePlayback"]))\n"

        s += "\n=== canPlayType ===\n"
        appendDictionary(d["canPlay"], to: &s)

        s += "\n=== MediaSource ===\n"
        appendDictionary(d["mse"], to: &s)

        s += "\n=== ManagedMediaSource ===\n"
        appendDictionary(d["managedMse"], to: &s)

        s += "\n=== EME ===\n"
        s += "\(d["emeTest"] ?? "")\n"

        s += "\n=== Elementos de mídia ===\n"
        s += "Vídeos: \(d["videoCount"] ?? 0)\n"
        s += "Áudios: \(d["audioCount"] ?? 0)\n"

        if let videos = d["videoDetails"] as? [[String: Any]], !videos.isEmpty {
            for (i, video) in videos.enumerated() {
                s += "\n--- VIDEO \(i + 1) ---\n"
                for (k, v) in video {
                    s += "\(k): \(v)\n"
                }
            }
        }

        s += "\n=== Diagnóstico concluído ===\n"
        s += ISO8601DateFormatter().string(from: Date()) + "\n"

        logs = s
    }

    private func boolText(_ value: Any?) -> String {
        if let b = value as? Bool {
            return b ? "SIM" : "NÃO"
        }
        return "\(value ?? "N/A")"
    }

    private func appendDictionary(_ value: Any?, to s: inout String) {
        guard let dict = value as? [String: Any] else {
            s += "N/A\n"
            return
        }

        for key in dict.keys.sorted() {
            s += "\(key): \(dict[key] ?? "")\n"
        }
    }
}
