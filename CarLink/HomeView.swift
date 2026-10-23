import AVKit
import SwiftUI

struct HomeView: View {
    @StateObject private var browser = BrowserViewModel()
    @ObservedObject private var playback = MediaPlaybackCoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            Divider()

            WebBrowserView(model: browser)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            mediaBar
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            TextField("Endereço", text: $browser.addressText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
                .onSubmit { browser.navigate() }

            Button("Ir") {
                browser.navigate()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(10)
    }

    private var mediaBar: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playback.currentMedia?.title ?? "Nenhum vídeo preparado")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(browser.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    browser.useDetectedMedia()
                } label: {
                    Label("Preparar", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(browser.bestPlayableURL == nil)
            }

            if playback.currentMedia != nil {
                HStack(spacing: 12) {
                    Button {
                        playback.isPlaying ? playback.pause() : playback.play()
                    } label: {
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 34, height: 28)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        playback.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .frame(width: 34, height: 28)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Ver no carro")
                            .font(.subheadline.weight(.semibold))
                        RoutePickerView()
                            .frame(width: 44, height: 34)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .padding(10)
    }
}
