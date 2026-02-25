

import SwiftUI

@main
struct creatorshub_frontendApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(UserSession.shared)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
