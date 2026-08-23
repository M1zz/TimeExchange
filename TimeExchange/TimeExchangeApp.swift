import SwiftUI
import SwiftData

@main
struct TimeExchangeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Exchange.self)
    }
}
