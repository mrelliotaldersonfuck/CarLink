import Combine
import Foundation
import CarLinkCore

@MainActor
final class CarWindowExperiment: ObservableObject {
    static let shared = CarWindowExperiment()
    @Published var parkedConfirmed = false {
        didSet { if !parkedConfirmed { stop() } }
    }
    private weak var controller: CarWindowProbeController?

    func attach(_ controller: CarWindowProbeController) {
        self.controller = controller
    }

    func detach(_ controller: CarWindowProbeController) {
        controller.stopMedia()
        if self.controller === controller { self.controller = nil }
        parkedConfirmed = false
    }

    func showMarker() {
        guard let controller else { unavailable(); return }
        controller.showMarker()
    }

    func playMovie() {
        guard let controller else { unavailable(); return }
        guard parkedConfirmed else { needsParking(); return }
        guard active() else { return }
        controller.playMovie()
    }

    func showYouTube(_ input: String) {
        guard YouTubeVideoID.parse(input) != nil else {
            AppModel.shared.diagnostics.record("Janela: link YouTube inválido; use o endereço de um vídeo")
            return
        }
        guard let controller else { unavailable(); return }
        guard parkedConfirmed else { needsParking(); return }
        guard active() else { return }
        controller.showYouTube(input)
    }

    func stop() { controller?.stopMedia() }

    private func unavailable() {
        AppModel.shared.diagnostics.record("Janela: comando não executado; iOS ainda não entregou uma cena própria")
        AppModel.shared.diagnostics.recordScenes()
    }

    private func needsParking() {
        AppModel.shared.diagnostics.record("Janela: confirme no iPhone que o veículo está estacionado")
    }

    private func active() -> Bool {
        guard AppModel.shared.diagnostics.carWindowActive else {
            AppModel.shared.diagnostics.record("Janela: comando não executado; a cena própria está inativa")
            return false
        }
        return true
    }
}
