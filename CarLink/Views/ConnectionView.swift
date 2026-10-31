import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var diagnostics: Diagnostics
    @EnvironmentObject private var library: MediaLibrary
    @EnvironmentObject private var playback: PlaybackController
    @ObservedObject private var experiment = CarWindowExperiment.shared
    @State private var windowYouTubeInput = "https://www.youtube.com/watch?v=M7lc1UVf-VE"
    var body: some View {
        NavigationStack {
            List {
                Section("Experimento de janela · 45") {
                    Text("Este build recupera a categoria áudio usada no catálogo do build 43. A janela própria continua como experimento separado; o retorno do ícone não confirma vídeo.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Janela própria", value: diagnostics.carWindowConnected ? "Conectada" : "Não entregue pelo iOS")
                    LabeledContent("Cena ativa", value: diagnostics.carWindowActive ? "Sim" : "Não")
                    LabeledContent("Dimensões", value: diagnostics.carWindowDetails)
                    LabeledContent("Conteúdo", value: diagnostics.carWindowMode)
                    LabeledContent("Vídeo local", value: diagnostics.carWindowVideoState)
                    LabeledContent("Layer pronto", value: diagnostics.carWindowFrameReady ? "Sim" : "Não")
                    LabeledContent("Tempo na janela", value: "\(Int(diagnostics.carWindowElapsed)) s")
                    LabeledContent("YouTube da janela", value: diagnostics.carWindowYouTubeState)
                    Toggle("Veículo estacionado · habilitar testes", isOn: $experiment.parkedConfirmed)
                    Text("Esta confirmação é manual; o app não mede a velocidade do veículo.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("1. Mostrar tela verde na central") { experiment.showMarker() }
                    Button("2. Reproduzir vídeo local na janela") { experiment.playMovie() }
                        .disabled(!experiment.parkedConfirmed)
                    TextField("Link YouTube para a janela", text: $windowYouTubeInput)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("3. Abrir YouTube na janela") { experiment.showYouTube(windowYouTubeInput) }
                        .disabled(!experiment.parkedConfirmed || windowYouTubeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("No YouTube, toque em reproduzir dentro do player na central. Este navegador é separado do player do iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Parar teste da janela") { experiment.stop() }
                    Button("Vi a tela verde na central") { diagnostics.observeCarWindow("Tela verde visível na central") }
                    Button("Vi a barra branca do vídeo se mover na central") { diagnostics.observeCarWindow("Vídeo local em movimento na central") }
                    Button("Vi o YouTube na central") { diagnostics.observeCarWindow("YouTube visível na central") }
                    Button("Não apareceu imagem na central") { diagnostics.observeCarWindow("Sem imagem na central") }
                    LabeledContent("Resultado informado", value: diagnostics.carWindowObservation)
                    Button("Atualizar cenas e diagnóstico") { diagnostics.recordSnapshot() }
                    Text(diagnostics.connectedSceneRoles).font(.caption.monospaced()).textSelection(.enabled)
                }
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: diagnostics.carConnected ? "car.side.fill" : "car.side")
                            .font(.system(size: 44)).foregroundStyle(.mint)
                        Text(diagnostics.carConnected ? "CarLink conectado" : "Pronto para conectar")
                            .font(.title2.bold())
                        Text(diagnostics.carConnected ? "A central e o iOS determinam a disponibilidade de vídeo." : "Conecte o iPhone ao CarPlay pelo método que você já usa.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }
                Section("Estado da conexão") {
                    LabeledContent("Interface CarPlay do app", value: diagnostics.carConnected ? "Conectada" : "Sem cena do app")
                    LabeledContent("Vídeo na central", value: videoStatus)
                    LabeledContent("Saída externa AVPlayer", value: diagnostics.externalPlaybackActive ? "Ativa" : "Inativa")
                    LabeledContent("Mídia AVPlayer", value: diagnostics.nativeMediaState)
                    LabeledContent("Player AVPlayer", value: diagnostics.nativePlaybackState)
                    LabeledContent("Tempo AVPlayer", value: "\(Int(diagnostics.nativeElapsed)) s")
                    LabeledContent("Vídeo da mídia", value: diagnostics.nativeVideoSize)
                    LabeledContent("YouTube", value: diagnostics.youtubeState)
                    LabeledContent("Áudio", value: diagnostics.audioRoute.isEmpty ? "Sem saída" : diagnostics.audioRoute)
                    HStack { Text("Escolher saída"); Spacer(); RoutePicker().frame(width: 44, height: 44) }
                }
                Section("Primeiro teste") {
                    Text("Com o carro estacionado, adicione o teste HLS e abra o CarLink na central. Selecione o vídeo e confira os estados acima.")
                        .foregroundStyle(.secondary)
                    Button("Reproduzir teste HLS da Apple") {
                        if let demo = library.addDemo() { playback.play(demo) }
                    }
                    Text("Este é o teste nativo de referência. Ele é separado do vídeo local da janela e pode depender de suporte de vídeo anunciado pela central.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Resultado na central") {
                    Text("Depois de testar, registre o que você viu. O relógio avançar e o áudio sair no carro não comprovam que a imagem apareceu.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Vi a imagem na central") { diagnostics.observePicture(visible: true) }
                    Button("Não vi a imagem na central") { diagnostics.observePicture(visible: false) }
                    LabeledContent("Observação", value: diagnostics.visualObservation)
                }
                Section("Sobre a reprodução") {
                    Text("O CarLink reproduz arquivos e links que você fornece. Os formatos aceitos dependem do AVPlayer; esta versão não inclui transcodificação.")
                    Text("A aba Web funciona no iPhone e usa os controles do próprio site. Não transforma outros aplicativos em fontes de vídeo e não garante a saída de conteúdo protegido.")
                    Text("A aba YouTube usa o player incorporado. O estado de saída AVPlayer acima pertence ao teste nativo; ele não monitora a saída do YouTube/WebKit.")
                    Text("Os endereços e a biblioteca ficam no aparelho. URLs de playlists podem conter credenciais; os eventos de diagnóstico não registram seus caminhos ou parâmetros.")
                }.font(.footnote).foregroundStyle(.secondary)
                Section("Diagnóstico") {
                    Button("Registrar estado agora") { diagnostics.recordSnapshot() }
                    ShareLink(item: diagnostics.exportText) { Label("Compartilhar diagnóstico", systemImage: "square.and.arrow.up") }
                    ForEach(Array(diagnostics.events.prefix(20).enumerated()), id: \.offset) { _, event in
                        Text(event).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                Section {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.6.0"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "45"
                    LabeledContent("CarLink", value: "\(version) (\(build))")
                }
            }
            .navigationTitle("Conexão")
        }
    }

    private var videoStatus: String {
        guard diagnostics.carConnected else { return "Capacidade não recebida" }
        guard let supported = diagnostics.videoSupported else { return "API indisponível neste iOS" }
        return supported ? "Suportado" : "Não anunciado pela central"
    }
}
