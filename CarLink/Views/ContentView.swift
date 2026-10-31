import SwiftUI
import UniformTypeIdentifiers
import CarLinkCore

struct ContentView: View {
    @EnvironmentObject private var library: MediaLibrary
    @EnvironmentObject private var playback: PlaybackController
    var body: some View {
        TabView {
            LibraryView().tabItem { Label("Biblioteca", systemImage: "play.rectangle.on.rectangle") }
            YouTubeScreen().tabItem { Label("YouTube", systemImage: "play.rectangle.fill") }
            BrowserScreen().tabItem { Label("Web", systemImage: "globe") }
            ConnectionView().tabItem { Label("Conexão", systemImage: "car.side") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if playback.current != nil { MiniPlayer() }
        }
        .sheet(isPresented: $playback.showPlayer) { PlayerScreen() }
        .alert("Não foi possível importar", isPresented: Binding(
            get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } }
        )) { Button("OK") { library.errorMessage = nil } } message: { Text(library.errorMessage ?? "") }
        .alert("Reprodução", isPresented: Binding(
            get: { playback.errorMessage != nil }, set: { if !$0 { playback.errorMessage = nil } }
        )) { Button("OK") { playback.errorMessage = nil } } message: { Text(playback.errorMessage ?? "") }
    }
}

private struct LibraryView: View {
    @EnvironmentObject private var library: MediaLibrary
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var diagnostics: Diagnostics
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var showAdd = false
    @State private var showImporter = false
    @State private var pendingRemoval: MediaEntry?

    private var filtered: [MediaEntry] {
        library.entries.filter {
            (!favoritesOnly || $0.favorite) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.group.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "play.rectangle.fill").font(.system(size: 32)).foregroundStyle(.mint)
                            Spacer()
                            Label(diagnostics.carConnected ? "CONECTADO" : "NO SEU IPHONE", systemImage: diagnostics.carConnected ? "checkmark.circle.fill" : "iphone")
                                .font(.caption2.bold()).foregroundStyle(diagnostics.carConnected ? Color.mint : Color.secondary)
                        }
                        Text("Seu vídeo.\nSua próxima pausa.").font(.system(.largeTitle, design: .rounded).bold())
                        Text("Arquivos, links e canais em um só lugar.").font(.subheadline).foregroundStyle(.secondary)
                        Button { showAdd = true } label: { Label("Adicionar mídia", systemImage: "plus").font(.headline) }
                            .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                    }
                    .padding(.vertical, 12)
                }.listRowBackground(LinearGradient(colors: [Color(red: 0.08, green: 0.20, blue: 0.23), Color(red: 0.06, green: 0.10, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing))

                Section {
                    Picker("Mostrar", selection: $favoritesOnly) {
                        Text("Todos · \(library.entries.count)").tag(false)
                        Text("Favoritos").tag(true)
                    }.pickerStyle(.segmented).listRowBackground(Color.clear)
                }

                if library.isImporting {
                    Section { ProgressView("Importando sua mídia…") }
                }
                Section {
                    if filtered.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "Sua seleção começa aqui" : "Nenhum resultado",
                                               systemImage: "play.rectangle.on.rectangle",
                                               description: Text(query.isEmpty ? "Adicione um arquivo, uma URL de vídeo ou uma lista M3U." : "Tente outro nome ou categoria."))
                            .listRowBackground(Color.clear)
                        if library.entries.isEmpty {
                            Button("Adicionar vídeo de teste HLS") { library.addDemo() }
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(filtered) { entry in
                        HStack(spacing: 14) {
                            Image(systemName: entry.isLive ? "dot.radiowaves.left.and.right" : "play.rectangle.fill")
                                .font(.title2).foregroundStyle(.mint)
                                .frame(width: 48, height: 48).background(.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                            Button { playback.play(entry) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.title).font(.headline).lineLimit(2)
                                    Text(subtitle(entry)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Button { library.toggleFavorite(entry) } label: {
                                Image(systemName: entry.favorite ? "star.fill" : "star").foregroundStyle(entry.favorite ? Color.yellow : Color.secondary)
                                    .frame(width: 44, height: 44)
                            }.buttonStyle(.borderless).accessibilityLabel(entry.favorite ? "Remover dos favoritos" : "Adicionar aos favoritos")
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) { pendingRemoval = entry } label: { Label("Remover", systemImage: "trash") }
                        }
                    }
                } header: { Text("Sua biblioteca") }
            }
            .navigationTitle("CarLink")
            .searchable(text: $query, prompt: "Buscar vídeo ou canal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Adicionar URL", systemImage: "link") { showAdd = true }
                        Button("Importar arquivo ou M3U", systemImage: "folder") { showImporter = true }
                        Button("Adicionar teste HLS", systemImage: "checkmark.play") { library.addDemo() }
                    } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Adicionar mídia")
                }
            }
            .sheet(isPresented: $showAdd) { AddMediaSheet() }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.movie, .audio, .playlist, .plainText, .data], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await library.importFiles(urls) }
                case .failure: library.errorMessage = "Não foi possível acessar os arquivos selecionados."
                }
            }
            .confirmationDialog("Remover esta mídia da biblioteca?", isPresented: Binding(
                get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }
            ), titleVisibility: .visible) {
                Button("Remover", role: .destructive) {
                    if let entry = pendingRemoval {
                        if playback.current?.id == entry.id { playback.stop() }
                        library.remove(entry)
                    }
                    pendingRemoval = nil
                }
            }
        }
    }

    private func subtitle(_ entry: MediaEntry) -> String {
        if !entry.group.isEmpty { return entry.group }
        if entry.source == .local { return "Arquivo no iPhone" }
        return entry.isLive ? "Ao vivo" : "Vídeo por link"
    }
}

private struct AddMediaSheet: View {
    @EnvironmentObject private var library: MediaLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var title = ""
    @State private var playlist = false
    @State private var live = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $playlist) { Text("Vídeo / HLS").tag(false); Text("Lista M3U").tag(true) }
                        .pickerStyle(.segmented)
                    TextField("https://…", text: $input, axis: .vertical)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !playlist {
                        TextField("Nome (opcional)", text: $title)
                        Toggle("Transmissão ao vivo", isOn: $live)
                    }
                } header: { Text(playlist ? "Endereço da lista" : "Endereço da mídia") }
                Section {
                    Text("Use uma URL direta de vídeo, áudio ou HLS. Páginas do YouTube e outros sites abrem na aba Web.")
                        .foregroundStyle(.secondary)
                    Text("Listas M3U não incluem conteúdo. O CarLink usa apenas os endereços que você fornece.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = message ?? library.errorMessage { Section { Text(message).foregroundStyle(.orange) } }
            }
            .navigationTitle("Adicionar mídia").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        if playlist {
                            library.errorMessage = nil
                            Task { await library.importRemotePlaylist(input); if library.errorMessage == nil { dismiss() } }
                        } else {
                            do { try library.addRemote(input, title: title, live: live); dismiss() }
                            catch { message = error.localizedDescription }
                        }
                    }.disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || library.isImporting)
                }
            }
        }.presentationDetents([.medium, .large])
    }
}
