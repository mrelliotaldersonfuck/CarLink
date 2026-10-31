import UIKit
import CarPlay

@MainActor
final class CarLinkAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppModel.shared.diagnostics.record("Experimento janela 45 iniciado; categoria áudio única para recuperar catálogo")
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let diagnostics = AppModel.shared.diagnostics
        diagnostics.record("Sistema solicitou cena: \(session.role.rawValue)")
        if session.role.rawValue == CarWindowSceneDelegate.roleName {
            let configuration = UISceneConfiguration(name: "CarWindowExperiment", sessionRole: session.role)
            configuration.sceneClass = UIWindowScene.self
            configuration.delegateClass = CarWindowSceneDelegate.self
            return configuration
        }
        if session.role == .carTemplateApplication {
            let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: session.role)
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = CarPlaySceneDelegate.self
            return configuration
        }
        // SwiftUI keeps ownership of the phone window. Only observe its lifecycle.
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        if session.role == .windowApplication {
            configuration.delegateClass = PhoneSceneObserver.self
        }
        return configuration
    }
}

@MainActor
final class PhoneSceneObserver: NSObject, UIWindowSceneDelegate {
    func sceneDidBecomeActive(_ scene: UIScene) {
        AppModel.shared.diagnostics.recordScenes()
    }
}
