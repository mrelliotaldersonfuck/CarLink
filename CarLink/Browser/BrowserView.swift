import SwiftUI

/// Full in-app browser. Pushed from the Home screen inside its NavigationStack,
/// so it hides the system nav bar and draws its own chrome.
struct BrowserView: View {
    @StateObject private var model: BrowserViewModel

    init(initialURL: URL? = AppConfig.homeURL) {
        _model = StateObject(wrappedValue: BrowserViewModel(initialURL: initialURL))
    }

    var body: some View {
        Group {
            if let tab = model.current {
                BrowserContent(model: model, tab: tab)
                    .id(tab.id)
            } else {
                Theme.background
            }
        }
        .background(Theme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BrowserContent: View {
    @ObservedObject var model: BrowserViewModel
    @ObservedObject var tab: WebTab
    @ObservedObject private var store = BrowserStore.shared
    @FocusState private var addressFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showTabs = false

    private var addressBinding: Binding<String> {
        Binding(get: { tab.addressText }, set: { tab.addressText = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar
            WebViewContainer(tab: tab)
                .ignoresSafeArea(.container, edges: .bottom)
            bottomBar
        }
        .background(Theme.background)
        .sheet(isPresented: $showTabs) {
            TabsSheet(model: model)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: addressFocused) { _, focused in
            tab.isEditingSafe = focused
            if !focused, let url = tab.webView.url {
                tab.addressText = url.absoluteString
            }
        }
    }

    // MARK: - Top bar (address + actions)

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                Image(systemName: tab.webView.hasOnlySecureContent ? "lock.fill" : "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)

                TextField("Buscar ou digitar endereço", text: addressBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .onSubmit {
                        addressFocused = false
                        model.submitAddress(tab.addressText)
                    }

                if addressFocused {
                    Button {
                        tab.addressText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    Button {
                        tab.isLoading ? tab.stop() : tab.reload()
                    } label: {
                        Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))

            AirPlayButton()
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    @ViewBuilder
    private var progressBar: some View {
        if tab.isLoading, tab.progress > 0, tab.progress < 1 {
            ProgressView(value: tab.progress)
                .progressViewStyle(.linear)
                .tint(Theme.accent)
                .frame(height: 2)
        } else {
            Color.clear.frame(height: 2)
        }
    }

    // MARK: - Bottom bar (navigation)

    private var bottomBar: some View {
        HStack {
            toolButton(system: "chevron.backward", enabled: tab.canGoBack) { tab.goBack() }
            Spacer()
            toolButton(system: "chevron.forward", enabled: tab.canGoForward) { tab.goForward() }
            Spacer()
            toolButton(system: model.currentIsFavorite() ? "star.fill" : "star", enabled: true, tint: model.currentIsFavorite() ? Theme.accent : Theme.textPrimary) {
                model.toggleFavoriteForCurrent()
            }
            Spacer()
            toolButton(system: tab.isDesktopMode ? "desktopcomputer" : "iphone", enabled: true) {
                model.toggleDesktopMode()
            }
            Spacer()
            Button {
                showTabs = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Theme.textPrimary, lineWidth: 1.8)
                        .frame(width: 22, height: 22)
                    Text("\(model.tabs.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Theme.background)
    }

    private func toolButton(system: String, enabled: Bool, tint: Color = Theme.textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(enabled ? tint : Theme.textSecondary.opacity(0.4))
        }
        .disabled(!enabled)
    }
}

// MARK: - Tabs sheet

private struct TabsSheet: View {
    @ObservedObject var model: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.tabs) { tab in
                    Button {
                        model.select(tab)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(Theme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tab.title).lineLimit(1).foregroundStyle(Theme.textPrimary)
                                Text(tab.addressText).font(.caption).lineLimit(1).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if tab.id == model.current?.id {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                            Button {
                                model.closeTab(tab)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Abas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.addTab(url: AppConfig.homeURL)
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
