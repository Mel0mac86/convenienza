import SwiftUI
import SwiftData

@main
struct ConvenienzaApp: App {
    private let container: ModelContainer
    @State private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: TrackedProduct.self, OfferRecord.self, PricePoint.self)
        } catch {
            fatalError("Impossibile inizializzare il database: \(error)")
        }
        self.container = container
        _appState = State(initialValue: AppState(container: container))

        // La registrazione dei task in background deve avvenire al lancio.
        BackgroundRefreshService.register(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.green)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                appState.startServices()
            case .background:
                BackgroundRefreshService.scheduleNext()
            default:
                break
            }
        }
    }
}
