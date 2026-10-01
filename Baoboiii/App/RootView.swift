import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "baoboiii",
                systemImage: "character.bubble",
                description: Text("Việt hoá toàn màn hình. Đang xây dựng…")
            )
        }
    }
}
