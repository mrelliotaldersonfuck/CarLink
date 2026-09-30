import SwiftUI

struct BrowserView: View {
    @StateObject private var model: BrowserViewModel
    private let screenTitle: String

    init(initialURL: URL = AppConfig.homeURL, title: String = "CarLink") {
        _model = StateObject(wrappedValue: BrowserViewModel(initialURL: initialURL))
        self.screenTitle = title
    }
    @FocusState private var addressIsFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addressBar
                if model.isLoading {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                }
                WebView(model: model)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DiagnosticsView(browserModel: model)
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                    .accessibilityLabel("Diagnóstico")
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: model.goBack) {
                        Label("Voltar", systemImage: "chevron.backward")
                    }
                    .disabled(!model.canGoBack)

                    Button(action: model.goForward) {
                        Label("Avançar", systemImage: "chevron.forward")
                    }
                    .disabled(!model.canGoForward)

                    Spacer()

                    Button(action: model.reload) {
                        Label("Recarregar", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            model.updateState()
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)

            TextField("Endereço", text: $model.addressText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($addressIsFocused)
                .onSubmit {
                    addressIsFocused = false
                    model.navigate()
                }

            Button {
                addressIsFocused = false
                model.navigate()
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    BrowserView()
}
