import SwiftUI

struct RootView: View {
    @State private var tab = "home"

    var body: some View {
        TabView(selection: $tab) {
            Tab("Dịch", systemImage: "character.bubble", value: "home") {
                HomeView()
            }
            Tab("Lịch sử", systemImage: "clock.arrow.circlepath", value: "history") {
                HistoryView()
            }
            Tab("Hướng dẫn", systemImage: "questionmark.circle", value: "guide") {
                GuideView()
            }
            Tab("Cài đặt", systemImage: "gearshape", value: "settings") {
                SettingsView()
            }
        }
    }
}
