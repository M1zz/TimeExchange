import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var board = BoardState()
    @AppStorage("didSeedDemo") private var didSeedDemo = false

    var body: some View {
        TabView {
            LoomView()
                .tabItem { Label("색칠판", systemImage: "square.grid.3x3.fill") }
            WeeklyReadingView()
                .tabItem { Label("주간 읽기", systemImage: "text.alignleft") }
            AssetsView()
                .tabItem { Label("자산", systemImage: "leaf") }
            ConceptView()
                .tabItem { Label("개념", systemImage: "book") }
            SettingsView()
                .tabItem { Label("환율", systemImage: "slider.horizontal.3") }
        }
        .environment(board)
        .task {
            guard !didSeedDemo else { return }
            didSeedDemo = true
            if let focus = SeedData.install(into: context) { board.monday = focus }
        }
    }
}
