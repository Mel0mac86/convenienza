import SwiftUI
import CoreLocation

/// Riga riutilizzabile per un'offerta: prodotto, prezzo scontato, prezzo precedente,
/// supermercato, distanza e scadenza.
struct OfferRowView: View {
    let offer: OfferRecord
    let userLocation: CLLocation?
    var highlightExpiry = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: offer.category.icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(offer.productLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(Formatters.price(offer.price))
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                    if let previous = offer.previousPrice {
                        Text(Formatters.price(previous))
                            .font(.caption)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                    if let discount = offer.discountPercent {
                        Text("-\(discount)%")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(offer.supermarketName)
                    if let distance = offer.distance(from: userLocation) {
                        Text("· \(Formatters.distance(distance))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Text(Formatters.expiry(offer.endsAt))
                    .font(.caption2)
                    .foregroundStyle(highlightExpiry || offer.isExpiringSoon ? .orange : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
