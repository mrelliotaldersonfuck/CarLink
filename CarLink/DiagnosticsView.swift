import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var diagnostics: DiagnosticsModel

    init(browserModel: BrowserViewModel) {
        _diagnostics = StateObject(
            wrappedValue: DiagnosticsModel(webView: browserModel.webView)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(
                    diagnostics.logs.isEmpty
                    ? "Nenhum diagnóstico executado."
                    : diagnostics.logs
                )
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    diagnostics.runDiagnostics()
                } label: {
                    Label("Executar", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.borderedProminent)
                .disabled(diagnostics.isRunning)

                Button {
                    diagnostics.copyLogs()
                } label: {
                    Label("Copiar logs", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    diagnostics.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Diagnóstico")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            diagnostics.runDiagnostics()
        }
    }
}
