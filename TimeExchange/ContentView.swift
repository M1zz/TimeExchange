import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var board = BoardState()

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
    }
}
