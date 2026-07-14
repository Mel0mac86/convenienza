import SwiftUI

/// Radice dell'app: mostra login/registrazione oppure l'app vera e propria.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if app.auth.isAuthenticated {
            MainTabView()
                .transition(.opacity)
        } else {
            AuthView()
                .transition(.opacity)
        }
    }
}

/// Struttura a schede: Home (dashboard), Cerca, Offerte, Profilo.
struct MainTabView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            SearchView()
                .tabItem { Label("Cerca", systemImage: "magnifyingglass") }

            OffersView()
                .tabItem { Label("Offerte", systemImage: "tag.fill") }

            SettingsView()
                .tabItem { Label("Profilo", systemImage: "person.fill") }
        }
        .task {
            app.startServices()
            if app.location.authorizationStatus == .notDetermined {
                app.location.requestPermission()
            }
            if !app.notifications.isAuthorized {
                await app.notifications.requestPermission()
            }
        }
    }
}
