import SwiftUI
import CarLinkCore

@main
struct CarLinkApp: App {
    @UIApplicationDelegateAdaptor(CarLinkAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model.library)
                .environmentObject(model.playback)
                .environmentObject(model.diagnostics)
                .tint(.mint)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.scheme == "carlink", url.host == "play",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let input = components.queryItems?.first(where: { $0.name == "url" })?.value else { return }
                    do {
                        // Import only: an external deep link must not start playback without a tap.
                        try model.library.addRemote(input)
                    } catch { model.library.errorMessage = error.localizedDescription }
                }
        }
    }
}
