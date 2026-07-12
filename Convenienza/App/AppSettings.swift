import Foundation
import Observation

/// Impostazioni utente persistite in UserDefaults.
@Observable
final class AppSettings {
    static let radiusKey = "convenienza.radiusKm"

    /// Raggio di ricerca dei supermercati, configurabile: 5, 10, 20 o 30 km.
    static let radiusOptions: [Double] = [5, 10, 20, 30]

    var radiusKm: Double {
        didSet { UserDefaults.standard.set(radiusKm, forKey: Self.radiusKey) }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: Self.radiusKey)
        radiusKm = stored > 0 ? stored : 10
    }

    /// Lettura statica per i task in background.
    static func storedRadiusKm() -> Double {
        let stored = UserDefaults.standard.double(forKey: radiusKey)
        return stored > 0 ? stored : 10
    }
}
