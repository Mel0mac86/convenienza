import Foundation

/// Categorie merceologiche usate per classificare prodotti e filtrare le offerte.
enum ProductCategory: String, CaseIterable, Identifiable, Codable {
    case fruttaVerdura = "Frutta e Verdura"
    case latticini = "Latticini e Uova"
    case carne = "Carne e Pesce"
    case dispensa = "Dispensa"
    case surgelati = "Surgelati"
    case bevande = "Bevande"
    case colazione = "Colazione e Dolci"
    case cura = "Cura Persona"
    case casa = "Cura Casa"
    case altro = "Altro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fruttaVerdura: return "carrot"
        case .latticini: return "waterbottle"
        case .carne: return "fish"
        case .dispensa: return "takeoutbag.and.cup.and.straw"
        case .surgelati: return "snowflake"
        case .bevande: return "cup.and.saucer"
        case .colazione: return "birthday.cake"
        case .cura: return "heart.circle"
        case .casa: return "house.circle"
        case .altro: return "bag"
        }
    }

    /// Classificazione euristica a partire dal nome del prodotto.
    static func guess(from name: String) -> ProductCategory {
        let n = TrackedProduct.normalize(name)
        let map: [(ProductCategory, [String])] = [
            (.fruttaVerdura, ["mela", "banana", "pomodor", "insalata", "zucchin", "carot", "patat", "frutta", "verdura", "aranc", "limon", "pera", "uva", "kiwi", "melanzan", "pepero"]),
            (.latticini, ["latte", "yogurt", "formaggio", "mozzarella", "burro", "uova", "uovo", "parmigiano", "grana", "ricotta", "stracchino", "panna"]),
            (.carne, ["pollo", "manzo", "maiale", "prosciutto", "salame", "tonno", "salmone", "pesce", "carne", "wurstel", "bresaola", "tacchino", "gamber"]),
            (.dispensa, ["pasta", "riso", "olio", "sale", "farina", "zucchero", "passata", "pelati", "legumi", "fagioli", "ceci", "lenticchie", "aceto", "sugo", "conserva"]),
            (.surgelati, ["surgelat", "gelato", "pizza surgelata", "bastoncini", "minestrone"]),
            (.bevande, ["acqua", "vino", "birra", "succo", "cola", "aranciata", "the ", "tè", "spremuta", "bibita"]),
            (.colazione, ["biscott", "caffe", "caffè", "cereali", "merendin", "cioccolat", "nutella", "marmellata", "miele", "fette biscottate", "croissant", "brioche", "torta"]),
            (.cura, ["shampoo", "sapone", "dentifricio", "bagnoschiuma", "deodorante", "rasoi", "assorbent", "spazzolino"]),
            (.casa, ["detersivo", "ammorbidente", "candeggina", "carta igienica", "scottex", "sgrassatore", "sacchetti", "spugn", "piatti"]),
        ]
        for (category, keywords) in map where keywords.contains(where: { n.contains($0) }) {
            return category
        }
        return .altro
    }
}
