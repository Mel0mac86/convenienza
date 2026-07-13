import Foundation

/// Offerta "grezza" restituita da un provider di volantini/promozioni.
struct OfferDTO {
    let productQuery: String
    let productLabel: String
    let chain: SupermarketChain
    let price: Double
    let previousPrice: Double?
    let startsAt: Date
    let endsAt: Date
}

/// Sorgente dei prezzi e delle promozioni dei supermercati fisici.
///
/// L'implementazione di produzione è `GroqOfferProvider`, che usa i modelli Groq
/// "compound" (con ricerca web integrata) per trovare le offerte reali pubblicate
/// nei volantini della GDO italiana. `SimulatedOfferProvider` resta disponibile
/// solo come modalità demo esplicita (nessun dato reale configurato).
protocol OfferProvider {
    /// Restituisce le offerte attive per i prodotti indicati presso le catene indicate.
    /// `city` aiuta a localizzare la ricerca (i volantini possono variare per zona).
    func fetchOffers(products: [String], chains: [SupermarketChain], city: String?) async throws -> [OfferDTO]
}

/// Sceglie la sorgente dati corrente in base alla configurazione dell'utente.
enum OfferProviderFactory {
    static let demoModeKey = "convenienza.demoMode"

    /// Provider attivo: Groq se la chiave API è configurata, altrimenti la modalità
    /// demo se esplicitamente attivata, altrimenti nessuno (nessuna offerta finta).
    static func makeProvider() -> OfferProvider? {
        if let key = KeychainStore.get(GroqOfferProvider.apiKeyKeychainKey),
           !key.trimmingCharacters(in: .whitespaces).isEmpty {
            return GroqOfferProvider(apiKey: key)
        }
        if UserDefaults.standard.bool(forKey: demoModeKey) {
            return SimulatedOfferProvider()
        }
        return nil
    }

    static var isRealDataConfigured: Bool {
        guard let key = KeychainStore.get(GroqOfferProvider.apiKeyKeychainKey) else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Provider simulato e deterministico, SOLO per la modalità demo: per una data coppia
/// (prodotto, catena) e una data settimana promozionale, l'offerta è sempre la stessa.
struct SimulatedOfferProvider: OfferProvider {
    func fetchOffers(products: [String], chains: [SupermarketChain], city: String?) async throws -> [OfferDTO] {
        // Simula la latenza di rete di una vera API.
        try? await Task.sleep(nanoseconds: 300_000_000)

        var offers: [OfferDTO] = []
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)

        for product in products {
            let normalized = TrackedProduct.normalize(product)
            for chain in Set(chains) where chain != .altra {
                var rng = SeededGenerator(seed: Self.seed(product: normalized, chain: chain, week: week, year: year))

                // Non tutti i prodotti sono in promozione ovunque: ~1 catena su 3.
                guard rng.next(upperBound: 100) < 35 else { continue }

                let basePrice = Self.basePrice(for: normalized)
                let discount = Double(rng.next(upperBound: 41) + 10) / 100.0 // 10%...50%
                let price = max(0.29, (basePrice * (1 - discount) * 100).rounded() / 100)

                // La promozione copre la settimana del volantino corrente.
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
                let duration = Int(rng.next(upperBound: 4)) + 5 // 5...8 giorni
                let endsAt = calendar.date(byAdding: .day, value: duration, to: startOfWeek) ?? .now

                guard endsAt > .now else { continue }

                offers.append(OfferDTO(
                    productQuery: product,
                    productLabel: product.capitalized(with: Locale(identifier: "it_IT")),
                    chain: chain,
                    price: price,
                    previousPrice: (basePrice * 100).rounded() / 100,
                    startsAt: startOfWeek,
                    endsAt: endsAt
                ))
            }
        }
        return offers
    }

    /// Prezzo di listino plausibile e stabile per prodotto (0,80 € – 12,50 €).
    private static func basePrice(for normalizedName: String) -> Double {
        var rng = SeededGenerator(seed: StableHash.fnv1a(normalizedName + "::base"))
        return 0.80 + Double(rng.next(upperBound: 1171)) / 100.0
    }

    private static func seed(product: String, chain: SupermarketChain, week: Int, year: Int) -> UInt64 {
        StableHash.fnv1a("\(product)|\(chain.rawValue)|\(year)-W\(week)")
    }
}

/// Hash stabile tra esecuzioni (a differenza di `String.hashValue`, che usa un seed
/// casuale per processo). Usato per chiavi di cache e seed deterministici.
enum StableHash {
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

/// Generatore pseudo-casuale deterministico (SplitMix64).
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(upperBound: UInt64) -> UInt64 {
        nextUInt64() % upperBound
    }
}
