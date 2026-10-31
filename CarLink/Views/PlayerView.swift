import SwiftUI
import AVKit

@MainActor
struct NativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        AppModel.shared.diagnostics.nativePlayerAttached = true
        AppModel.shared.diagnostics.record("Interface AVPlayerViewController criada no iPhone")
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player = nil
        AppModel.shared.diagnostics.nativePlayerAttached = false
    }
}

struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        view.activeTintColor = .systemMint
        return view
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}

struct PlayerScreen: View {
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var diagnostics: Diagnostics
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                NativePlayer(player: playback.player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                VStack(spacing: 8) {
                    Text(playback.current?.title ?? "CarLink")
                        .font(.title2.bold()).multilineTextAlignment(.center)
                    Text(diagnostics.externalPlaybackActive ? "Reprodução externa ativa" : "Reproduzindo no iPhone · escolha uma saída")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if playback.isBuffering { ProgressView("Carregando…").padding(.top, 8) }
                }
                HStack(spacing: 36) {
                    Button { playback.previous() } label: { Image(systemName: "backward.end.fill") }
                        .accessibilityLabel("Mídia anterior")
                    Button { playback.skip(-15) } label: { Image(systemName: "gobackward.15") }
                        .disabled(playback.duration == 0).accessibilityLabel("Voltar 15 segundos")
                    Button { playback.toggle() } label: {
                        Image(systemName: playback.isPlaying || playback.isBuffering ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }.accessibilityLabel(playback.isPlaying ? "Pausar" : "Reproduzir")
                    Button { playback.skip(15) } label: { Image(systemName: "goforward.15") }
                        .disabled(playback.duration == 0).accessibilityLabel("Avançar 15 segundos")
                    Button { playback.next() } label: { Image(systemName: "forward.end.fill") }
                        .accessibilityLabel("Próxima mídia")
                }.font(.title2).buttonStyle(.plain)
                RoutePicker().frame(width: 60, height: 50).accessibilityLabel("Escolher tela ou saída AirPlay")
                if playback.current?.source == .local {
                    Text("Arquivos locais usam um servidor interno no iPhone. A apresentação no carro depende do suporte da central e do proxy de mídia do iOS.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Reproduzindo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Concluir") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { Button("Parar") { playback.stop(); dismiss() } }
            }
        }
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var playback: PlaybackController
    var body: some View {
        VStack(spacing: 0) {
            if !playback.showPlayer {
                NativePlayer(player: playback.player)
                    .frame(height: 130)
                    .background(.black)
            }
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill").foregroundStyle(.mint).font(.title2)
                Button { playback.showPlayer = true } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(playback.current?.title ?? "CarLink").font(.subheadline.bold()).lineLimit(1)
                        Text(playback.isBuffering ? "Carregando…" : "Abrir player").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { playback.toggle() } label: {
                    Image(systemName: playback.isPlaying || playback.isBuffering ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }.accessibilityLabel(playback.isPlaying ? "Pausar" : "Reproduzir")
                RoutePicker().frame(width: 38, height: 44).accessibilityLabel("Escolher saída")
            }.padding(.horizontal, 16).padding(.vertical, 4)
        }.background(.ultraThinMaterial)
    }
}
