import Foundation
import CoreLocation
import SwiftData

/// Un'offerta trovata per un prodotto monitorato presso un supermercato fisico vicino.
/// Persistita per costruire lo storico prezzi e per capire quali offerte sono già state notificate.
@Model
final class OfferRecord {
    /// Identificatore stabile dell'offerta (prodotto + catena + settimana promozionale),
    /// usato per non notificare due volte la stessa promozione.
    @Attribute(.unique) var offerKey: String

    var productNormalizedName: String
    var productLabel: String
    var categoryRaw: String

    var chainRaw: String
    var supermarketName: String
    var supermarketAddress: String
    var latitude: Double
    var longitude: Double

    var price: Double
    var previousPrice: Double?
    var startsAt: Date
    var endsAt: Date

    var foundAt: Date
    var notifiedAt: Date?

    init(
        offerKey: String,
        productNormalizedName: String,
        productLabel: String,
        category: ProductCategory,
        chain: SupermarketChain,
        supermarketName: String,
        supermarketAddress: String,
        latitude: Double,
        longitude: Double,
        price: Double,
        previousPrice: Double?,
        startsAt: Date,
        endsAt: Date
    ) {
        self.offerKey = offerKey
        self.productNormalizedName = productNormalizedName
        self.productLabel = productLabel
        self.categoryRaw = category.rawValue
        self.chainRaw = chain.rawValue
        self.supermarketName = supermarketName
        self.supermarketAddress = supermarketAddress
        self.latitude = latitude
        self.longitude = longitude
        self.price = price
        self.previousPrice = previousPrice
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.foundAt = .now
        self.notifiedAt = nil
    }

    var category: ProductCategory { ProductCategory(rawValue: categoryRaw) ?? .altro }
    var chain: SupermarketChain { SupermarketChain(rawValue: chainRaw) ?? .altra }

    var isActive: Bool { endsAt >= .now && startsAt <= .now }

    /// Offerta in scadenza entro 48 ore.
    var isExpiringSoon: Bool {
        isActive && endsAt.timeIntervalSinceNow < 48 * 3600
    }

    var discountPercent: Int? {
        guard let previous = previousPrice, previous > price, previous > 0 else { return nil }
        return Int(((previous - price) / previous * 100).rounded())
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude).distance(from: location)
    }
}
