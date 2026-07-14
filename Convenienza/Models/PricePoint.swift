import Foundation
import SwiftData

/// Un punto dello storico prezzi: il prezzo di un prodotto presso una catena in una certa data.
@Model
final class PricePoint {
    var productNormalizedName: String
    var chainRaw: String
    var price: Double
    var isPromo: Bool
    var recordedAt: Date

    init(productNormalizedName: String, chain: SupermarketChain, price: Double, isPromo: Bool, recordedAt: Date = .now) {
        self.productNormalizedName = productNormalizedName
        self.chainRaw = chain.rawValue
        self.price = price
        self.isPromo = isPromo
        self.recordedAt = recordedAt
    }

    var chain: SupermarketChain { SupermarketChain(rawValue: chainRaw) ?? .altra }
}
