import SwiftUI
import SwiftData

/// Schermata principale: prodotti monitorati, offerte attive, offerte in scadenza,
/// supermercati vicini. Si aggiorna automaticamente e supporta il pull-to-refresh.
struct DashboardView: View {
    @Environment(AppState.self) private var app
    @Query(filter: #Predicate<TrackedProduct> { $0.isActive }, sort: \TrackedProduct.createdAt, order: .reverse)
    private var products: [TrackedProduct]
    @Query(sort: \OfferRecord.price) private var allOffers: [OfferRecord]

    private var activeOffers: [OfferRecord] {
        allOffers.filter(\.isActive)
    }

    private var expiringOffers: [OfferRecord] {
        activeOffers.filter(\.isExpiringSoon).sorted { $0.endsAt < $1.endsAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: []) {
                    locationBanner

                    if !app.realDataConfigured {
                        ContentCard(icon: "key.fill", tint: .orange,
                                    title: "Configura i prezzi reali",
                                    message: "Aggiungi la tua chiave API Groq nella scheda Profilo: le offerte verranno cercate nei volantini reali dei supermercati della tua zona.")
                    }

                    if products.isEmpty {
                        emptyState
                    } else {
                        summaryRow
                        if !expiringOffers.isEmpty {
                            expiringSection
                        }
                        if !activeOffers.isEmpty {
                            offersSection
                        }
                        productsSection
                    }

                    supermarketsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationDestination(for: String.self) { normalizedName in
                ProductDetailView(normalizedName: normalizedName)
            }
            .navigationTitle("Convenienza")
            .refreshable {
                await app.refreshEverything()
            }
            .overlay(alignment: .bottom) {
                if app.isChecking {
                    Label("Controllo offerte in corso…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Sezioni

    private var locationBanner: some View {
        Group {
            if app.location.isDenied {
                ContentCard(icon: "location.slash", tint: .orange,
                            title: "Posizione disattivata",
                            message: "Attiva la posizione nelle Impostazioni di iOS per vedere le offerte dei supermercati vicino a te.")
            } else if let city = app.location.currentCity {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text("\(city) · raggio \(Int(app.settings.radiusKm)) km")
                        .font(.subheadline)
                    Spacer()
                    if let last = app.lastCheckAt {
                        Text("Agg. \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            SummaryTile(value: products.count, label: "Monitorati", icon: "eye", tint: .blue)
            SummaryTile(value: activeOffers.count, label: "Offerte attive", icon: "tag", tint: .green)
            SummaryTile(value: expiringOffers.count, label: "In scadenza", icon: "clock", tint: .orange)
        }
    }

    private var expiringSection: some View {
        DashboardSection(title: "In scadenza", icon: "clock.badge.exclamationmark") {
            ForEach(expiringOffers.prefix(3)) { offer in
                NavigationLink(value: offer.productNormalizedName) {
                    OfferRowView(offer: offer, userLocation: app.location.currentLocation, highlightExpiry: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var offersSection: some View {
        DashboardSection(title: "Migliori offerte attive", icon: "tag.fill") {
            ForEach(activeOffers.prefix(4)) { offer in
                NavigationLink(value: offer.productNormalizedName) {
                    OfferRowView(offer: offer, userLocation: app.location.currentLocation)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var productsSection: some View {
        DashboardSection(title: "Prodotti monitorati", icon: "eye.fill") {
            NavigationLink("Vedi tutti (\(products.count))") {
                ProductListView()
            }
            .font(.subheadline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(products.prefix(10)) { product in
                        NavigationLink(value: product.normalizedName) {
                            ProductChip(
                                product: product,
                                offerCount: activeOffers.filter { $0.productNormalizedName == product.normalizedName }.count
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var supermarketsSection: some View {
        DashboardSection(title: "Supermercati vicini", icon: "storefront") {
            if app.supermarketService.supermarkets.isEmpty {
                Text(app.location.isAuthorized
                     ? "Nessun supermercato trovato entro \(Int(app.settings.radiusKm)) km."
                     : "Consenti l'accesso alla posizione per rilevare i supermercati in zona.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(app.supermarketService.supermarkets.prefix(5)) { market in
                    SupermarketRowView(supermarket: market)
                }
                NavigationLink("Tutti i supermercati (\(app.supermarketService.supermarkets.count))") {
                    SupermarketListView()
                }
                .font(.subheadline)
            }
        }
    }

    private var emptyState: some View {
        ContentCard(icon: "cart.badge.plus", tint: .green,
                    title: "Inizia a monitorare",
                    message: "Cerca un prodotto nella scheda Cerca: lo salveremo nella tua lista e ti avviseremo quando sarà in offerta in un supermercato vicino a te.")
            .padding(.top, 24)
    }
}

// MARK: - Componenti della dashboard

private struct SummaryTile: View {
    let value: Int
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProductChip: View {
    let product: TrackedProduct
    let offerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: product.category.icon)
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(product.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            Text(offerCount > 0 ? "\(offerCount) offerte" : "Nessuna offerta")
                .font(.caption2)
                .foregroundStyle(offerCount > 0 ? .green : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContentCard: View {
    let icon: String
    let tint: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
