import SwiftUI

struct HomeView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.tint)

                        Text("CarLink")
                            .font(.largeTitle.bold())

                        Text("Escolha um serviço para abrir no navegador")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(AppConfig.services) { service in
                            NavigationLink {
                                BrowserView(initialURL: service.url, title: service.name)
                            } label: {
                                ServiceCard(service: service)
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink {
                            BrowserView(initialURL: AppConfig.fallbackURL, title: "Navegador")
                        } label: {
                            ServiceCard(
                                name: "Navegador",
                                symbol: "globe",
                                subtitle: "Abrir qualquer endereço"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("CarLink")
        }
    }
}

private struct ServiceCard: View {
    let name: String
    let symbol: String
    let subtitle: String

    init(service: CarLinkService) {
        self.name = service.name
        self.symbol = service.symbol
        self.subtitle = service.url.host ?? ""
    }

    init(name: String, symbol: String, subtitle: String) {
        self.name = name
        self.symbol = symbol
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 42, height: 42)

            Text(name)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.quaternary)
        }
    }
}

#Preview {
    HomeView()
}
