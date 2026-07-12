import SwiftUI

/// Riga riutilizzabile per un supermercato vicino.
struct SupermarketRowView: View {
    let supermarket: Supermarket

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(supermarket.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if supermarket.chain != .altra {
                    Text(supermarket.chain.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(supermarket.formattedDistance)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
