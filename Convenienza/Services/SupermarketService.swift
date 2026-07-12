import Foundation
import MapKit
import Observation

/// Rileva automaticamente i supermercati FISICI attorno alla posizione dell'utente
/// usando MapKit. Per requisito, nessun e-commerce, marketplace o negozio online:
/// vengono considerati solo punti di interesse di tipo alimentare sul territorio.
@Observable
final class SupermarketService {
    private(set) var supermarkets: [Supermarket] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastRefreshedAt: Date?

    /// Cerca i supermercati entro il raggio indicato (in km) dalla posizione data.
    @MainActor
    func refresh(around location: CLLocation, radiusKm: Double) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let found = try await Self.search(around: location, radiusKm: radiusKm)
            supermarkets = found.sorted { $0.distance < $1.distance }
            lastRefreshedAt = .now
        } catch {
            lastError = "Impossibile trovare i supermercati in zona. Riprova."
        }
    }

    /// Ricerca statica riutilizzabile anche dai task in background.
    static func search(around location: CLLocation, radiusKm: Double) async throws -> [Supermarket] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "supermercato"
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.foodMarket])
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radiusKm * 2000,
            longitudinalMeters: radiusKm * 2000
        )

        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems.compactMap { item -> Supermarket? in
            guard let name = item.name else { return nil }
            let itemLocation = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            let distance = itemLocation.distance(from: location)
            // MapKit restituisce risultati anche oltre la regione richiesta: filtra sul raggio reale.
            guard distance <= radiusKm * 1000 else { return nil }

            return Supermarket(
                id: "\(name)-\(item.placemark.coordinate.latitude)-\(item.placemark.coordinate.longitude)",
                name: name,
                chain: SupermarketChain.detect(from: name),
                address: item.placemark.title ?? "",
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude,
                distance: distance
            )
        }
    }
}
