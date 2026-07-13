import SwiftUI

/// Profilo e impostazioni: raggio di ricerca, permessi, account.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var showLogoutConfirm = false
    @State private var groqKeyInput = ""
    @State private var keySaved = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                dataSourceSection
                radiusSection
                permissionsSection
                infoSection
            }
            .navigationTitle("Profilo")
            .onAppear {
                groqKeyInput = app.storedGroqKey
            }
        }
    }

    private var dataSourceSection: some View {
        Section {
            LabeledContent("Stato") {
                Text(app.realDataConfigured ? "Prezzi reali attivi" : "Non configurata")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(app.realDataConfigured ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundStyle(app.realDataConfigured ? .green : .orange)
                    .clipShape(Capsule())
            }
            SecureField("Chiave API Groq (gsk_...)", text: $groqKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(keySaved ? "Salvata ✓" : "Salva chiave") {
                app.updateGroqKey(groqKeyInput)
                keySaved = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    keySaved = false
                }
            }
            .disabled(groqKeyInput.trimmingCharacters(in: .whitespaces) == app.storedGroqKey)
            if !app.realDataConfigured {
                Toggle("Modalità demo (dati di esempio)", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: OfferProviderFactory.demoModeKey) },
                    set: { enabled in
                        UserDefaults.standard.set(enabled, forKey: OfferProviderFactory.demoModeKey)
                        Task { await app.refreshEverything() }
                    }
                ))
            }
        } header: {
            Text("Sorgente prezzi reali")
        } footer: {
            Text("Le offerte vengono cercate sul web nei volantini reali delle catene tramite Groq (modelli con ricerca web integrata). La chiave è salvata solo nel Keychain di questo dispositivo. Ottienila gratis su console.groq.com.")
        }
    }

    private var accountSection: some View {
        Section {
            if let user = app.auth.currentUser {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name).font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button("Esci", role: .destructive) {
                showLogoutConfirm = true
            }
            .confirmationDialog("Vuoi uscire dal tuo account?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Esci", role: .destructive) {
                    app.auth.logout()
                }
            }
        }
    }

    private var radiusSection: some View {
        Section {
            Picker("Raggio di ricerca", selection: Binding(
                get: { app.settings.radiusKm },
                set: { app.updateRadius($0) }
            )) {
                ForEach(AppSettings.radiusOptions, id: \.self) { km in
                    Text("\(Int(km)) km").tag(km)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Zona di ricerca")
        } footer: {
            Text("I supermercati e le offerte vengono cercati entro questo raggio dalla tua posizione. La zona si aggiorna automaticamente quando ti sposti.")
        }
    }

    private var permissionsSection: some View {
        Section {
            LabeledContent("Posizione") {
                permissionBadge(
                    granted: app.location.isAuthorized,
                    deniedText: app.location.isDenied ? "Negata" : "Da richiedere"
                )
            }
            LabeledContent("Notifiche") {
                permissionBadge(granted: app.notifications.isAuthorized, deniedText: "Disattivate")
            }
            if app.location.isDenied || !app.notifications.isAuthorized {
                Button("Apri Impostazioni di iOS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("Permessi")
        } footer: {
            Text("La posizione serve solo a trovare i supermercati fisici vicini. Le notifiche ti avvisano quando un prodotto monitorato entra in promozione: una sola notifica per offerta, mai spam.")
        }
    }

    private var infoSection: some View {
        Section {
            LabeledContent("Versione", value: "1.1.0")
            LabeledContent("Fonte offerte", value: app.realDataConfigured ? "Volantini GDO via Groq" : "Nessuna")
        } footer: {
            Text("Convenienza confronta esclusivamente i prezzi dei supermercati fisici presenti sul territorio. Nessun e-commerce, marketplace o negozio online.")
        }
    }

    private func permissionBadge(granted: Bool, deniedText: String) -> some View {
        Text(granted ? "Attiva" : deniedText)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(granted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(granted ? .green : .orange)
            .clipShape(Capsule())
    }
}
