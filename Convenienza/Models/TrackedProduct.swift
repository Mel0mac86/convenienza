import Foundation
import SwiftData

/// Un prodotto che l'utente sta monitorando.
/// Viene creato automaticamente quando l'utente cerca un prodotto.
@Model
final class TrackedProduct {
    @Attribute(.unique) var normalizedName: String
    var displayName: String
    var categoryRaw: String
    var createdAt: Date
    var isActive: Bool

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .altro }
        set { categoryRaw = newValue.rawValue }
    }

    init(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = trimmed
        self.normalizedName = Self.normalize(trimmed)
        self.categoryRaw = ProductCategory.guess(from: trimmed).rawValue
        self.createdAt = .now
        self.isActive = true
    }

    static func normalize(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
