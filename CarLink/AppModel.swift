import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let library: MediaLibrary
    let diagnostics: Diagnostics
    let playback: PlaybackController

    private init() {
        let library = MediaLibrary()
        let diagnostics = Diagnostics()
        self.library = library
        self.diagnostics = diagnostics
        self.playback = PlaybackController(library: library, diagnostics: diagnostics)
        diagnostics.record("CarLink iniciado")
    }
}
