import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "clock") }
            HistoryView()
                .tabItem { Label("거래내역", systemImage: "list.bullet.rectangle") }
            SettingsView()
                .tabItem { Label("환율", systemImage: "slider.horizontal.3") }
        }
    }
}
