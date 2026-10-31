import UIKit

@MainActor
final class CarWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Experimental role observed in Cafari Lite. Its admission is decided by iOS.
    static let roleName = "UIWindowSceneSessionRoleCarPlay"
    var window: UIWindow?
    private var controller: CarWindowProbeController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        let diagnostics = AppModel.shared.diagnostics
        diagnostics.record("Janela: callback recebido para \(session.role.rawValue), classe \(type(of: scene))")
        guard session.role.rawValue == Self.roleName,
              let windowScene = scene as? UIWindowScene else {
            diagnostics.record("Janela: cena recusada por papel ou classe incompatível")
            return
        }
        let controller = CarWindowProbeController()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.backgroundColor = .black
        self.controller = controller
        self.window = window
        CarWindowExperiment.shared.attach(controller)
        diagnostics.carWindowConnected = true
        diagnostics.carWindowDetails = "\(Int(windowScene.screen.bounds.width))×\(Int(windowScene.screen.bounds.height)); escala \(windowScene.screen.scale)"
        window.makeKeyAndVisible()
        diagnostics.record("Janela: UIWindow criada, makeKeyAndVisible solicitado; imagem não confirmada")
        diagnostics.recordScenes()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppModel.shared.diagnostics.carWindowActive = true
        AppModel.shared.diagnostics.record("Janela: cena ativa")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        AppModel.shared.diagnostics.carWindowActive = false
        controller?.stopMedia()
        AppModel.shared.diagnostics.record("Janela: cena inativa; reprodução encerrada")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let controller { CarWindowExperiment.shared.detach(controller) }
        controller = nil
        window = nil
        let diagnostics = AppModel.shared.diagnostics
        diagnostics.carWindowConnected = false
        diagnostics.carWindowActive = false
        diagnostics.record("Janela: cena desconectada")
        diagnostics.recordScenes()
    }
}
