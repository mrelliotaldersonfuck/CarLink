import SwiftUI

struct HomeView: View {
    private enum Route: Hashable {
        case browser(URL)
        case video
    }

    private struct HomeItem: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let tint: UInt32
        let route: Route
    }

    @State private var path: [Route] = []
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    private var items: [HomeItem] {
        var result = AppConfig.services.map {
            HomeItem(id: $0.id, name: $0.name, symbol: $0.symbol, tint: $0.tint, route: .browser($0.url))
        }
        result.append(HomeItem(id: "browser", name: "Navegador", symbol: "safari.fill", tint: 0x4C8DFF, route: .browser(AppConfig.homeURL)))
        result.append(HomeItem(id: "video", name: "Vídeo teste", symbol: "play.rectangle.on.rectangle.fill", tint: 0x8E8E93, route: .video))
        return result
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                GeometryReader { geo in
                    grid(in: geo.size)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .browser(let url): BrowserView(initialURL: url)
                case .video: VideoTestView()
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("CarLink")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField("Buscar no Google ou digitar endereço", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($searchFocused)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .onSubmit(runSearch)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func runSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searchFocused = false
        path.append(.browser(URLBuilder.resolve(text)))
        query = ""
    }

    // MARK: - Adaptive grid (fits without scrolling)

    private func grid(in size: CGSize) -> some View {
        let columns = columnCount(for: size.width)
        let rows = Int(ceil(Double(items.count) / Double(columns)))
        let spacing: CGFloat = 12
        let available = size.height - spacing * CGFloat(max(0, rows - 1))
        let cellHeight = max(92, min(190, available / CGFloat(max(1, rows))))

        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < items.count {
                            card(items[index], height: cellHeight)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: cellHeight)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private func columnCount(for width: CGFloat) -> Int {
        switch width {
        case ..<500: return 3
        case ..<820: return 4
        default: return 5
        }
    }

    private func card(_ item: HomeItem, height: CGFloat) -> some View {
        Button {
            path.append(item.route)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(hex: item.tint))
                    Image(systemName: item.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
}
