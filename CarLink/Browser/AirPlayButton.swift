import AVKit
import SwiftUI

/// System AirPlay route picker. On a video route (the car's display or an Apple
/// TV) it hands playback off to the external screen.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = UIColor(Theme.textPrimary)
        picker.activeTintColor = UIColor(Theme.accent)
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
