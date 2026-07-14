import SwiftUI
import MapKit

/// Tutti i supermercati fisici rilevati nel raggio configurato, con mappa.
struct SupermarketListView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        List {
            Section {
                mapSection
                    .listRowInsets(EdgeInsets())
            }

            Section("Entro \(Int(app.settings.radiusKm)) km da te") {
                if app.supermarketService.isLoading {
                    HStack {
                        ProgressView()
                        Text("Ricerca dei supermercati in corso…")
                            .foregroundStyle(.secondary)
                    }
                } else if app.supermarketService.supermarkets.isEmpty {
                    Text("Nessun supermercato trovato. Prova ad aumentare il raggio nelle impostazioni.")
                        .foregroundStyle(.secondary)
                }
                ForEach(app.supermarketService.supermarkets) { market in
                    Button {
                        openInMaps(market)
                    } label: {
                        SupermarketRowView(supermarket: market)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Supermercati vicini")
        .refreshable {
            await app.refreshEverything()
        }
    }

    private var mapSection: some View {
        Map {
            UserAnnotation()
            ForEach(app.supermarketService.supermarkets) { market in
                Marker(market.name, systemImage: "cart", coordinate: market.coordinate)
                    .tint(.green)
            }
        }
        .frame(height: 220)
        .allowsHitTesting(false)
    }

    private func openInMaps(_ market: Supermarket) {
        let placemark = MKPlacemark(coordinate: market.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = market.name
        item.openInMaps()
    }
}
