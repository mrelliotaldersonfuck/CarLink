import AVKit
import SwiftUI

struct VideoTestView: View {
    private let playback = CarLinkVideoPlayback.shared

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.tint)

            Text("Vídeo de teste CarLink")
                .font(.title2.bold())

            Text("Um vídeo HLS de exemplo para testar o player nativo e a saída AirPlay. O vídeo no painel do carro requer iOS 27, veículo compatível e carro estacionado.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VideoPlayer(player: playback.player)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 22) {
                Button("Reproduzir") { playback.playSample() }
                    .buttonStyle(.borderedProminent)
                Button("Pausar") { playback.pause() }
                    .buttonStyle(.bordered)
            }

            Text("Netflix e outras páginas do navegador continuam independentes do player de teste.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Vídeo HLS")
        .navigationBarTitleDisplayMode(.inline)
    }
}
