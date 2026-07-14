import SwiftUI

/// Filtri offerte: distanza, supermercato, categoria, sconto minimo, prezzo massimo.
struct FilterSheetView: View {
    @Binding var filter: OfferFilter
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Catene effettivamente presenti in zona (più eventuali già selezionate).
    private var availableChains: [SupermarketChain] {
        let inArea = Set(app.supermarketService.supermarkets.map(\.chain))
        return SupermarketChain.allCases.filter { inArea.contains($0) || filter.chains.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Distanza massima") {
                    Picker("Distanza", selection: $filter.maxDistanceKm) {
                        Text("Tutta la zona").tag(Double?.none)
                        ForEach([1.0, 2, 5, 10, 20, 30], id: \.self) { km in
                            Text("Entro \(Int(km)) km").tag(Double?.some(km))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Supermercati") {
                    if availableChains.isEmpty {
                        Text("Nessun supermercato rilevato in zona.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableChains) { chain in
                            Toggle(chain.rawValue, isOn: binding(for: chain))
                        }
                    }
                }

                Section("Categorie") {
                    ForEach(ProductCategory.allCases) { category in
                        Toggle(isOn: binding(for: category)) {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }

                Section("Sconto minimo: \(filter.minDiscount)%") {
                    Slider(
                        value: Binding(
                            get: { Double(filter.minDiscount) },
                            set: { filter.minDiscount = Int($0) }
                        ),
                        in: 0...70,
                        step: 5
                    )
                }

                Section("Prezzo massimo") {
                    Picker("Prezzo massimo", selection: $filter.maxPrice) {
                        Text("Nessun limite").tag(Double?.none)
                        ForEach([1.0, 2, 3, 5, 10, 20], id: \.self) { price in
                            Text(Formatters.price(price)).tag(Double?.some(price))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Filtri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Azzera") { filter.reset() }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func binding(for chain: SupermarketChain) -> Binding<Bool> {
        Binding(
            get: { filter.chains.contains(chain) },
            set: { isOn in
                if isOn { filter.chains.insert(chain) } else { filter.chains.remove(chain) }
            }
        )
    }

    private func binding(for category: ProductCategory) -> Binding<Bool> {
        Binding(
            get: { filter.categories.contains(category) },
            set: { isOn in
                if isOn { filter.categories.insert(category) } else { filter.categories.remove(category) }
            }
        )
    }
}
