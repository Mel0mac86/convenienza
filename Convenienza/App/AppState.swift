import Foundation
import CoreLocation
import SwiftData
import Observation

/// Stato globale dell'app: collega i servizi tra loro e orchestra gli aggiornamenti
/// automatici (avvio, cambio posizione, ritorno in foreground).
@Observable
@MainActor
final class AppState {
    let auth = AuthService()
    let settings = AppSettings()
    let location = LocationService()
    let supermarketService = SupermarketService()
    let notifications = NotificationService()
    let engine = MonitoringEngine()

    let container: ModelContainer

    private(set) var isChecking = false
    private(set) var lastCheckAt: Date?

    /// True se è configurata una sorgente di prezzi reali (chiave API Groq).
    private(set) var realDataConfigured = OfferProviderFactory.isRealDataConfigured

    init(container: ModelContainer) {
        self.container = container

        // Quando l'utente cambia zona o città, aggiorna automaticamente
        // supermercati e offerte.
        location.onSignificantMove = { [weak self] newLocation in
            Task { @MainActor [weak self] in
                await self?.refreshEverything(at: newLocation)
            }
        }
    }

    /// Avvio dei servizi dopo il login / all'apertura dell'app.
    func startServices() {
        Task { await notifications.refreshAuthorizationStatus() }
        if location.isAuthorized {
            location.start()
            if let loc = location.currentLocation {
                Task { await refreshEverything(at: loc) }
            }
        }
    }

    /// Ciclo completo: supermercati in zona + controllo offerte + notifiche.
    func refreshEverything(at location: CLLocation? = nil) async {
        guard let loc = location ?? self.location.currentLocation else { return }
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        await supermarketService.refresh(around: loc, radiusKm: settings.radiusKm)
        await engine.runCheck(
            container: container,
            location: loc,
            radiusKm: settings.radiusKm,
            supermarkets: supermarketService.supermarkets,
            city: self.location.currentCity
        )
        lastCheckAt = .now
    }

    /// Cambio del raggio di ricerca dalle impostazioni.
    func updateRadius(_ radiusKm: Double) {
        settings.radiusKm = radiusKm
        Task { await refreshEverything() }
    }

    /// Salva (o rimuove, se vuota) la chiave API Groq nel Keychain e riavvia il
    /// controllo delle offerte con la nuova sorgente dati.
    func updateGroqKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.delete(GroqOfferProvider.apiKeyKeychainKey)
        } else {
            KeychainStore.set(trimmed, forKey: GroqOfferProvider.apiKeyKeychainKey)
        }
        realDataConfigured = OfferProviderFactory.isRealDataConfigured
        Task { await refreshEverything() }
    }

    var storedGroqKey: String {
        KeychainStore.get(GroqOfferProvider.apiKeyKeychainKey) ?? ""
    }
}
