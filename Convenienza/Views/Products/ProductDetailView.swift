import SwiftUI
import SwiftData
import Charts

/// Dettaglio di un prodotto monitorato: confronto prezzi tra i supermercati
/// della zona e storico dei prezzi nel tempo.
struct ProductDetailView: View {
    let normalizedName: String

    @Environment(AppState.self) private var app
    @Query private var products: [TrackedProduct]
    @Query private var offers: [OfferRecord]
    @Query(sort: \PricePoint.recordedAt) private var pricePoints: [PricePoint]

    init(normalizedName: String) {
        self.normalizedName = normalizedName
        _products = Query(filter: #Predicate<TrackedProduct> { $0.normalizedName == normalizedName })
        _offers = Query(
            filter: #Predicate<OfferRecord> { $0.productNormalizedName == normalizedName },
            sort: \OfferRecord.price
        )
        _pricePoints = Query(
            filter: #Predicate<PricePoint> { $0.productNormalizedName == normalizedName },
            sort: \.recordedAt
        )
    }

    private var product: TrackedProduct? { products.first }
    private var activeOffers: [OfferRecord] { offers.filter(\.isActive) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let best = activeOffers.first {
                    bestOfferCard(best)
                }

                comparisonSection
                historySection
            }
            .padding()
        }
        .navigationTitle(product?.displayName ?? normalizedName.capitalized)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await app.refreshEverything()
        }
    }

    // MARK: - Miglior offerta

    private func bestOfferCard(_ offer: OfferRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Miglior prezzo in zona", systemImage: "crown.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Formatters.price(offer.price))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if let previous = offer.previousPrice {
                    Text(Formatters.price(previous))
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
                if let discount = offer.discountPercent {
                    Text("-\(discount)%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "storefront")
                Text(offer.supermarketName)
                if let distance = offer.distance(from: app.location.currentLocation) {
                    Text("· \(Formatters.distance(distance))")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(Formatters.expiry(offer.endsAt))
                .font(.caption)
                .foregroundStyle(offer.isExpiringSoon ? .orange : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Confronto tra supermercati

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Confronto in zona", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)

            if activeOffers.isEmpty {
                Text("Nessuna offerta attiva per questo prodotto nei supermercati entro \(Int(app.settings.radiusKm)) km. Continuiamo a monitorarlo per te.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activeOffers) { offer in
                    OfferRowView(offer: offer, userLocation: app.location.currentLocation)
                }
            }
        }
    }

    // MARK: - Storico prezzi

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Storico prezzi", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)

            if pricePoints.count < 2 {
                Text("Lo storico si costruisce nel tempo: qui vedrai l'andamento dei prezzi rilevati settimana dopo settimana.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(pricePoints) { point in
                    LineMark(
                        x: .value("Data", point.recordedAt),
                        y: .value("Prezzo", point.price)
                    )
                    .foregroundStyle(by: .value("Catena", point.chainRaw))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Data", point.recordedAt),
                        y: .value("Prezzo", point.price)
                    )
                    .foregroundStyle(by: .value("Catena", point.chainRaw))
                    .symbolSize(point.isPromo ? 60 : 25)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let price = value.as(Double.self) {
                                Text(Formatters.price(price))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 220)

                Text("I punti più grandi indicano prezzi in promozione.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
