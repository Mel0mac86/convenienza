import Foundation
import CryptoKit
import Observation

/// Errori di autenticazione con messaggi in italiano pronti per la UI.
enum AuthError: LocalizedError {
    case emailInvalid
    case passwordTooShort
    case nameMissing
    case emailAlreadyRegistered
    case wrongCredentials

    var errorDescription: String? {
        switch self {
        case .emailInvalid: return "Inserisci un indirizzo email valido."
        case .passwordTooShort: return "La password deve avere almeno 8 caratteri."
        case .nameMissing: return "Inserisci il tuo nome."
        case .emailAlreadyRegistered: return "Esiste già un account con questa email. Prova ad accedere."
        case .wrongCredentials: return "Email o password non corretti."
        }
    }
}

/// Autenticazione locale: gli account sono salvati sul dispositivo con password
/// salata e hashata (SHA-256). L'interfaccia è async per poter sostituire in futuro
/// questo servizio con un backend remoto senza toccare le viste.
@Observable
final class AuthService {
    private(set) var currentUser: User?

    private let defaults = UserDefaults.standard
    private let accountsKey = "convenienza.accounts"
    private let sessionKey = "convenienza.session.email"

    var isAuthenticated: Bool { currentUser != nil }

    init() {
        restoreSession()
    }

    func register(name: String, email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AuthError.nameMissing }
        guard Self.isValidEmail(email) else { throw AuthError.emailInvalid }
        guard password.count >= 8 else { throw AuthError.passwordTooShort }

        var accounts = loadAccounts()
        guard accounts[email] == nil else { throw AuthError.emailAlreadyRegistered }

        let salt = UUID().uuidString
        let user = User(name: name, email: email, createdAt: .now)
        accounts[email] = StoredCredential(user: user, salt: salt, passwordHash: Self.hash(password: password, salt: salt))
        saveAccounts(accounts)

        currentUser = user
        defaults.set(email, forKey: sessionKey)
    }

    func login(email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let credential = loadAccounts()[email],
              credential.passwordHash == Self.hash(password: password, salt: credential.salt) else {
            throw AuthError.wrongCredentials
        }
        currentUser = credential.user
        defaults.set(email, forKey: sessionKey)
    }

    func logout() {
        currentUser = nil
        defaults.removeObject(forKey: sessionKey)
    }

    // MARK: - Private

    private func restoreSession() {
        guard let email = defaults.string(forKey: sessionKey),
              let credential = loadAccounts()[email] else { return }
        currentUser = credential.user
    }

    private func loadAccounts() -> [String: StoredCredential] {
        guard let data = defaults.data(forKey: accountsKey),
              let accounts = try? JSONDecoder().decode([String: StoredCredential].self, from: data) else {
            return [:]
        }
        return accounts
    }

    private func saveAccounts(_ accounts: [String: StoredCredential]) {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: accountsKey)
        }
    }

    private static func hash(password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".") && email.count >= 5 && !email.contains(" ")
    }
}
