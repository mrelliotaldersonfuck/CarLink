import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private weak var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        showHome()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        if self.interfaceController === interfaceController {
            self.interfaceController = nil
        }
    }

    private func showHome() {
        let serviceButtons = AppConfig.services.map { service in
            CPGridButton(
                titleVariants: [service.name],
                image: UIImage(systemName: service.symbol) ?? UIImage(),
                handler: { [weak self] _ in
                    self?.showService(service)
                }
            )
        }

        let browserButton = CPGridButton(
            titleVariants: ["Navegador"],
            image: UIImage(systemName: "globe") ?? UIImage(),
            handler: { [weak self] _ in
                self?.showBrowser()
            }
        )

        let home = CPGridTemplate(
            title: "CarLink",
            gridButtons: serviceButtons + [browserButton]
        )

        interfaceController?.setRootTemplate(home, animated: false)
    }

    private func showService(_ service: CarLinkService) {
        let item = CPListItem(
            text: service.name,
            detailText: "Abrir \(service.url.host ?? service.url.absoluteString) no CarLink"
        )

        item.handler = { [weak self] _, completion in
            self?.showOpenOnPhone(service)
            completion()
        }

        let template = CPListTemplate(
            title: service.name,
            sections: [CPListSection(items: [item])]
        )

        interfaceController?.pushTemplate(template, animated: true)
    }

    private func showBrowser() {
        let item = CPListItem(
            text: "Abrir navegador",
            detailText: "Use o navegador CarLink no iPhone"
        )

        item.handler = { [weak self] _, completion in
            self?.showBrowserNotice()
            completion()
        }

        let template = CPListTemplate(
            title: "Navegador",
            sections: [CPListSection(items: [item])]
        )

        interfaceController?.pushTemplate(template, animated: true)
    }

    private func showOpenOnPhone(_ service: CarLinkService) {
        let alert = CPAlertTemplate(
            titleVariants: ["CarLink"],
            actions: [
                CPAlertAction(title: "OK", style: .default, handler: { _ in })
            ]
        )

        alert.userInfo = [
            "url": service.url.absoluteString,
            "message": "A página está preparada para abrir no navegador CarLink."
        ]

        interfaceController?.presentTemplate(alert, animated: true)
    }

    private func showBrowserNotice() {
        let alert = CPAlertTemplate(
            titleVariants: ["CarLink"],
            actions: [
                CPAlertAction(title: "OK", style: .default, handler: { _ in })
            ]
        )

        alert.userInfo = [
            "message": "O navegador WKWebView está disponível no iPhone. A exibição de conteúdo web/vídeo diretamente no CarPlay depende das capacidades autorizadas para o aplicativo."
        ]

        interfaceController?.presentTemplate(alert, animated: true)
    }
}
