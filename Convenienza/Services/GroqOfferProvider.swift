import Foundation

/// Provider di offerte REALI basato su Groq.
///
/// Usa i modelli `groq/compound` (con ricerca web integrata lato server) per cercare
/// le promozioni realmente pubblicate nei volantini delle catene della GDO italiana
/// e le restituisce in JSON strutturato. Nessun dato inventato: se il modello non
/// trova riscontri online, il prodotto semplicemente non compare tra le offerte.
///
/// Accorgimenti per il piano gratuito di Groq (limiti di token/minuto):
/// - i prodotti vengono richiesti in piccoli lotti sequenziali;
/// - le risposte sono messe in cache per alcune ore (i volantini cambiano su base
///   settimanale, non serve richiedere più spesso);
/// - in caso di HTTP 429 la richiesta viene ritentata una volta dopo l'attesa
///   suggerita dal server.
struct GroqOfferProvider: OfferProvider {
    static let apiKeyKeychainKey = "groq.apiKey"

    let apiKey: String
    var model = "groq/compound"
    /// Validità della cache: 6 ore.
    var cacheTTL: TimeInterval = 6 * 3600
    /// Prodotti per singola richiesta (per restare nei limiti di token).
    var batchSize = 3

    private static let cachePrefix = "convenienza.groqCache."

    func fetchOffers(products: [String], chains: [SupermarketChain], city: String?) async throws -> [OfferDTO] {
        let realChains = chains.filter { $0 != .altra }
        guard !products.isEmpty, !realChains.isEmpty else { return [] }

        var offers: [OfferDTO] = []
        let batches = stride(from: 0, to: products.count, by: batchSize).map {
            Array(products[$0..<min($0 + batchSize, products.count)])
        }

        for batch in batches {
            if let cached = cachedResponse(for: batch, chains: realChains) {
                offers.append(contentsOf: parse(content: cached, requestedProducts: batch))
                continue
            }
            do {
                let content = try await requestOffers(products: batch, chains: realChains, city: city)
                storeCache(content, for: batch, chains: realChains)
                offers.append(contentsOf: parse(content: content, requestedProducts: batch))
            } catch {
                // Rate limit o errore di rete: restituisce quanto trovato finora,
                // i lotti rimanenti verranno riprovati al prossimo ciclo.
                break
            }
        }
        return offers
    }

    // MARK: - Chiamata API

    private enum GroqError: Error {
        case rateLimited
        case badResponse
    }

    private func requestOffers(products: [String], chains: [SupermarketChain], city: String?, isRetry: Bool = false) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 150
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateFormat = "d MMMM yyyy"
        let today = dateFormatter.string(from: .now)

        let systemPrompt = """
        Sei un motore di ricerca di offerte dei supermercati fisici italiani. \
        Cerca sul web (siti ufficiali delle catene e aggregatori di volantini come \
        volantinofacile, promoqui, doveconviene) le promozioni ATTIVE dei volantini di questa settimana. \
        Considera solo supermercati fisici: mai e-commerce, marketplace o negozi online. \
        Alla fine rispondi SOLO con JSON valido in questo formato esatto, senza testo aggiuntivo né markdown: \
        {"offers":[{"product":"query originale","label":"nome prodotto come nel volantino","chain":"Lidl","price":1.99,"previous_price":2.99,"starts_at":"2026-07-06","ends_at":"2026-07-19"}]} \
        Regole: "product" deve essere una delle query richieste, identica. "chain" deve essere una delle catene richieste. \
        "previous_price", "starts_at", "ends_at" possono essere null se non noti. I prezzi sono in euro. \
        Includi SOLO offerte di cui hai trovato riscontro reale online: se non trovi nulla per un prodotto, non includerlo. \
        Non inventare mai prezzi.
        """

        let userPrompt = """
        Oggi è \(today). Trova le offerte attive questa settimana nei volantini in Italia\(city.map { ", zona \($0)" } ?? "") \
        per questi prodotti: \(products.joined(separator: ", ")). \
        Catene da controllare: \(chains.map(\.rawValue).joined(separator: ", ")).
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "temperature": 0.2,
            "max_tokens": 3000,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GroqError.badResponse }

        if http.statusCode == 429 || isRateLimitBody(data) {
            guard !isRetry else { throw GroqError.rateLimited }
            let wait = retryDelay(from: http, data: data)
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            return try await requestOffers(products: products, chains: chains, city: city, isRetry: true)
        }

        guard http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.badResponse
        }
        return content
    }

    private func isRateLimitBody(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let code = error["code"] as? String else { return false }
        return code == "rate_limit_exceeded"
    }

    private func retryDelay(from response: HTTPURLResponse, data: Data) -> TimeInterval {
        if let header = response.value(forHTTPHeaderField: "retry-after"), let seconds = TimeInterval(header) {
            return min(seconds + 1, 60)
        }
        // Il messaggio d'errore di Groq contiene "Please try again in 11.03s".
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           let range = message.range(of: #"in (\d+(\.\d+)?)s"#, options: .regularExpression),
           let seconds = TimeInterval(message[range].dropFirst(3).dropLast(1)) {
            return min(seconds + 1, 60)
        }
        return 20
    }

    // MARK: - Parsing

    /// Estrae il JSON dalla risposta (tollera testo o code fence attorno) e valida le offerte.
    private func parse(content: String, requestedProducts: [String]) -> [OfferDTO] {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              start < end else { return [] }
        let jsonString = String(content[start...end])
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawOffers = root["offers"] as? [[String: Any]] else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.dateInterval(of: .weekOfYear, for: .now)
        let defaultStart = week?.start ?? .now
        let defaultEnd = week?.end ?? .now.addingTimeInterval(7 * 24 * 3600)

        let normalizedRequests = Dictionary(
            requestedProducts.map { (TrackedProduct.normalize($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return rawOffers.compactMap { raw -> OfferDTO? in
            guard let productRaw = raw["product"] as? String,
                  let label = raw["label"] as? String,
                  let chainRaw = raw["chain"] as? String,
                  let price = Self.double(raw["price"]),
                  price > 0, price < 500 else { return nil }

            // Riconduce la risposta a una delle query effettivamente richieste.
            let normalized = TrackedProduct.normalize(productRaw)
            guard let matchedQuery = normalizedRequests[normalized] ?? normalizedRequests.first(where: {
                normalized.contains($0.key) || $0.key.contains(normalized)
            })?.value else { return nil }

            let chain = SupermarketChain.detect(from: chainRaw)
            guard chain != .altra else { return nil }

            var previousPrice = Self.double(raw["previous_price"])
            if let previous = previousPrice, previous <= price { previousPrice = nil }

            let startsAt = (raw["starts_at"] as? String).flatMap { dateFormatter.date(from: $0) } ?? defaultStart
            let endsAt = (raw["ends_at"] as? String).flatMap { dateFormatter.date(from: $0) } ?? defaultEnd
            guard endsAt > .now else { return nil }

            return OfferDTO(
                productQuery: matchedQuery,
                productLabel: label,
                chain: chain,
                price: (price * 100).rounded() / 100,
                previousPrice: previousPrice.map { ($0 * 100).rounded() / 100 },
                startsAt: startsAt,
                endsAt: min(endsAt, .now.addingTimeInterval(60 * 24 * 3600))
            )
        }
    }

    private static func double(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    // MARK: - Cache

    private func cacheKey(for products: [String], chains: [SupermarketChain]) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)
        let signature = (products.map(TrackedProduct.normalize).sorted() + chains.map(\.rawValue).sorted())
            .joined(separator: "|")
        return Self.cachePrefix + "\(year)-W\(week)." + String(StableHash.fnv1a(signature), radix: 16, uppercase: false)
    }

    private func cachedResponse(for products: [String], chains: [SupermarketChain]) -> String? {
        let key = cacheKey(for: products, chains: chains)
        guard let entry = UserDefaults.standard.dictionary(forKey: key),
              let savedAt = entry["savedAt"] as? TimeInterval,
              let content = entry["content"] as? String,
              Date.now.timeIntervalSince1970 - savedAt < cacheTTL else { return nil }
        return content
    }

    private func storeCache(_ content: String, for products: [String], chains: [SupermarketChain]) {
        let key = cacheKey(for: products, chains: chains)
        UserDefaults.standard.set(
            ["savedAt": Date.now.timeIntervalSince1970, "content": content],
            forKey: key
        )
    }
}
