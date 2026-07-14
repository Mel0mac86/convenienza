import Foundation
import CoreLocation

/// Un supermercato fisico rilevato nella zona dell'utente tramite MapKit.
/// Solo punti vendita fisici: nessun e-commerce o marketplace.
struct Supermarket: Identifiable, Hashable {
    let id: String
    let name: String
    let chain: SupermarketChain
    let address: String
    let latitude: Double
    let longitude: Double
    /// Distanza in metri dalla posizione corrente dell'utente.
    var distance: CLLocationDistance

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var formattedDistance: String {
        Formatters.distance(distance)
    }
}

/// Catene note della GDO italiana. Le offerte sono pubblicate a livello di catena,
/// quindi i punti vendita della stessa insegna condividono lo stesso volantino.
enum SupermarketChain: String, CaseIterable, Codable, Identifiable {
    case coop = "Coop"
    case conad = "Conad"
    case esselunga = "Esselunga"
    case lidl = "Lidl"
    case eurospin = "Eurospin"
    case carrefour = "Carrefour"
    case md = "MD"
    case penny = "Penny Market"
    case pam = "Pam"
    case famila = "Famila"
    case despar = "Despar"
    case crai = "Crai"
    case sigma = "Sigma"
    case tigre = "Tigre"
    case altra = "Altro supermercato"

    var id: String { rawValue }

    /// Riconosce la catena dal nome del punto vendita restituito da MapKit.
    static func detect(from name: String) -> SupermarketChain {
        let n = name.lowercased()
        let patterns: [(SupermarketChain, [String])] = [
            (.esselunga, ["esselunga"]),
            (.eurospin, ["eurospin"]),
            (.carrefour, ["carrefour"]),
            (.conad, ["conad", "spazio conad", "todis"]),
            (.coop, ["coop", "ipercoop", "incoop"]),
            (.lidl, ["lidl"]),
            (.penny, ["penny"]),
            (.pam, ["pam ", "pam,", "panorama"]),
            (.famila, ["famila"]),
            (.despar, ["despar", "eurospar", "interspar"]),
            (.crai, ["crai"]),
            (.sigma, ["sigma"]),
            (.tigre, ["tigre", "oasi"]),
            (.md, ["md ", "md,", "md discount"]),
        ]
        for (chain, keywords) in patterns where keywords.contains(where: { n.contains($0) }) {
            return chain
        }
        if n == "md" { return .md }
        if n == "pam" { return .pam }
        return .altra
    }

    var brandColorName: String {
        switch self {
        case .coop: return "red"
        case .conad: return "orange"
        case .esselunga: return "blue"
        case .lidl: return "yellow"
        case .eurospin: return "cyan"
        case .carrefour: return "indigo"
        case .md: return "green"
        case .penny: return "red"
        default: return "gray"
        }
    }
}
