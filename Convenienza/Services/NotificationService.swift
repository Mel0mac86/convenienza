import Foundation
import UserNotifications
import CoreLocation
import Observation

/// Invia notifiche locali quando un prodotto monitorato entra in promozione
/// in un supermercato vicino. Le notifiche sono pensate per essere poco invasive:
/// una sola notifica per offerta, mai duplicata.
@Observable
final class NotificationService {
    private(set) var isAuthorized = false

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        isAuthorized = granted
        return granted
    }

    /// Contenuto della notifica come da specifica: nome prodotto, prezzo in offerta,
    /// prezzo precedente, supermercato, distanza e scadenza della promozione.
    static func notify(offer: OfferRecord, userLocation: CLLocation?) async {
        let content = UNMutableNotificationContent()
        content.title = "\(offer.productLabel) è in offerta!"

        var parts: [String] = []
        var priceLine = Formatters.price(offer.price)
        if let previous = offer.previousPrice {
            priceLine += " invece di \(Formatters.price(previous))"
            if let discount = offer.discountPercent {
                priceLine += " (-\(discount)%)"
            }
        }
        parts.append(priceLine)

        var whereLine = "Da \(offer.supermarketName)"
        if let distance = offer.distance(from: userLocation) {
            whereLine += " · a \(Formatters.distance(distance))"
        }
        parts.append(whereLine)
        parts.append(Formatters.expiry(offer.endsAt))

        content.body = parts.joined(separator: "\n")
        content.sound = .default
        content.threadIdentifier = "offers"
        content.userInfo = ["offerKey": offer.offerKey]

        let request = UNNotificationRequest(
            identifier: offer.offerKey,
            content: content,
            trigger: nil // consegna immediata
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
