import SwiftUI
import SwiftData

/// Ricerca prodotti: l'utente scrive il nome di un prodotto e questo viene salvato
/// automaticamente nella lista personale, dove resta monitorato nel tempo.
struct SearchView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TrackedProduct> { $0.isActive }, sort: \TrackedProduct.createdAt, order: .reverse)
    private var products: [TrackedProduct]

    @State private var query = ""
    @State private var justAdded: String?
    @FocusState private var searchFocused: Bool

    private static let suggestions = [
        "Pasta", "Latte", "Olio extravergine", "Caffè", "Tonno",
        "Pollo", "Yogurt", "Detersivo piatti", "Acqua naturale", "Biscotti",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchBar
                addButton

                if let justAdded {
                    Label("\"\(justAdded)\" aggiunto alla tua lista. Ti avviseremo quando sarà in offerta!",
                          systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if products.isEmpty {
                    suggestionsSection
                } else {
                    recentSection
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Cerca prodotti")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Es. passata di pomodoro", text: $query)
                .focused($searchFocused)
                .submitLabel(.done)
                .onSubmit(addProduct)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var addButton: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            Button {
                addProduct()
            } label: {
                Label("Monitora questo prodotto", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prova a monitorare")
                .font(.headline)
            FlowChips(items: Self.suggestions) { suggestion in
                query = suggestion
                addProduct()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ricerche monitorate")
                .font(.headline)
            ForEach(products.prefix(8)) { product in
                HStack {
                    Image(systemName: product.category.icon)
                        .foregroundStyle(.green)
                    Text(product.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text(product.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            NavigationLink("Gestisci la lista completa") {
                ProductListView()
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addProduct() {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let normalized = TrackedProduct.normalize(name)
        let existing = try? context.fetch(FetchDescriptor<TrackedProduct>(
            predicate: #Predicate { $0.normalizedName == normalized }
        )).first

        if let existing {
            existing.isActive = true
        } else {
            context.insert(TrackedProduct(name: name))
        }
        try? context.save()

        withAnimation { justAdded = name }
        query = ""
        searchFocused = false

        // Controlla subito se il nuovo prodotto è già in offerta in zona.
        Task {
            await app.refreshEverything()
        }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { justAdded = nil }
        }
    }
}

/// Chips disposte su più righe per i suggerimenti di ricerca.
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    Text(item)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
