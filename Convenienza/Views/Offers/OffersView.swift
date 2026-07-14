import SwiftUI
import SwiftData

/// Elenco completo delle offerte attive in zona, con filtri per distanza,
/// supermercato, categoria, percentuale di sconto e prezzo massimo.
struct OffersView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \OfferRecord.price) private var allOffers: [OfferRecord]

    @State private var filter = OfferFilter()
    @State private var sort: OfferSort = .sconto
    @State private var showFilters = false

    private var filteredOffers: [OfferRecord] {
        let location = app.location.currentLocation
        let active = allOffers.filter { $0.isActive && filter.matches($0, userLocation: location) }
        switch sort {
        case .distanza:
            return active.sorted {
                ($0.distance(from: location) ?? .infinity) < ($1.distance(from: location) ?? .infinity)
            }
        case .sconto:
            return active.sorted { ($0.discountPercent ?? 0) > ($1.discountPercent ?? 0) }
        case .prezzo:
            return active.sorted { $0.price < $1.price }
        case .scadenza:
            return active.sorted { $0.endsAt < $1.endsAt }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredOffers.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredOffers) { offer in
                                NavigationLink {
                                    ProductDetailView(normalizedName: offer.productNormalizedName)
                                } label: {
                                    OfferRowView(offer: offer, userLocation: app.location.currentLocation)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Offerte in zona")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Label("Filtri", systemImage: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Ordina", selection: $sort) {
                        ForEach(OfferSort.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheetView(filter: $filter)
                    .presentationDetents([.medium, .large])
            }
            .refreshable {
                await app.refreshEverything()
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            ContentCard(
                icon: filter.isActive ? "line.3.horizontal.decrease.circle" : "tag.slash",
                tint: .gray,
                title: filter.isActive ? "Nessuna offerta con questi filtri" : "Nessuna offerta al momento",
                message: filter.isActive
                    ? "Prova ad allentare i filtri per vedere più risultati."
                    : "Continuiamo a controllare i volantini dei supermercati in zona: ti avviseremo appena uno dei tuoi prodotti sarà in promozione."
            )
            .padding()
            if filter.isActive {
                Button("Rimuovi filtri") {
                    filter.reset()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
