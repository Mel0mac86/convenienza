import Foundation
import CoreLocation

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    static func price(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? String(format: "€ %.2f", value)
    }

    static func distance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        }
        return String(format: "%.1f km", meters / 1000).replacingOccurrences(of: ".", with: ",")
    }

    static func expiry(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if date < .now { return "Scaduta" }
        if Calendar.current.isDateInToday(date) { return "Scade oggi" }
        if Calendar.current.isDateInTomorrow(date) { return "Scade domani" }
        if days <= 6 { return "Scade tra \(days) giorni" }
        return "Fino al \(shortDate.string(from: date))"
    }
}
