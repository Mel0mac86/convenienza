import Foundation
import CoreLocation
import Observation

/// Gestisce la geolocalizzazione (solo previo consenso dell'utente) e rileva
/// quando l'utente cambia zona o città, così l'app può aggiornare i supermercati.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var currentCity: String?

    /// Chiamato quando l'utente si sposta in modo significativo (nuova zona/città).
    var onSignificantMove: ((CLLocation) -> Void)?

    /// Spostamento minimo (in metri) che fa scattare un nuovo rilevamento dei supermercati.
    private let significantMoveThreshold: CLLocationDistance = 2000
    private var lastNotifiedLocation: CLLocation?

    static let lastLatitudeKey = "convenienza.lastLocation.lat"
    static let lastLongitudeKey = "convenienza.lastLocation.lon"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        authorizationStatus = manager.authorizationStatus
        restoreLastLocation()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
        // Con autorizzazione "Sempre" l'app viene svegliata anche in background
        // quando l'utente cambia città.
        if authorizationStatus == .authorizedAlways {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }

    /// Ultima posizione nota, disponibile anche al riavvio o nei task in background.
    static func storedLocation() -> CLLocation? {
        let defaults = UserDefaults.standard
        let lat = defaults.double(forKey: lastLatitudeKey)
        let lon = defaults.double(forKey: lastLongitudeKey)
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        persist(location)
        updateCityIfNeeded(for: location)

        // Notifica solo per spostamenti significativi (cambio zona/città).
        if let last = lastNotifiedLocation, location.distance(from: last) < significantMoveThreshold {
            return
        }
        lastNotifiedLocation = location
        onSignificantMove?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Errori transitori (es. kCLErrorLocationUnknown): la posizione precedente resta valida.
    }

    // MARK: - Private

    private func persist(_ location: CLLocation) {
        let defaults = UserDefaults.standard
        defaults.set(location.coordinate.latitude, forKey: Self.lastLatitudeKey)
        defaults.set(location.coordinate.longitude, forKey: Self.lastLongitudeKey)
    }

    private func restoreLastLocation() {
        currentLocation = Self.storedLocation()
    }

    private func updateCityIfNeeded(for location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }
            let city = placemark.locality ?? placemark.subAdministrativeArea
            if let city, city != self.currentCity {
                self.currentCity = city
            }
        }
    }
}
