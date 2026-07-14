import SwiftUI

/// Schermata di accesso e registrazione, minimale e in un solo passaggio.
struct AuthView: View {
    @Environment(AppState.self) private var app

    @State private var isRegistering = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 12) {
                        if isRegistering {
                            TextField("Nome", text: $name)
                                .textContentType(.name)
                                .authFieldStyle()
                        }
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .authFieldStyle()
                        SecureField("Password", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)
                            .authFieldStyle()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: submit) {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(isRegistering ? "Crea account" : "Accedi")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)

                    Button {
                        withAnimation { isRegistering.toggle() }
                        errorMessage = nil
                    } label: {
                        Text(isRegistering
                             ? "Hai già un account? Accedi"
                             : "Non hai un account? Registrati")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .padding(24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Convenienza")
                .font(.largeTitle.bold())
            Text("Le offerte dei supermercati vicino a te,\nsolo quando conviene davvero.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                if isRegistering {
                    try await app.auth.register(name: name, email: email, password: password)
                } else {
                    try await app.auth.login(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension View {
    func authFieldStyle() -> some View {
        self
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
