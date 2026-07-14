import Foundation

/// Profilo utente autenticato.
struct User: Codable, Equatable {
    var name: String
    var email: String
    var createdAt: Date
}

/// Credenziali memorizzate localmente (password salata e hashata, mai in chiaro).
struct StoredCredential: Codable {
    var user: User
    var salt: String
    var passwordHash: String
}
