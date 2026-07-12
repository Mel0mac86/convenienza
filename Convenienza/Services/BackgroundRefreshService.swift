import Foundation
import BackgroundTasks
import SwiftData

/// Controllo periodico in background: iOS sveglia l'app a intervalli decisi dal
/// sistema, l'app controlla le offerte della zona per i prodotti monitorati e,
/// se trova nuove promozioni, invia le notifiche. L'utente riceve l'avviso senza
/// mai aprire l'app.
enum BackgroundRefreshService {
    static let taskIdentifier = "it.convenienza.app.refresh"

    /// Da chiamare al lancio dell'app, prima che termini `didFinishLaunching`.
    static func register(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask, container: container)
        }
    }

    /// Pianifica il prossimo controllo (circa ogni 4 ore, a discrezione di iOS).
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask, container: ModelContainer) {
        scheduleNext() // ripianifica subito il ciclo successivo

        guard let location = LocationService.storedLocation() else {
            task.setTaskCompleted(success: true)
            return
        }

        let radiusKm = AppSettings.storedRadiusKm()

        let work = Task { @MainActor in
            let engine = MonitoringEngine()
            await engine.runCheck(container: container, location: location, radiusKm: radiusKm)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
