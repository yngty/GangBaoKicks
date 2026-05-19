import SwiftUI

@main
struct GangBaoKicksApp: App {
    @StateObject private var store = KickStore()
    @StateObject private var syncService = WatchSyncService()
    @StateObject private var themeController = ThemeController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(syncService)
                .environmentObject(themeController)
                .preferredColorScheme(themeController.colorSchemePreference.preferredColorScheme)
                .onAppear {
                    syncService.configure(store: store)
                }
        }
    }
}
