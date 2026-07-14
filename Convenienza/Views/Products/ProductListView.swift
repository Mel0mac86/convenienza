import SwiftUI
import SwiftData

/// Lista personale dei prodotti monitorati, con possibilità di sospendere
/// o eliminare il monitoraggio.
struct ProductListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrackedProduct.createdAt, order: .reverse)
    private var products: [TrackedProduct]
    @Query private var allOffers: [OfferRecord]

    var body: some View {
        List {
            if products.isEmpty {
                ContentUnavailableView(
                    "Nessun prodotto monitorato",
                    systemImage: "cart",
                    description: Text("Cerca un prodotto per iniziare a monitorarne il prezzo.")
                )
            }
            ForEach(products) { product in
                NavigationLink {
                    ProductDetailView(normalizedName: product.normalizedName)
                } label: {
                    row(for: product)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(product)
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                    Button {
                        product.isActive.toggle()
                        try? context.save()
                    } label: {
                        Label(product.isActive ? "Sospendi" : "Riattiva",
                              systemImage: product.isActive ? "pause" : "play")
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("I miei prodotti")
    }

    private func row(for product: TrackedProduct) -> some View {
        let offerCount = allOffers.filter {
            $0.productNormalizedName == product.normalizedName && $0.isActive
        }.count

        return HStack(spacing: 12) {
            Image(systemName: product.category.icon)
                .foregroundStyle(product.isActive ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(product.isActive ? .primary : .secondary)
                Text(product.isActive
                     ? (offerCount > 0 ? "\(offerCount) offerte attive in zona" : "Monitoraggio attivo")
                     : "Monitoraggio sospeso")
                    .font(.caption)
                    .foregroundStyle(offerCount > 0 && product.isActive ? .green : .secondary)
            }
            Spacer()
            if offerCount > 0 && product.isActive {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private func delete(_ product: TrackedProduct) {
        context.delete(product)
        try? context.save()
    }
}
