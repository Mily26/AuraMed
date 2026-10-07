import SwiftUI
import SwiftData

@main
struct AuraMedApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var profile = Profile.shared

    init() {
        AuraFonts.registerBundledFonts()
        NotificationManager.shared.configure()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedDemo") {
            DemoData.seedIfEmpty()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .environmentObject(NotificationManager.shared)
                .preferredColorScheme(.light)
                .tint(Aura.primary)
        }
        .modelContainer(Store.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.reschedule()
                Task { await NotificationManager.shared.refreshAuthorization() }
            }
        }
    }
}
