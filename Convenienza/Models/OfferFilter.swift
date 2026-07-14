import Foundation
import CoreLocation

/// Filtri applicabili all'elenco delle offerte.
struct OfferFilter: Equatable {
    /// Distanza massima in km (nil = usa il raggio globale).
    var maxDistanceKm: Double?
    var chains: Set<SupermarketChain> = []
    var categories: Set<ProductCategory> = []
    /// Sconto minimo in percentuale.
    var minDiscount: Int = 0
    var maxPrice: Double?

    var isActive: Bool {
        maxDistanceKm != nil || !chains.isEmpty || !categories.isEmpty || minDiscount > 0 || maxPrice != nil
    }

    var activeCount: Int {
        var count = 0
        if maxDistanceKm != nil { count += 1 }
        if !chains.isEmpty { count += 1 }
        if !categories.isEmpty { count += 1 }
        if minDiscount > 0 { count += 1 }
        if maxPrice != nil { count += 1 }
        return count
    }

    func matches(_ offer: OfferRecord, userLocation: CLLocation?) -> Bool {
        if let maxKm = maxDistanceKm {
            guard let distance = offer.distance(from: userLocation), distance <= maxKm * 1000 else { return false }
        }
        if !chains.isEmpty && !chains.contains(offer.chain) { return false }
        if !categories.isEmpty && !categories.contains(offer.category) { return false }
        if minDiscount > 0 && (offer.discountPercent ?? 0) < minDiscount { return false }
        if let maxPrice, offer.price > maxPrice { return false }
        return true
    }

    mutating func reset() {
        self = OfferFilter()
    }
}

/// Ordinamento delle offerte.
enum OfferSort: String, CaseIterable, Identifiable {
    case distanza = "Distanza"
    case sconto = "Sconto"
    case prezzo = "Prezzo"
    case scadenza = "Scadenza"

    var id: String { rawValue }
}
