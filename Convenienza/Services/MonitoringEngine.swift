import Foundation
import CoreLocation
import SwiftData

/// Il cuore dell'app: controlla periodicamente le offerte dei supermercati della zona
/// per i prodotti monitorati, aggiorna lo storico prezzi e invia una notifica quando
/// trova una nuova promozione. Viene eseguito in foreground (all'apertura, al cambio
/// posizione, al pull-to-refresh) e in background tramite BGTaskScheduler.
final class MonitoringEngine {
    /// Provider fisso per i test; se nil, viene risolto a ogni ciclo in base
    /// alla configurazione corrente (chiave Groq presente, modalità demo, ...).
    private let fixedProvider: OfferProvider?

    init(provider: OfferProvider? = nil) {
        self.fixedProvider = provider
    }

    /// Esegue un ciclo completo di controllo. Ritorna il numero di nuove offerte trovate.
    @discardableResult
    @MainActor
    func runCheck(
        container: ModelContainer,
        location: CLLocation,
        radiusKm: Double,
        supermarkets: [Supermarket]? = nil,
        city: String? = nil,
        sendNotifications: Bool = true
    ) async -> Int {
        // Senza una sorgente dati configurata non ci sono offerte da controllare
        // (mai dati inventati).
        guard let provider = fixedProvider ?? OfferProviderFactory.makeProvider() else { return 0 }

        let context = ModelContext(container)

        // 1. Prodotti monitorati attivi.
        guard let products = try? context.fetch(
            FetchDescriptor<TrackedProduct>(predicate: #Predicate { $0.isActive })
        ), !products.isEmpty else { return 0 }

        // 2. Supermercati fisici in zona (riusa quelli già trovati, se disponibili).
        let nearby: [Supermarket]
        if let supermarkets, !supermarkets.isEmpty {
            nearby = supermarkets
        } else {
            nearby = (try? await SupermarketService.search(around: location, radiusKm: radiusKm)) ?? []
        }
        guard !nearby.isEmpty else { return 0 }

        // 3. Offerte attive per (prodotto × catena) dalle catene presenti in zona.
        let chains = Array(Set(nearby.map(\.chain)))
        guard let dtos = try? await provider.fetchOffers(
            products: products.map(\.displayName),
            chains: chains,
            city: city
        ) else { return 0 }

        // 4. Aggiorna il database e individua le offerte mai viste prima.
        var newOffers: [OfferRecord] = []
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)

        for dto in dtos {
            let normalized = TrackedProduct.normalize(dto.productQuery)
            guard let product = products.first(where: { $0.normalizedName == normalized }) else { continue }

            // Punto vendita più vicino della catena.
            guard let branch = nearby
                .filter({ $0.chain == dto.chain })
                .min(by: { $0.distance < $1.distance }) else { continue }

            let offerKey = "\(normalized)|\(dto.chain.rawValue)|\(year)-W\(week)"

            let existing = try? context.fetch(FetchDescriptor<OfferRecord>(
                predicate: #Predicate { $0.offerKey == offerKey }
            )).first

            if let existing {
                // Aggiorna il punto vendita più vicino se l'utente si è spostato.
                existing.supermarketName = branch.name
                existing.supermarketAddress = branch.address
                existing.latitude = branch.latitude
                existing.longitude = branch.longitude
            } else {
                let record = OfferRecord(
                    offerKey: offerKey,
                    productNormalizedName: normalized,
                    productLabel: dto.productLabel,
                    category: product.category,
                    chain: dto.chain,
                    supermarketName: branch.name,
                    supermarketAddress: branch.address,
                    latitude: branch.latitude,
                    longitude: branch.longitude,
                    price: dto.price,
                    previousPrice: dto.previousPrice,
                    startsAt: dto.startsAt,
                    endsAt: dto.endsAt
                )
                context.insert(record)
                newOffers.append(record)

                // Storico prezzi: registra sia il prezzo pieno sia quello promozionale.
                if let previous = dto.previousPrice {
                    context.insert(PricePoint(
                        productNormalizedName: normalized,
                        chain: dto.chain,
                        price: previous,
                        isPromo: false,
                        recordedAt: dto.startsAt
                    ))
                }
                context.insert(PricePoint(
                    productNormalizedName: normalized,
                    chain: dto.chain,
                    price: dto.price,
                    isPromo: true
                ))
            }
        }

        // 5. Elimina le offerte scadute da oltre 30 giorni (lo storico prezzi resta).
        let cutoff = Date.now.addingTimeInterval(-30 * 24 * 3600)
        if let stale = try? context.fetch(FetchDescriptor<OfferRecord>(
            predicate: #Predicate { $0.endsAt < cutoff }
        )) {
            stale.forEach { context.delete($0) }
        }

        // 6. Notifica le nuove offerte (una sola volta per offerta).
        if sendNotifications {
            for offer in newOffers where offer.notifiedAt == nil {
                await NotificationService.notify(offer: offer, userLocation: location)
                offer.notifiedAt = .now
            }
        }

        try? context.save()
        return newOffers.count
    }
}
