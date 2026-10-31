import Foundation
import Combine
import AVFoundation
import CarLinkCore
import UIKit

@MainActor
final class Diagnostics: ObservableObject {
    @Published var carConnected = false
    @Published var videoSupported: Bool?
    @Published var externalPlaybackActive = false
    @Published var audioRoute = "iPhone"
    @Published var nativeMediaState = "Sem mídia"
    @Published var nativePlaybackState = "Parado"
    @Published var nativeVideoSize = "Ainda não informado"
    @Published var nativeElapsed: Double = 0
    @Published var nativePlayerAttached = false
    @Published var youtubeState = "Não carregado"
    @Published var visualObservation = "Não informado"
    @Published var carWindowConnected = false
    @Published var carWindowActive = false
    @Published var carWindowDetails = "Não recebida"
    @Published var carWindowMode = "Aguardando cena"
    @Published var carWindowVideoState = "Sem teste"
    @Published var carWindowFrameReady = false
    @Published var carWindowElapsed: Double = 0
    @Published var carWindowYouTubeState = "Não carregado"
    @Published var carWindowObservation = "Não informado"
    @Published var connectedSceneRoles = "Nenhuma cena registrada"
    @Published private(set) var events: [String] = []
    private let logURL: URL?

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let directory, (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil {
            logURL = directory.appendingPathComponent("carlink-window-events.txt")
        } else { logURL = nil }
        if let logURL, let previous = try? String(contentsOf: logURL, encoding: .utf8) {
            events = Array(previous.components(separatedBy: "\n").filter { !$0.isEmpty }.prefix(150))
        }
        record("Nova sessão do experimento de janela; eventos anteriores preservados")
    }

    func record(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        events.insert("\(time) · \(message)", at: 0)
        if events.count > 150 { events.removeLast(events.count - 150) }
        if let logURL { try? events.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8) }
    }

    func updateRoute(_ player: AVPlayer) {
        externalPlaybackActive = player.isExternalPlaybackActive
        audioRoute = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: ", ")
    }

    func recordSnapshot() {
        recordScenes()
        record("Snapshot: suporte CarPlay=\(videoSupported.map(String.init) ?? "não informado"); AVPlayer externo=\(externalPlaybackActive); mídia=\(nativeMediaState); estado=\(nativePlaybackState); tempo=\(Int(nativeElapsed))s; YouTube=\(youtubeState)")
        record("Snapshot janela: conectada=\(carWindowConnected); ativa=\(carWindowActive); modo=\(carWindowMode); layer=\(carWindowFrameReady); tempo=\(Int(carWindowElapsed))s")
    }

    func recordScenes() {
        let scenes = UIApplication.shared.connectedScenes.map {
            "\($0.session.role.rawValue) [\(type(of: $0)), estado=\($0.activationState.rawValue)]"
        }.sorted()
        connectedSceneRoles = scenes.isEmpty ? "Nenhuma cena conectada" : scenes.joined(separator: "; ")
        record("Cenas entregues pelo sistema: \(connectedSceneRoles)")
    }

    func observeCarWindow(_ result: String) {
        carWindowObservation = result
        record("Resultado visual da janela informado pelo usuário: \(result)")
    }

    func observePicture(visible: Bool) {
        visualObservation = visible ? "Imagem visível na central" : "Imagem não visível na central"
        record("Resultado visual informado pelo usuário: \(visualObservation)")
    }

    var exportText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return """
        CarLink \(version) (\(build))
        Sistema: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Categoria declarada no build: \(Bundle.main.infoDictionary?["CarLinkCarPlayCategory"] as? String ?? "não informada") (entitlement único)
        Experimento: \(Bundle.main.infoDictionary?["CarLinkExperiment"] as? String ?? "não informado")
        Cenas entregues: \(connectedSceneRoles)
        Janela própria conectada: \(carWindowConnected)
        Janela própria ativa: \(carWindowActive)
        Dimensões da janela: \(carWindowDetails)
        Conteúdo da janela: \(carWindowMode)
        Vídeo local da janela: \(carWindowVideoState)
        Layer da janela pronto: \(carWindowFrameReady)
        Tempo do vídeo da janela: \(Int(carWindowElapsed))s
        YouTube da janela: \(carWindowYouTubeState)
        Resultado visual da janela: \(carWindowObservation)
        Cena CarPlay do app conectada: \(carConnected)
        Vídeo anunciado: \(videoSupported.map(String.init) ?? "não informado")
        Reprodução externa AVPlayer: \(externalPlaybackActive)
        Estado da mídia AVPlayer: \(nativeMediaState)
        Estado da reprodução AVPlayer: \(nativePlaybackState)
        Tempo AVPlayer: \(Int(nativeElapsed))s
        Dimensões AVPlayer: \(nativeVideoSize)
        Interface AVPlayer criada: \(nativePlayerAttached)
        Player YouTube: \(youtubeState)
        Saída de áudio: \(audioRoute)
        Observação visual do usuário: \(visualObservation)
        A flag de saída AVPlayer não mede a saída do player YouTube/WebKit.
        Cena ativa, layer pronto e relógio avançando não comprovam imagem na central.

        \(events.joined(separator: "\n"))
        """
    }
}
